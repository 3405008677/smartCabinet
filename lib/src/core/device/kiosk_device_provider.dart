import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smart_cabinet/src/core/device/kiosk_device.dart';
import 'package:smart_cabinet/src/core/device/method_channel_kiosk_device.dart';

/// Kiosk 设备能力的 Riverpod Provider。
///
/// 页面或业务逻辑可以通过读取 [kioskDeviceProvider] 获取 [KioskDevice]，
/// 而不需要关心它背后是 MethodChannel、模拟实现还是其它实现方式。
final kioskDeviceProvider = Provider<KioskDevice>((ref) {
  return const MethodChannelKioskDevice();
});
