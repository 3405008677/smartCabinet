import '../core/network/fake_http_client.dart';
import '../core/network/network_result.dart';
import '../dto/dropoff_response_dto.dart';

/// 放件接口。
class DropoffApi {
  /// 创建放件接口实例。
  const DropoffApi();

  /// 获取放件展示数据。
  ///
  /// 当前通过假数据客户端读取 `/api/dropoff`，
  /// 后续改为真实 HTTP 请求时只需替换内部实现。
  Future<DropoffResponseDto> fetchData() async {
    final result = await fakeHttpClient.get<Map<String, Object>>(
      '/api/dropoff',
    );
    return switch (result) {
      NetworkSuccess<Map<String, Object>>(data: final data) =>
        DropoffResponseDto.fromJson(data),
      NetworkFailure<Map<String, Object>>(message: final message) =>
        throw Exception(message),
    };
  }
}

/// 默认放件接口实例。
const DropoffApi dropoffApi = DropoffApi();
