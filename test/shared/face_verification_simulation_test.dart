import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/features/identity_verification/presentation/widgets/face_verification_card.dart';

void main() {
  testWidgets('test mode face verification skips camera and backend', (
    WidgetTester tester,
  ) async {
    var verified = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 520,
            child: FaceVerificationCard(
              verified: false,
              simulateVerification: true,
              onVerified: () => verified = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('测试模式：点击确认完成人脸模拟认证'), findsWidgets);
    expect(find.text('确认模拟认证'), findsOneWidget);

    await tester.tap(find.text('确认模拟认证'));
    await tester.pumpAndSettle();

    expect(verified, isTrue);
    expect(find.text('测试模式：人脸模拟认证已完成'), findsWidgets);
  });
}
