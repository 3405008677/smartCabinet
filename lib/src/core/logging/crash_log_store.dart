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
/// 后续接入文件或数据库时，可以保持公开方法不变。
class CrashLogStore {
  CrashLogStore._();

  /// 全局崩溃日志存储实例。
  static final CrashLogStore instance = CrashLogStore._();

  static const int _maxEntries = 100;

  final List<CrashLogEntry> _entries = <CrashLogEntry>[];

  /// 写入崩溃日志。
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
  List<CrashLogEntry> recentLogs({int limit = 20}) {
    final safeLimit = limit < 0 ? 0 : limit;
    return _entries.reversed.take(safeLimit).toList(growable: false);
  }

  /// 清空日志，供测试和手动维护使用。
  void clear() => _entries.clear();
}
