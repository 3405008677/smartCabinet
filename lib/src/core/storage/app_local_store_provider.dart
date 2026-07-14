import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';

import 'package:smart_cabinet/src/core/storage/app_local_store.dart';
import 'package:smart_cabinet/src/core/storage/shared_preferences_async_key_value_storage.dart';
import 'package:smart_cabinet/src/core/storage/shared_preferences_key_value_storage.dart';

/// 应用本地 Store Provider。
///
/// 页面和启动服务统一从这里获取 [AppLocalStore]，确保读写的是同一套本地持久化实现。
final appLocalStoreProvider = FutureProvider<AppLocalStore>((ref) async {
  try {
    final preferences = SharedPreferencesAsync(
      options: const SharedPreferencesAsyncAndroidOptions(
        backend: SharedPreferencesAndroidBackendLibrary.SharedPreferences,
        originalSharedPreferencesOptions: AndroidSharedPreferencesStoreOptions(
          fileName: 'FlutterSharedPreferences',
        ),
      ),
    );
    final storage = SharedPreferencesAsyncKeyValueStorage(
      SharedPreferencesAsyncClient(preferences),
    );

    return AppLocalStore(storage);
  } on StateError {
    // Widget tests do not register platform plugins. Keep the legacy adapter
    // only as a narrow fallback; Android production uses the async path above.
    final preferences = await SharedPreferences.getInstance();
    return AppLocalStore(SharedPreferencesKeyValueStorage(preferences));
  }
});
