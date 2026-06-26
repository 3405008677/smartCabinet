import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cabinet/src/core/device/device_info_service.dart';

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
}
