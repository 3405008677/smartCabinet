/// 通用结果类型。
///
/// 当一个操作可能成功也可能失败时，可以返回 [Result]，
/// 避免到处使用异常控制流程。
sealed class Result<T> {
  const Result();
}

/// 成功结果。
class Success<T> extends Result<T> {
  /// 创建成功结果。
  const Success(this.value);

  /// 成功时携带的数据。
  final T value;
}

/// 失败结果。
class Error<T> extends Result<T> {
  /// 创建失败结果。
  const Error(this.message, {this.cause});

  /// 错误说明。
  final String message;

  /// 原始错误对象。
  final Object? cause;
}
