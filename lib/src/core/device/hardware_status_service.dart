import 'package:flutter/services.dart';

import 'package:smart_cabinet/src/core/logging/communication_log_store.dart';

/// 终端硬件状态服务。
class HardwareStatusService {
  /// 创建终端硬件状态服务。
  const HardwareStatusService();

  /// Flutter 与 Android 原生层约定的 Kiosk 通道名称。
  static const MethodChannel _channel = MethodChannel('smart_cabinet/kiosk');

  /// 读取当前 WiFi、指纹和 NFC 真实硬件状态。
  Future<DeviceHardwareStatus> fetchHardwareStatus() async {
    final rawStatus = await CommunicationLogStore.instance
        .traceExchange<Map<String, Object?>?>(
          targetType: CommunicationTargetType.hardware,
          channel: _channel.name,
          operation: 'getHardwareStatus',
          requestBody: const <String, Object?>{},
          action: () =>
              _channel.invokeMapMethod<String, Object?>('getHardwareStatus'),
        );

    return DeviceHardwareStatus.fromMap(rawStatus ?? const <String, Object?>{});
  }
}

/// 终端硬件状态。
class DeviceHardwareStatus {
  /// 创建终端硬件状态对象。
  const DeviceHardwareStatus({
    required this.wifiConnected,
    required this.wifiName,
    required this.ethernetConnected,
    required this.fingerprintAvailable,
    required this.nfcAvailable,
  });

  /// 当前设备是否已连接 WiFi。
  final bool wifiConnected;

  /// 当前 WiFi 名称。
  final String wifiName;

  /// 当前 RJ45 以太网是否已连接。
  final bool ethernetConnected;

  /// 当前设备是否具备指纹模块。
  final bool fingerprintAvailable;

  /// 当前设备是否具备 NFC 模块。
  final bool nfcAvailable;

  /// 从原生通道返回值创建硬件状态。
  factory DeviceHardwareStatus.fromMap(Map<String, Object?> map) {
    return DeviceHardwareStatus(
      wifiConnected: map['wifiConnected'] == true,
      wifiName: map['wifiName']?.toString() ?? '',
      ethernetConnected: map['ethernetConnected'] == true,
      fingerprintAvailable: map['fingerprintAvailable'] == true,
      nfcAvailable: map['nfcAvailable'] == true,
    );
  }
}
