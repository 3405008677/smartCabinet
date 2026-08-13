import 'package:smart_cabinet/src/core/network/api_client.dart';

/// 设备状态 URL。
const String adminDeviceStatusUrl = '/api/admin/device-status';

/// 获取当前柜体设备状态的接口边界。
///
/// 数据源不解释硬件状态，只保留服务端协议结构供仓库转换。
Future<Map<String, Object>> adminDeviceStatusAPI() {
  return apiClient.get<Map<String, Object>>(adminDeviceStatusUrl);
}
