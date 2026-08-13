import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'release_version.dart';
import 'release_file_transaction.dart';

/// 自动分配下一版本、构建并验真 Android release APK。
///
/// 默认执行 `patch + 1` 与 `versionCode + 1`。只有正式签名 APK 通过元数据和
/// 签名验证后才写回 `pubspec.yaml`；`--allow-unsigned-compile-check` 只做编译
/// 检查，既不递增持久版本，也不生成正式发布制品。
Future<void> main(List<String> arguments) async {
  try {
    final options = _BuildOptions.parse(arguments);
    final projectRoot = _findProjectRoot(Directory.current);
    final runner = _ReleaseBuildRunner(projectRoot, options);
    await runner.run();
  } on _UsageException catch (error) {
    if (error.message.isNotEmpty) stderr.writeln('参数错误：${error.message}');
    stderr.writeln(_BuildOptions.usage);
    exitCode = error.exitCode;
  } on Object catch (error) {
    stderr.writeln('发布构建失败：$error');
    exitCode = 1;
  }
}

/// 运行一次有工作区排他锁的 release 构建事务。
final class _ReleaseBuildRunner {
  _ReleaseBuildRunner(this.projectRoot, this.options);

  final Directory projectRoot;
  final _BuildOptions options;

  File get _pubspec => File(_join(projectRoot.path, 'pubspec.yaml'));
  File get _lockFile =>
      File(_join(projectRoot.path, '.dart_tool', 'release_build.lock'));
  File get _localProperties =>
      File(_join(projectRoot.path, 'android', 'local.properties'));

  RandomAccessFile? _lockHandle;
  List<int>? _localPropertiesSnapshot;
  bool _localPropertiesExisted = false;
  bool _localPropertiesWasSnapshotted = false;

  /// 执行预检、构建、验真和持久版本提交，并保证临时状态最终被清理。
  Future<void> run() async {
    await _acquireLock();
    try {
      final originalPubspecBytes = await _pubspec.readAsBytes();
      final originalPubspec = utf8.decode(originalPubspecBytes);
      final document = parsePubspecVersion(originalPubspec);
      final candidate = options.allowUnsignedCompileCheck
          ? document.version
          : options.resolveCandidate(document.version);

      stdout.writeln('当前版本：${document.version.pubspecValue}');
      if (options.allowUnsignedCompileCheck) {
        stdout.writeln('编译检查版本：${candidate.pubspecValue}（不递增）');
      } else if (options.localBuild) {
        stdout.writeln('本地安装包版本：${candidate.pubspecValue}');
      } else {
        stdout.writeln('本次构建：${candidate.pubspecValue}');
      }
      if (options.dryRun) {
        stdout.writeln('Dry run：未启动 Flutter，未修改任何版本文件。');
        return;
      }

      await _validateStableApplicationId();
      if (!options.allowUnsignedCompileCheck && !options.localBuild) {
        await _validateProductionMode();
        options.validateProductionDefines();
        final expectedSignerDigest =
            await _validateReleaseSigningConfiguration();
        _expectedSignerDigest = expectedSignerDigest;
      } else {
        await _validateUnsignedCompileCheckConfiguration();
      }
      await _snapshotLocalProperties();
      await _runFlutterBuild(candidate);
      final artifact = await _locateFreshArtifact(candidate);
      await _verifyApkMetadata(artifact, candidate);

      if (options.allowUnsignedCompileCheck) {
        await _verifyApkIsUnsigned(artifact);
        stdout.writeln('未签名 release 编译检查通过：${artifact.path}');
        stdout.writeln('编译检查不会修改 pubspec.yaml，也不能用于生产 OTA。');
        return;
      }

      if (options.localBuild) {
        await _verifyApkHasAnySignature(artifact);
      } else {
        await _verifyApkSignature(artifact);
      }
      final currentPubspecBytes = await _pubspec.readAsBytes();
      if (!_bytesEqual(currentPubspecBytes, originalPubspecBytes)) {
        throw StateError('构建期间 pubspec.yaml 已被其它操作修改，拒绝覆盖');
      }
      // 在版本与正式制品提交前恢复 Flutter 的本地缓存，避免提交成功后清理失败
      // 被外层误判为“发布失败”并触发盲目重试。
      await _restoreLocalProperties();
      final releaseArtifact = await _copyReleaseArtifact(
        artifact,
        candidate,
        localBuild: options.localBuild,
      );
      try {
        await _replacePubspecAtomically(
          utf8.encode(document.replaceVersion(candidate)),
          originalPubspecBytes,
        );
      } on Object {
        await _deleteReleaseArtifact(releaseArtifact);
        rethrow;
      }
      stdout.writeln(
        options.localBuild
            ? '本地安装包构建成功：${releaseArtifact.path}'
            : '发布构建成功：${releaseArtifact.path}',
      );
      stdout.writeln('pubspec.yaml 已更新为 ${candidate.pubspecValue}');
      if (options.localBuild) {
        stdout.writeln('注意：该 APK 使用 debug 证书，只用于本机/设备测试，不能用于生产 OTA。');
      }
    } finally {
      try {
        await _restoreLocalProperties();
      } finally {
        await _releaseLock();
      }
    }
  }

