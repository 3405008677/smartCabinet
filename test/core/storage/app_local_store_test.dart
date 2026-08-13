import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_cabinet/src/core/config/app_config.dart';
import 'package:smart_cabinet/src/core/storage/app_local_store.dart';
import 'package:smart_cabinet/src/core/storage/shared_preferences_key_value_storage.dart';

/// 应用本地 Store 测试。
///
/// 验证本地 Store 像 Pinia 一样以一个集中 state 对象管理状态。
void main() {
  setUp(() {
    /// 清空 SharedPreferences 测试内存，保证每个用例互不影响。
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('returns default Pinia-like state before any writes', () async {
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesKeyValueStorage(preferences);
    final store = AppLocalStore(storage);

    final state = await store.state();

    expect(state.authToken, '');
    expect(state.languageCode, 'zh-CN');
    expect(state.info, <String, Object?>{});
    expect(state.logging, <String, Object?>{
      'errorReportUrl': 'http://192.168.1.100:3000/api/logs/error',
      'uploadEnabled': false,
    });
    expect(state.video, <String, Object?>{'streamUrl': ''});
    expect(state.upgrade, <String, Object?>{
      'enabled': false,
      'host': '',
      'port': 0,
      'terminalId': '',
      'packageTag': '',
    });
    expect(await store.snapshot(), <String, Object?>{
      'authToken': '',
      'languageCode': 'zh-CN',
      'info': <String, Object?>{},
      'level': <String, Object?>{},
      'deviceInfo': <String, Object?>{},
      'logging': <String, Object?>{
        'errorReportUrl': 'http://192.168.1.100:3000/api/logs/error',
        'uploadEnabled': false,
      },
      'video': <String, Object?>{'streamUrl': ''},
      'upgrade': <String, Object?>{
        'enabled': false,
        'host': '',
        'port': 0,
        'terminalId': '',
        'packageTag': '',
      },
    });
  });

  test('sets complete state and reads it back as one object', () async {
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesKeyValueStorage(preferences);
    final store = AppLocalStore(storage);

    await store.setState(
      const AppLocalState().copyWith(
        authToken: 'token-001',
        info: <String, Object?>{'viso': 'v2.4.1', 'title': '管管智能柜'},
        level: <String, Object?>{'code': 'admin', 'priority': 10},
        logging: <String, Object?>{
          'errorReportUrl': 'http://127.0.0.1:3000/api/logs/error',
          'uploadEnabled': false,
        },
        video: <String, Object?>{
          'streamUrl': '${AppConfig.streamBaseUrl}/a1b2c3d4e5f67890',
        },
        upgrade: <String, Object?>{
          'enabled': true,
          'host': '10.0.0.8',
          'port': 8001,
          'terminalId': '13800138000',
          // 模拟升级旧版本重复保存的设备身份。
          'moduleImei': '123456789012345',
          'dataProtocolIp': '10.0.0.8',
          'chipId': 'legacy-chip',
          'packageTag': 'APP',
        },
      ),
    );

    final rawState = await storage.readString(AppLocalStore.localStateKey);
    expect(rawState, isNot(contains('moduleImei')));
    expect(rawState, isNot(contains('dataProtocolIp')));
    expect(rawState, isNot(contains('chipId')));

    expect(await store.snapshot(), <String, Object?>{
      'authToken': 'token-001',
      'languageCode': 'zh-CN',
      'info': <String, Object?>{'viso': 'v2.4.1', 'title': '管管智能柜'},
      'level': <String, Object?>{'code': 'admin', 'priority': 10},
      'deviceInfo': <String, Object?>{},
      'logging': <String, Object?>{
        'errorReportUrl': 'http://127.0.0.1:3000/api/logs/error',
        'uploadEnabled': false,
      },
      'video': <String, Object?>{
        'streamUrl': '${AppConfig.streamBaseUrl}/a1b2c3d4e5f67890',
      },
      'upgrade': <String, Object?>{
        'enabled': true,
        'host': '10.0.0.8',
        'port': 8001,
        'terminalId': '13800138000',
        'packageTag': 'APP',
      },
    });
  });

  test('updates partial state by assigning a copied state', () async {
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesKeyValueStorage(preferences);
    final store = AppLocalStore(storage);

    await store.update(
      (state) => state.copyWith(
        video: <String, Object?>{...state.video, 'activeProfile': '720p'},
      ),
    );

    final state = await store.state();

    expect(state.authToken, '');
    expect(state.video, <String, Object?>{
      'streamUrl': '',
      'activeProfile': '720p',
    });
  });
}
