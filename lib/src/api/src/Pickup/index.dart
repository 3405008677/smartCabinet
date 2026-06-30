import '../../index.dart';
import '../../../dto/pickup_response_dto.dart';

/// 取件接口。
class PickupApi {
  /// 创建取件接口实例。
  const PickupApi({this.client = apiClient});

  /// 全局 API 请求客户端。
  final ApiClient client;

  /// 获取取件展示数据。
  ///
  /// 当前通过假数据客户端读取 `/api/pickup`，后续替换为真实 HTTP
  /// 接口时尽量保持该方法签名不变，减少上层 Repository 的改动范围。
  Future<PickupResponseDto> fetchData() async {
    final data = await client.get<Map<String, Object>>('/api/pickup');
    return PickupResponseDto.fromJson(data);
  }
}

/// 默认取件接口实例。
const PickupApi pickupApi = PickupApi();
