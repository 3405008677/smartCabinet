import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cabinet/src/core/device/hardware_recovery_advice.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/widgets/sensor_verification_card.dart';

void main() {
  testWidgets('sensor card shows hardware recovery advice when unavailable', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SensorVerificationCard(
            title: '指纹识别',
            subtitle: 'Fingerprint Scan',
            icon: Icons.fingerprint_rounded,
            verified: false,
            actionText: '确认指纹识别',
            verifiedText: '指纹识别已完成',
            onConfirm: () {},
            recoveryAdvice: HardwareRecoveryAdvice.forFailure(
              hardware: CabinetHardware.fingerprint,
              failure: HardwareFailure.unavailable,
            ),
          ),
        ),
      ),
    );

    expect(find.text('指纹模块不可用'), findsOneWidget);
    expect(find.textContaining('清洁指纹模块并重新按压'), findsOneWidget);
    expect(find.text('重新检测'), findsOneWidget);
  });
}
