/// 应用自定义异常。
///
/// 当业务或基础设施层需要抛出明确错误时，可以使用这个类型，
/// 比直接抛字符串或普通 [Exception] 更容易统一处理。
class AppException implements Exception {
  /// 创建应用异常。
  const AppException(this.message, {this.code, this.cause});

  /// 给用户或开发者看的错误说明。
  final String message;

  /// 可选错误码，方便和后端或业务规则对应。
  final String? code;

  /// 原始异常对象。
  ///
  /// 例如网络库、数据库或平台通道抛出的底层错误。
  final Object? cause;

  @override
  String toString() => 'AppException(code: $code, message: $message)';
}
