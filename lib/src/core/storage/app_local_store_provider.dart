import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';

import 'package:smart_cabinet/src/core/storage/app_local_store.dart';
import 'package:smart_cabinet/src/core/storage/shared_preferences_async_key_value_storage.dart';
import 'package:smart_cabinet/src/core/storage/shared_preferences_key_value_storage.dart';

/// 应用本地 Store Provider。
///
/// 页面和启动服务统一从这里获取 [AppLocalStore]，确保读写的是同一套本地持久化实现。
/// Android 正式环境使用非阻塞异步 API，并显式指向历史 Flutter 偏好文件以兼容旧数据。
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
    // Widget 测试通常没有注册平台插件。仅在这种受限环境回退到旧适配器；
    // Android 正式运行仍固定使用上面的异步路径，避免同步缓存产生陈旧读数。
    final preferences = await SharedPreferences.getInstance();
    return AppLocalStore(SharedPreferencesKeyValueStorage(preferences));
  }
});
