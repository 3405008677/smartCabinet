/// 内存采样记录。
class MemorySample {
  /// 创建内存采样记录。
  const MemorySample({required this.time, required this.usedBytes});

  /// 采样时间。
  final DateTime time;

  /// 当前已使用内存字节数。
  final int usedBytes;
}

/// 卡顿风险记录。
class JankRiskEvent {
  /// 创建卡顿风险记录。
  const JankRiskEvent({required this.time, required this.reason});

  /// 记录时间。
  final DateTime time;

  /// 风险原因。
  final String reason;
}

/// 运行健康快照。
class RuntimeHealthSnapshot {
  /// 创建运行健康快照。
  const RuntimeHealthSnapshot({
    required this.startedAt,
    required this.lastHeartbeat,
    required this.uptime,
    required this.memorySamples,
    required this.jankRisks,
  });

  /// 应用启动监测时间。
  final DateTime? startedAt;

  /// 最近一次心跳时间。
  final DateTime? lastHeartbeat;

  /// 已运行时长。
  final Duration uptime;

  /// 内存采样。
  final List<MemorySample> memorySamples;

  /// 卡顿风险事件。
  final List<JankRiskEvent> jankRisks;
}

/// 运行健康监测器。
class RuntimeHealthMonitor {
  RuntimeHealthMonitor._();

  /// 全局运行健康监测实例。
  static final RuntimeHealthMonitor instance = RuntimeHealthMonitor._();

  /// 内存样本和卡顿事件的最大保留数量。
  ///
  /// 这里使用固定上限，避免长时间运行后监测数据无限增长。
  static const int _maxSamples = 240;

  /// 健康监测开始时间。
  DateTime? _startedAt;

  /// 最近一次心跳记录时间。
  DateTime? _lastHeartbeat;

  /// 已采集的内存样本列表。
  final List<MemorySample> _memorySamples = <MemorySample>[];

  /// 已记录的卡顿风险事件列表。
  final List<JankRiskEvent> _jankRisks = <JankRiskEvent>[];

  /// 启动健康监测。
  ///
  /// 如果此前尚未启动过，则记录首次启动时间；
  /// 无论是否首次启动，都会同步刷新一次心跳时间。
  void start({DateTime? now}) {
    _startedAt ??= now ?? DateTime.now();
    recordHeartbeat(now: now);
  }

  /// 记录心跳。
  ///
  /// 心跳通常表示应用主循环仍在正常运行，可用于后续上报在线状态。
  void recordHeartbeat({DateTime? now}) {
    _lastHeartbeat = now ?? DateTime.now();
  }

  /// 记录内存样本。
  ///
  /// 采样会按固定上限保留最近数据，较旧的样本会被移除。
  void recordMemorySample({required int usedBytes, DateTime? now}) {
    _memorySamples.add(
      MemorySample(time: now ?? DateTime.now(), usedBytes: usedBytes),
    );
    if (_memorySamples.length > _maxSamples) {
      _memorySamples.removeAt(0);
    }
  }

  /// 记录卡顿风险。
  ///
  /// 当发现主线程阻塞、长帧或其它明显卡顿征兆时，可调用该方法留痕。
  void recordJankRisk({required String reason, DateTime? now}) {
    _jankRisks.add(JankRiskEvent(time: now ?? DateTime.now(), reason: reason));
    if (_jankRisks.length > _maxSamples) {
      _jankRisks.removeAt(0);
    }
  }

  /// 读取当前健康快照。
  ///
  /// 返回不可变视图，调用方可以安全读取但不应直接修改内部监测集合。
  RuntimeHealthSnapshot snapshot({DateTime? now}) {
    final current = now ?? DateTime.now();
    final startedAt = _startedAt;
    return RuntimeHealthSnapshot(
      startedAt: startedAt,
      lastHeartbeat: _lastHeartbeat,
      uptime: startedAt == null ? Duration.zero : current.difference(startedAt),
      memorySamples: List<MemorySample>.unmodifiable(_memorySamples),
      jankRisks: List<JankRiskEvent>.unmodifiable(_jankRisks),
    );
  }

  /// 重置监测数据，供测试使用。
  ///
  /// 生产代码不应依赖该方法，它主要用于隔离不同测试用例的状态。
  void resetForTest() {
    _startedAt = null;
    _lastHeartbeat = null;
    _memorySamples.clear();
    _jankRisks.clear();
  }
}
