import 'package:flutter/foundation.dart';

import 'package:smart_cabinet/src/features/terminal_upgrade/domain/entities/terminal_upgrade.dart';

/// 保存应用进程内当前需要管理员处理的升级 offer。
///
/// 本通知器只传递已经由 Repository 校验通过的不可变 offer，不包含导航、下载或
/// 安装副作用。应用级覆盖层负责展示脱敏入口，管理员确认仍由升级页和 Repository
/// 共同校验，远端 S03 不能借此绕过安全门禁。
final class TerminalUpgradeOfferNotifier extends ChangeNotifier {
  TerminalUpgradeOffer? _currentOffer;

  /// 当前需要管理员处理的升级包；没有待处理任务时为 null。
  TerminalUpgradeOffer? get currentOffer => _currentOffer;

  /// 发布一份合法升级包；同一份 offer 的精确重传不会重复刷新界面。
  void show(TerminalUpgradeOffer offer) {
    if (_currentOffer?.identityKey == offer.identityKey) {
      return;
    }
    _currentOffer = offer;
    notifyListeners();
  }

  /// 清除已经处理或失效的升级包；重复清除是幂等操作。
  void dismiss() {
    if (_currentOffer == null) {
      return;
    }
    _currentOffer = null;
    notifyListeners();
  }

  /// 供 Widget 测试在应用重新装配前清除进程级状态。
  @visibleForTesting
  void resetForTesting() => dismiss();
}

/// 应用进程内唯一的升级 offer 通知器。
final TerminalUpgradeOfferNotifier globalTerminalUpgradeOfferNotifier =
    TerminalUpgradeOfferNotifier();
