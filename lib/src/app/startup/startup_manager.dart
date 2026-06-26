import 'dart:async';

import '../../core/logging/app_logger.dart';
import 'startup_task.dart';

/// 应用启动任务管理器。
///
/// 采用稳定优先策略：启动任务按顺序执行，关键任务失败后立即停止，
/// 避免在硬件、缓存或基础设施未准备好时进入主界面。
class StartupManager {
  /// 创建启动任务管理器。
  const StartupManager({required List<StartupTask> tasks}) : this._(tasks);

  const StartupManager._(this._tasks);

  final List<StartupTask> _tasks;

  /// 执行全部启动任务。
  Future<StartupResult> start() async {
    final orderedTasks = [..._tasks]
      ..sort((a, b) => a.order.compareTo(b.order));
    final results = <StartupTaskResult>[];

    for (final task in orderedTasks) {
      final stopwatch = Stopwatch()..start();
      AppLogger.business('Startup task started: ${task.name}');

      try {
        await task.run().timeout(task.timeout);
        stopwatch.stop();

        final result = StartupTaskResult(
          name: task.name,
          status: StartupTaskStatus.succeeded,
          required: task.required,
          duration: stopwatch.elapsed,
        );
        results.add(result);
        AppLogger.business(
          'Startup task succeeded: ${task.name}, ${stopwatch.elapsedMilliseconds}ms',
        );
      } catch (error, stackTrace) {
        stopwatch.stop();

        final result = StartupTaskResult(
          name: task.name,
          status: StartupTaskStatus.failed,
          required: task.required,
          duration: stopwatch.elapsed,
          error: error,
          stackTrace: stackTrace,
        );
        results.add(result);
        AppLogger.error('Startup task failed: ${task.name}', error, stackTrace);

        if (task.required) {
          final startupResult = StartupResult(
            taskResults: List.unmodifiable(results),
          );
          throw StartupFailedException(startupResult);
        }
      }
    }

    return StartupResult(taskResults: List.unmodifiable(results));
  }
}
