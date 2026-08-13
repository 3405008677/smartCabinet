import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:smart_cabinet/src/core/logging/communication_log_store.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/domain/entities/terminal_upgrade.dart';

/// 升级包下载进度回调。
typedef TerminalUpgradeDownloadProgress =
    void Function(int downloadedBytes, int? totalBytes);

/// 升级包下载取消令牌。
///
/// Repository 在停止、重配或销毁时调用 [cancel]，下载器会同时中止 HTTP 请求、
/// 流式写盘与摘要计算，避免旧任务继续持有维护租约。
final class TerminalUpgradeDownloadCancellationToken {
  final Completer<void> _cancelled = Completer<void>();

  /// 当前下载是否已经被调用方取消。
  bool get isCancelled => _cancelled.isCompleted;

  /// 首次取消时完成的 Future，可用于打断底层 I/O。
  Future<void> get whenCancelled => _cancelled.future;

  /// 幂等取消当前下载。
  void cancel() {
    if (!_cancelled.isCompleted) {
      _cancelled.complete();
    }
  }

  /// 在同步边界拒绝继续执行已经取消的任务。
  void throwIfCancelled() {
    if (isCancelled) {
      throw const TerminalUpgradeDownloadException('升级包下载已取消');
    }
  }
}

/// 已下载并完成 MD5 校验的临时 APK。
class DownloadedTerminalUpgradePackage {
  /// 创建已校验升级包。
  const DownloadedTerminalUpgradePackage({
    required this.file,
    required this.md5,
    required this.size,
  });

  /// 应用私有临时目录中的 APK 文件。
  final File file;

  /// 实际计算得到的 32 位小写 MD5。
  final String md5;

  /// 文件字节数。
  final int size;
}

/// 不携带下载 URL、查询令牌或本地路径的安全下载异常。
class TerminalUpgradeDownloadException implements Exception {
  /// 创建可安全记录和展示的下载异常。
  const TerminalUpgradeDownloadException(this.message);

  /// 面向管理员的失败原因。
  final String message;

  @override
  String toString() => message;
}

/// URL 升级包下载能力。
abstract interface class TerminalUpgradePackageDownloader {
  /// 流式下载并校验服务端提供的完整 APK。
  Future<DownloadedTerminalUpgradePackage> download(
    TerminalUpgradeOffer offer, {
    required TerminalUpgradeDownloadProgress onProgress,
    TerminalUpgradeDownloadCancellationToken? cancellationToken,
  });
}