  /// 使用锁文件句柄阻止同一工作区同时分配或构建两个版本。
  Future<void> _acquireLock() async {
    await _lockFile.parent.create(recursive: true);
    try {
      _lockHandle = await _lockFile.open(mode: FileMode.append);
      await _lockHandle!.lock(
        Platform.isWindows ? FileLock.exclusive : FileLock.blockingExclusive,
      );
      await _lockHandle!.setPosition(0);
      await _lockHandle!.truncate(0);
      await _lockHandle!.writeString('$pid\n');
      await _lockHandle!.flush();
    } on FileSystemException {
      await _lockHandle?.close();
      _lockHandle = null;
      throw StateError('已有发布构建正在运行：${_lockFile.path}');
    }
  }

  /// 关闭锁句柄并删除当前事务创建的锁文件。
  Future<void> _releaseLock() async {
    final handle = _lockHandle;
    _lockHandle = null;
    if (handle != null) {
      await handle.setPosition(0);
      await handle.truncate(0);
      await handle.unlock();
      await handle.close();
    }
  }

  /// 正式构建前确认签名属性、keystore 文件和冻结的发布基线完整。
  Future<String> _validateReleaseSigningConfiguration() async {
    final propertiesFile = File(
      _join(projectRoot.path, 'android', 'key.properties'),
    );
    if (!await propertiesFile.exists()) {
      throw StateError(
        '缺少 android/key.properties；正式 release 必须配置稳定证书。'
        '如仅验证编译，请使用 --allow-unsigned-compile-check',
      );
    }
    final properties = _parseProperties(await propertiesFile.readAsString());
    for (final key in const <String>[
      'storeFile',
      'storePassword',
      'keyAlias',
      'keyPassword',
      'certificateSha256',
      'applicationId',
    ]) {
      if ((properties[key] ?? '').trim().isEmpty) {
        throw StateError('android/key.properties 缺少 $key');
      }
    }
    final expectedDigest = _normalizedSha256(properties['certificateSha256']!);
    if (expectedDigest == null) {
      throw StateError(
        'android/key.properties 的 certificateSha256 必须为 64 位 SHA-256',
      );
    }
    final pinnedApplicationId = properties['applicationId']!.trim();
    if (pinnedApplicationId != _expectedApplicationId) {
      throw StateError('Android applicationId 与 key.properties 固定的生产包名不一致');
    }
    final storePath = properties['storeFile']!;
    final storeFile = File(
      _isAbsoluteWindowsPath(storePath)
          ? storePath
          : _join(projectRoot.path, 'android', 'app', storePath),
    );
    if (!await storeFile.exists()) {
      throw StateError('release keystore 文件不存在（路径已隐藏）');
    }

    return expectedDigest;
  }

  /// 阻止业务测试旁路被误打入正式 OTA 包。
  Future<void> _validateProductionMode() async {
    final configFile = File(
      _join(
        projectRoot.path,
        'lib',
        'src',
        'core',
        'config',
        'app_config.dart',
      ),
    );
    final source = await configFile.readAsString();
    final currentConfig = RegExp(
      r'static const AppConfig current\s*=\s*AppConfig\([\s\S]*?\n\s*\);',
    ).firstMatch(source)?.group(0);
    final assignments = currentConfig == null
        ? const <RegExpMatch>[]
        : RegExp(
            r'^\s*isTestMode\s*:\s*(true|false)\s*,\s*$',
            multiLine: true,
          ).allMatches(currentConfig).toList();
    if (assignments.length != 1 || assignments.single.group(1) != 'false') {
      throw StateError(
        '正式 release 要求 AppConfig.current.isTestMode 明确为 false；'
        '当前只能使用 --allow-unsigned-compile-check',
      );
    }
  }

