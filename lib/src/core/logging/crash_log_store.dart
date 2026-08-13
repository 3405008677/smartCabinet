/// 单条崩溃或严重错误日志。
class CrashLogEntry {
  /// 创建崩溃日志条目。
  const CrashLogEntry({
    required this.time,
    required this.message,
    required this.error,
    required this.stackTrace,
  });

  /// 日志发生时间。
  final DateTime time;

  /// 当前场景说明。
  final String message;

  /// 错误内容。
  final String error;

  /// 堆栈内容。
  final String stackTrace;
}

/// 崩溃日志存储。
///
/// 当前先使用内存环形队列，保证 Flutter 层可测试、可查询。
/// 后续接入文件或数据库时，可以保持公开方法不变。该存储只覆盖当前进程生命期，
/// 不能替代原生持久化日志或远程故障上报。
class CrashLogStore {
  CrashLogStore._();

  /// 全局崩溃日志存储实例。
  static final CrashLogStore instance = CrashLogStore._();

  /// 内存中最多保留的最近错误数，避免长期运行后日志集合无界增长。
  static const int _maxEntries = 100;

  /// 按发生时间从旧到新保存的环形队列内容。
  final List<CrashLogEntry> _entries = <CrashLogEntry>[];

  /// 写入崩溃日志；超过容量时丢弃最旧记录。
  void record({
    required String message,
    required Object error,
    StackTrace? stackTrace,
    DateTime? time,
  }) {
    _entries.add(
      CrashLogEntry(
        time: time ?? DateTime.now(),
        message: message,
        error: error.toString(),
        stackTrace: stackTrace?.toString() ?? '',
      ),
    );
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
  }

  /// 查询最近的崩溃日志。
  ///
  /// 结果按从新到旧排列；负数 [limit] 按 0 处理，返回列表不与内部队列共享。
  List<CrashLogEntry> recentLogs({int limit = 20}) {
    final safeLimit = limit < 0 ? 0 : limit;
    return _entries.reversed.take(safeLimit).toList(growable: false);
  }

  /// 清空日志，供测试和手动维护使用。
  void clear() => _entries.clear();
}
