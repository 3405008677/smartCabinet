import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/theme/app_theme.dart';
import 'package:smart_cabinet/src/features/home/domain/entities/home.dart';
import 'package:smart_cabinet/src/features/home/presentation/widgets/home_dashboard.dart';

/// 验证首页只暴露新的身份登录入口，并适配柜机目标分辨率。
void main() {
  testWidgets('首页展示可点击的人脸和账号登录入口且不再展示旧业务入口', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var faceLoginCount = 0;
    var accountLoginCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: AppLocalizationsScope(
          localizations: const AppLocalizations(AppLanguage.simplifiedChinese),
          child: Scaffold(
            body: HomeDashboard(
              homeData: HomeData.fallback(),
              onCabinetModelTap: () {},
              onFaceLogin: () => faceLoginCount += 1,
              onAccountLogin: () => accountLoginCount += 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final faceLogin = find.byKey(const ValueKey('home_face_login_action'));
    final accountLogin = find.byKey(
      const ValueKey('home_account_login_action'),
    );

    expect(faceLogin, findsOneWidget);
    expect(accountLogin, findsOneWidget);
    expect(
      find.byKey(const ValueKey('home_task_background_image')),
      findsOneWidget,
    );
    expect(find.text('人脸登录'), findsOneWidget);
    expect(find.text('账号登录'), findsOneWidget);
    expect(find.text('任务概览'), findsNothing);
    expect(find.text('存证'), findsNothing);
    expect(find.text('取证'), findsNothing);
    expect(find.text('借证'), findsNothing);
    expect(find.text('还证'), findsNothing);
    expect(find.text('盘点任务'), findsNothing);
    expect(find.text('存取件'), findsNothing);
    expect(find.text('飞检操作'), findsNothing);

    final identityTitleRect = tester.getRect(find.text('身份登录'));
    final faceLoginRect = tester.getRect(faceLogin);
    final accountLoginRect = tester.getRect(accountLogin);
    final buttonGroupCenterX =
        (faceLoginRect.center.dx + accountLoginRect.center.dx) / 2;

    expect(buttonGroupCenterX, closeTo(identityTitleRect.center.dx, 1));
    expect(faceLoginRect.top - identityTitleRect.bottom, lessThan(100));

    await tester.tap(faceLogin);
    await tester.tap(accountLogin);
    await tester.pumpAndSettle();

    expect(faceLoginCount, 1);
    expect(accountLoginCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('四种语言下登录内容保持居中且按钮不溢出', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final language in AppLanguage.values) {
      final localizations = AppLocalizations(language);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AppLocalizationsScope(
            localizations: localizations,
            child: Scaffold(
              body: HomeDashboard(
                homeData: HomeData.fallback(),
                onCabinetModelTap: () {},
                onFaceLogin: () {},
                onAccountLogin: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final identityTitle = find.text(
        localizations.t('homeIdentityLoginTitle', '身份登录'),
      );
      final faceLogin = find.byKey(const ValueKey('home_face_login_action'));
      final accountLogin = find.byKey(
        const ValueKey('home_account_login_action'),
      );
      final identityTitleRect = tester.getRect(identityTitle);
      final faceLoginRect = tester.getRect(faceLogin);
      final accountLoginRect = tester.getRect(accountLogin);
      final buttonGroupCenterX =
          (faceLoginRect.center.dx + accountLoginRect.center.dx) / 2;

      expect(buttonGroupCenterX, closeTo(identityTitleRect.center.dx, 1));
      expect(faceLoginRect.top - identityTitleRect.bottom, lessThan(100));
      expect(tester.takeException(), isNull);
    }
  });
}