  /// 阻止示例包名被误认为可以原位升级的正式应用标识。
  Future<void> _validateStableApplicationId() async {
    final gradleFile = File(
      _join(projectRoot.path, 'android', 'app', 'build.gradle.kts'),
    );
    final source = await gradleFile.readAsString();
    final applicationId = RegExp(
      r'applicationId\s*=\s*"([^"]+)"',
    ).firstMatch(source)?.group(1);
    if (applicationId == null || applicationId.isEmpty) {
      throw StateError('无法读取 Android applicationId');
    }
    if (!options.allowUnsignedCompileCheck &&
        !options.localBuild &&
        applicationId.startsWith('com.example.')) {
      throw StateError(
        '正式 release 仍使用示例 applicationId：$applicationId；'
        '首次生产安装前必须冻结正式包名',
      );
    }
    _expectedApplicationId = applicationId;
  }

  String? _expectedApplicationId;
  String? _expectedSignerDigest;

  /// 未签名模式只允许在完全没有 release 签名配置时使用。
  Future<void> _validateUnsignedCompileCheckConfiguration() async {
    final propertiesFile = File(
      _join(projectRoot.path, 'android', 'key.properties'),
    );
    if (await propertiesFile.exists()) {
      throw StateError(
        '检测到 android/key.properties；请移除 --allow-unsigned-compile-check '
        '并执行正式发布构建',
      );
    }
  }

  /// 保存 Flutter 可能改写的本地构建缓存，事务结束时恢复现场状态。
  Future<void> _snapshotLocalProperties() async {
    _localPropertiesWasSnapshotted = true;
    _localPropertiesExisted = await _localProperties.exists();
    if (_localPropertiesExisted) {
      _localPropertiesSnapshot = await _localProperties.readAsBytes();
    }
  }

  /// 恢复构建前的 `android/local.properties`，避免命令行候选版本泄漏到后续 Gradle 构建。
  Future<void> _restoreLocalProperties() async {
    if (!_localPropertiesWasSnapshotted) {
      return;
    }
    if (_localPropertiesSnapshot != null) {
      await _localProperties.writeAsBytes(
        _localPropertiesSnapshot!,
        flush: true,
      );
    } else if (!_localPropertiesExisted && await _localProperties.exists()) {
      await _localProperties.delete();
    }
    _localPropertiesWasSnapshotted = false;
    _localPropertiesSnapshot = null;
    _localPropertiesExisted = false;
  }

  /// 从项目根目录运行 Flutter，并显式传入由当前 pubspec 派生的候选版本。
  Future<void> _runFlutterBuild(AppReleaseVersion candidate) async {
    final flutter = _findExecutable('flutter.bat');
    final startedAt = DateTime.now();
    final buildMode = options.localBuild ? 'debug' : 'release';
    stdout.writeln('开始 Flutter $buildMode 构建……');
    final process = await Process.start(
      flutter,
      <String>[
        'build',
        'apk',
        '--$buildMode',
        '--no-pub',
        '--build-name=${candidate.versionName}',
        '--build-number=${candidate.versionCode}',
        ...options.flutterDefineArguments,
      ],
      workingDirectory: projectRoot.path,
      mode: ProcessStartMode.inheritStdio,
      runInShell: false,
    );
    final result = await process.exitCode;
    if (result != 0) {
      throw ProcessException(flutter, const [], 'Flutter 构建失败', result);
    }
    _buildStartedAt = startedAt;
  }

  DateTime? _buildStartedAt;

  /// 根据 Gradle 输出元数据定位本次新生成的唯一 APK。
  Future<File> _locateFreshArtifact(AppReleaseVersion candidate) async {
    final buildMode = options.localBuild ? 'debug' : 'release';
    final outputDirectory = Directory(
      _join(projectRoot.path, 'build', 'app', 'outputs', 'apk', buildMode),
    );
    final metadataFile = File(
      _join(outputDirectory.path, 'output-metadata.json'),
    );
    if (!await metadataFile.exists()) {
      throw StateError('缺少 $buildMode output-metadata.json');
    }
    final metadata = jsonDecode(await metadataFile.readAsString());
    if (metadata is! Map<String, Object?>) {
      throw StateError('$buildMode 输出元数据格式错误');
    }
    final elements = metadata['elements'];
    if (elements is! List || elements.length != 1 || elements.single is! Map) {
      throw StateError('$buildMode 输出必须且只能包含一个 APK');
    }
    final element = Map<String, Object?>.from(elements.single as Map);
    if (element['versionName'] != candidate.versionName ||
        element['versionCode'] != candidate.versionCode) {
      throw StateError('$buildMode 输出元数据版本与候选版本不一致');
    }
    final outputFile = element['outputFile'];
    if (outputFile is! String || outputFile.isEmpty) {
      throw StateError('$buildMode 输出缺少 APK 文件名');
    }
    final artifact = File(_join(outputDirectory.path, outputFile));
    if (!await artifact.exists()) throw StateError('$buildMode APK 不存在');
    final startedAt = _buildStartedAt!;
    if ((await artifact.lastModified()).isBefore(
      startedAt.subtract(const Duration(seconds: 2)),
    )) {
      throw StateError('$buildMode APK 不是本次构建生成的产物');
    }
    return artifact;
  }

