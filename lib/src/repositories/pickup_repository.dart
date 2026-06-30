import '../api/src/Pickup/index.dart';
import '../dto/pickup_response_dto.dart';
import '../models/pickup_model.dart';

/// 取件仓库接口。
abstract interface class IPickupRepository {
  /// 获取取件展示数据。
  Future<PickupModel> fetchPickupData();
}

/// 取件数据仓库。
class PickupRepository implements IPickupRepository {
  /// 创建取件数据仓库。
  const PickupRepository({this.api = pickupApi});

  /// 取件接口实现。
  ///
  /// Repository 不直接关心数据来自假数据还是真实网络，
  /// 只依赖接口层返回的 DTO，再统一映射为页面模型。
  final PickupApi api;

  /// 获取取件展示数据。
  ///
  /// 页面层只依赖 [PickupModel]，不直接操作 DTO，
  /// 这样后续接口字段变化时不会把影响扩散到页面代码。
  @override
  Future<PickupModel> fetchPickupData() async {
    final dto = await api.fetchData();
    return _mapPickupDtoToModel(dto);
  }

  /// 将取件 DTO 转为页面模型。
  ///
  /// 当前模型创建仍基于 `raw` Map，是因为页面所需字段和接口字段基本一致；
  /// 如果后续页面模型与接口协议明显分离，可以在这里增加更明确的字段转换逻辑。
  PickupModel _mapPickupDtoToModel(PickupResponseDto dto) {
    return PickupModel.fromMap(dto.raw);
  }
}

/// 默认取件仓库实例。
const PickupRepository pickupRepository = PickupRepository();
