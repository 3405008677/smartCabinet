import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/routing/app_routes.dart';
import 'package:smart_cabinet/src/features/admin/presentation/widgets/admin_login_dialog.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/presentation/terminal_upgrade_offer_notifier.dart';

/// 在全部业务页面之上展示脱敏的终端升级管理员入口。
///
/// 覆盖层只展示目标版本，不展示 URL、MD5 或设备身份。点击处理后仍先执行管理员
/// 账号登录与三因子校验，认证通过才进入终端升级页；这里绝不直接下载或安装。
final class TerminalUpgradeOfferOverlay extends StatelessWidget {
  /// 创建应用级终端升级提示层。
  const TerminalUpgradeOfferOverlay({
    required this.child,
    required this.navigatorKey,
    this.notifier,
    super.key,
  });

  /// 正常应用内容。
  final Widget child;

  /// 根导航器，用于从全局提示打开受保护的管理员登录弹窗。
  final GlobalKey<NavigatorState> navigatorKey;

  /// 测试可注入的升级 offer 通知器。
  final TerminalUpgradeOfferNotifier? notifier;

  @override
  Widget build(BuildContext context) {
    final effectiveNotifier = notifier ?? globalTerminalUpgradeOfferNotifier;
    return AnimatedBuilder(
      animation: effectiveNotifier,
      child: child,
      builder: (context, child) {
        final offer = effectiveNotifier.currentOffer;
        return Stack(
          fit: StackFit.expand,
          children: [
            child ?? const SizedBox.shrink(),
            if (offer != null)
              _TerminalUpgradeOfferPrompt(
                version: offer.targetVersion,
                onDismiss: effectiveNotifier.dismiss,
                onOpenAdministratorEntry: () {
                  final navigatorContext = navigatorKey.currentContext;
                  if (navigatorContext == null) {
                    return;
                  }
                  showAdminLoginDialog(
                    navigatorContext,
                    postVerificationRoute: AppRoutes.adminTerminalUpgrade,
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

/// 覆盖在当前页面顶部、不会泄露升级地址或设备身份的通知卡片。
final class _TerminalUpgradeOfferPrompt extends StatelessWidget {
  const _TerminalUpgradeOfferPrompt({
    required this.version,
    required this.onDismiss,
    required this.onOpenAdministratorEntry,
  });

  final String version;
  final VoidCallback onDismiss;
  final VoidCallback onOpenAdministratorEntry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Positioned(
      top: 24,
      left: 24,
      right: 24,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Material(
              color: Colors.white,
              elevation: 12,
              shadowColor: const Color(0x330B1F4D),
              borderRadius: BorderRadius.circular(16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFB9CDFB)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.system_update_alt_rounded,
                        color: Color(0xFF2457D6),
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.t(
                                'terminalUpgradeOfferPromptTitle',
                                '发现终端新版本',
                              ),
                              style: const TextStyle(
                                color: Color(0xFF10234E),
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n
                                  .t(
                                    'terminalUpgradeOfferPromptMessage',
                                    '服务端已提供版本 {version}。请管理员确认后下载并安装。',
                                  )
                                  .replaceAll('{version}', version),
                              style: const TextStyle(
                                color: Color(0xFF52607A),
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: onOpenAdministratorEntry,
                        child: Text(
                          l10n.t('terminalUpgradeOfferPromptAction', '管理员处理'),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: l10n.t('messageDismiss', '关闭提示'),
                        child: IconButton(
                          onPressed: onDismiss,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
