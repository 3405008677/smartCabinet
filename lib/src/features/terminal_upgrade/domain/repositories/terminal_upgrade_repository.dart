import 'dart:async';

import 'package:smart_cabinet/src/features/terminal_upgrade/domain/entities/terminal_upgrade.dart';

/// 终端升级监控与安装的领域契约。
abstract interface class TerminalUpgradeRepository {
  /// 当前升级状态快照。
  TerminalUpgradeSnapshot get current;

  /// 后续升级状态变化。
  Stream<TerminalUpgradeSnapshot> get states;

  /// 使用现场配置启动或重启升级监控。
  ///
  /// 该方法只启动后台连接循环，不等待长期 Socket 会话结束。
  Future<void> start(TerminalUpgradeSettings settings);

  /// 停止连接与自动重连，但不取消已经提交给系统的安装会话。
  Future<void> stop();

  /// 在已登录连接上重新发送一次 T03；断线时立即重新连接。
  Future<void> requestCheck();

  /// 下载、校验并提交管理员刚刚确认的 S03 升级包。
  ///
  /// [confirmedOffer] 必须是确认弹窗打开时展示的同一个不可变对象，
  /// [administratorConfirmed] 必须来自本次明确确认；Repository 会再次核对，
  /// 避免弹窗期间 offer 被替换或其它调用方绕过确认直接安装。
  Future<void> installAvailableUpdate({
    required TerminalUpgradeOffer confirmedOffer,
    required bool administratorConfirmed,
  });

  /// 读取 Android PackageInstaller 最近一次异步结果。
  Future<void> refreshInstallStatus();

  /// 释放 Socket、计时器与状态流。
  Future<void> dispose();
}
