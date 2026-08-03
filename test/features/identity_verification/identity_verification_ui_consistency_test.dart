import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/app/theme/app_theme.dart';
import 'package:smart_cabinet/src/core/config/app_config.dart';
import 'package:smart_cabinet/src/features/admin/presentation/pages/admin_verification_page.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_identity_navigation.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/pages/operator_verification_page.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/widgets/verification_step_card.dart';

void main() {
  testWidgets('operator and admin verification use the same card layout', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const AdminVerificationPage(),
      ),
    );
    await tester.pumpAndSettle();
    final adminCardSize = tester.getSize(
      find.byType(VerificationStepCard).first,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const OperatorVerificationPage(
          appConfig: AppConfig(
            appName: '测试终端',
            apiBaseUrl: '',
            isTestMode: true,
          ),
          arguments: OperatorVerificationArguments(
            account: OperatorAccount(
              id: 'operator-layout',
              username: '666666',
              name: '测试操作员',
              organizationId: 'org-001',
              organizationName: '测试机构',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final operatorCardSize = tester.getSize(
      find.byType(VerificationStepCard).first,
    );

    expect(operatorCardSize.width, adminCardSize.width);
    expect(operatorCardSize.height, closeTo(adminCardSize.height, 4));
    expect(operatorCardSize.width, 295);
    expect(operatorCardSize.height, lessThanOrEqualTo(500));
    expect(tester.takeException(), isNull);
  });
}
