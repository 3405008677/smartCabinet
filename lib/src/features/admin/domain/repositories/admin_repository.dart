import 'package:smart_cabinet/src/features/admin/domain/entities/admin.dart';

/// 管理员业务数据边界。
abstract interface class AdminRepository {
  /// 校验管理员凭据；认证失败通过结果对象表达，网络或协议故障才抛出异常。
  Future<AdminLoginResult> login({
    required String username,
    required String password,
  });

  /// 读取控制台首屏所需的柜体与外围设备状态快照。
  Future<AdminDeviceStatus> fetchDeviceStatus();
}
