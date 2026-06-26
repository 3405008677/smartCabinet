import '../core/network/fake_http_client.dart';
import '../core/network/network_result.dart';
import '../dto/home_response_dto.dart';

/// 首页接口。
class HomeApi {
  /// 创建首页接口实例。
  const HomeApi();

  /// 获取首页展示数据。
  ///
  /// 当前通过假数据客户端读取 `/api/home`，未来接入真实接口时，
  /// 建议保持返回 DTO 的方式不变，让上层 Repository 的调用面稳定。
  Future<HomeResponseDto> fetchData() async {
    final result = await fakeHttpClient.get<Map<String, Object>>('/api/home');
    return switch (result) {
      NetworkSuccess<Map<String, Object>>(data: final data) =>
        HomeResponseDto.fromJson(data),
      NetworkFailure<Map<String, Object>>(message: final message) =>
        throw Exception(message),
    };
  }
}

/// 默认首页接口实例。
const HomeApi homeApi = HomeApi();
