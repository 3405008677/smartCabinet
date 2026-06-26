import 'package:flutter/foundation.dart';

import 'crash_log_store.dart';

/// 应用日志工具。
///
/// 统一通过这个类输出日志，后续如果要接入文件日志、远程日志平台，
/// 只需要改这里，不必到处修改业务代码。
class AppLogger {
  const AppLogger._();

  /// 输出调试日志。
  ///
  /// 只在 Debug 模式打印，避免生产环境输出过多调试信息。
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('[DEBUG] $message');
    }
  }

  /// 输出业务日志。
  ///
  /// 适合记录用户操作、关键业务流程等信息。
  static void business(String message) {
    debugPrint('[BUSINESS] $message');
  }

  /// 输出错误日志。
  ///
  /// [message] 是当前场景说明，[error] 是具体错误对象，
  /// [stackTrace] 可以帮助定位错误发生的代码位置。
  static void error(String message, Object error, StackTrace? stackTrace) {
    CrashLogStore.instance.record(
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
    debugPrint('[ERROR] $message: $error');
    if (stackTrace != null && kDebugMode) {
      debugPrint(stackTrace.toString());
    }
  }
}
