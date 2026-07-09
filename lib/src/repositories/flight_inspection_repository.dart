import '../api/FlightInspection/Task/index.dart';
import '../dto/flight_inspection_response_dto.dart';
import '../models/flight_inspection_model.dart';

/// 飞检仓库接口。
abstract interface class IFlightInspectionRepository {
  /// 获取飞检展示数据。
  Future<FlightInspectionModel> fetchFlightInspectionData();
}

/// 飞检数据仓库。
class FlightInspectionRepository implements IFlightInspectionRepository {
  /// 创建飞检数据仓库。
  const FlightInspectionRepository();

  /// 获取飞检展示数据。
  ///
  /// 页面层只读取 [FlightInspectionModel]，不会直接接触 DTO 或动态结构。
  @override
  Future<FlightInspectionModel> fetchFlightInspectionData() async {
    final dto = await flightInspectionTaskAPI();
    return _mapFlightInspectionDtoToModel(dto);
  }

  /// 将飞检 DTO 转为页面模型。
  ///
  /// 当前飞检任务列表、批次号和人员信息都在这里完成统一映射。
  FlightInspectionModel _mapFlightInspectionDtoToModel(
    FlightInspectionResponseDto dto,
  ) {
    return FlightInspectionModel.fromMap(dto.raw);
  }
}

/// 默认飞检仓库实例。
const FlightInspectionRepository flightInspectionRepository =
    FlightInspectionRepository();
