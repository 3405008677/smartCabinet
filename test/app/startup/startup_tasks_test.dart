import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cabinet/src/app/startup/startup_tasks.dart';
import 'package:smart_cabinet/src/core/camera/camera_binding_service.dart';

void main() {
  tearDown(CameraBindingService.debugReset);

  test('camera startup task succeeds when cameras are available', () async {
    CameraBindingService.debugUseCameraData(
      cameras: const [
        CameraDescription(
          name: 'cameraId_0',
          lensDirection: CameraLensDirection.front,
          sensorOrientation: 90,
        ),
      ],
    );

    await const LoadCamerasStartupTask().run();
  });

  test('camera startup task fails when no camera is available', () async {
    CameraBindingService.debugUseCameraData(cameras: const []);

    await expectLater(
      const LoadCamerasStartupTask(
        maxAttempts: 2,
        retryDelay: Duration.zero,
      ).run(),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'camera startup task retries temporary camera initialization errors',
    () async {
      var attempts = 0;

      await LoadCamerasStartupTask(
        maxAttempts: 3,
        retryDelay: Duration.zero,
        cameraLoader: ({required forceReload}) async {
          attempts += 1;
          if (attempts < 3) {
            throw StateError('Device reporting less cameras than anticipated');
          }
          return const [
            CabinetCameraDevice(
              id: 'cameraId_0',
              displayName: 'cameraId_0',
              description: CameraDescription(
                name: 'cameraId_0',
                lensDirection: CameraLensDirection.front,
                sensorOrientation: 90,
              ),
            ),
          ];
        },
      ).run();

      expect(attempts, 3);
    },
  );

  test(
    'camera startup task can allow empty cameras for non-camera terminals',
    () async {
      CameraBindingService.debugUseCameraData(cameras: const []);

      await const LoadCamerasStartupTask(requireAtLeastOneCamera: false).run();
    },
  );
}
