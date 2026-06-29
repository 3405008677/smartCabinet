import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cabinet/src/app/stream_failure_overlay.dart';
import 'package:smart_cabinet/src/core/camera/camera_binding_service.dart';

/// 全局推流异常弹窗测试。
void main() {
  tearDown(CameraBindingService.debugReset);

  testWidgets('shows global dialog when outside stream status fails', (
    tester,
  ) async {
    CameraBindingService.debugUseCameraData(
      cameras: const <CameraDescription>[],
      outsideEnvironmentStreamStatus: const CameraStreamStatus(
        status: '推流断开：Broken pipe，3 秒后重连第 1 次',
        url: 'rtsp://example.test/app/device-001',
        cameraId: 'cameraId_1',
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: StreamFailureOverlay(
          pollingInterval: Duration(milliseconds: 10),
          child: Scaffold(body: Text('首页')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('推流异常'), findsOneWidget);
    expect(find.textContaining('柜外环境推流异常'), findsOneWidget);
    expect(find.textContaining('3 秒后重连第 1 次'), findsOneWidget);
  });
}