  /// 通过 Android `aapt` 复核 APK 包名、versionName 与 versionCode。
  Future<void> _verifyApkMetadata(
    File artifact,
    AppReleaseVersion candidate,
  ) async {
    final aapt = _findLatestAndroidBuildTool('aapt.exe');
    final result = await Process.run(
      aapt,
      <String>['dump', 'badging', artifact.path],
      workingDirectory: projectRoot.path,
      runInShell: false,
    );
    if (result.exitCode != 0) throw StateError('aapt 无法读取本次 APK');
    final firstLine =
        LineSplitter.split(result.stdout as String).firstOrNull ?? '';
    final packageMatch = RegExp(
      r"^package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'",
    ).firstMatch(firstLine);
    if (packageMatch == null ||
        packageMatch.group(1) != _expectedApplicationId ||
        packageMatch.group(2) != '${candidate.versionCode}' ||
        packageMatch.group(3) != candidate.versionName) {
      throw StateError('APK 包名或版本元数据校验失败');
    }
  }

  /// 使用 Android `apksigner` 验证正式 APK 确实带有可用签名。
  Future<void> _verifyApkSignature(File artifact) async {
    final apksigner = _findLatestAndroidBuildTool(
      _join('lib', 'apksigner.jar'),
    );
    final java = _join(_findJavaHome(), 'bin', 'java.exe');
    final result = await Process.run(
      java,
      <String>[
        '-jar',
        apksigner,
        'verify',
        '--verbose',
        '--print-certs',
        artifact.path,
      ],
      workingDirectory: projectRoot.path,
      runInShell: false,
    );
    if (result.exitCode != 0) throw StateError('APK 签名验证失败');
    final output = '${result.stdout}\n${result.stderr}';
    final signerMatches = RegExp(
      r"Signer #\d+ certificate SHA-256 digest: ([0-9a-fA-F: ]+)",
    ).allMatches(output).toList(growable: false);
    final actualDigests = signerMatches
        .map((match) => _normalizedSha256(match.group(1)!))
        .whereType<String>()
        .toList(growable: false);
    if (actualDigests.length != 1 ||
        actualDigests.single != _expectedSignerDigest) {
      throw StateError('APK 签名证书与 key.properties 固定的 SHA-256 指纹不一致');
    }
  }

  /// 本地安装包只要求存在可安装签名，不把 debug 证书误认为生产签名基线。
  Future<void> _verifyApkHasAnySignature(File artifact) async {
    final apksigner = _findLatestAndroidBuildTool(
      _join('lib', 'apksigner.jar'),
    );
    final java = _join(_findJavaHome(), 'bin', 'java.exe');
    final result = await Process.run(
      java,
      <String>['-jar', apksigner, 'verify', artifact.path],
      workingDirectory: projectRoot.path,
      runInShell: false,
    );
    if (result.exitCode != 0) {
      throw StateError('本地安装包没有可用签名');
    }
  }

  /// 未签名检查模式必须拒绝任何意外签名产物，避免与正式发布语义混淆。
  Future<void> _verifyApkIsUnsigned(File artifact) async {
    final apksigner = _findLatestAndroidBuildTool(
      _join('lib', 'apksigner.jar'),
    );
    final java = _join(_findJavaHome(), 'bin', 'java.exe');
    final result = await Process.run(
      java,
      <String>['-jar', apksigner, 'verify', artifact.path],
      workingDirectory: projectRoot.path,
      runInShell: false,
    );
    if (result.exitCode == 0) {
      throw StateError('未签名编译检查意外生成了已签名 APK，拒绝继续');
    }
    final output = '${result.stdout}\n${result.stderr}'.toLowerCase();
    if (!output.contains('does not verify') &&
        !output.contains('missing meta-inf/manifest.mf') &&
        !output.contains('not signed')) {
      throw StateError('无法确认编译检查 APK 是否未签名');
    }
  }

