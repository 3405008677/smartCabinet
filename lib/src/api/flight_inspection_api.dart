import '../core/network/fake_http_client.dart';
import '../core/network/network_result.dart';
import '../dto/flight_inspection_response_dto.dart';

/// 飞检接口。
class FlightInspectionApi {
  /// 创建飞检接口实例。
  const FlightInspectionApi();

  /// 获取飞检展示数据。
  ///
  /// 当前从 `/api/flight-inspection` 获取模拟任务数据，
  /// 返回 DTO 供 Repository 继续映射为页面模型。
  Future<FlightInspectionResponseDto> fetchData() async {
    final result = await fakeHttpClient.get<Map<String, Object>>(
      '/api/flight-inspection',
    );
    return switch (result) {
      NetworkSuccess<Map<String, Object>>(data: final data) =>
        FlightInspectionResponseDto.fromJson(data),
      NetworkFailure<Map<String, Object>>(message: final message) =>
        throw Exception(message),
    };
  }
}

/// 默认飞检接口实例。
const FlightInspectionApi flightInspectionApi = FlightInspectionApi();
