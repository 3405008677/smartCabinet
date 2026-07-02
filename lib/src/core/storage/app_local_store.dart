import 'dart:convert';

import 'key_value_storage.dart';

/// 应用本地状态对象。
///
/// 这里就是本项目的 Pinia 风格 state 定义区，所有本地持久化字段统一放在这个对象里。
final class AppLocalState {
  /// 创建应用本地状态对象。
  const AppLocalState({
    this.authToken = '',
    this.languageCode = 'zh-CN',
    this.info = const <String, Object?>{},
    this.level = const <String, Object?>{},
    this.deviceInfo = const <String, Object?>{},
    this.logging = const <String, Object?>{
      'errorReportUrl': 'http://192.168.1.100:3000/api/logs/error',
      'uploadEnabled': true,
    },
    this.video = const <String, Object?>{
      'streamUrl': '',
      'streamSwitches': <String, Object?>{'720p': false, '1080p': false},
    },
  });

  /// 管理员或接口登录态 token。
  final String authToken;

  /// 当前界面语言代码。
  final String languageCode;

  /// 应用信息对象。
  final Map<String, Object?> info;

  /// 当前权限级别或层级对象。
  final Map<String, Object?> level;

  /// 启动阶段缓存的设备信息对象。
  final Map<String, Object?> deviceInfo;

  /// 日志配置对象。
  final Map<String, Object?> logging;

  /// 视频推流配置对象。
  final Map<String, Object?> video;

  /// 复制当前状态并覆盖指定字段。
  AppLocalState copyWith({
    String? authToken,
    String? languageCode,
    Map<String, Object?>? info,
    Map<String, Object?>? level,
    Map<String, Object?>? deviceInfo,
    Map<String, Object?>? logging,
    Map<String, Object?>? video,
  }) {
    return AppLocalState(
      authToken: authToken ?? this.authToken,
      languageCode: languageCode ?? this.languageCode,
      info: info ?? this.info,
      level: level ?? this.level,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      logging: logging ?? this.logging,
      video: video ?? this.video,
    );
  }

  /// 转成可 JSON 序列化的 Map。
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'authToken': authToken,
      'languageCode': languageCode,
      'info': info,
      'level': level,
      'deviceInfo': deviceInfo,
      'logging': logging,
      'video': video,
    };
  }

  /// 从 JSON Map 创建应用本地状态对象。
  factory AppLocalState.fromJson(Map<String, Object?> json) {
    return AppLocalState(
      authToken: json['authToken']?.toString() ?? '',
      languageCode: json['languageCode']?.toString() ?? 'zh-CN',
      info: _asStringObjectMap(json['info']),
      level: _asStringObjectMap(json['level']),
      deviceInfo: _asStringObjectMap(json['deviceInfo']),
      logging: _mergeObjectMap(const <String, Object?>{
        'errorReportUrl': 'http://192.168.1.100:3000/api/logs/error',
        'uploadEnabled': true,
      }, json['logging']),
      video: _mergeObjectMap(const <String, Object?>{
        'streamUrl': '',
        'streamSwitches': <String, Object?>{'720p': false, '1080p': false},
      }, json['video']),
    );
  }
}

/// 应用本地 Store。
///
/// 底层只保存一个 `app.localState` JSON 字符串，上层像 Pinia 一样读写整个 state 对象。
final class AppLocalStore {
  /// 创建应用本地 Store。
  const AppLocalStore(this._storage);

  /// SharedPreferences 中保存整个本地状态对象的 key。
  static const localStateKey = 'app.localState';

  /// 底层键值存储实现。
  final KeyValueStorage _storage;

  /// 读取当前完整状态。
  Future<AppLocalState> state() async {
    final value = await _storage.readString(localStateKey);

    if (value == null || value.isEmpty) {
      return const AppLocalState();
    }

    final decoded = jsonDecode(value);
    if (decoded is Map) {
      return AppLocalState.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    }

    return const AppLocalState();
  }

  /// 直接覆盖当前完整状态。
  Future<void> setState(AppLocalState state) async {
    await _storage.writeString(localStateKey, jsonEncode(state.toJson()));
  }

  /// 基于当前状态做局部更新。
  Future<AppLocalState> update(
    AppLocalState Function(AppLocalState state) updater,
  ) async {
    final nextState = updater(await state());
    await setState(nextState);
    return nextState;
  }

  /// 导出当前完整状态快照。
  Future<Map<String, Object?>> snapshot() async {
    return (await state()).toJson();
  }
}

/// 将动态对象转换成 `Map<String, Object?>`。
Map<String, Object?> _asStringObjectMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  return <String, Object?>{};
}

/// 将动态对象转换成 Map，并叠加默认值。
Map<String, Object?> _mergeObjectMap(
  Map<String, Object?> defaults,
  Object? value,
) {
  return <String, Object?>{...defaults, ..._asStringObjectMap(value)};
}
