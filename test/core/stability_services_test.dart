import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cabinet/src/core/device/hardware_recovery_advice.dart';
import 'package:smart_cabinet/src/core/logging/app_logger.dart';
import 'package:smart_cabinet/src/core/logging/crash_log_store.dart';
import 'package:smart_cabinet/src/core/monitoring/runtime_health_monitor.dart';

/// 稳定性基础服务测试。
///
/// 用于验证崩溃日志记录、运行健康监测和硬件异常恢复建议这些底层能力是否按预期工作。
void main() {
  setUp(() {
    /// 每个用例前清空全局单例状态，避免不同测试之间相互污染。
    CrashLogStore.instance.clear();
    RuntimeHealthMonitor.instance.resetForTest();
  });

  test('app logger stores crash logs for later inspection', () {
    /// 构造一条错误和堆栈，模拟应用内部捕获到的真实崩溃记录。
    final error = StateError('camera crashed');
    final stackTrace = StackTrace.current;

    AppLogger.error('Camera failure', error, stackTrace);

    /// 读取最近崩溃日志，确认错误已经成功落入本地可查询存储。
    final logs = CrashLogStore.instance.recentLogs();
    expect(logs, hasLength(1));
    expect(logs.single.message, 'Camera failure');
    expect(logs.single.error, contains('camera crashed'));
    expect(logs.single.stackTrace, contains('stability_services_test.dart'));
  });

  test('runtime health monitor records heartbeat, memory, and jank risk', () {
    /// 直接读取全局监测器，模拟启动、心跳、内存和卡顿记录过程。
    final monitor = RuntimeHealthMonitor.instance;

    monitor.start(now: DateTime(2026, 6, 18, 9));
    monitor.recordHeartbeat(now: DateTime(2026, 6, 18, 9, 1));
    monitor.recordMemorySample(
      usedBytes: 128 * 1024 * 1024,
      now: DateTime(2026, 6, 18, 9, 2),
    );
    monitor.recordJankRisk(
      reason: 'main isolate blocked for 150ms',
      now: DateTime(2026, 6, 18, 9, 3),
    );

    /// 拉取监测快照，确认内部状态聚合正确。
    final snapshot = monitor.snapshot(now: DateTime(2026, 6, 18, 10));
    expect(snapshot.uptime, const Duration(hours: 1));
    expect(snapshot.lastHeartbeat, DateTime(2026, 6, 18, 9, 1));
    expect(snapshot.memorySamples.single.usedBytes, 128 * 1024 * 1024);
    expect(snapshot.jankRisks.single.reason, 'main isolate blocked for 150ms');
  });

  test('hardware recovery advice explains how to recover field failures', () {
    final cameraAdvice = HardwareRecoveryAdvice.forFailure(
      hardware: CabinetHardware.camera,
      failure: HardwareFailure.permissionDenied,
    );
    final fingerprintAdvice = HardwareRecoveryAdvice.forFailure(
      hardware: CabinetHardware.fingerprint,
      failure: HardwareFailure.unavailable,
    );
    final nfcAdvice = HardwareRecoveryAdvice.forFailure(
      hardware: CabinetHardware.nfc,
      failure: HardwareFailure.timeout,
    );
    final cabinetAdvice = HardwareRecoveryAdvice.forFailure(
      hardware: CabinetHardware.cabinetController,
      failure: HardwareFailure.disconnected,
    );

    expect(cameraAdvice.recoverySteps, contains('到系统设置开启摄像头权限'));
    expect(fingerprintAdvice.recoverySteps, contains('清洁指纹模块并重新按压'));
    expect(nfcAdvice.recoverySteps, contains('重新贴近 NFC 读卡区域'));
    expect(cabinetAdvice.recoverySteps, contains('检查柜控板电源和通讯线'));
  });
}