  /// 把已验真的 APK 复制为不可覆盖、带版本号的发布制品并生成 SHA-256。
  Future<File> _copyReleaseArtifact(
    File artifact,
    AppReleaseVersion candidate, {
    required bool localBuild,
  }) async {
    final releases = Directory(_join(projectRoot.path, 'build', 'releases'));
    await releases.create(recursive: true);
    final target = File(
      _join(
        releases.path,
        'smart-cabinet-${candidate.versionName}+${candidate.versionCode}'
        '${localBuild ? '-local' : ''}.apk',
      ),
    );
    if (await target.exists()) {
      throw StateError('同版本发布制品已存在，拒绝覆盖：${target.path}');
    }
    final partial = File('${target.path}.part');
    final sha256File = File('${target.path}.sha256');
    final md5File = File('${target.path}.md5');
    final sha256Partial = File('${sha256File.path}.part');
    final md5Partial = File('${md5File.path}.part');
    for (final file in <File>[
      partial,
      sha256File,
      md5File,
      sha256Partial,
      md5Partial,
    ]) {
      if (await file.exists()) {
        throw StateError('发现同版本残留制品，请人工核对后处理：${file.path}');
      }
    }
    try {
      await artifact.copy(partial.path);
      final sha256Digest = await _digestOf(partial, sha256);
      final md5Digest = await _digestOf(partial, md5);
      await sha256Partial.writeAsString(
        '$sha256Digest  ${_basename(target.path)}\n',
        flush: true,
      );
      await md5Partial.writeAsString(
        '$md5Digest  ${_basename(target.path)}\n',
        flush: true,
      );
      await partial.rename(target.path);
      await sha256Partial.rename(sha256File.path);
      await md5Partial.rename(md5File.path);
      return target;
    } on Object {
      for (final file in <File>[
        sha256Partial,
        md5Partial,
        sha256File,
        md5File,
        target,
        partial,
      ]) {
        if (await file.exists()) {
          await file.delete();
        }
      }
      rethrow;
    }
  }

  /// 版本提交失败时删除尚未发布的归档，避免下一次重试被同名候选阻塞。
  Future<void> _deleteReleaseArtifact(File artifact) async {
    for (final extension in const <String>['.sha256', '.md5']) {
      final digestFile = File('${artifact.path}$extension');
      if (await digestFile.exists()) {
        await digestFile.delete();
      }
    }
    if (await artifact.exists()) {
      await artifact.delete();
    }
  }

  /// 使用同目录临时文件和 Windows 原子替换提交版本，避免写出半个 pubspec。
  Future<void> _replacePubspecAtomically(
    List<int> replacement,
    List<int> original,
  ) async {
    final temporary = File(
      '${_pubspec.path}.release-${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    final backup = File('${temporary.path}.backup');
    await temporary.writeAsBytes(replacement, flush: true);
    var replaced = false;
    var safeToDeleteBackup = false;
    try {
      // 在真正提交前再次比较，缩短从并发检查到替换之间的 TOCTOU 窗口。
      if (!_bytesEqual(await _pubspec.readAsBytes(), original)) {
        throw StateError('提交版本前 pubspec.yaml 已被其它操作修改，拒绝覆盖');
      }
      if (Platform.isWindows) {
        final result = await replaceWindowsFile(
          source: temporary.path,
          destination: _pubspec.path,
          backup: backup.path,
        );
        if (result.exitCode != 0) {
          throw StateError('无法原子更新 pubspec.yaml');
        }
        replaced = true;
      } else {
        await temporary.rename(_pubspec.path);
        replaced = true;
      }
      if (!_bytesEqual(await _pubspec.readAsBytes(), replacement)) {
        if (Platform.isWindows && await backup.exists()) {
          final failedReplacement = File('${temporary.path}.failed');
          await replaceWindowsFile(
            source: backup.path,
            destination: _pubspec.path,
            backup: failedReplacement.path,
          );
          if (await failedReplacement.exists()) {
            await failedReplacement.delete();
          }
        }
        final restored = _bytesEqual(await _pubspec.readAsBytes(), original);
        if (!restored) {
          throw StateError('pubspec.yaml 写入校验失败，备份保留于 ${backup.path}');
        }
        safeToDeleteBackup = true;
        throw StateError('pubspec.yaml 写入后校验失败，已恢复原内容');
      }
      safeToDeleteBackup = true;
    } finally {
      if (await temporary.exists()) await temporary.delete();
      if ((!replaced || safeToDeleteBackup) && await backup.exists()) {
        await backup.delete();
      }
    }
  }
}

/// 解析构建模式和可选的人工 major/minor 跳版参数。
final class _BuildOptions {
  const _BuildOptions({
    required this.allowUnsignedCompileCheck,
    required this.localBuild,
    required this.dryRun,
    this.versionName,
    this.versionCode,
    required this.productionDefines,
  });

