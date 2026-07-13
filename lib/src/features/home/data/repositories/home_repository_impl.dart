import '../api/Home/Dashboard/index.dart';
import '../dto/home_response_dto.dart';
import '../models/home_model.dart';

/// 首页仓库接口。
abstract interface class IHomeRepository {
  /// 获取首页展示数据。
  Future<HomeModel> fetchHomeData();
}

/// 首页数据仓库。
class HomeRepository implements IHomeRepository {
  /// 创建首页数据仓库。
  const HomeRepository();

  /// 获取首页展示数据。
  ///
  /// 页面只接收 [HomeModel]，因此接口结构变化会被限制在 Repository 内部。
  @override
  Future<HomeModel> fetchHomeData() async {
    final dto = await homeDashboardAPI();
    return _mapHomeDtoToModel(dto);
  }

  /// 将首页 DTO 转为页面模型。
  ///
  /// 这里把首页统计区和底部摘要区分别转换为更明确的子模型，
  /// 避免页面直接从动态 Map 中取值。
  HomeModel _mapHomeDtoToModel(HomeResponseDto dto) {
    return HomeModel(
      cabinetCode: dto.cabinetCode,
      region: dto.region,
      status: dto.status,
      headline: dto.headline,
      stats: HomeStatsModel.fromMap(dto.stats),
      footer: HomeFooterModel.fromMap(dto.footer),
    );
  }
}

/// 默认首页仓库实例。
const HomeRepository homeRepository = HomeRepository();
