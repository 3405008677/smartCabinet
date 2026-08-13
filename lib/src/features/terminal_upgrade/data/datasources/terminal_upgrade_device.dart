import 'package:smart_cabinet/src/features/terminal_upgrade/domain/entities/terminal_upgrade.dart';

/// 终端升级数据层访问 Android 应用版本与 APK 安装器的抽象边界。
///
/// 该接口只描述升级 Feature 所需的原生设备能力，不负责 STUM 协议决策、
/// 下载或管理员确认。具体平台实现可以通过依赖注入替换，便于 Repository 测试。
abstract interface class TerminalUpgradeDevice {
  /// 读取 Android PackageManager 报告的当前应用版本名和版本号。
  Future<TerminalAppVersion> getAppVersion();

  /// 读取最近一次持久化的 PackageInstaller 会话状态。
  ///
  /// 返回值可能是等待用户确认、提交中或安装终态，由 Repository 决定后续流程。
  Future<TerminalInstallStatus> getInstallStatus();

  /// 将已下载并完成 Dart 侧校验的本地 APK 提交给 PackageInstaller。
  ///
  /// [targetVersion] 是 STUM 协议声明的目标版本；Android 侧仍须独立校验 APK
  /// 元数据、包名、签名连续性和递增版本号，不能信任 Dart 侧校验结果。
  Future<TerminalInstallSubmission> installApk(
    String apkPath, {
    required String targetVersion,
    required String operationId,
  });

  /// 使仍未执行 `PackageInstaller.Session.commit` 的原生提交失效。
  ///
  /// 返回 true 表示取消标记已经作用于排队中或执行中的同一操作；系统会话已经
  /// commit 或操作已经结束时返回 false，调用方必须继续按安装状态收敛维护租约。
  Future<bool> cancelInstall(String operationId);
}