  final bool allowUnsignedCompileCheck;
  final bool localBuild;
  final bool dryRun;
  final String? versionName;
  final int? versionCode;
  final Map<String, String> productionDefines;

  static const String usage = '''
用法：
  dart run tool/build_release.dart --dry-run
  dart run tool/build_release.dart --local-build
  dart run tool/build_release.dart `
    --dart-define=AFRR_HOST=10.0.0.1 `
    --dart-define=AFRR_PORT=16666 `
    --dart-define=AFRR_SHELF_CODE=123456789012345 `
    --dart-define=DEVICE_IMEI=123456789012345 `
    --dart-define=STUM_DP=10.0.0.1 `
    --dart-define=STUM_VERSION_DATE=20260812
  dart run tool/build_release.dart --allow-unsigned-compile-check

默认正式构建会把 patch 和 versionCode 各加 1，并在验签通过后更新 pubspec.yaml。
--local-build 用于本机安装测试，同样自动加 1，但生成 debug 签名 APK，不能用于生产 OTA。
PowerShell 多行命令必须在每个待续行末尾保留反引号 `，也可复制为同一行执行。
未签名编译检查不会修改 pubspec.yaml，也不能用于生产 OTA。''';

  /// 只接受明确支持的参数组合，避免未知参数被静默忽略。
  factory _BuildOptions.parse(List<String> arguments) {
    var allowUnsigned = false;
    var localBuild = false;
    var dryRun = false;
    String? versionName;
    int? versionCode;
    final productionDefines = <String, String>{};
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (argument.startsWith('--dart-define=')) {
        _addProductionDefine(
          productionDefines,
          argument.substring('--dart-define='.length),
        );
        continue;
      }
      switch (argument) {
        case '--help':
        case '-h':
          throw const _UsageException('', exitCode: 0);
        case '--allow-unsigned-compile-check':
          allowUnsigned = true;
        case '--local-build':
          localBuild = true;
        case '--dry-run':
          dryRun = true;
        case '--version-name':
          if (++index >= arguments.length) {
            throw const _UsageException('--version-name 缺少值');
          }
          versionName = arguments[index];
        case '--version-code':
          if (++index >= arguments.length) {
            throw const _UsageException('--version-code 缺少值');
          }
          versionCode = int.tryParse(arguments[index]);
          if (versionCode == null) {
            throw const _UsageException('--version-code 必须是整数');
          }
        case '--dart-define':
          if (++index >= arguments.length) {
            throw const _UsageException('--dart-define 缺少 KEY=VALUE');
          }
          _addProductionDefine(productionDefines, arguments[index]);
        default:
          throw _UsageException('未知参数：$argument');
      }
    }
    if ((versionName == null) != (versionCode == null)) {
      throw const _UsageException('--version-name 与 --version-code 必须一起提供');
    }
    if (allowUnsigned && (versionName != null || versionCode != null)) {
      throw const _UsageException('未签名编译检查不能预留人工指定版本');
    }
    if (allowUnsigned && localBuild) {
      throw const _UsageException(
        '--local-build 不能与 --allow-unsigned-compile-check 同时使用',
      );
    }
    return _BuildOptions(
      allowUnsignedCompileCheck: allowUnsigned,
      localBuild: localBuild,
      dryRun: dryRun,
      versionName: versionName,
      versionCode: versionCode,
      productionDefines: productionDefines,
    );
  }

  /// 解析单个 `KEY=VALUE`，同时供空格格式和等号格式的参数使用。
  static void _addProductionDefine(
    Map<String, String> definitions,
    String definition,
  ) {
    final separator = definition.indexOf('=');
    if (separator <= 0 || separator == definition.length - 1) {
      throw const _UsageException('--dart-define 必须为 KEY=VALUE');
    }
    final key = definition.substring(0, separator);
    if (definitions.containsKey(key)) {
      throw _UsageException('重复的 --dart-define：$key');
    }
    definitions[key] = definition.substring(separator + 1);
  }

