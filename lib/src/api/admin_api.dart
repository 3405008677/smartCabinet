import '../core/network/fake_http_client.dart';
import '../core/network/network_result.dart';
import '../models/admin_model.dart';

/// 管理员后台接口。
class AdminApi {
  /// 创建管理员后台接口实例。
  const AdminApi();

  /// 校验管理员账号密码是否具备权限。
  ///
  /// 当前后台未实现，先读取 `/api/admin/login` 假数据，并用请求参数模拟后端校验。
  Future<AdminLoginModel> login({
    required String username,
    required String password,
  }) async {
    final result = await fakeHttpClient.post<Map<String, Object>>(
      '/api/admin/login',
      body: {'username': username, 'password': password},
    );
    return switch (result) {
      NetworkSuccess<Map<String, Object>>(data: final data) =>
        AdminLoginModel.fromMap({
          ...data,
          'authorized':
              username == data['username'] && password == data['password'],
          'message':
              username == data['username'] && password == data['password']
              ? '管理员权限校验通过'
              : '账号或密码错误，或没有管理员权限',
        }),
      NetworkFailure<Map<String, Object>>(message: final message) =>
        throw Exception(message),
    };
  }

  /// 获取当前柜体设备状态。
  @Deprecated('管理员控制台已改为读取本地 Store 和原生硬件状态。')
  Future<AdminDeviceStatusModel> fetchDeviceStatus() async {
    final result = await fakeHttpClient.get<Map<String, Object>>(
      '/api/admin/device-status',
    );
    return switch (result) {
      NetworkSuccess<Map<String, Object>>(data: final data) =>
        AdminDeviceStatusModel.fromMap(data),
      NetworkFailure<Map<String, Object>>(message: final message) =>
        throw Exception(message),
    };
  }
}

/// 默认管理员接口实例。
const AdminApi adminApi = AdminApi();
