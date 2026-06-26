import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_cabinet/src/core/storage/shared_preferences_key_value_storage.dart';

/// SharedPreferences 键值存储实现测试。
///
/// 覆盖字符串读写、删除、键枚举和一次性读取全部对象这些类似 LocalStorage 的能力。
void main() {
  setUp(() {
    /// 每个用例使用独立内存数据，避免本地持久化状态影响测试结果。
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('stores, lists, reads all, and removes string values', () async {
    /// 构造基于 SharedPreferences 的本地存储，模拟应用内常规键值写入流程。
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesKeyValueStorage(preferences);

    await storage.writeString('token', 'abc123');
    await storage.writeString('language', 'zh-CN');

    expect(await storage.readString('token'), 'abc123');
    expect(await storage.keys(), containsAll(<String>{'token', 'language'}));
    expect(await storage.readAll(), <String, Object?>{
      'token': 'abc123',
      'language': 'zh-CN',
    });

    await storage.remove('token');

    expect(await storage.readString('token'), isNull);
    expect(await storage.keys(), isNot(contains('token')));
    expect(await storage.readAll(), <String, Object?>{'language': 'zh-CN'});
  });
}
