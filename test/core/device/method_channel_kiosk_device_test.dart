import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cabinet/src/core/device/method_channel_kiosk_device.dart';

/// MethodChannel Kiosk 设备实现测试。
void main() {
  const kioskChannel = MethodChannel('smart_cabinet/kiosk');

  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kioskChannel, null);
  });

  test('starts the requested stream profile on demand', () async {
    final calls = <MethodCall>[];
    const device = MethodChannelKioskDevice();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kioskChannel, (call) async {
          calls.add(call);
          return null;
        });

    await device.startStreamProfile('720p', cameraId: '0');

    expect(calls, hasLength(1));
    expect(calls.single.method, 'startStreamProfile');
    expect(calls.single.arguments, <String, Object?>{
      'profile': '720p',
      'cameraId': '0',
    });
  });

  test('stops the requested stream profile on demand', () async {
    final calls = <MethodCall>[];
    const device = MethodChannelKioskDevice();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kioskChannel, (call) async {
          calls.add(call);
          return null;
        });

    await device.stopStreamProfile('1080p', cameraId: '0');

    expect(calls, hasLength(1));
    expect(calls.single.method, 'stopStreamProfile');
    expect(calls.single.arguments, <String, Object?>{
      'profile': '1080p',
      'cameraId': '0',
    });
  });
}
