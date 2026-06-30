import '../../index.dart';
import '../../../dto/dropoff_response_dto.dart';

/// 放件接口。
class DropoffApi {
  /// 创建放件接口实例。
  const DropoffApi({this.client = apiClient});

  /// 全局 API 请求客户端。
  final ApiClient client;

  /// 获取放件展示数据。
  ///
  /// 当前通过假数据客户端读取 `/api/dropoff`，
  /// 后续改为真实 HTTP 请求时只需替换内部实现。
  Future<DropoffResponseDto> fetchData() async {
    final data = await client.get<Map<String, Object>>('/api/dropoff');
    return DropoffResponseDto.fromJson(data);
  }
}

/// 默认放件接口实例。
const DropoffApi dropoffApi = DropoffApi();
