import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cabinet/src/core/camera/cabinet_camera.dart';
import 'package:smart_cabinet/src/features/admin/presentation/widgets/admin_camera_capability_panel.dart';

const MethodChannel _kioskChannel = MethodChannel('smart_cabinet/kiosk');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    CabinetCameraService.debugReset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_kioskChannel, null);
  });

  test('parses native Camera2 capability and exact profile compatibility', () {
    final capability = CameraStreamCapability.fromMap({
      'configuredCameraId': '1',
      'availableCameraIds': <String>['0', '1', '2'],
      'available': true,
      'supportedYuvSizes': <Map<String, Object>>[
        <String, Object>{'width': 1920, 'height': 1080},
        <String, Object>{'width': 1024, 'height': 768},
      ],
      'configuredProfiles': <Map<String, Object>>[
        <String, Object>{
          'name': '1080p',
          'width': 1920,
          'height': 1080,
          'compatible': true,
        },
        <String, Object>{
          'name': '720p',
          'width': 1280,
          'height': 720,
          'compatible': false,
        },
      ],
    });

    expect(capability.configuredCameraId, '1');
    expect(capability.available, isTrue);
    expect(
      capability.supportedYuvSizes,
      contains(const CameraYuvSize(1024, 768)),
    );
    expect(capability.incompatibleProfiles, hasLength(1));
    expect(capability.incompatibleProfiles.single.name, '720p');
  });

  test('distinguishes a probe failure from confirmed camera disconnection', () {
    final probeFailure = CameraStreamCapability.fromMap({
      'configuredCameraId': '1',
      'availableCameraIds': <String>['1'],
      'available': true,
      'errorCode': 'CAMERA_SERVICE',
      'errorMessage': 'Camera service unavailable',
    });
    final disconnected = CameraStreamCapability.fromMap({
      'configuredCameraId': '1',
      'availableCameraIds': const <String>[],
      'available': false,
      'errorCode': 'CAMERA_OFFLINE',
    });

    expect(probeFailure.hasConnectionProbeError, isTrue);
    expect(disconnected.hasConnectionProbeError, isFalse);
  });
  test('infers configured camera availability across Flutter ID prefixes', () {
    final capability = CameraStreamCapability.fromMap({
      'configuredCameraId': 'cameraId_1',
      'availableCameraIds': '0,1,2',
      'supportedYuvSizes': '1024x768; 640×480',
    });

    expect(capability.available, isTrue);
    expect(capability.supportedYuvSizes, <CameraYuvSize>[
      const CameraYuvSize(1024, 768),
      const CameraYuvSize(640, 480),
    ]);
  });

  test(
    'camera service requests capability for the selected business role',
    () async {
      MethodCall? receivedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_kioskChannel, (call) async {
            receivedCall = call;
            return <String, Object?>{
              'configuredCameraId': '2',
              'availableCameraIds': <String>['0', '1', '2'],
              'available': true,
              'supportedYuvSizes': <Map<String, Object?>>[
                <String, Object?>{'width': 1280, 'height': 720},
              ],
              'configuredProfiles': <Map<String, Object?>>[
                <String, Object?>{
                  'name': '720p',
                  'width': 1280,
                  'height': 720,
                  'compatible': true,
                },
              ],
            };
          });

      final capability = await const CabinetCameraService()
          .readCameraStreamCapability(CabinetCameraRole.operationArea);

      expect(receivedCall?.method, 'readCameraStreamCapability');
      expect(receivedCall?.arguments, <String, Object?>{
        'role': 'operationArea',
      });
      expect(capability.configuredCameraId, '2');
      expect(capability.incompatibleProfiles, isEmpty);
    },
  );

  test(
    'structured stream errors remain visible even if status text changes',
    () {
      final status = CameraStreamStatus.fromMap({
        'status': '正在等待重试',
        'url': '',
        'cameraId': '1',
        'lastErrorCode': 'CAMERA_IN_USE',
        'lastErrorMessage': '摄像头 ID 1 正被其他页面或应用占用',
        'failureStage': 'camera_open',
      });

      expect(status.lastErrorCode, 'CAMERA_IN_USE');
      expect(status.lastErrorMessage, contains('占用'));
      expect(status.failureStage, 'camera_open');
      expect(status.needsUserAttention, isTrue);
      expect(status.displayStatus, status.lastErrorMessage);
    },
  );

  test(
    'streaming state overrides stale errors and parses desired profiles',
    () {
      final status = CameraStreamStatus.fromMap({
        'status': '1080p 推流中',
        'state': 'streaming',
        'url': 'rtsp://server/app/device/1080p',
        'cameraId': '1',
        'profile': '1080p',
        'enabledProfiles': '1080p',
        'lastErrorCode': 'UNSUPPORTED_PROFILE',
        'lastErrorMessage': '历史 720p 失败',
      });

      expect(status.enabledProfiles, ['1080p']);
      expect(status.isStreaming, isTrue);
      expect(status.needsUserAttention, isFalse);
      expect(status.displayStatus, '1080p 推流中');
    },
  );
  test('does not report dual stream healthy until every profile pushes', () {
    final status = CameraStreamStatus.fromMap({
      'status': '720p,1080p 720p RKMPP H265 推流中：pushed=30',
      'state': 'streaming',
      'url': 'rtsp://server/app/device',
      'cameraId': '1',
      'profile': '720p,1080p',
      'enabledProfiles': '720p,1080p',
      'streamingProfiles': '720p',
      'allProfilesStreaming': 'false',
    });

    expect(status.enabledProfiles, ['720p', '1080p']);
    expect(status.streamingProfiles, ['720p']);
    expect(status.allProfilesStreaming, isFalse);
    expect(status.isStreaming, isFalse);
  });
  test(
    'admin preview configuration is unchanged and occupancy is actionable',
    () {
      expect(adminCameraPreviewAspectRatio, 16 / 9);
      expect(adminCameraPreviewResolutionPreset, ResolutionPreset.medium);
      expect(
        adminCameraPreviewErrorMessage('Camera is already in use'),
        '预览异常：摄像头正被其他页面或应用占用，请先关闭其他预览',
      );
      expect(
        adminCameraPreviewErrorMessage('Too many cameras already open'),
        '预览异常：已达到系统同时打开摄像头上限，请先关闭其他摄像头',
      );
      expect(
        adminCameraPreviewErrorMessage(
          'The limit number of open cameras has been reached, and more cameras '
          'cannot be opened until other instances are closed.',
        ),
        '预览异常：已达到系统同时打开摄像头上限，请先关闭其他摄像头',
      );
    },
  );
}
