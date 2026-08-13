import 'package:smart_cabinet/src/features/home/domain/entities/home.dart';

/// 首页数据边界。
abstract interface class HomeRepository {
  /// 读取首页看板快照；调用方只依赖领域模型，不感知底层数据传输方式。
  Future<HomeData> fetchHomeData();
}
