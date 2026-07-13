import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cabinet/src/core/camera/cabinet_camera.dart';
import 'package:smart_cabinet/src/core/device/method_channel_kiosk_device.dart';

/// MethodChannel Kiosk 设备实现测试。
void main() {
  const kioskChannel = MethodChannel('smart_cabinet/kiosk');

  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kioskChannel, null);
  });

  test('starts camera stream by role', () async {
    final calls = <MethodCall>[];
    const device = MethodChannelKioskDevice();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kioskChannel, (call) async {
          calls.add(call);
          return null;
        });

    await device.startCameraStream(
      CabinetCameraRole.outsideEnvironment,
      profiles: const ['720p'],
    );

    expect(calls, hasLength(1));
    expect(calls.single.method, 'startCameraStream');
    expect(calls.single.arguments, <String, Object?>{
      'role': 'outsideEnvironment',
      'profiles': ['720p'],
    });
  });

  test('stops camera stream by role', () async {
    final calls = <MethodCall>[];
    const device = MethodChannelKioskDevice();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kioskChannel, (call) async {
          calls.add(call);
          return null;
        });

    await device.stopCameraStream(
      CabinetCameraRole.outsideEnvironment,
      profiles: const ['1080p'],
    );

    expect(calls, hasLength(1));
    expect(calls.single.method, 'stopCameraStream');
    expect(calls.single.arguments, <String, Object?>{
      'role': 'outsideEnvironment',
      'profiles': ['1080p'],
    });
  });
}
