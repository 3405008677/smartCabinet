import '../../index.dart';
import '../../../dto/home_response_dto.dart';

/// 首页接口。
class HomeApi {
  /// 创建首页接口实例。
  const HomeApi({this.client = apiClient});

  /// 全局 API 请求客户端。
  final ApiClient client;

  /// 获取首页展示数据。
  ///
  /// 当前通过假数据客户端读取 `/api/home`，未来接入真实接口时，
  /// 建议保持返回 DTO 的方式不变，让上层 Repository 的调用面稳定。
  Future<HomeResponseDto> fetchData() async {
    final data = await client.get<Map<String, Object>>('/api/home');
    return HomeResponseDto.fromJson(data);
  }
}

/// 默认首页接口实例。
const HomeApi homeApi = HomeApi();
