import 'package:smart_cabinet/src/features/pickup/data/datasources/pickup_remote_data_source.dart';
import 'package:smart_cabinet/src/features/pickup/data/dtos/pickup_response_dto.dart';
import 'package:smart_cabinet/src/features/pickup/domain/entities/pickup.dart';
import 'package:smart_cabinet/src/features/pickup/domain/repositories/pickup_repository.dart';

/// 取件数据仓库。
class PickupRepositoryImpl implements PickupRepository {
  /// 创建取件数据仓库。
  const PickupRepositoryImpl();

  /// 获取取件展示数据。
  ///
  /// 页面层只依赖 [PickupData]，不直接操作 DTO，
  /// 这样后续接口字段变化时不会把影响扩散到页面代码。
  @override
  Future<PickupData> fetchPickupData() async {
    final dto = await pickupVerificationAPI();
    return _mapPickupDtoToModel(dto);
  }

  /// 将取件 DTO 转为页面模型。
  ///
  /// 当前模型创建仍基于 `raw` Map，是因为页面所需字段和接口字段基本一致；
  /// 如果后续页面模型与接口协议明显分离，可以在这里增加更明确的字段转换逻辑。
  PickupData _mapPickupDtoToModel(PickupResponseDto dto) {
    return PickupData.fromMap(dto.raw);
  }
}

/// 默认取件仓库实例。
const PickupRepository pickupRepository = PickupRepositoryImpl();
