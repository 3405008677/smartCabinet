/// 网络请求结果基类。
///
/// 使用 sealed class 可以让 Dart 知道所有可能的子类型，
/// 配合 switch 时更容易写出完整的成功/失败处理逻辑。
sealed class NetworkResult<T> {
  const NetworkResult();
}

/// 网络请求成功。
class NetworkSuccess<T> extends NetworkResult<T> {
  /// 创建成功结果。
  const NetworkSuccess(this.data);

  /// 接口返回的数据。
  final T data;
}

/// 网络请求失败。
class NetworkFailure<T> extends NetworkResult<T> {
  /// 创建失败结果。
  const NetworkFailure(this.message, {this.code});

  /// 错误说明。
  final String message;

  /// 可选错误码。
  final String? code;
}
