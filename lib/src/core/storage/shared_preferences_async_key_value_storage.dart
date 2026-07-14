import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_cabinet/src/core/storage/key_value_storage.dart';

/// Small async preference client used by the storage adapter.
abstract interface class AsyncPreferencesClient {
  Future<String?> getString(String key);

  Future<void> setString(String key, String value);

  Future<void> remove(String key);

  Future<Set<String>> getKeys();

  Future<Map<String, Object?>> getAll();
}

/// Production client backed by the non-blocking SharedPreferences API.
final class SharedPreferencesAsyncClient implements AsyncPreferencesClient {
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

/// Async storage compatible with the legacy Flutter SharedPreferences layout.
final class SharedPreferencesAsyncKeyValueStorage implements KeyValueStorage {
  const SharedPreferencesAsyncKeyValueStorage(this._preferences);

  /// Prefix used by the legacy SharedPreferences Dart API.
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

  String _platformKey(String key) => '$legacyFlutterPrefix$key';
}
