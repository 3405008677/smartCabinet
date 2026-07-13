import 'package:smart_cabinet/src/features/admin/data/datasources/admin_console_remote_data_source.dart';
import 'package:smart_cabinet/src/features/admin/data/datasources/admin_auth_remote_data_source.dart';
import 'package:smart_cabinet/src/features/admin/domain/entities/admin.dart';
import 'package:smart_cabinet/src/features/admin/domain/repositories/admin_repository.dart';

/// 管理员后台数据仓库。
class AdminRepositoryImpl implements AdminRepository {
  /// 创建管理员后台数据仓库。
  const AdminRepositoryImpl();

  @override
  Future<AdminLoginResult> login({
    required String username,
    required String password,
  }) async {
    final data = await adminLoginAPI(username: username, password: password);

    final authorized =
        username == data['username'] && password == data['password'];
    return AdminLoginResult.fromMap({
      ...data,
      'authorized': authorized,
      'message': authorized ? '管理员权限校验通过' : '账号或密码错误，或没有管理员权限',
    });
  }

  @override
  Future<AdminDeviceStatus> fetchDeviceStatus() {
    return adminDeviceStatusAPI().then(AdminDeviceStatus.fromMap);
  }
}

/// 默认管理员仓库实例。
const AdminRepository adminRepository = AdminRepositoryImpl();
