import 'package:flutter/services.dart';

import 'package:smart_cabinet/src/core/logging/communication_log_store.dart';

/// 当前已安装应用的 Android 包版本信息。
class AppVersionInfo {
  /// 创建不可变的应用版本信息。
  const AppVersionInfo({required this.name, required this.code});

  /// Android `versionName`，同时作为 STUM 的当前版本号。
  final String name;

  /// Android `versionCode`，用于安装升级时防止降级或同版本覆盖。
  final int code;
}

/// 从 Android `PackageManager` 读取并缓存当前已安装应用版本。
///
/// 全局页脚和终端升级共用这一服务，避免分别维护 UI 版本常量。缓存的是
/// 当前进程对应 APK 的不可变元数据；安装新 APK 后应用进程会重建并重新读取。
class AppVersionService {
  /// 创建使用默认升级 MethodChannel 的应用版本服务。
  AppVersionService({Future<AppVersionInfo> Function()? loader})
    : _loader = loader ?? _loadFromAndroid;

  /// 与终端升级安装器共用只读版本入口，不建立第二套平台通道。
  static const MethodChannel _channel = MethodChannel('smart_cabinet/upgrade');

  final Future<AppVersionInfo> Function() _loader;
  Future<AppVersionInfo>? _cachedVersion;

  /// 返回当前已安装 APK 的版本信息，并在进程内复用同一次读取结果。
  Future<AppVersionInfo> load() {
    return _cachedVersion ??= _loader().onError((Object error, stackTrace) {
      // 失败不能永久污染缓存；原生通道恢复后，后续页面仍可再次读取。
      _cachedVersion = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  /// 调用 Android `PackageManager` 入口并校验跨层返回结构。
  static Future<AppVersionInfo> _loadFromAndroid() async {
    final result = await CommunicationLogStore.instance
        .traceExchange<Map<String, Object?>?>(
          targetType: CommunicationTargetType.hardware,
          channel: _channel.name,
          operation: 'getAppVersion',
          requestBody: const <String, Object?>{},
          action: () =>
              _channel.invokeMapMethod<String, Object?>('getAppVersion'),
        );
    if (result == null) {
      throw StateError('Android 未返回应用版本');
    }
    final name = result['versionName']?.toString().trim() ?? '';
    final code = int.tryParse(result['versionCode']?.toString() ?? '');
    if (name.isEmpty || code == null || code <= 0) {
      throw StateError('Android 返回的应用版本格式无效');
    }
    return AppVersionInfo(name: name, code: code);
  }
}

/// 应用进程内唯一的版本读取服务。
final globalAppVersionService = AppVersionService();
