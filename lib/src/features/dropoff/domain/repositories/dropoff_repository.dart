import 'package:smart_cabinet/src/features/dropoff/domain/entities/dropoff.dart';

/// 放件数据边界。
abstract interface class DropoffRepository {
  Future<DropoffData> fetchDropoffData();
}
