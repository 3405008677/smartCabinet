import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_cabinet/src/core/config/index.dart';
import 'package:smart_cabinet/src/core/device/device_info_service.dart';
import 'package:smart_cabinet/src/core/storage/app_local_store.dart';
import 'package:smart_cabinet/src/core/storage/local_store_bootstrap_service.dart';
import 'package:smart_cabinet/src/core/storage/shared_preferences_key_value_storage.dart';

/// 本地 Store 启动缓存服务测试。
///
/// 验证启动阶段会把设备信息和依赖唯一设备 ID 的 video 配置写入本地 Store。
void main() {
  setUp(() {
    /// 使用 SharedPreferences 内存实现，保证测试不会污染真实设备本地数据。
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('caches device info and video settings during startup', () async {
    /// 构造启动服务，模拟 Android 原生层返回“关于设备”数据。
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesKeyValueStorage(preferences);
    final store = AppLocalStore(storage);
    final service = LocalStoreBootstrapService(
      store: store,
      fetchDeviceInfo: () async {
        return const <DeviceInfoItem>[
          DeviceInfoItem(label: '唯一设备ID', value: 'a1b2c3d4e5f67890'),
          DeviceInfoItem(label: '主板', value: 'rk3568'),
          DeviceInfoItem(label: '型号', value: 'SC-Board-A1'),
        ];
      },
    );

    await service.cacheStartupData();

    final state = await store.state();

    expect(state.deviceInfo, <String, Object?>{
      '唯一设备ID': 'a1b2c3d4e5f67890',
      '主板': 'rk3568',
      '型号': 'SC-Board-A1',
    });
    expect(state.video, <String, Object?>{
      'streamUrl': '${AppConfig.streamBaseUrl}/a1b2c3d4e5f67890',
      'streamSwitches': <String, Object?>{'720p': false, '1080p': false},
      'streamProfiles': [
        for (final profile in AppConfig.streamProfiles)
          <String, Object?>{
            'name': profile.name,
            'width': profile.width,
            'height': profile.height,
            'fps': profile.fps,
            'bitrate': profile.bitrate,
            'gopSeconds': profile.gopSeconds,
          },
      ],
    });
    expect(state.logging, <String, Object?>{
      'errorReportUrl': 'http://192.168.1.100:3000/api/logs/error',
      'uploadEnabled': true,
    });
  });
}
