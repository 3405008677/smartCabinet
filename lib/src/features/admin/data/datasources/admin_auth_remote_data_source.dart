import 'package:smart_cabinet/src/core/network/api_client.dart';

/// 管理员登录 URL。
const String adminLoginUrl = '/api/admin/login';

/// 管理员登录校验接口。
Future<Map<String, Object>> adminLoginAPI({
  required String username,
  required String password,
}) {
  return apiClient.post<Map<String, Object>>(
    adminLoginUrl,
    body: {'username': username, 'password': password},
  );
}