  /// 根据当前 pubspec 计算默认下一版或校验人工指定目标。
  AppReleaseVersion resolveCandidate(AppReleaseVersion current) {
    if (versionName == null) return current.nextPatch();
    return parseExplicitReleaseVersion(
      current: current,
      versionName: versionName!,
      versionCode: versionCode!,
    );
  }

  /// 验证正式包所需的 AFRR/STUM 环境字段，禁止静默使用源码现场样例值。
  void validateProductionDefines() {
    const requiredKeys = <String>{
      'AFRR_HOST',
      'AFRR_PORT',
      'AFRR_SHELF_CODE',
      'DEVICE_IMEI',
      'STUM_DP',
      'STUM_VERSION_DATE',
    };
    final missing = requiredKeys.difference(productionDefines.keys.toSet());
    if (missing.isNotEmpty) {
      throw _UsageException(
        '正式 release 缺少 --dart-define：${missing.join(', ')}',
      );
    }
    final port = int.tryParse(productionDefines['AFRR_PORT']!);
    if (port == null || port < 1 || port > 65535) {
      throw const _UsageException('AFRR_PORT 必须为 1..65535');
    }
    if (!RegExp(
      r'^\d{15,16}$',
    ).hasMatch(productionDefines['AFRR_SHELF_CODE']!)) {
      throw const _UsageException('AFRR_SHELF_CODE 必须为 15 或 16 位数字');
    }
    if (!RegExp(r'^\d{15}$').hasMatch(productionDefines['DEVICE_IMEI']!)) {
      throw const _UsageException('DEVICE_IMEI 必须为 15 位数字');
    }
    final dataProtocolIps = productionDefines['STUM_DP']!.split(',');
    if (dataProtocolIps.any((value) => !_isIpv4(value))) {
      throw const _UsageException('STUM_DP 必须为英文逗号分隔的 IPv4 地址');
    }
    if (productionDefines['AFRR_HOST']!.trim().isEmpty) {
      throw const _UsageException('AFRR_HOST 不能为空');
    }
    if (!_isValidCompactDate(productionDefines['STUM_VERSION_DATE']!)) {
      throw const _UsageException('STUM_VERSION_DATE 必须是有效的 yyyyMMdd');
    }
  }

  /// 转换为 Flutter 能直接接收的独立参数，避免通过 shell 拼接导致转义问题。
  List<String> get flutterDefineArguments => <String>[
    for (final entry in productionDefines.entries)
      '--dart-define=${entry.key}=${entry.value}',
  ];
}

final class _UsageException implements Exception {
  const _UsageException(this.message, {this.exitCode = 64});
  final String message;
  final int exitCode;
}

bool _isIpv4(String value) {
  final parts = value.split('.');
  if (parts.length != 4) return false;
  return parts.every((part) {
    if (!RegExp(r'^(0|[1-9]\d{0,2})$').hasMatch(part)) return false;
    final number = int.tryParse(part);
    return number != null && number <= 255;
  });
}

/// 校验发布包绑定的 STUM 版本批次日期。
bool _isValidCompactDate(String value) {
  if (!RegExp(r'^\d{8}$').hasMatch(value)) return false;
  final year = int.parse(value.substring(0, 4));
  final month = int.parse(value.substring(4, 6));
  final day = int.parse(value.substring(6, 8));
  final parsed = DateTime.utc(year, month, day);
  return parsed.year == year && parsed.month == month && parsed.day == day;
}

String? _normalizedSha256(String value) {
  final normalized = value.replaceAll(RegExp(r'[:\s]'), '').toLowerCase();
  return RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized) ? normalized : null;
}

/// 从当前目录向上查找同时包含 pubspec 与 Android 工程的 Flutter 根目录。
Directory _findProjectRoot(Directory start) {
  var current = start.absolute;
  while (true) {
    if (File(_join(current.path, 'pubspec.yaml')).existsSync() &&
        Directory(_join(current.path, 'android')).existsSync()) {
      return current;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      throw StateError('当前目录不在 Flutter Android 项目中');
    }
    current = parent;
  }
}

Map<String, String> _parseProperties(String source) {
  final result = <String, String>{};
  for (final line in LineSplitter.split(source)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#') || trimmed.startsWith('!')) {
      continue;
    }
    if (trimmed.endsWith(r'\') ||
        (!trimmed.contains('=') && trimmed.contains(':'))) {
      throw const FormatException('key.properties 只支持无需转义或续行的 key=value 单行格式');
    }
    final separator = trimmed.indexOf('=');
    if (separator <= 0) continue;
    result[trimmed.substring(0, separator).trim()] = trimmed
        .substring(separator + 1)
        .trim();
  }
  return result;
}

