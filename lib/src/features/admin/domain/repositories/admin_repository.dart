import 'package:smart_cabinet/src/features/admin/domain/entities/admin.dart';

/// 管理员业务数据边界。
abstract interface class AdminRepository {
  Future<AdminLoginResult> login({
    required String username,
    required String password,
  });

  Future<AdminDeviceStatus> fetchDeviceStatus();
}
