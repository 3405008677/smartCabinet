import 'package:smart_cabinet/src/core/network/network_result.dart';
import 'package:smart_cabinet/src/core/network/http_client.dart';
import 'package:smart_cabinet/src/core/network/mock_api_data.dart';

/// 基于内存假数据的 HTTP 客户端。
class FakeHttpClient implements HttpClient {
  /// 创建假数据 HTTP 客户端。
  const FakeHttpClient();

  @override
  /// 模拟 GET 请求。
  ///
  /// 按 [path] 从内存假数据表中取值，若路径不存在则返回 `not_found` 失败结果。
  Future<NetworkResult<T>> get<T>(String path) async {
    final data = mockGetApiData[path];
    if (data == null) {
      return NetworkFailure<T>('未找到对应的假数据接口', code: 'not_found');
    }
    return NetworkSuccess<T>(data as T);
  }

  @override
  /// 模拟 POST 请求。
  ///
  /// 当前不会真实使用 [body] 做业务处理，仅根据路径返回预定义假数据。
  Future<NetworkResult<T>> post<T>(String path, {Object? body}) async {
    final data = mockPostApiData[path];
    if (data == null) {
      return NetworkFailure<T>('未找到对应的假数据接口', code: 'not_found');
    }
    return NetworkSuccess<T>(data as T);
  }
}

/// 全局假数据客户端实例。
const HttpClient fakeHttpClient = FakeHttpClient();