String _findExecutable(String name) {
  final path = Platform.environment['PATH'];
  if (path != null) {
    for (final directory in path.split(';')) {
      final candidate = File(_join(directory.replaceAll('"', ''), name));
      if (candidate.existsSync()) return candidate.path;
    }
  }
  throw StateError('PATH 中找不到 $name');
}

String _findJavaHome() {
  final candidates = <String?>[
    Platform.environment['JAVA_HOME'],
    r'C:\Program Files\Android\Android Studio\jbr',
    if (Platform.environment['LOCALAPPDATA'] != null)
      _join(
        Platform.environment['LOCALAPPDATA']!,
        'Programs',
        'Android Studio',
        'jbr',
      ),
    r'D:\software\Android-Studio\jbr',
    r'D:\software\AndroidStudio\jbr',
  ];
  for (final candidate in candidates) {
    if (candidate != null &&
        File(_join(candidate, 'bin', 'java.exe')).existsSync()) {
      return candidate;
    }
  }
  throw StateError('找不到可供 Android 签名工具使用的 JDK，请设置 JAVA_HOME');
}

String _findLatestAndroidBuildTool(String name) {
  final sdkRoots = <String?>[
    _androidSdkFromLocalProperties(),
    Platform.environment['ANDROID_SDK_ROOT'],
    Platform.environment['ANDROID_HOME'],
    _join(Platform.environment['LOCALAPPDATA'] ?? '', 'Android', 'Sdk'),
  ];
  for (final sdkRoot in sdkRoots.whereType<String>().toSet()) {
    final buildTools = Directory(_join(sdkRoot, 'build-tools'));
    if (!buildTools.existsSync()) continue;
    final candidates = buildTools
        .listSync()
        .whereType<Directory>()
        .where((directory) => _buildToolsRevision(directory.path).first >= 0)
        .map((directory) => File(_join(directory.path, name)))
        .where((file) => file.existsSync())
        .toList(growable: false);
    final nestedToolPath = name.contains('/') || name.contains(r'\');
    candidates.sort((left, right) {
      final leftRevision = _buildToolsRevision(
        nestedToolPath ? left.parent.parent.path : left.parent.path,
      );
      final rightRevision = _buildToolsRevision(
        nestedToolPath ? right.parent.parent.path : right.parent.path,
      );
      return _compareRevision(rightRevision, leftRevision);
    });
    if (candidates.isNotEmpty) return candidates.first.path;
  }
  throw StateError('Android build-tools 中找不到稳定版 $name');
}

List<int> _buildToolsRevision(String path) {
  final name = _basename(path);
  final stable = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(name);
  if (stable == null) return const <int>[-1];
  return <int>[
    int.parse(stable.group(1)!),
    int.parse(stable.group(2)!),
    int.parse(stable.group(3)!),
  ];
}

int _compareRevision(List<int> left, List<int> right) {
  final length = left.length > right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final leftValue = index < left.length ? left[index] : 0;
    final rightValue = index < right.length ? right[index] : 0;
    final result = leftValue.compareTo(rightValue);
    if (result != 0) return result;
  }
  return 0;
}

String? _androidSdkFromLocalProperties() {
  var current = Directory.current.absolute;
  while (true) {
    final file = File(_join(current.path, 'android', 'local.properties'));
    if (file.existsSync()) {
      final value = _parseProperties(file.readAsStringSync())['sdk.dir'];
      if (value != null && value.isNotEmpty) {
        return value.replaceAll(r'\:', ':').replaceAll(r'\\', r'\');
      }
    }
    if (current.parent.path == current.path) {
      return null;
    }
    current = current.parent;
  }
}

bool _isAbsoluteWindowsPath(String path) =>
    RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path) || path.startsWith(r'\\');

String _join(
  String first,
  String second, [
  String? third,
  String? fourth,
  String? fifth,
  String? sixth,
]) {
  final parts = <String>[first, second, ?third, ?fourth, ?fifth, ?sixth];
  return parts.join(Platform.pathSeparator);
}

String _basename(String path) => path.split(RegExp(r'[\\/]')).last;

bool _bytesEqual(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

/// 以流式读取方式计算发布 APK 摘要，不把大文件一次性载入内存。
Future<String> _digestOf(File file, Hash algorithm) async {
  return (await algorithm.bind(file.openRead()).first).toString();
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
