import 'package:flutter/services.dart';

import 'package:smart_cabinet/src/core/device/app_version_service.dart';
import 'package:smart_cabinet/src/core/logging/communication_log_store.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/data/datasources/terminal_upgrade_device.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/domain/entities/terminal_upgrade.dart';

/// 通过独立 MethodChannel 访问 Android 终端升级安装能力。
///
/// 本类仅负责 Dart 与 Kotlin 间的方法、参数和结果映射；APK 的安全校验与
/// PackageInstaller 会话管理由 Android `upgrade/` 实现负责。
class MethodChannelTerminalUpgradeDevice implements TerminalUpgradeDevice {
  /// 创建使用固定升级通道的原生设备数据源。
  MethodChannelTerminalUpgradeDevice({AppVersionService? appVersionService})
    : _appVersionService =
          appVersionService ??
          // 默认实例与全局页脚共用缓存，避免每个页面重复读取 PackageManager。
          globalAppVersionService;

  final AppVersionService _appVersionService;

  /// 与摄像头/Kiosk 通道隔离，避免 APK 复制占用其他设备控制通道。
  static const MethodChannel _channel = MethodChannel('smart_cabinet/upgrade');
  static const Set<String> _knownInstallStates = <String>{
    'idle',
    'validating',
    'submitting',
    'submitted',
    'pending_user_action',
    'success',
    'failed',
    'failure',
  };

  /// 调用 Android `getAppVersion` 并映射当前应用版本。
  @override
  Future<TerminalAppVersion> getAppVersion() async {
    final version = await _appVersionService.load();
    return TerminalAppVersion(name: version.name, code: version.code);
  }

  /// 调用 Android `getInstallStatus` 并兼容原生状态字段的现有别名。
  @override
  Future<TerminalInstallStatus> getInstallStatus() async {
    final result = await _invokeMap('getInstallStatus');
    if (result == null) {
      throw StateError('Android 未返回安装状态');
    }
    final state =
        (result['state']?.toString() ?? result['status']?.toString() ?? '')
            .trim();
    if (!_knownInstallStates.contains(state)) {
      throw StateError('Android 返回了未知安装状态');
    }
    final sessionId = int.tryParse(result['sessionId']?.toString() ?? '');
    if ((state == 'submitting' ||
            state == 'submitted' ||
            state == 'pending_user_action') &&
        (sessionId == null || sessionId <= 0)) {
      throw StateError('Android 活动安装状态缺少有效会话');
    }
    return TerminalInstallStatus(
      state: state,
      message: result['message']?.toString() ?? '',
      sessionId: sessionId,
      targetVersion:
          result['targetVersion']?.toString() ??
          result['versionName']?.toString() ??
          '',
      silentInstallRequested: result['silentInstallRequested'] == true,
      requiresUserAction: result['requiresUserAction'] == true,
      confirmationLaunchFailed: result['confirmationLaunchFailed'] == true,
      diagnosticCode: result['diagnosticCode']?.toString() ?? '',
    );
  }

  /// 调用 Android `installApk` 并验证原生层返回的会话标识和初始状态。
  @override
  Future<TerminalInstallSubmission> installApk(
    String apkPath, {
    required String targetVersion,
    required String operationId,
  }) async {
    final arguments = <String, Object?>{
      'apkPath': apkPath,
      'targetVersion': targetVersion,
      'operationId': operationId,
    };
    final result = await _invokeMap('installApk', arguments);
    final sessionId = int.tryParse(result?['sessionId']?.toString() ?? '');
    final state =
        result?['state']?.toString() ?? result?['status']?.toString() ?? '';
    if (sessionId == null || sessionId <= 0 || state != 'submitted') {
      throw StateError('Android 未返回有效的安装会话');
    }
    return TerminalInstallSubmission(sessionId: sessionId, state: state);
  }

  /// 通过轻量原生入口取消尚未 commit 的同一安装操作。
  @override
  Future<bool> cancelInstall(String operationId) async {
    final arguments = <String, Object?>{'operationId': operationId};
    final cancelled = await CommunicationLogStore.instance.traceExchange<bool?>(
      targetType: CommunicationTargetType.hardware,
      channel: _channel.name,
      operation: 'cancelInstall',
      requestBody: arguments,
      action: () => _channel.invokeMethod<bool>('cancelInstall', arguments),
    );
    if (cancelled == null) {
      throw StateError('Android 未返回安装取消结果');
    }
    return cancelled;
  }

  /// 调用升级通道的 Map 方法并记录已经脱敏的请求与应答。
  Future<Map<String, Object?>?> _invokeMap(
    String method, [
    Map<String, Object?>? arguments,
  ]) {
    return CommunicationLogStore.instance.traceExchange<Map<String, Object?>?>(
      targetType: CommunicationTargetType.hardware,
      channel: _channel.name,
      operation: method,
      requestBody: arguments ?? const <String, Object?>{},
      action: () =>
          _channel.invokeMapMethod<String, Object?>(method, arguments),
    );
  }
}
