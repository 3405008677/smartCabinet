import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cabinet/src/app/overlays/stream_failure_overlay.dart';
import 'package:smart_cabinet/src/core/camera/cabinet_camera.dart';

/// 全局推流异常提示测试。
void main() {
  tearDown(CabinetCameraService.debugReset);

  testWidgets('shows global message when outside stream status fails', (
    tester,
  ) async {
    CabinetCameraService.debugUseCameraData(
      cameras: const <CameraDescription>[],
      outsideEnvironmentStreamStatus: const CameraStreamStatus(
        status: '推流断开：Broken pipe，3 秒后重连第 1 次',
        url: 'rtsp://example.test/app/device-001',
        cameraId: 'cameraId_1',
      ),
    );
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: StreamFailureOverlay(
          navigatorKey: navigatorKey,
          pollingInterval: Duration(milliseconds: 10),
          child: const Scaffold(body: Text('首页')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.textContaining('推流异常：柜外环境推流异常'), findsOneWidget);
    expect(find.textContaining('柜外环境推流异常'), findsOneWidget);
    expect(find.textContaining('3 秒后重连第 1 次'), findsOneWidget);
  });
  testWidgets('polling exceptions never escape the widget zone', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: StreamFailureOverlay(
          navigatorKey: navigatorKey,
          cameraService: const _ThrowingCameraService(),
          pollingInterval: const Duration(milliseconds: 10),
          child: const Scaffold(body: Text('home')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing the overlay closes its persistent prompt', (
    tester,
  ) async {
    CabinetCameraService.debugUseCameraData(
      cameras: const <CameraDescription>[],
      outsideEnvironmentStreamStatus: const CameraStreamStatus(
        status: 'dispose-test failure',
        url: 'rtsp://example.test/app/device-001',
        cameraId: 'cameraId_1',
        state: CameraStreamState.failed,
      ),
    );
    final navigatorKey = GlobalKey<NavigatorState>();
    final showOverlay = ValueNotifier<bool>(true);
    addTearDown(showOverlay.dispose);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: ValueListenableBuilder<bool>(
          valueListenable: showOverlay,
          builder: (context, visible, child) {
            if (!visible) {
              return const Scaffold(body: Text('replacement'));
            }
            return StreamFailureOverlay(
              navigatorKey: navigatorKey,
              pollingInterval: const Duration(milliseconds: 10),
              child: const Scaffold(body: Text('home')),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.textContaining('dispose-test failure'), findsOneWidget);

    showOverlay.value = false;
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('dispose-test failure'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('a timed-out native read does not start overlapping polls', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final cameraService = _HangingCameraService();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: StreamFailureOverlay(
          navigatorKey: navigatorKey,
          cameraService: cameraService,
          pollingInterval: const Duration(milliseconds: 10),
          child: const Scaffold(body: Text('home')),
        ),
      ),
    );
    await tester.pump();

    expect(cameraService.outsideReadCount, 1);
    expect(cameraService.operationReadCount, 1);

    await tester.pump(const Duration(seconds: 2));

    expect(cameraService.outsideReadCount, 1);
    expect(cameraService.operationReadCount, 1);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    cameraService.complete();
    await tester.pump();
  });
}

class _ThrowingCameraService extends CabinetCameraService {
  const _ThrowingCameraService();

  @override
  Future<CameraStreamStatus> readOutsideEnvironmentStreamStatus() {
    return Future<CameraStreamStatus>.error(StateError('outside failed'));
  }

  @override
  Future<CameraStreamStatus> readOperationAreaStreamStatus() {
    return Future<CameraStreamStatus>.error(StateError('operation failed'));
  }
}

class _HangingCameraService extends CabinetCameraService {
  final Completer<CameraStreamStatus> _outsideStatus =
      Completer<CameraStreamStatus>();
  final Completer<CameraStreamStatus> _operationStatus =
      Completer<CameraStreamStatus>();

  int outsideReadCount = 0;
  int operationReadCount = 0;

  @override
  Future<CameraStreamStatus> readOutsideEnvironmentStreamStatus() {
    outsideReadCount++;
    return _outsideStatus.future;
  }

  @override
  Future<CameraStreamStatus> readOperationAreaStreamStatus() {
    operationReadCount++;
    return _operationStatus.future;
  }

  void complete() {
    const status = CameraStreamStatus(
      status: 'streaming',
      url: 'rtsp://example.test/app/device-001',
      cameraId: 'cameraId_1',
      state: CameraStreamState.streaming,
    );
    _outsideStatus.complete(status);
    _operationStatus.complete(status);
  }
}
