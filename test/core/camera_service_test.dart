import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cabinet/src/core/camera/cabinet_camera.dart';
import 'package:smart_cabinet/src/core/config/app_config.dart';

void main() {
  tearDown(CabinetCameraService.debugReset);

  test('face recognition uses front camera by default', () async {
    CabinetCameraService.debugUseCameraData(
      cameras: const [
        CameraDescription(
          name: 'cameraId_0',
          lensDirection: CameraLensDirection.front,
          sensorOrientation: 90,
        ),
        CameraDescription(
          name: 'cameraId_2',
          lensDirection: CameraLensDirection.external,
          sensorOrientation: 0,
        ),
      ],
    );

    final selectedCamera = await const CabinetCameraService()
        .resolveFaceRecognitionCamera();

    expect(selectedCamera?.name, 'cameraId_0');
  });

  test(
    'configured raw Camera2 id takes precedence over lens fallback',
    () async {
      CabinetCameraService.debugUseCameraData(
        cameras: const [
          CameraDescription(
            name: '1',
            lensDirection: CameraLensDirection.front,
            sensorOrientation: 90,
          ),
          CameraDescription(
            name: '0',
            lensDirection: CameraLensDirection.back,
            sensorOrientation: 90,
          ),
        ],
      );

      final selectedCamera = await const CabinetCameraService()
          .resolveFaceRecognitionCamera();

      expect(selectedCamera?.name, '0');
    },
  );

  test('face recognition falls back to front camera without binding', () async {
    CabinetCameraService.debugUseCameraData(
      cameras: const [
        CameraDescription(
          name: 'cameraId_1',
          lensDirection: CameraLensDirection.external,
          sensorOrientation: 0,
        ),
        CameraDescription(
          name: 'cameraId_0',
          lensDirection: CameraLensDirection.front,
          sensorOrientation: 90,
        ),
      ],
    );

    final selectedCamera = await const CabinetCameraService()
        .resolveFaceRecognitionCamera();

    expect(selectedCamera?.name, 'cameraId_0');
  });

  test('converts unified camera2 id to flutter camera plugin id', () {
    expect(CabinetCameraConfig.toFlutterCameraId('0'), 'cameraId_0');
    expect(CabinetCameraConfig.toFlutterCameraId('3'), 'cameraId_3');
  });

  test('reads outside environment stream status from debug data', () async {
    CabinetCameraService.debugUseCameraData(
      cameras: const [],
      outsideEnvironmentStreamStatus: const CameraStreamStatus(
        status: '推流中',
        url: '${AppConfig.streamBaseUrl}/device-001',
        cameraId: 'cameraId_1',
        profile: '720p',
        streamMode: 'dual_active_profiles',
      ),
    );

    final status = await const CabinetCameraService()
        .readOutsideEnvironmentStreamStatus();

    expect(status.status, '推流中');
    expect(status.url, '${AppConfig.streamBaseUrl}/device-001');
    expect(status.cameraId, 'cameraId_1');
    expect(status.profile, '720p');
    expect(status.streamMode, 'dual_active_profiles');
  });

  test(
    'reads operation area RTSP H265 stream status from debug data',
    () async {
      CabinetCameraService.debugUseCameraData(
        cameras: const [],
        operationAreaStreamStatus: const CameraStreamStatus(
          status: '推流中',
          url: '${AppConfig.streamBaseUrl}/device-001-operation',
          cameraId: 'cameraId_2',
        ),
      );

      final status = await const CabinetCameraService()
          .readOperationAreaStreamStatus();

      expect(status.status, '推流中');
      expect(status.url, '${AppConfig.streamBaseUrl}/device-001-operation');
      expect(status.cameraId, 'cameraId_2');
    },
  );

  test('detects stream failure statuses that need user attention', () {
    const disconnectedStatus = CameraStreamStatus(
      status: '推流断开：Broken pipe，3 秒后重连第 1 次',
      url: '${AppConfig.streamBaseUrl}/device-001',
      cameraId: 'cameraId_1',
    );
    const normalStatus = CameraStreamStatus(
      status: 'RKMPP H265 推流中：encoded=30 pushed=30',
      url: '${AppConfig.streamBaseUrl}/device-001',
      cameraId: 'cameraId_1',
    );

    expect(disconnectedStatus.needsUserAttention, isTrue);
    expect(normalStatus.needsUserAttention, isFalse);
  });

  test('parses active stream profile from native status map', () {
    final status = CameraStreamStatus.fromMap(const <String, Object?>{
      'status': '720p/1080p 双路推流中',
      'url':
          '${AppConfig.streamBaseUrl}/device-001/720p,${AppConfig.streamBaseUrl}/device-001/1080p',
      'cameraId': 'cameraId_1',
      'profile': '720p,1080p',
      'streamMode': 'dual_active_profiles',
    });

    expect(status.status, '720p/1080p 双路推流中');
    expect(
      status.url,
      '${AppConfig.streamBaseUrl}/device-001/720p,${AppConfig.streamBaseUrl}/device-001/1080p',
    );
    expect(status.cameraId, 'cameraId_1');
    expect(status.profile, '720p,1080p');
    expect(status.streamMode, 'dual_active_profiles');
  });
}
