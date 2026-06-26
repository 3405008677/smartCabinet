import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_local_store.dart';
import 'shared_preferences_key_value_storage.dart';

/// 应用本地 Store Provider。
///
/// 页面和启动服务统一从这里获取 [AppLocalStore]，确保读写的是同一套本地持久化实现。
final appLocalStoreProvider = FutureProvider<AppLocalStore>((ref) async {
  final preferences = await SharedPreferences.getInstance();
  final storage = SharedPreferencesKeyValueStorage(preferences);

  return AppLocalStore(storage);
});
