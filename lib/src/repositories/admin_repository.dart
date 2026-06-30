import '../api/src/Admin/index.dart';
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
  const AdminRepository({this.api = adminApi});

  /// 管理员后台接口实现。
  final AdminApi api;

  @override
  Future<AdminLoginModel> login({
    required String username,
    required String password,
  }) {
    return api.login(username: username, password: password);
  }

  @override
  Future<AdminDeviceStatusModel> fetchDeviceStatus() {
    return api.fetchDeviceStatus();
  }
}

/// 默认管理员仓库实例。
const AdminRepository adminRepository = AdminRepository();
