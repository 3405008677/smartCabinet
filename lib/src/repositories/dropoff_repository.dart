import '../api/dropoff_api.dart';
import '../dto/dropoff_response_dto.dart';
import '../models/dropoff_model.dart';

/// 放件仓库接口。
abstract interface class IDropoffRepository {
  /// 获取放件展示数据。
  Future<DropoffModel> fetchDropoffData();
}

/// 放件数据仓库。
class DropoffRepository implements IDropoffRepository {
  /// 创建放件数据仓库。
  const DropoffRepository({this.api = dropoffApi});

  /// 放件接口实现。
  ///
  /// Repository 通过该接口获取放件原始响应，再转换为页面模型。
  final DropoffApi api;

  /// 获取放件展示数据。
  ///
  /// 页面层只接触 [DropoffModel]，便于后续替换数据源而不影响 UI 代码。
  @override
  Future<DropoffModel> fetchDropoffData() async {
    final dto = await api.fetchData();
    return _mapDropoffDtoToModel(dto);
  }

  /// 将放件 DTO 转为页面模型。
  ///
  /// 当前直接基于 DTO 的原始 Map 构建模型，后续字段差异扩大后可在这里细化转换逻辑。
  DropoffModel _mapDropoffDtoToModel(DropoffResponseDto dto) {
    return DropoffModel.fromMap(dto.raw);
  }
}

/// 默认放件仓库实例。
const DropoffRepository dropoffRepository = DropoffRepository();
