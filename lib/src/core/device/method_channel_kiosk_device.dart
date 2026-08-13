import 'package:flutter/services.dart';

import 'package:smart_cabinet/src/core/camera/cabinet_camera.dart';
import 'package:smart_cabinet/src/core/device/kiosk_device.dart';
import 'package:smart_cabinet/src/core/logging/communication_log_store.dart';

/// 基于 Flutter MethodChannel 的 Kiosk 设备实现。
///
/// Dart 代码无法直接调用 Android 的所有系统能力，
/// 所以这里通过 [MethodChannel] 把请求发送到 Android 原生层处理。
class MethodChannelKioskDevice implements KioskDevice {
  /// 创建 Kiosk 设备实现。
  const MethodChannelKioskDevice();

  /// Flutter 和 Android 原生层约定的通道名称。
  static const MethodChannel _channel = MethodChannel('smart_cabinet/kiosk');

  @override
  Future<bool> enterKioskMode() async {
    return await _invoke<bool>('enterKioskMode') ?? false;
  }

  @override
  Future<bool> exitKioskMode() async {
    return await _invoke<bool>('exitKioskMode') ?? false;
  }

  @override
  Future<bool> isDeviceOwner() async {
    return await _invoke<bool>('isDeviceOwner') ?? false;
  }

  @override
  Future<bool> isKioskModeActive() async {
    return await _invoke<bool>('isKioskModeActive') ?? false;
  }

  @override
  Future<void> openSystemSettings() async {
    await _invoke<void>('openSystemSettings');
  }

  @override
  Future<void> startCameraStream(
    CabinetCameraRole role, {
    required List<String> profiles,
  }) async {
    await _invoke<void>('startCameraStream', <String, Object?>{
      'role': role.name,
      'profiles': profiles,
    });
  }

  @override
  Future<void> stopCameraStream(
    CabinetCameraRole role, {
    List<String>? profiles,
  }) async {
    await _invoke<void>('stopCameraStream', <String, Object?>{
      'role': role.name,
      'profiles': profiles ?? const <String>[],
    });
  }

  @override
  Future<List<String>> retryCameraStream(CabinetCameraRole role) async {
    final arguments = <String, Object?>{'role': role.name};
    final profiles = await CommunicationLogStore.instance
        .traceExchange<List<String>?>(
          targetType: CommunicationTargetType.hardware,
          channel: _channel.name,
          operation: 'retryCameraStream',
          requestBody: arguments,
          action: () =>
              _channel.invokeListMethod<String>('retryCameraStream', arguments),
        );
    return List<String>.unmodifiable(profiles ?? const <String>[]);
  }

  /// 调用 Kiosk 原生方法，并以不改变调用结果的方式记录请求与应答。
  Future<T?> _invoke<T>(String method, [Object? arguments]) {
    return CommunicationLogStore.instance.traceExchange<T?>(
      targetType: CommunicationTargetType.hardware,
      channel: _channel.name,
      operation: method,
      requestBody: arguments ?? const <String, Object?>{},
      action: () => _channel.invokeMethod<T>(method, arguments),
    );
  }
}
