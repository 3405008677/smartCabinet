import 'package:smart_cabinet/src/core/network/api_client.dart';
import 'package:smart_cabinet/src/features/home/data/dtos/home_response_dto.dart';

/// 首页看板 URL。
const String homeDashboardUrl = '/api/home';

/// 获取首页看板数据接口。
Future<HomeResponseDto> homeDashboardAPI() async {
  final data = await apiClient.get<Map<String, Object>>(homeDashboardUrl);
  return HomeResponseDto.fromJson(data);
}
