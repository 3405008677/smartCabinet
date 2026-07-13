import 'package:smart_cabinet/src/core/network/fake_http_client.dart';
import 'package:smart_cabinet/src/core/network/http_client.dart';
import 'package:smart_cabinet/src/core/network/network_result.dart';

/// 全局 API 异常。
class ApiException implements Exception {
  /// 创建 API 异常。
  const ApiException(this.message, {this.code});

  /// 错误说明。
  final String message;

  /// 可选错误码。
  final String? code;

  @override
  String toString() => code == null ? message : '$message ($code)';
}

/// 全局 API 请求封装。
///
/// 页面级 API 只负责声明业务接口路径和 DTO 转换，通用请求错误处理统一收敛在这里。
class ApiClient {
  /// 创建 API 客户端。
  const ApiClient({this.httpClient = fakeHttpClient});

  /// 底层 HTTP 客户端。
  final HttpClient httpClient;

  /// 发送 GET 请求，失败时统一抛出 [ApiException]。
  Future<T> get<T>(String path) async {
    return _unwrap(await httpClient.get<T>(path));
  }

  /// 发送 POST 请求，失败时统一抛出 [ApiException]。
  Future<T> post<T>(String path, {Object? body}) async {
    return _unwrap(await httpClient.post<T>(path, body: body));
  }

  T _unwrap<T>(NetworkResult<T> result) {
    return switch (result) {
      NetworkSuccess<T>(data: final data) => data,
      NetworkFailure<T>(message: final message, code: final code) =>
        throw ApiException(message, code: code),
    };
  }
}

/// 默认全局 API 客户端。
const ApiClient apiClient = ApiClient();
