import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/core/camera/cabinet_camera.dart';
import 'package:smart_cabinet/src/features/admin/domain/entities/admin.dart';
import 'package:smart_cabinet/src/features/admin/presentation/widgets/admin_auto_detection_dialog.dart';

void main() {
  const deviceStatus = AdminDeviceStatus(
    cabinetCode: 'cabinet-1',
    region: 'A',
    wifiName: 'Factory-WiFi',
    rj45Status: '已连接',
    nfcStatus: '可用',
    fingerprintStatus: '可用',
    cabinetBoardStatus: '待接入',
    scannerStatus: '待接入',
  );
  const outsideCapability = CameraStreamCapability(
    configuredCameraId: '1',
    availableCameraIds: ['1'],
    available: true,
    supportedYuvSizes: [],
    configuredProfiles: [],
  );

  Future<List<AdminDetectionItem>> buildItems(
    WidgetTester tester, {
    required CameraStreamStatus streamStatus,
  }) async {
    late List<AdminDetectionItem> items;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            items = buildAdminDetectionItems(
              context: context,
              deviceStatus: deviceStatus,
              deviceStatusLoading: false,
              deviceStatusError: null,
              cameraConfigLoading: false,
              cameraConfigError: null,
              availableCameras: const [],
              cameraCapabilities: const {
                CabinetCameraRole.outsideEnvironment: outsideCapability,
              },
              cameraCapabilityErrors: const {},
              streamStatusErrors: const {},
              outsideEnvironmentStreamStatus: streamStatus,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return items;
  }

  testWidgets(
    'stream failure does not turn a connected camera into connection failure',
    (tester) async {
      final items = await buildItems(
        tester,
        streamStatus: const CameraStreamStatus(
          status: '推流断开：连接被服务器关闭',
          url: '',
          cameraId: '1',
          enabledProfiles: ['720p'],
          state: CameraStreamState.reconnecting,
          recoverable: true,
          reconnectAttempts: 1,
          lastErrorCode: 'RTSP_WRITE_FAILED',
          lastErrorMessage: 'RTSP 推流失败',
        ),
      );

      final outside = items.singleWhere(
        (item) => item.id == 'camera_outsideEnvironment',
      );
      expect(outside.state, AdminDetectionState.abnormal);
      expect(outside.result, contains('设备连接：连接成功'));
      expect(outside.result, contains('视频推流：自动重连中'));
      expect(outside.recoveryAction, AdminDetectionRecoveryAction.retryStream);
      expect(outside.streamHealthy, isFalse);
    },
  );

  testWidgets('successful stream suppresses a stale historical error', (
    tester,
  ) async {
    final items = await buildItems(
      tester,
      streamStatus: const CameraStreamStatus(
        status: '1080p 推流中',
        url: '',
        cameraId: '1',
        profile: '1080p',
        enabledProfiles: ['1080p'],
        state: CameraStreamState.streaming,
        lastErrorCode: 'UNSUPPORTED_PROFILE',
        lastErrorMessage: '历史 720p 失败',
      ),
    );

    final outside = items.singleWhere(
      (item) => item.id == 'camera_outsideEnvironment',
    );
    expect(outside.state, AdminDetectionState.healthy);
    expect(outside.result, '设备连接：连接成功\n视频推流：1080p 推流中');
    expect(outside.result, isNot(contains('历史 720p 失败')));
    expect(outside.recoveryAction, AdminDetectionRecoveryAction.recheck);
    expect(outside.streamHealthy, isTrue);
  });
  testWidgets('stream status read failure is not reported as stale streaming', (
    tester,
  ) async {
    late List<AdminDetectionItem> items;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            items = buildAdminDetectionItems(
              context: context,
              deviceStatus: deviceStatus,
              deviceStatusLoading: false,
              deviceStatusError: null,
              cameraConfigLoading: false,
              cameraConfigError: '部分摄像头状态读取失败',
              availableCameras: const [],
              cameraCapabilities: const {
                CabinetCameraRole.outsideEnvironment: outsideCapability,
              },
              cameraCapabilityErrors: const {},
              streamStatusErrors: const {
                CabinetCameraRole.outsideEnvironment: '状态通道读取失败',
              },
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final outside = items.singleWhere(
      (item) => item.id == 'camera_outsideEnvironment',
    );
    expect(outside.result, '设备连接：连接成功\n视频推流：状态读取失败');
    expect(outside.state, AdminDetectionState.abnormal);
    expect(outside.result, isNot(contains('推流中')));
    expect(outside.streamHealthy, isFalse);
  });
  testWidgets('camera probe error is not shown as connection success', (
    tester,
  ) async {
    late List<AdminDetectionItem> items;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            items = buildAdminDetectionItems(
              context: context,
              deviceStatus: deviceStatus,
              deviceStatusLoading: false,
              deviceStatusError: null,
              cameraConfigLoading: false,
              cameraConfigError: null,
              availableCameras: const [],
              cameraCapabilities: const {
                CabinetCameraRole.outsideEnvironment: CameraStreamCapability(
                  configuredCameraId: '1',
                  availableCameraIds: ['1'],
                  available: true,
                  supportedYuvSizes: [],
                  configuredProfiles: [],
                  errorCode: 'CAMERA_SERVICE',
                  errorMessage: 'Camera2 服务异常',
                ),
              },
              cameraCapabilityErrors: const {},
              streamStatusErrors: const {},
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final outside = items.singleWhere(
      (item) => item.id == 'camera_outsideEnvironment',
    );
    expect(outside.result, contains('设备连接：连接检测异常'));
    expect(outside.result, isNot(contains('设备连接：连接成功')));
    expect(outside.state, AdminDetectionState.abnormal);
  });
}
