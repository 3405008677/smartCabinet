import 'dart:convert';

import 'package:smart_cabinet/src/core/storage/key_value_storage.dart';

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
      'uploadEnabled': false,
    },
    this.video = const <String, Object?>{'streamUrl': ''},
    this.upgrade = const <String, Object?>{
      'enabled': false,
      'host': '',
      'port': 0,
      'terminalId': '',
      'packageTag': '',
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

  /// ZRD STUM 升级监控现场配置。
  final Map<String, Object?> upgrade;

  /// 复制当前状态并覆盖指定字段。
  AppLocalState copyWith({
    String? authToken,
    String? languageCode,
    Map<String, Object?>? info,
    Map<String, Object?>? level,
    Map<String, Object?>? deviceInfo,
    Map<String, Object?>? logging,
    Map<String, Object?>? video,
    Map<String, Object?>? upgrade,
  }) {
    return AppLocalState(
      authToken: authToken ?? this.authToken,
      languageCode: languageCode ?? this.languageCode,
      info: info ?? this.info,
      level: level ?? this.level,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      logging: logging ?? this.logging,
      video: video ?? this.video,
      upgrade: upgrade ?? this.upgrade,
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
      // 登录身份不属于可持久化设置；即使调用方直接构造旧 Map，也在最终
      // 序列化边界统一丢弃，避免敏感旧值再次写进 SharedPreferences。
      'upgrade': _upgradeSettingsMap(upgrade),
    };
  }

  /// 从 JSON Map 创建应用本地状态对象。
  ///
  /// 缺失的复合字段会叠加当前默认值，使旧版本快照升级后仍具备新增配置。
  factory AppLocalState.fromJson(Map<String, Object?> json) {
    return AppLocalState(
      authToken: json['authToken']?.toString() ?? '',
      languageCode: json['languageCode']?.toString() ?? 'zh-CN',
      info: _asStringObjectMap(json['info']),
      level: _asStringObjectMap(json['level']),
      deviceInfo: _asStringObjectMap(json['deviceInfo']),
      logging: _mergeObjectMap(const <String, Object?>{
        'errorReportUrl': 'http://192.168.1.100:3000/api/logs/error',
        'uploadEnabled': false,
      }, json['logging']),
      video: _mergeObjectMap(const <String, Object?>{
        'streamUrl': '',
      }, json['video']),
      upgrade: _upgradeSettingsMap(json['upgrade']),
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
  ///
  /// 键不存在、内容为空或顶层不是对象时返回默认状态；非法 JSON 的解析异常会继续
  /// 向上传播，让启动编排记录真实的存储损坏原因，而不是静默覆盖原数据。
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

  /// 基于当前状态做一次“读取—转换—写回”的局部更新。
  ///
  /// 此方法不提供跨调用事务或互斥；多个并发更新可能基于同一旧快照计算，调用方
  /// 必须串行化存在写冲突的操作，或在更高层提供队列。
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

/// 迁移升级设置并移除旧版本重复保存的登录身份。
///
/// STUM 的 IM/DP 统一读取 `AppConfig`，CD 读取“关于设备”的唯一设备 ID；这里
/// 删除遗留键，确保后续任意 Store 写回都不会继续携带可能已经失效的身份。
Map<String, Object?> _upgradeSettingsMap(Object? value) {
  final settings = _mergeObjectMap(const <String, Object?>{
    'enabled': false,
    'host': '',
    'port': 0,
    'terminalId': '',
    'packageTag': '',
  }, value);
  settings.remove('moduleImei');
  settings.remove('dataProtocolIp');
  settings.remove('chipId');
  return settings;
}
