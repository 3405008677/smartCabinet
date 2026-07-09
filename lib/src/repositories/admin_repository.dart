import '../api/Admin/Console/index.dart';
import '../api/Admin/Verification/index.dart';
import '../models/admin_model.dart';

/// 管理员后台仓库接口。
abstract interface class IAdminRepository {
  /// 校验管理员登录权限。
  Future<AdminLoginModel> login({
    required String username,
    required String password,
  });

  /// 获取管理员控制台设备状态。
  Future<AdminDeviceStatusModel> fetchDeviceStatus();
}

/// 管理员后台数据仓库。
class AdminRepository implements IAdminRepository {
  /// 创建管理员后台数据仓库。
  const AdminRepository();

  @override
  Future<AdminLoginModel> login({
    required String username,
    required String password,
  }) async {
    final data = await adminLoginAPI(username: username, password: password);

    final authorized =
        username == data['username'] && password == data['password'];
    return AdminLoginModel.fromMap({
      ...data,
      'authorized': authorized,
      'message': authorized ? '管理员权限校验通过' : '账号或密码错误，或没有管理员权限',
    });
  }

  @override
  Future<AdminDeviceStatusModel> fetchDeviceStatus() {
    return adminDeviceStatusAPI().then(AdminDeviceStatusModel.fromMap);
  }
}

/// 默认管理员仓库实例。
const AdminRepository adminRepository = AdminRepository();
