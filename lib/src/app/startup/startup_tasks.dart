import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smart_cabinet/src/core/camera/cabinet_camera.dart';
import 'package:smart_cabinet/src/core/mqtt/mqtt_service.dart';
import 'package:smart_cabinet/src/core/storage/app_local_store_provider.dart';
import 'package:smart_cabinet/src/core/storage/local_store_bootstrap_service.dart';
import 'package:smart_cabinet/src/app/startup/startup_task.dart';

/// 摄像头加载函数。
typedef CameraLoader =
    Future<List<CabinetCameraDevice>> Function({required bool forceReload});

/// 启动阶段缓存本地 Store 数据。
class CacheLocalStoreStartupTask implements StartupTask {
  /// 创建本地 Store 缓存启动任务。
  const CacheLocalStoreStartupTask(this._providerContainer);

  final ProviderContainer _providerContainer;

  @override
  String get name => '缓存本地设备数据';

  @override
  int get order => 10;

  @override
  bool get required => false;

  @override
  Duration get timeout => const Duration(seconds: 8);

  @override
  Future<void> run() async {
    final store = await _providerContainer.read(appLocalStoreProvider.future);
    await LocalStoreBootstrapService(store: store).cacheStartupData();
  }
}

/// 启动阶段加载全部摄像头。
class LoadCamerasStartupTask implements StartupTask {
  /// 创建摄像头加载启动任务。
  const LoadCamerasStartupTask({
    CabinetCameraService? cameraService,
    bool requireAtLeastOneCamera = true,
    CameraLoader? cameraLoader,
    int maxAttempts = 6,
    Duration retryDelay = const Duration(seconds: 2),
  }) : this._(
         cameraService,
         requireAtLeastOneCamera,
         cameraLoader,
         maxAttempts,
         retryDelay,
       );

  const LoadCamerasStartupTask._(
    this._cameraService,
    this._requireAtLeastOneCamera,
    this._cameraLoader,
    this._maxAttempts,
    this._retryDelay,
  );

  final CabinetCameraService? _cameraService;
  final bool _requireAtLeastOneCamera;
  final CameraLoader? _cameraLoader;
  final int _maxAttempts;
  final Duration _retryDelay;

  @override
  String get name => '加载摄像头';

  @override
  int get order => 20;

  @override
  bool get required => true;

  @override
  Duration get timeout => const Duration(seconds: 35);

  @override
  Future<void> run() async {
    Object? lastError;

    for (var attempt = 1; attempt <= _maxAttempts; attempt += 1) {
      try {
        final cameras = await _loadCameras(forceReload: true);

        if (!_requireAtLeastOneCamera || cameras.isNotEmpty) {
          return;
        }

        lastError = StateError('未检测到可用摄像头');
      } catch (error) {
        lastError = error;
      }

      if (attempt < _maxAttempts) {
        await Future<void>.delayed(_retryDelay);
      }
    }

    throw StateError('摄像头启动检测失败，已重试 $_maxAttempts 次：$lastError');
  }

  Future<List<CabinetCameraDevice>> _loadCameras({required bool forceReload}) {
    final cameraLoader = _cameraLoader;
    if (cameraLoader != null) {
      return cameraLoader(forceReload: forceReload);
    }

    return (_cameraService ?? const CabinetCameraService())
        .loadAvailableCameras(forceReload: forceReload);
  }
}

/// 启动阶段连接 MQTT 并订阅命令主题。
class ConnectMqttStartupTask implements StartupTask {
  /// 创建 MQTT 启动任务。
  const ConnectMqttStartupTask({this.mqttService});

  /// MQTT 连接服务。
  final SmartCabinetMqttConnector? mqttService;

  @override
  String get name => '连接 MQTT';

  @override
  int get order => 30;

  @override
  bool get required => false;

  @override
  Duration get timeout => const Duration(seconds: 8);

  @override
  Future<void> run() {
    return (mqttService ?? const SmartCabinetMqttService())
        .connectAndSubscribe();
  }
}
