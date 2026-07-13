import 'package:smart_cabinet/src/core/network/network_result.dart';

/// HTTP 客户端抽象。
///
/// 业务层只依赖这个接口，不直接依赖具体网络库。
/// 这样以后无论使用 dio、http 还是 mock 实现，都可以保持业务代码稳定。
abstract interface class HttpClient {
  /// 发送 GET 请求。
  ///
  /// [path] 是接口路径，返回值用 [NetworkResult] 表示成功或失败。
  Future<NetworkResult<T>> get<T>(String path);

  /// 发送 POST 请求。
  ///
  /// [body] 是可选请求体，通常可以是 Map、List 或其它可序列化对象。
  Future<NetworkResult<T>> post<T>(String path, {Object? body});
}
