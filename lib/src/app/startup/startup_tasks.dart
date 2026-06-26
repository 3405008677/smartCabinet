import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/camera/camera_binding_service.dart';
import '../../core/storage/app_local_store_provider.dart';
import '../../core/storage/local_store_bootstrap_service.dart';
import 'startup_task.dart';

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
  bool get required => true;

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
    CameraBindingService? cameraBindingService,
    bool requireAtLeastOneCamera = true,
    CameraLoader? cameraLoader,
    int maxAttempts = 6,
    Duration retryDelay = const Duration(seconds: 2),
  }) : this._(
         cameraBindingService,
         requireAtLeastOneCamera,
         cameraLoader,
         maxAttempts,
         retryDelay,
       );

  const LoadCamerasStartupTask._(
    this._cameraBindingService,
    this._requireAtLeastOneCamera,
    this._cameraLoader,
    this._maxAttempts,
    this._retryDelay,
  );

  final CameraBindingService? _cameraBindingService;
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

    return (_cameraBindingService ?? CameraBindingService())
        .loadAvailableCameras(forceReload: forceReload);
  }
}
