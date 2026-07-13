import '../../index.dart';

/// 设备状态 URL。
const String adminDeviceStatusUrl = '/api/admin/device-status';

/// 获取当前柜体设备状态接口。
Future<Map<String, Object>> adminDeviceStatusAPI() {
  return apiClient.get<Map<String, Object>>(adminDeviceStatusUrl);
}
