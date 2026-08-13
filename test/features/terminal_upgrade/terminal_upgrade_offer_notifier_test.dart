import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/overlays/terminal_upgrade_offer_overlay.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/domain/entities/terminal_upgrade.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/presentation/terminal_upgrade_offer_notifier.dart';

/// 后台 S03 提升为管理员可见入口的 Widget 回归测试。
void main() {
  testWidgets(
    'shows one redacted administrator prompt without starting installation',
    (tester) async {
      final notifier = TerminalUpgradeOfferNotifier();
      final navigatorKey = GlobalKey<NavigatorState>();
      addTearDown(notifier.resetForTesting);

      await tester.pumpWidget(
        AppLocalizationsScope(
          localizations: const AppLocalizations(AppLanguage.simplifiedChinese),
          child: MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) => TerminalUpgradeOfferOverlay(
              notifier: notifier,
              navigatorKey: navigatorKey,
              child: child ?? const SizedBox.shrink(),
            ),
            home: const Scaffold(body: Text('首页')),
          ),
        ),
      );

      final offer = TerminalUpgradeOffer(
        targetVersion: '2.0.0',
        downloadUrl: Uri.parse(
          'https://user:secret@updates.example.com/app.apk?token=private',
        ),
        md5: '0123456789abcdef0123456789abcdef',
        packageTag: '',
        serialNumber: 10,
      );
      notifier.show(offer);
      notifier.show(offer);
      await tester.pump();

      expect(find.text('发现终端新版本'), findsOneWidget);
      expect(find.text('服务端已提供版本 2.0.0。请管理员确认后下载并安装。'), findsOneWidget);
      expect(find.text('管理员处理'), findsOneWidget);
      expect(find.textContaining('updates.example.com'), findsNothing);
      expect(find.textContaining(offer.md5), findsNothing);

      await tester.tap(find.text('管理员处理'));
      await tester.pumpAndSettle();

      expect(find.text('管理员后台'), findsOneWidget);
      // 登录弹窗覆盖提示；只有真正进入升级页才清除 offer，取消登录后仍可重试。
      expect(find.text('发现终端新版本'), findsOneWidget);
    },
  );
}