/// 基于 dart:io 的升级包流式下载器。
final class IoTerminalUpgradePackageDownloader
    implements TerminalUpgradePackageDownloader {
  /// 创建升级包下载器。
  const IoTerminalUpgradePackageDownloader({
    this.timeout = const Duration(seconds: 30),
    this.totalTimeout = const Duration(minutes: 20),
    this.maxPackageBytes = 512 * 1024 * 1024,
    this.stalePackageAge = const Duration(days: 1),
  });

  /// 连接、响应和单次流读取的等待上限。
  final Duration timeout;

  /// 从连接到摘要校验完成的整包截止时间，慢滴流量不能无限续期。
  final Duration totalTimeout;

  /// 允许下载的最大升级包，防止错误地址耗尽柜机磁盘。
  final int maxPackageBytes;

  /// 崩溃或断电遗留的临时升级目录保留上限。
  final Duration stalePackageAge;

  @override
  Future<DownloadedTerminalUpgradePackage> download(
    TerminalUpgradeOffer offer, {
    required TerminalUpgradeDownloadProgress onProgress,
    TerminalUpgradeDownloadCancellationToken? cancellationToken,
  }) async {
    _validateConfiguration();
    _validateOffer(offer);
    final token =
        cancellationToken ?? TerminalUpgradeDownloadCancellationToken();
    final client = HttpClient()..connectionTimeout = timeout;
    Directory? directory;
    HttpClientRequest? request;
    int? requestLogId;
    var totalDeadlineExceeded = false;
    void throwIfAborted() {
      if (totalDeadlineExceeded) {
        throw const TerminalUpgradeDownloadException('下载升级包超过整包时间上限');
      }
      token.throwIfCancelled();
    }

    final totalDeadline = Timer(totalTimeout, () {
      totalDeadlineExceeded = true;
      request?.abort();
      client.close(force: true);
    });

    // HttpClient 没有独立取消令牌；关闭当前专用 client 可立即打断连接、响应流和
    // 空闲等待，而且不会影响应用里的其它 HTTP 请求。
    unawaited(
      token.whenCancelled.then((_) {
        request?.abort();
        client.close(force: true);
      }),
    );

    try {
      throwIfAborted();
      await _deleteStalePackageDirectories();
      throwIfAborted();
      directory = await Directory.systemTemp.createTemp(
        'smart_cabinet_upgrade_',
      );
      throwIfAborted();
      final partialFile = File(
        '${directory.path}${Platform.pathSeparator}update.apk.part',
      );
      final completedFile = File(
        '${directory.path}${Platform.pathSeparator}update.apk',
      );
      requestLogId = CommunicationLogStore.instance.tryRecord(
        targetType: CommunicationTargetType.server,
        direction: CommunicationDirection.outbound,
        channel: 'HTTPS',
        operation: '下载终端升级包',
        messageBody: <String, Object?>{
          'method': 'GET',
          'url': offer.downloadUrl,
          'accept': 'application/vnd.android.package-archive',
        },
        result: '处理中',
      );
      request = await client.getUrl(offer.downloadUrl).timeout(timeout);
      throwIfAborted();
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.android.package-archive',
      );
      final response = await request.close().timeout(timeout);
      throwIfAborted();
      CommunicationLogStore.instance.tryRecord(
        targetType: CommunicationTargetType.server,
        direction: CommunicationDirection.inbound,
        channel: 'HTTPS',
        operation: '下载终端升级包',
        messageBody: <String, Object?>{
          'statusCode': response.statusCode,
          'contentLength': response.contentLength,
          'contentType': response.headers.contentType?.mimeType ?? '',
        },
        result: response.statusCode >= 200 && response.statusCode < 300
            ? '成功'
            : '失败：HTTP ${response.statusCode}',
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TerminalUpgradeDownloadException(
          '升级包服务器返回 HTTP ${response.statusCode}',
        );
      }

      final declaredLength = response.contentLength;
      if (declaredLength > maxPackageBytes) {
        throw StateError('升级包超过允许的最大大小');
      }
      final totalBytes = declaredLength > 0 ? declaredLength : null;
      final output = await partialFile.open(mode: FileMode.write);
      var downloadedBytes = 0;
      try {
        await for (final chunk in response.timeout(timeout)) {
          throwIfAborted();
          downloadedBytes += chunk.length;
          if (downloadedBytes > maxPackageBytes) {
            throw StateError('升级包超过允许的最大大小');
          }
          // 等待当前数据块真正写入后再读取下一块，为慢闪存提供自然背压。
          await output.writeFrom(chunk);
          throwIfAborted();
          onProgress(downloadedBytes, totalBytes);
        }
        await output.flush();
        throwIfAborted();
      } finally {
        await output.close();
      }

      if (downloadedBytes <= 0) {
        throw StateError('升级包内容为空');
      }
      throwIfAborted();
      final digestInput = partialFile.openRead().map((chunk) {
        throwIfAborted();
        return chunk;
      });
      final actualMd5 = (await md5.bind(digestInput).first).toString();
      throwIfAborted();
      if (actualMd5.toLowerCase() != offer.md5.toLowerCase()) {
        throw StateError('升级包 MD5 校验失败');
      }
      await partialFile.rename(completedFile.path);
      throwIfAborted();
      CommunicationLogStore.instance.tryUpdateResult(requestLogId, '成功');
      return DownloadedTerminalUpgradePackage(
        file: completedFile,
        md5: actualMd5,
        size: downloadedBytes,
      );
    } catch (error) {
      if (requestLogId != null) {
        CommunicationLogStore.instance.tryUpdateResult(
          requestLogId,
          '失败：${error.runtimeType}',
        );
      }
      await _deleteDirectorySafely(directory);
      if (totalDeadlineExceeded) {
        throw const TerminalUpgradeDownloadException('下载升级包超过整包时间上限');
      }
      if (token.isCancelled) {
        throw const TerminalUpgradeDownloadException('升级包下载已取消');
      }
      if (error is TerminalUpgradeDownloadException) {
        rethrow;
      }
      throw _safeDownloadException(error);
    } finally {
      totalDeadline.cancel();
      client.close(force: true);
    }
  }

  /// 拒绝会导致即时超时、无限保留或无界写盘的下载器配置。
  void _validateConfiguration() {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', '单次等待时间必须大于 0');
    }
    if (totalTimeout <= Duration.zero) {
      throw ArgumentError.value(totalTimeout, 'totalTimeout', '整包时限必须大于 0');
    }
    if (maxPackageBytes <= 0) {
      throw ArgumentError.value(
        maxPackageBytes,
        'maxPackageBytes',
        '升级包大小上限必须大于 0',
      );
    }
    if (stalePackageAge.isNegative) {
      throw ArgumentError.value(
        stalePackageAge,
        'stalePackageAge',
        '遗留目录保留时间不能为负数',
      );
    }
  }

  /// 清理超过保留期限的进程崩溃或断电遗留升级目录。
  Future<void> _deleteStalePackageDirectories() async {
    final cutoff = DateTime.now().subtract(stalePackageAge);
    try {
      await for (final entity in Directory.systemTemp.list(
        followLinks: false,
      )) {
        if (entity is! Directory ||
            !_fileName(entity.path).startsWith('smart_cabinet_upgrade_')) {
          continue;
        }
        try {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entity.delete(recursive: true);
          }
        } on FileSystemException {
          // 单个历史目录不可读或已被并发清理时继续处理，本次下载仍可安全进行。
        }
      }
    } on FileSystemException {
      // 系统临时目录不可枚举不应阻止本次下载；新目录创建失败仍会走安全错误映射。
    }
  }

  /// 最佳努力删除本次临时目录，且不让清理异常遮蔽真实下载错误。
  Future<void> _deleteDirectorySafely(Directory? directory) async {
    if (directory == null) {
      return;
    }
    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } on FileSystemException {
      // 下次下载会按 [stalePackageAge] 再次回收遗留目录。
    }
  }

  /// 从任意平台路径取得末级名称，不把绝对路径带入异常或日志。
  String _fileName(String path) {
    final separator = Platform.pathSeparator;
    final index = path.lastIndexOf(separator);
    return index < 0 ? path : path.substring(index + separator.length);
  }

  /// 检查 URL 模式所需的地址和完整文件 MD5。
  void _validateOffer(TerminalUpgradeOffer offer) {
    if (offer.downloadUrl.scheme != 'http' &&
        offer.downloadUrl.scheme != 'https') {
      throw const TerminalUpgradeDownloadException('只支持 HTTP/HTTPS 升级包');
    }
    if (offer.downloadUrl.host.isEmpty) {
      throw const TerminalUpgradeDownloadException('升级包地址缺少主机');
    }
    if (!RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(offer.md5)) {
      throw const TerminalUpgradeDownloadException('URL 升级包必须提供 32 位 MD5');
    }
  }

  /// 把底层异常收敛成不泄露 URL 查询参数或本地路径的管理员提示。
  TerminalUpgradeDownloadException _safeDownloadException(Object error) {
    if (error is TimeoutException) {
      return const TerminalUpgradeDownloadException('下载升级包超时');
    }
    if (error is HandshakeException) {
      return const TerminalUpgradeDownloadException('升级包服务器证书校验失败');
    }
    if (error is SocketException) {
      return const TerminalUpgradeDownloadException('无法连接升级包服务器');
    }
    if (error is StateError) {
      return TerminalUpgradeDownloadException(error.message);
    }
    if (error is HttpException) {
      return const TerminalUpgradeDownloadException('升级包服务器响应异常');
    }
    if (error is FileSystemException) {
      return const TerminalUpgradeDownloadException('升级包临时存储不可用');
    }
    return TerminalUpgradeDownloadException('下载升级包失败（${error.runtimeType}）');
  }
}
