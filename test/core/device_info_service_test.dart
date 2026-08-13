import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cabinet/src/core/device/device_info_service.dart';
import 'package:smart_cabinet/src/core/logging/communication_log_store.dart';

/// 设备信息服务测试。
void main() {
  const kioskChannel = MethodChannel('smart_cabinet/kiosk');

  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'returns web debug device info without invoking platform channel',
    () async {
      final service = DeviceInfoService();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kioskChannel, (call) async {
            return <String, Object?>{'唯一设备ID': 'native-debug-device'};
          });

      final items = await service.fetchDeviceInfo();
      final itemMap = <String, String>{
        for (final item in items) item.label: item.value,
      };

      if (kIsWeb) {
        expect(itemMap['唯一设备ID'], 'web-debug-device');
        expect(itemMap['平台'], 'Flutter Web');
        expect(itemMap['状态'], '浏览器调试环境');
      } else {
        expect(itemMap['唯一设备ID'], 'native-debug-device');
      }

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kioskChannel, null);
    },
  );

  test('extracts the same unique device ID shown in About Device', () {
    expect(
      DeviceInfoService.uniqueDeviceIdFrom(const <String, Object?>{
        DeviceInfoService.uniqueDeviceIdLabel: '  AABBCIID33  ',
      }),
      'AABBCIID33',
    );
  });

  test('rejects missing and placeholder unique device IDs', () {
    expect(
      DeviceInfoService.uniqueDeviceIdFrom(const <String, Object?>{}),
      isNull,
    );
    expect(
      DeviceInfoService.uniqueDeviceIdFrom(const <String, Object?>{
        DeviceInfoService.uniqueDeviceIdLabel: '未知',
      }),
      isNull,
    );
    expect(
      DeviceInfoService.uniqueDeviceIdFrom(const <String, Object?>{
        DeviceInfoService.uniqueDeviceIdLabel: 'unknown',
      }),
      isNull,
    );
  });

  test(
    'fetches the unique device ID from the native About Device source',
    () async {
      if (kIsWeb) {
        expect(
          await const DeviceInfoService().fetchUniqueDeviceId(),
          'web-debug-device',
        );
        return;
      }
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kioskChannel, (call) async {
            expect(call.method, 'getDeviceInfo');
            return <String, Object?>{
              DeviceInfoService.uniqueDeviceIdLabel: 'native-device-id',
            };
          });
      CommunicationLogStore.instance.clear();
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(kioskChannel, null);
        CommunicationLogStore.instance.clear();
      });

      expect(
        await const DeviceInfoService().fetchUniqueDeviceId(),
        'native-device-id',
      );
      expect(
        CommunicationLogStore.instance.entries
            .map((entry) => entry.completeInformation)
            .join('\n'),
        isNot(contains('native-device-id')),
      );
    },
  );

  test('fails closed when About Device has no unique device ID', () async {
    if (kIsWeb) {
      return;
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kioskChannel, (call) async {
          return <String, Object?>{'状态': '当前平台未返回设备信息'};
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kioskChannel, null);
    });

    await expectLater(
      const DeviceInfoService().fetchUniqueDeviceId(),
      throwsStateError,
    );
  });
}
