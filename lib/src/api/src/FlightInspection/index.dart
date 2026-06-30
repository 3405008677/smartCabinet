import '../../index.dart';
import '../../../dto/flight_inspection_response_dto.dart';

/// 飞检接口。
class FlightInspectionApi {
  /// 创建飞检接口实例。
  const FlightInspectionApi({this.client = apiClient});

  /// 全局 API 请求客户端。
  final ApiClient client;

  /// 获取飞检展示数据。
  ///
  /// 当前从 `/api/flight-inspection` 获取模拟任务数据，
  /// 返回 DTO 供 Repository 继续映射为页面模型。
  Future<FlightInspectionResponseDto> fetchData() async {
    final data = await client.get<Map<String, Object>>(
      '/api/flight-inspection',
    );
    return FlightInspectionResponseDto.fromJson(data);
  }
}

/// 默认飞检接口实例。
const FlightInspectionApi flightInspectionApi = FlightInspectionApi();
