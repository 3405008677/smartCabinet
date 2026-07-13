import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/widgets/face_verification_card.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/widgets/sensor_verification_card.dart';

/// 共享身份认证组件测试。
///
/// 重点验证共享卡片是否能触发外部回调，以及测试环境下的人脸 fallback 是否可走通。
void main() {
  testWidgets('sensor verification card triggers confirmation', (
    WidgetTester tester,
  ) async {
    /// 用于确认点击按钮后外部回调是否真的被触发。
    var confirmed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SensorVerificationCard(
            title: '指纹识别',
            subtitle: 'Fingerprint Scan',
            icon: Icons.fingerprint_rounded,
            stepNumber: 2,
            verified: false,
            actionText: '确认指纹识别',
            verifiedText: '指纹识别已完成',
            onConfirm: () => confirmed = true,
          ),
        ),
      ),
    );

    expect(find.text('指纹识别'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('确认指纹识别'), findsOneWidget);

    await tester.tap(find.text('确认指纹识别'));

    expect(confirmed, isTrue);
  });

  testWidgets('face verification card can fallback without camera', (
    WidgetTester tester,
  ) async {
    /// 通过 fallback 模式验证无摄像头测试环境下的人脸流程仍然可用。
    var verified = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 520,
            child: FaceVerificationCard(
              verified: false,
              stepNumber: 1,
              allowFallbackWithoutCamera: true,
              onVerified: () => verified = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('人脸识别'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('正在启动摄像头...'), findsWidgets);
    expect(find.text('确认并拍照校验'), findsOneWidget);

    await tester.tap(find.text('确认并拍照校验'));
    await tester.pumpAndSettle();

    expect(verified, isTrue);
  });
}
