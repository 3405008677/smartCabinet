import 'package:smart_cabinet/src/core/network/api_client.dart';

/// 管理员登录 URL。
const String adminLoginUrl = '/api/admin/login';

/// 管理员登录接口边界。
///
/// 这里只声明业务路径和请求体；当前模拟传输或未来真实网络由 [apiClient] 决定。
Future<Map<String, Object>> adminLoginAPI({
  required String username,
  required String password,
}) {
  return apiClient.post<Map<String, Object>>(
    adminLoginUrl,
    body: {'username': username, 'password': password},
  );
}
