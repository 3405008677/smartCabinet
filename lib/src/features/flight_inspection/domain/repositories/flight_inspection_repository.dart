import 'package:smart_cabinet/src/features/flight_inspection/domain/entities/flight_inspection.dart';

/// 飞检数据边界。
abstract interface class FlightInspectionRepository {
  Future<FlightInspectionData> fetchFlightInspectionData();
}
