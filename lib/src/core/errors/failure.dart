/// 失败结果模型。
///
/// 和 [AppException] 不同，Failure 通常用于“返回错误结果”，
/// 而不是直接抛出异常。
class Failure {
  /// 创建失败信息。
  const Failure({required this.message, this.code, this.cause});

  /// 错误说明。
  final String message;

  /// 可选错误码。
  final String? code;

  /// 原始错误对象。
  final Object? cause;
}
