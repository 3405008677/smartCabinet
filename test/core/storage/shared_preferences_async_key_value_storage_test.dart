import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cabinet/src/core/storage/app_local_store.dart';
import 'package:smart_cabinet/src/core/storage/shared_preferences_async_key_value_storage.dart';

void main() {
  test(
    'reads legacy prefixed state and persists updates to the same key',
    () async {
      final preferences = _MemoryAsyncPreferences({
        'flutter.${AppLocalStore.localStateKey}': jsonEncode(
          const AppLocalState(authToken: 'legacy-token').toJson(),
        ),
        'native.unrelated': 'keep-me',
      });
      final storage = SharedPreferencesAsyncKeyValueStorage(preferences);
      final store = AppLocalStore(storage);

      expect((await store.state()).authToken, 'legacy-token');

      await store.update((state) => state.copyWith(languageCode: 'en-US'));

      expect(
        preferences.values.containsKey(
          'flutter.${AppLocalStore.localStateKey}',
        ),
        isTrue,
      );
      expect(
        preferences.values.containsKey(AppLocalStore.localStateKey),
        isFalse,
      );

      final restartedStore = AppLocalStore(
        SharedPreferencesAsyncKeyValueStorage(preferences),
      );
      expect((await restartedStore.state()).languageCode, 'en-US');
      expect(await storage.keys(), {AppLocalStore.localStateKey});
      expect(
        await storage.readAll(),
        containsPair(AppLocalStore.localStateKey, isA<String>()),
      );
      expect(preferences.values['native.unrelated'], 'keep-me');
    },
  );
}

final class _MemoryAsyncPreferences implements AsyncPreferencesClient {
  _MemoryAsyncPreferences(this.values);

  final Map<String, Object?> values;

  @override
  Future<Map<String, Object?>> getAll() async => Map.of(values);

  @override
  Future<Set<String>> getKeys() async => values.keys.toSet();

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}
