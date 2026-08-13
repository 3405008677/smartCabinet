import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:smart_cabinet/src/core/logging/communication_log_store.dart';

/// 读取终端主板和系统信息的服务。
class DeviceInfoService {
  /// 创建设备信息服务。
  const DeviceInfoService();

  /// 原生设备信息与本地缓存共同使用的唯一设备 ID 字段名。
  static const String uniqueDeviceIdLabel = '唯一设备ID';

  /// Flutter 与 Android 原生层约定的 Kiosk 通道名称。
  static const MethodChannel _channel = MethodChannel('smart_cabinet/kiosk');

  /// 读取当前主板和 Android 系统信息。
  Future<List<DeviceInfoItem>> fetchDeviceInfo() async {
    if (kIsWeb) {
      return const <DeviceInfoItem>[
        DeviceInfoItem(label: uniqueDeviceIdLabel, value: 'web-debug-device'),
        DeviceInfoItem(label: '平台', value: 'Flutter Web'),
        DeviceInfoItem(label: '状态', value: '浏览器调试环境'),
      ];
    }

    final rawDeviceInfo = await CommunicationLogStore.instance
        .traceExchange<Map<String, Object?>?>(
          targetType: CommunicationTargetType.hardware,
          channel: _channel.name,
          operation: 'getDeviceInfo',
          requestBody: const <String, Object?>{},
          action: () =>
              _channel.invokeMapMethod<String, Object?>('getDeviceInfo'),
          // 设备信息正文包含 Android ID 等身份，只记录返回规模，不能把原始
          // Map 交给诊断日志，即使通用脱敏规则以后调整也不泄露具体值。
          responseBody: (value) => <String, Object?>{
            'returned': value != null,
            'fieldCount': value?.length ?? 0,
          },
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

  /// 直接从原生设备信息中读取“关于设备”展示的唯一设备 ID。
  ///
  /// 空值和原生占位文案会明确失败，调用方不得把它们作为协议身份发送。
  Future<String> fetchUniqueDeviceId() async {
    final items = await fetchDeviceInfo();
    final values = <String, Object?>{
      for (final item in items) item.label: item.value,
    };
    final uniqueDeviceId = uniqueDeviceIdFrom(values);
    if (uniqueDeviceId == null) {
      throw StateError('当前平台未返回有效的唯一设备 ID');
    }
    return uniqueDeviceId;
  }

  /// 从启动缓存中提取可用于设备协议的唯一设备 ID。
  ///
  /// 返回 null 表示缓存缺失、为空或仍是平台占位值。
  static String? uniqueDeviceIdFrom(Map<String, Object?> deviceInfo) {
    final value = deviceInfo[uniqueDeviceIdLabel]?.toString().trim() ?? '';
    if (value.isEmpty || value == '未知' || value.toLowerCase() == 'unknown') {
      return null;
    }
    return value;
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
