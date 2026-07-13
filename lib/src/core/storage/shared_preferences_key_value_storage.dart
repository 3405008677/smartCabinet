import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_cabinet/src/core/storage/key_value_storage.dart';

/// 基于 SharedPreferences 的键值存储实现。
///
/// 用于提供类似 Web LocalStorage 的本地简单键值读写和全量枚举能力。
final class SharedPreferencesKeyValueStorage implements KeyValueStorage {
  /// 创建 SharedPreferences 键值存储实现。
  const SharedPreferencesKeyValueStorage(this._preferences);

  /// 当前存储实现依赖的 SharedPreferences 实例。
  final SharedPreferences _preferences;

  @override
  Future<String?> readString(String key) async {
    return _preferences.getString(key);
  }

  @override
  Future<void> writeString(String key, String value) async {
    await _preferences.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _preferences.remove(key);
  }

  @override
  Future<Set<String>> keys() async {
    return _preferences.getKeys();
  }

  @override
  Future<Map<String, Object?>> readAll() async {
    final values = <String, Object?>{};

    for (final key in _preferences.getKeys()) {
      values[key] = _preferences.get(key);
    }

    return values;
  }
}
