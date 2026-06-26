/// 启动任务执行状态。
enum StartupTaskStatus {
  /// 等待执行。
  pending,

  /// 正在执行。
  running,

  /// 执行成功。
  succeeded,

  /// 执行失败。
  failed,
}

/// 应用启动阶段的一个可编排任务。
abstract interface class StartupTask {
  /// 任务名称，用于日志、错误页和后续启动页展示。
  String get name;

  /// 执行顺序，数值越小越早执行。
  int get order;

  /// 是否为关键任务。
  ///
  /// 关键任务失败时，软件不会进入主界面。
  bool get required;

  /// 单个任务的最长等待时间。
  Duration get timeout;

  /// 执行启动逻辑。
  Future<void> run();
}

/// 单个启动任务的执行结果。
class StartupTaskResult {
  /// 创建启动任务执行结果。
  const StartupTaskResult({
    required this.name,
    required this.status,
    required this.required,
    required this.duration,
    this.error,
    this.stackTrace,
  });

  /// 任务名称。
  final String name;

  /// 任务状态。
  final StartupTaskStatus status;

  /// 是否为关键任务。
  final bool required;

  /// 任务耗时。
  final Duration duration;

  /// 失败错误。
  final Object? error;

  /// 失败堆栈。
  final StackTrace? stackTrace;

  /// 是否执行成功。
  bool get succeeded => status == StartupTaskStatus.succeeded;
}

/// 完整启动结果。
class StartupResult {
  /// 创建完整启动结果。
  const StartupResult({required this.taskResults});

  /// 所有已执行任务的结果。
  final List<StartupTaskResult> taskResults;

  /// 是否所有关键任务都执行成功。
  bool get canEnterApp {
    return taskResults.every((result) => !result.required || result.succeeded);
  }

  /// 第一个失败的关键任务。
  StartupTaskResult? get firstRequiredFailure {
    for (final result in taskResults) {
      if (result.required && !result.succeeded) {
        return result;
      }
    }
    return null;
  }
}

/// 启动关键任务失败。
class StartupFailedException implements Exception {
  /// 创建启动失败异常。
  const StartupFailedException(this.result);

  /// 启动结果。
  final StartupResult result;

  @override
  String toString() {
    final failure = result.firstRequiredFailure;
    if (failure == null) {
      return 'Startup failed';
    }
    return 'Startup failed at ${failure.name}: ${failure.error}';
  }
}
