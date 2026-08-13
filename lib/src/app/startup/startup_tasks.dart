import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smart_cabinet/src/core/camera/cabinet_camera.dart';
import 'package:smart_cabinet/src/core/config/app_config.dart';
import 'package:smart_cabinet/src/core/mqtt/mqtt_service.dart';
import 'package:smart_cabinet/src/core/storage/app_local_store_provider.dart';
import 'package:smart_cabinet/src/core/storage/local_store_bootstrap_service.dart';
import 'package:smart_cabinet/src/app/startup/startup_task.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/repositories/operator_identity_repository_impl.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/domain/entities/terminal_upgrade.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/domain/repositories/terminal_upgrade_repository.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/terminal_upgrade_providers.dart';

/// 摄像头加载函数。
///
/// 作为测试注入点，允许启动任务在不访问真实 camera 插件的情况下验证重试策略。
typedef CameraLoader =
    Future<List<CabinetCameraDevice>> Function({required bool forceReload});

/// 执行 AFRR APP 登录的函数类型，测试可注入受控实现。
typedef AfrrAppLogon = Future<void> Function();

/// 启动阶段连接监管服务并完成 APP `logon`。
///
/// 这是进入主界面的关键任务。任务成功后保留同一条 AFRR 长连接，供后续操作员
/// 登录复用，保证 `logon` 是新连接发送的第一条消息。
class ConnectAfrrAppStartupTask implements StartupTask {
  /// 创建监管服务 APP 登录任务。
  const ConnectAfrrAppStartupTask({this.logon});

  /// 测试可注入不访问真实 Socket 的登录函数。
  final AfrrAppLogon? logon;

  @override
  String get name => '登录监管服务';

  @override
  int get order => 10;

  @override
  bool get required => true;

  @override
  Duration get timeout => const Duration(seconds: 25);

  @override
  Future<void> run() {
    return (logon ?? operatorAfrrLoginDataSource.logonApp)();
  }
}

/// 启动阶段缓存本地 Store 数据。
///
/// 该任务是首帧后的可选任务；设备信息或存储失败会留痕，但不阻止主界面使用。
class CacheLocalStoreStartupTask implements StartupTask {
  /// 创建本地 Store 缓存启动任务。
  const CacheLocalStoreStartupTask(this._providerContainer);

  /// 正式应用持有的 Provider 容器，确保启动缓存与页面共享同一 Store 实例。
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
///
/// 摄像头是进入主界面的关键能力。任务采用有上限的间隔重试，并在每次尝试时
/// 绕过枚举缓存，以便识别启动过程中刚完成连接或授权的设备。
class LoadCamerasStartupTask implements StartupTask {
  /// 创建摄像头加载启动任务。
  ///
  /// [maxAttempts] 限制总尝试次数，[retryDelay] 控制相邻尝试的等待时间；
  /// [requireAtLeastOneCamera] 可由不要求实体摄像头的受控场景关闭。
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
        // 保留最后一次具体错误，最终失败页可以展示最接近现场的原因。
        lastError = error;
      }

      if (attempt < _maxAttempts) {
        await Future<void>.delayed(_retryDelay);
      }
    }

    throw StateError('摄像头启动检测失败，已重试 $_maxAttempts 次：$lastError');
  }

  /// 通过测试注入函数或正式服务执行一次摄像头枚举。
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
///
/// MQTT 属于首帧后的可选能力，broker 暂时不可用时不阻塞终端进入主界面。
class ConnectMqttStartupTask implements StartupTask {
  /// 创建 MQTT 启动任务。
  const ConnectMqttStartupTask({this.mqttService});

  /// MQTT 连接服务；测试可以注入不访问真实 broker 的实现。
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

/// 首帧前恢复 Android 活动安装与应用级柜门维护租约。
///
/// 该任务不读取 STUM 开关也不建立网络连接。即使升级监控已经关闭，只要原生
/// PackageInstaller 仍处于提交或等待确认状态，就必须先阻止新开门再展示主界面。
class RestoreTerminalUpgradeInstallSafetyTask implements StartupTask {
  /// 创建安装安全恢复任务。
  const RestoreTerminalUpgradeInstallSafetyTask(
    this._providerContainer, {
    this.repository,
  });

  final ProviderContainer _providerContainer;

  /// 测试可注入不访问真实 MethodChannel 的 Repository。
  final TerminalUpgradeRepository? repository;

  @override
  String get name => '恢复终端升级安装安全状态';

  @override
  int get order => 5;

  @override
  bool get required => true;

  @override
  Duration get timeout => const Duration(seconds: 8);

  @override
  Future<void> run() async {
    final injectedRepository = repository;
    final TerminalUpgradeRepository targetRepository =
        injectedRepository ??
        _providerContainer.read(terminalUpgradeRepositoryProvider);
    await targetRepository.refreshInstallStatus();
    final safetyError = targetRepository.current.errorMessage;
    if (safetyError?.code ==
            TerminalUpgradeMessageCode.readInstallStatusFailed ||
        safetyError?.code ==
            TerminalUpgradeMessageCode.maintenanceRestoreFailed) {
      // 无法判断系统安装状态或无法取得维护租约时，继续进入主界面会允许不安全开门。
      throw TerminalUpgradeOperationException(safetyError!);
    }
  }
}

/// 首帧后按本地配置启动终端升级监控。
///
/// 本任务必须排在本地缓存之后，并且只调度 Repository 持有的长连接循环；升级
/// 服务端不可用时作为可选能力留痕，不阻止柜机继续处理本地业务。
class StartTerminalUpgradeMonitorTask implements StartupTask {
  /// 创建升级监控启动任务。
  const StartTerminalUpgradeMonitorTask(
    this._providerContainer, {
    this.repository,
  });

  final ProviderContainer _providerContainer;

  /// 测试可注入不访问真实 Socket 的 Repository。
  final TerminalUpgradeRepository? repository;

  @override
  String get name => '启动终端升级监控';

  @override
  int get order => 40;

  @override
  bool get required => false;

  @override
  Duration get timeout => const Duration(seconds: 8);

  @override
  Future<void> run() async {
    final store = await _providerContainer.read(appLocalStoreProvider.future);
    final settings = TerminalUpgradeSettings.fromJson(
      (await store.state()).upgrade,
      defaultHost: AppConfig.terminalUpgradeHost,
      defaultPort: AppConfig.terminalUpgradePort,
    );
    if (!settings.enabled) {
      return;
    }
    final injectedRepository = repository;
    final TerminalUpgradeRepository targetRepository =
        injectedRepository ??
        _providerContainer.read(terminalUpgradeRepositoryProvider);
    await targetRepository.start(settings);
  }
}
