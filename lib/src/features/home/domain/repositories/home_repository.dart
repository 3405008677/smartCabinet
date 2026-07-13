import 'package:smart_cabinet/src/features/home/domain/entities/home.dart';

/// 首页数据边界。
abstract interface class HomeRepository {
  Future<HomeData> fetchHomeData();
}
