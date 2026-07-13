import 'package:smart_cabinet/src/features/flight_inspection/data/datasources/flight_inspection_remote_data_source.dart';
import 'package:smart_cabinet/src/features/flight_inspection/data/dtos/flight_inspection_response_dto.dart';
import 'package:smart_cabinet/src/features/flight_inspection/domain/entities/flight_inspection.dart';
import 'package:smart_cabinet/src/features/flight_inspection/domain/repositories/flight_inspection_repository.dart';

/// 飞检数据仓库。
class FlightInspectionRepositoryImpl implements FlightInspectionRepository {
  /// 创建飞检数据仓库。
  const FlightInspectionRepositoryImpl();

  /// 获取飞检展示数据。
  ///
  /// 页面层只读取 [FlightInspectionData]，不会直接接触 DTO 或动态结构。
  @override
  Future<FlightInspectionData> fetchFlightInspectionData() async {
    final dto = await flightInspectionTaskAPI();
    return _mapFlightInspectionDtoToModel(dto);
  }

  /// 将飞检 DTO 转为页面模型。
  ///
  /// 当前飞检任务列表、批次号和人员信息都在这里完成统一映射。
  FlightInspectionData _mapFlightInspectionDtoToModel(
    FlightInspectionResponseDto dto,
  ) {
    return FlightInspectionData.fromMap(dto.raw);
  }
}

/// 默认飞检仓库实例。
const FlightInspectionRepository flightInspectionRepository =
    FlightInspectionRepositoryImpl();
