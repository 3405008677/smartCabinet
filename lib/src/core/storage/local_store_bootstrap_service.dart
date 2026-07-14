import 'package:smart_cabinet/src/core/config/app_config.dart';
import 'package:smart_cabinet/src/core/device/device_info_service.dart';
import 'package:smart_cabinet/src/core/storage/app_local_store.dart';

/// 读取设备信息的函数签名。
typedef FetchDeviceInfo = Future<List<DeviceInfoItem>> Function();

/// 本地 Store 启动缓存服务。
///
/// 应用启动后调用该服务，将启动阶段可确定的信息提前写入本地 Store。
class LocalStoreBootstrapService {
  /// 创建本地 Store 启动缓存服务。
  const LocalStoreBootstrapService({
    required AppLocalStore store,
    FetchDeviceInfo fetchDeviceInfo = _defaultFetchDeviceInfo,
  }) : this._(store, fetchDeviceInfo);

  /// 创建本地 Store 启动缓存服务内部构造器。
  const LocalStoreBootstrapService._(this._store, this._fetchDeviceInfo);

  /// 本地 Store。
  final AppLocalStore _store;

  /// 设备信息读取函数。
  final FetchDeviceInfo _fetchDeviceInfo;

  /// 缓存启动阶段需要写入本地 Store 的数据。
  Future<void> cacheStartupData() async {
    final deviceInfoItems = await _fetchDeviceInfo();
    final deviceInfo = <String, Object?>{};

    for (final item in deviceInfoItems) {
      deviceInfo[item.label] = item.value;
    }

    const placeholderReportUrl = 'http://192.168.1.100:3000/api/logs/error';
    await _store.update((state) {
      final logging = <String, Object?>{
        'errorReportUrl': placeholderReportUrl,
        'uploadEnabled': false,
        ...state.logging,
      };
      if (logging['errorReportUrl'] == placeholderReportUrl) {
        // The placeholder backend is not deployed; keep uploads opt-in.
        logging['uploadEnabled'] = false;
      }
      final configuredStreamUrl = state.video['streamUrl']?.toString().trim();

      return state.copyWith(
        deviceInfo: deviceInfo,
        logging: logging,
        video: <String, Object?>{
          ...state.video,
          'streamUrl': buildStreamUrl(deviceInfo['唯一设备ID']?.toString()),
          'streamProfiles': [
            for (final profile in AppConfig.streamProfiles)
              <String, Object?>{
                'name': profile.name,
                'width': profile.width,
                'height': profile.height,
                'fps': profile.fps,
                'bitrate': profile.bitrate,
                'gopSeconds': profile.gopSeconds,
              },
          ],
          if (configuredStreamUrl != null && configuredStreamUrl.isNotEmpty)
            'streamUrl': configuredStreamUrl,
        },
      );
    });
  }

  /// 根据唯一设备 ID 构建推流地址。
  static String buildStreamUrl(String? uniqueDeviceId) {
    final streamId = uniqueDeviceId == null || uniqueDeviceId.isEmpty
        ? 'unknown'
        : uniqueDeviceId;

    return '${AppConfig.streamBaseUrl}/$streamId';
  }

  /// 默认从原生通道读取设备信息。
  static Future<List<DeviceInfoItem>> _defaultFetchDeviceInfo() {
    return const DeviceInfoService().fetchDeviceInfo();
  }
}
