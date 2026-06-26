import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cabinet/src/core/camera/camera_binding_service.dart';

void main() {
  tearDown(CameraBindingService.debugReset);

  test('face recognition uses admin configured camera binding', () async {
    CameraBindingService.debugUseCameraData(
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
      bindings: const {CabinetCameraRole.faceRecognition: 'cameraId_2'},
    );

    final selectedCamera = await CameraBindingService()
        .resolveFaceRecognitionCamera();

    expect(selectedCamera?.name, 'cameraId_2');
  });

  test('face recognition falls back to front camera without binding', () async {
    CameraBindingService.debugUseCameraData(
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

    final selectedCamera = await CameraBindingService()
        .resolveFaceRecognitionCamera();

    expect(selectedCamera?.name, 'cameraId_0');
  });

  test('reads outside environment stream status from debug data', () async {
    CameraBindingService.debugUseCameraData(
      cameras: const [],
      outsideEnvironmentStreamStatus: const CameraStreamStatus(
        status: '推流中',
        url: 'rtsp://192.168.2.167/app/device-001',
        cameraId: 'cameraId_1',
      ),
    );

    final status = await CameraBindingService()
        .readOutsideEnvironmentStreamStatus();

    expect(status.status, '推流中');
    expect(status.url, 'rtsp://192.168.2.167/app/device-001');
    expect(status.cameraId, 'cameraId_1');
  });

  test('reads operation area H264 stream status from debug data', () async {
    CameraBindingService.debugUseCameraData(
      cameras: const [],
      operationAreaStreamStatus: const CameraStreamStatus(
        status: '推流中',
        url: 'rtmp://192.168.2.167/app/device-001-operation-h264',
        cameraId: 'cameraId_2',
      ),
    );

    final status = await CameraBindingService().readOperationAreaStreamStatus();

    expect(status.status, '推流中');
    expect(status.url, 'rtmp://192.168.2.167/app/device-001-operation-h264');
    expect(status.cameraId, 'cameraId_2');
  });
}
