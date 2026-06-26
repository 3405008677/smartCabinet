import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 读取终端主板和系统信息的服务。
class DeviceInfoService {
  /// 创建设备信息服务。
  const DeviceInfoService();

  /// Flutter 与 Android 原生层约定的 Kiosk 通道名称。
  static const MethodChannel _channel = MethodChannel('smart_cabinet/kiosk');

  /// 读取当前主板和 Android 系统信息。
  Future<List<DeviceInfoItem>> fetchDeviceInfo() async {
    if (kIsWeb) {
      return const <DeviceInfoItem>[
        DeviceInfoItem(label: '唯一设备ID', value: 'web-debug-device'),
        DeviceInfoItem(label: '平台', value: 'Flutter Web'),
        DeviceInfoItem(label: '状态', value: '浏览器调试环境'),
      ];
    }

    final rawDeviceInfo = await _channel.invokeMapMethod<String, Object?>(
      'getDeviceInfo',
    );

    if (rawDeviceInfo == null || rawDeviceInfo.isEmpty) {
      return const [DeviceInfoItem(label: '状态', value: '当前平台未返回设备信息')];
    }

    return rawDeviceInfo.entries
        .map(
          (entry) => DeviceInfoItem(
            label: entry.key,
            value: entry.value?.toString() ?? '未知',
          ),
        )
        .toList(growable: false);
  }
}

/// 单条设备信息键值。
class DeviceInfoItem {
  /// 创建设备信息键值。
  const DeviceInfoItem({required this.label, required this.value});

  /// 信息名称。
  final String label;

  /// 信息内容。
  final String value;
}
