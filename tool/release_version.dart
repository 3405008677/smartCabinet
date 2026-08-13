/// Android/Flutter 发布版本允许使用的最大 `versionCode`。
///
/// 采用 Google Play 的发布上限，避免现场侧载版本未来无法迁移到标准渠道。
const int maxAndroidVersionCode = 2100000000;

/// 表示 `pubspec.yaml` 中的三段式应用版本和 Android 构建号。
final class AppReleaseVersion implements Comparable<AppReleaseVersion> {
  /// 创建经过基本范围校验的发布版本。
  const AppReleaseVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.versionCode,
  });

  /// 主版本号。
  final int major;

  /// 次版本号。
  final int minor;

  /// 补丁版本号。
  final int patch;

  /// Android 单调递增的 `versionCode`。
  final int versionCode;

  /// 用户可见且由 STUM 使用的 Android `versionName`。
  String get versionName => '$major.$minor.$patch';

  /// `pubspec.yaml` 使用的完整版本文本。
  String get pubspecValue => '$versionName+$versionCode';

  /// 返回补丁版本和 Android 构建号各增加一的下一版。
  AppReleaseVersion nextPatch() {
    if (versionCode >= maxAndroidVersionCode) {
      throw const FormatException('versionCode 已达到 Android 发布上限');
    }
    return AppReleaseVersion(
      major: major,
      minor: minor,
      patch: patch + 1,
      versionCode: versionCode + 1,
    );
  }

  @override
  int compareTo(AppReleaseVersion other) {
    final majorResult = major.compareTo(other.major);
    if (majorResult != 0) return majorResult;
    final minorResult = minor.compareTo(other.minor);
    if (minorResult != 0) return minorResult;
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => pubspecValue;
}

/// 保存已解析版本及其在原始 `pubspec.yaml` 文本中的精确位置。
final class PubspecVersionDocument {
  const PubspecVersionDocument._({
    required this.source,
    required this.version,
    required this.valueStart,
    required this.valueEnd,
  });

  /// 未改写的原始文件内容。
  final String source;

  /// 当前应用版本。
  final AppReleaseVersion version;

  final int valueStart;
  final int valueEnd;

  /// 仅替换顶层 `version` 值，保留文件其余内容和换行风格。
  String replaceVersion(AppReleaseVersion replacement) {
    return source.replaceRange(valueStart, valueEnd, replacement.pubspecValue);
  }
}

final RegExp _pubspecVersionPattern = RegExp(
  r'^version:[ \t]+((0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)\+([1-9]\d*))[ \t]*\r?$',
  multiLine: true,
);

final RegExp _versionNamePattern = RegExp(
  r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$',
);

/// 从 `pubspec.yaml` 原文严格解析唯一的顶层应用版本。
PubspecVersionDocument parsePubspecVersion(String source) {
  final matches = _pubspecVersionPattern.allMatches(source).toList();
  if (matches.length != 1) {
    throw const FormatException(
      'pubspec.yaml 必须且只能包含一个 version: major.minor.patch+versionCode',
    );
  }
  final match = matches.single;
  final versionCode = int.parse(match.group(5)!);
  if (versionCode > maxAndroidVersionCode) {
    throw const FormatException('versionCode 超过 Android 发布上限');
  }
  return PubspecVersionDocument._(
    source: source,
    version: AppReleaseVersion(
      major: int.parse(match.group(2)!),
      minor: int.parse(match.group(3)!),
      patch: int.parse(match.group(4)!),
      versionCode: versionCode,
    ),
    valueStart: match.start + match.group(0)!.indexOf(match.group(1)!),
    valueEnd:
        match.start +
        match.group(0)!.indexOf(match.group(1)!) +
        match.group(1)!.length,
  );
}

/// 解析人工指定的目标版本，并确保名称与构建号都严格递增。
AppReleaseVersion parseExplicitReleaseVersion({
  required AppReleaseVersion current,
  required String versionName,
  required int versionCode,
}) {
  final match = _versionNamePattern.firstMatch(versionName);
  if (match == null) {
    throw const FormatException('目标 versionName 必须为 major.minor.patch 三段数字');
  }
  if (versionCode <= 0 || versionCode > maxAndroidVersionCode) {
    throw const FormatException('目标 versionCode 超出 Android 发布范围');
  }
  final target = AppReleaseVersion(
    major: int.parse(match.group(1)!),
    minor: int.parse(match.group(2)!),
    patch: int.parse(match.group(3)!),
    versionCode: versionCode,
  );
  if (target.compareTo(current) <= 0) {
    throw const FormatException('目标 versionName 必须严格高于当前版本');
  }
  if (target.versionCode <= current.versionCode) {
    throw const FormatException('目标 versionCode 必须严格高于当前构建号');
  }
  return target;
}
