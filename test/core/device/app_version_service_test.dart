import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/core/device/app_version_service.dart';

/// 应用版本服务的平台映射、缓存与失败恢复测试。
void main() {
  const channel = MethodChannel('smart_cabinet/upgrade');

  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('reads and caches the installed Android app version', () async {
    var callCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getAppVersion');
          callCount += 1;
          return <String, Object?>{'versionName': ' 1.2.3 ', 'versionCode': 23};
        });
    final service = AppVersionService();

    final first = await service.load();
    final second = await service.load();

    expect(first.name, '1.2.3');
    expect(first.code, 23);
    expect(identical(first, second), isTrue);
    expect(callCount, 1);
  });

  test('retries after a native version read failure', () async {
    var callCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          callCount += 1;
          if (callCount == 1) {
            throw PlatformException(code: 'temporarily_unavailable');
          }
          return <String, Object?>{'versionName': '1.2.4', 'versionCode': 24};
        });
    final service = AppVersionService();

    await expectLater(service.load(), throwsA(isA<PlatformException>()));
    final version = await service.load();

    expect(version.name, '1.2.4');
    expect(version.code, 24);
    expect(callCount, 2);
  });

  test('rejects invalid native app version metadata', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => <String, Object?>{
            'versionName': '',
            'versionCode': 0,
          },
        );

    await expectLater(AppVersionService().load(), throwsStateError);
  });
}
