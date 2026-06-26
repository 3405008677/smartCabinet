import 'package:flutter/services.dart';

import 'kiosk_device.dart';

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
    return await _channel.invokeMethod<bool>('enterKioskMode') ?? false;
  }

  @override
  Future<bool> exitKioskMode() async {
    return await _channel.invokeMethod<bool>('exitKioskMode') ?? false;
  }

  @override
  Future<bool> isDeviceOwner() async {
    return await _channel.invokeMethod<bool>('isDeviceOwner') ?? false;
  }

  @override
  Future<bool> isKioskModeActive() async {
    return await _channel.invokeMethod<bool>('isKioskModeActive') ?? false;
  }

  @override
  Future<void> openSystemSettings() async {
    await _channel.invokeMethod<void>('openSystemSettings');
  }
}
