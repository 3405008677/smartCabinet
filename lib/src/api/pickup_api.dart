import '../core/network/fake_http_client.dart';
import '../core/network/network_result.dart';
import '../dto/pickup_response_dto.dart';

/// 取件接口。
class PickupApi {
  /// 创建取件接口实例。
  const PickupApi();

  /// 获取取件展示数据。
  ///
  /// 当前通过假数据客户端读取 `/api/pickup`，后续替换为真实 HTTP
  /// 接口时尽量保持该方法签名不变，减少上层 Repository 的改动范围。
  Future<PickupResponseDto> fetchData() async {
    final result = await fakeHttpClient.get<Map<String, Object>>('/api/pickup');
    return switch (result) {
      NetworkSuccess<Map<String, Object>>(data: final data) =>
        PickupResponseDto.fromJson(data),
      NetworkFailure<Map<String, Object>>(message: final message) =>
        throw Exception(message),
    };
  }
}

/// 默认取件接口实例。
const PickupApi pickupApi = PickupApi();
