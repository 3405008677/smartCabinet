import 'package:smart_cabinet/src/features/dropoff/data/datasources/dropoff_remote_data_source.dart';
import 'package:smart_cabinet/src/features/dropoff/data/dtos/dropoff_response_dto.dart';
import 'package:smart_cabinet/src/features/dropoff/domain/entities/dropoff.dart';
import 'package:smart_cabinet/src/features/dropoff/domain/repositories/dropoff_repository.dart';

/// 放件数据仓库。
class DropoffRepositoryImpl implements DropoffRepository {
  /// 创建放件数据仓库。
  const DropoffRepositoryImpl();

  /// 获取放件展示数据。
  ///
  /// 页面层只接触 [DropoffData]，便于后续替换数据源而不影响 UI 代码。
  @override
  Future<DropoffData> fetchDropoffData() async {
    final dto = await dropoffFileVerificationAPI();
    return _mapDropoffDtoToModel(dto);
  }

  /// 将放件 DTO 转为页面模型。
  ///
  /// 当前直接基于 DTO 的原始 Map 构建模型，后续字段差异扩大后可在这里细化转换逻辑。
  DropoffData _mapDropoffDtoToModel(DropoffResponseDto dto) {
    return DropoffData.fromMap(dto.raw);
  }
}

/// 默认放件仓库实例。
const DropoffRepository dropoffRepository = DropoffRepositoryImpl();
