import 'package:smart_cabinet/src/features/home/data/datasources/home_remote_data_source.dart';
import 'package:smart_cabinet/src/features/home/data/dtos/home_response_dto.dart';
import 'package:smart_cabinet/src/features/home/domain/entities/home.dart';
import 'package:smart_cabinet/src/features/home/domain/repositories/home_repository.dart';

/// 首页数据仓库。
class HomeRepositoryImpl implements HomeRepository {
  /// 创建首页数据仓库。
  const HomeRepositoryImpl();

  /// 获取首页展示数据。
  ///
  /// 页面只接收 [HomeData]，因此接口结构变化会被限制在 Repository 内部。
  @override
  Future<HomeData> fetchHomeData() async {
    final dto = await homeDashboardAPI();
    return _mapHomeDtoToModel(dto);
  }

  /// 将首页 DTO 转为页面模型。
  ///
  /// 这里把首页统计区转换为强类型模型，避免页面直接从动态 Map 中取值。
  HomeData _mapHomeDtoToModel(HomeResponseDto dto) {
    return HomeData(
      cabinetCode: dto.cabinetCode,
      region: dto.region,
      status: dto.status,
      headline: dto.headline,
      stats: HomeStats.fromMap(dto.stats),
    );
  }
}

/// 默认首页仓库实例。
const HomeRepository homeRepository = HomeRepositoryImpl();
