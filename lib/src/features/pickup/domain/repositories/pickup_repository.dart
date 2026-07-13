import 'package:smart_cabinet/src/features/pickup/domain/entities/pickup.dart';

/// 取件数据边界。
abstract interface class PickupRepository {
  Future<PickupData> fetchPickupData();
}
