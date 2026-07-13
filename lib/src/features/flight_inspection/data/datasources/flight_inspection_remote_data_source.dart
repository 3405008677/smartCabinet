import 'package:smart_cabinet/src/core/network/api_client.dart';
import 'package:smart_cabinet/src/features/flight_inspection/data/dtos/flight_inspection_response_dto.dart';

/// 飞检任务 URL。
const String flightInspectionTaskUrl = '/api/flight-inspection';

/// 获取飞检任务数据接口。
Future<FlightInspectionResponseDto> flightInspectionTaskAPI() async {
  final data = await apiClient.get<Map<String, Object>>(
    flightInspectionTaskUrl,
  );
  return FlightInspectionResponseDto.fromJson(data);
}
