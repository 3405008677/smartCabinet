import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_cabinet/src/core/storage/key_value_storage.dart';

/// 异步偏好客户端的最小契约，供存储适配器与测试替身共同实现。
abstract interface class AsyncPreferencesClient {
  /// 读取字符串值，不存在时返回 null。
  Future<String?> getString(String key);

  /// 写入字符串值。
  Future<void> setString(String key, String value);

  /// 删除指定键。
  Future<void> remove(String key);

  /// 读取当前后端中的全部原始键。
  Future<Set<String>> getKeys();

  /// 读取当前后端中的全部原始键值。
  Future<Map<String, Object?>> getAll();
}

/// 基于非阻塞 [SharedPreferencesAsync] API 的正式环境客户端。
final class SharedPreferencesAsyncClient implements AsyncPreferencesClient {
  /// 创建异步偏好客户端。
  const SharedPreferencesAsyncClient(this._preferences);

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) => _preferences.getString(key);

  @override
  Future<void> setString(String key, String value) {
    return _preferences.setString(key, value);
  }

  @override
  Future<void> remove(String key) => _preferences.remove(key);

  @override
  Future<Set<String>> getKeys() => _preferences.getKeys();

  @override
  Future<Map<String, Object?>> getAll() => _preferences.getAll();
}

/// 与旧版 Flutter SharedPreferences 键布局兼容的异步存储。
///
/// 对上层暴露不带前缀的逻辑键，对平台后端读写带 `flutter.` 前缀的原始键，
/// 因此升级到异步 API 后仍能读取旧版插件已经保存的数据。
final class SharedPreferencesAsyncKeyValueStorage implements KeyValueStorage {
  /// 创建异步键值存储适配器。
  const SharedPreferencesAsyncKeyValueStorage(this._preferences);

  /// 旧版 SharedPreferences Dart API 写入平台后端时使用的命名空间前缀。
  static const String legacyFlutterPrefix = 'flutter.';

  final AsyncPreferencesClient _preferences;

  @override
  Future<String?> readString(String key) {
    return _preferences.getString(_platformKey(key));
  }

  @override
  Future<void> writeString(String key, String value) {
    return _preferences.setString(_platformKey(key), value);
  }

  @override
  Future<void> remove(String key) {
    return _preferences.remove(_platformKey(key));
  }

  @override
  Future<Set<String>> keys() async {
    final platformKeys = await _preferences.getKeys();
    // 只暴露 Flutter 命名空间，避免把同一偏好文件中的原生配置误交给上层。
    return {
      for (final key in platformKeys)
        if (key.startsWith(legacyFlutterPrefix))
          key.substring(legacyFlutterPrefix.length),
    };
  }

  @override
  Future<Map<String, Object?>> readAll() async {
    final platformValues = await _preferences.getAll();
    return {
      for (final MapEntry(key: key, value: value) in platformValues.entries)
        if (key.startsWith(legacyFlutterPrefix))
          key.substring(legacyFlutterPrefix.length): value,
    };
  }

  /// 将上层逻辑键转换为平台后端中的兼容键。
  String _platformKey(String key) => '$legacyFlutterPrefix$key';
}
