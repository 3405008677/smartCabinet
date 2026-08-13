import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:smart_cabinet/src/core/device/cabinet_door_guard.dart';
import 'package:smart_cabinet/src/core/logging/app_logger.dart';
import 'package:smart_cabinet/src/core/logging/communication_log_store.dart';
import 'package:smart_cabinet/src/core/network/protocol/tcp_protocol.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/data/datasources/method_channel_terminal_upgrade_device.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/data/datasources/terminal_upgrade_package_downloader.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/data/datasources/terminal_upgrade_device.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/data/protocol/zrd_stum_protocol.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/domain/entities/terminal_upgrade.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/domain/repositories/terminal_upgrade_repository.dart';

/// 异步读取“关于设备”唯一设备 ID 的可替换函数。
typedef TerminalUpgradeUniqueDeviceIdLoader = Future<String> Function();

/// 升级监控收到一份已经通过协议校验的 URL 升级包时的通知回调。
///
/// 回调只负责把“有新版本待管理员确认”提升到应用级 UI，不能在这里直接下载、
/// 取得维护租约或提交安装，避免远端 S03 绕过管理员确认门禁。
typedef TerminalUpgradeOfferAvailableCallback =
    void Function(TerminalUpgradeOffer offer);

/// ZRD STUM 升级监控 Repository。
///
/// 本实现只声明协议已经完整描述的 URL 模式。服务端返回 AD=2 时会按 NG3AD
/// 拒绝，避免在缺少分包编号、长度、重传和校验定义的情况下自行发明协议。
final class TerminalUpgradeRepositoryImpl implements TerminalUpgradeRepository {
  /// 创建升级监控 Repository。
  ///
  /// [moduleId] 与 [dataProtocolIp] 只由生产 Provider 从 `AppConfig` 注入；
  /// [versionDate] 是当前 APK 构建批次日期，用于形成 `SL_V版本_yyyyMMdd`；
  /// [uniqueDeviceIdLoader] 读取“关于设备”同源的唯一设备 ID 作为 T01.CD。
  /// 页面和本地升级设置均不能覆盖这三项身份。
  TerminalUpgradeRepositoryImpl({
    required String moduleId,
    required String dataProtocolIp,
    String versionDate = '20260812',
    required TerminalUpgradeUniqueDeviceIdLoader uniqueDeviceIdLoader,
    TerminalUpgradeDevice? device,
    TerminalUpgradePackageDownloader? downloader,
    TcpSocketConnector? socketConnector,
    CabinetDoorGuard? doorGuard,
    this.onOfferAvailable,
    this.connectTimeout = const Duration(seconds: 8),
    this.identityLoadTimeout = const Duration(seconds: 5),
    this.loginTimeout = const Duration(seconds: 10),
    this.upgradeCheckTimeout = const Duration(seconds: 30),
    this.installStatusPollInterval = const Duration(seconds: 3),
    this.initialReconnectDelay = const Duration(seconds: 5),
    this.maximumReconnectDelay = const Duration(minutes: 1),
  }) : _moduleId = moduleId.trim(),
       _dataProtocolIp = dataProtocolIp.trim(),
       _versionDate = versionDate.trim(),
       _loadUniqueDeviceId = uniqueDeviceIdLoader,
       _device = device ?? MethodChannelTerminalUpgradeDevice(),
       _downloader = downloader ?? const IoTerminalUpgradePackageDownloader(),
       _doorGuard = doorGuard ?? globalCabinetDoorGuard {
    _validatePositiveDuration(upgradeCheckTimeout, 'upgradeCheckTimeout');
    _validatePositiveDuration(identityLoadTimeout, 'identityLoadTimeout');
    _validatePositiveDuration(
      installStatusPollInterval,
      'installStatusPollInterval',
    );
    _validatePositiveDuration(initialReconnectDelay, 'initialReconnectDelay');
    _validatePositiveDuration(maximumReconnectDelay, 'maximumReconnectDelay');
    if (maximumReconnectDelay < initialReconnectDelay) {
      throw ArgumentError.value(
        maximumReconnectDelay,
        'maximumReconnectDelay',
        '最大重连等待时间不能小于首次重连等待时间',
      );
    }
    _protocolClient = TcpProtocolClient<ZrdStumMessage>(
      frameDecoderFactory: ZrdStumMessageFrameDecoder.new,
      socketConnector: socketConnector,
      communicationLogAdapter: const TcpCommunicationLogAdapter<ZrdStumMessage>(
        channel: 'ZRD STUM TCP',
        targetType: CommunicationTargetType.upgradeCommand,
        formatOutbound: _formatStumOutboundLog,
        formatInbound: _formatStumInboundLog,
      ),
      connectTimeout: connectTimeout,
      defaultRequestTimeout: loginTimeout,
    );
    _protocolMessagesSubscription = _protocolClient.unmatchedMessages.listen(
      _handleProtocolMessage,
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.error('STUM transport failed', error, stackTrace);
        // 登录应答刚完成、_connect 尚未退出时也可能立即断线；统一进入恢复流程，
        // _connect 的 catch 会通过现有重连定时器避免重复发布失败状态。
        _handleConnectionLost(_generation);
      },
    );
  }

  final TerminalUpgradeDevice _device;
  final String _moduleId;
  final String _dataProtocolIp;
  final String _versionDate;
  final TerminalUpgradeUniqueDeviceIdLoader _loadUniqueDeviceId;
  final TerminalUpgradePackageDownloader _downloader;
  final CabinetDoorGuard _doorGuard;

  /// 合法 S03 到达时通知应用级 UI 展示管理员处理入口。
  ///
  /// 该回调不是安装授权，也不得承担下载或安装副作用。
  final TerminalUpgradeOfferAvailableCallback? onOfferAvailable;
  late final TcpProtocolClient<ZrdStumMessage> _protocolClient;
  late final StreamSubscription<ZrdStumMessage> _protocolMessagesSubscription;

  /// 单次 TCP 连接等待上限。
  final Duration connectTimeout;

  /// 读取“关于设备”唯一设备 ID 的等待上限。
  final Duration identityLoadTimeout;

  /// T01 等待 S00 登录应答上限。
  final Duration loginTimeout;

  /// T03 发出后等待 S00/S03 完成一次检查的上限。
  final Duration upgradeCheckTimeout;

  /// 原生安装处于活动态时的状态对账间隔。
  final Duration installStatusPollInterval;

  /// 第一次断线重连等待时间。
  final Duration initialReconnectDelay;

  /// 指数退避允许的最大等待时间。
  final Duration maximumReconnectDelay;

  final StreamController<TerminalUpgradeSnapshot> _statesController =
      StreamController<TerminalUpgradeSnapshot>.broadcast();

  TerminalUpgradeSnapshot _current = const TerminalUpgradeSnapshot();
  TerminalUpgradeSettings? _settings;
  TerminalUpgradeLoginIdentity? _loginIdentity;
  TerminalAppVersion? _appVersion;
  Timer? _upgradeCheckTimer;
  Timer? _reconnectTimer;
  Timer? _installStatusPollTimer;
  ZrdStumMessageSequence _sequence = ZrdStumMessageSequence();
  int _generation = 0;
  int _identityLoadSequence = 0;
  int _reconnectAttempt = 0;
  int? _loginSerialNumber;
  int? _upgradeRequestSerialNumber;
  bool _started = false;
  bool _authenticated = false;
  bool _connecting = false;
  bool _awaitingOffer = false;
  bool _installing = false;
  bool _nativeInstallActive = false;
  bool _disposed = false;
  int _nextInstallOperation = 0;
  final String _operationNonce = _createOperationNonce();
  int _installStatusReadSequence = 0;
  String? _maintenanceLeaseId;
  TerminalUpgradeDownloadCancellationToken? _downloadCancellationToken;
  String? _nativeSubmissionOperationId;
  Completer<void>? _installOperationCompleter;

  @override
  TerminalUpgradeSnapshot get current => _current;

  @override
  Stream<TerminalUpgradeSnapshot> get states => _statesController.stream;

  @override
  Future<void> start(TerminalUpgradeSettings settings) async {
    _ensureNotDisposed();
    if (!settings.enabled) {
      await stop();
      return;
    }
    final validationError = settings.validate();
    if (validationError != null) {
      final reason = TerminalUpgradeMessage(validationError);
      _emitFailure(reason);
      throw TerminalUpgradeOperationException(reason);
    }

    final unchanged = _started && _settings == settings;
    if (unchanged &&
        _loginIdentity != null &&
        (_authenticated || _connecting)) {
      return;
    }

    // 先使旧异步连接失效，再等待旧 Socket 收敛；否则旧地址的迟到失败可能
    // 关闭新地址已经建立的连接。
    _generation += 1;
    final generation = _generation;
    _identityLoadSequence += 1;
    final identityLoadSequence = _identityLoadSequence;
    _installStatusReadSequence += 1;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _installStatusPollTimer?.cancel();
    _installStatusPollTimer = null;
    _settings = settings;
    _loginIdentity = null;
    _started = true;
    _authenticated = false;
    _connecting = false;
    _awaitingOffer = false;
    _reconnectAttempt = 0;
    _sequence = ZrdStumMessageSequence();
    // 配置换代后旧 offer 立即失效，不能在下面任何 await 窗口被管理员继续提交。
    if (_current.offer != null) {
      _emit(
        _current.copyWith(
          clearOffer: true,
          downloadedBytes: 0,
          clearTotalBytes: true,
        ),
      );
    }
    _downloadCancellationToken?.cancel();
    await _cancelUncommittedNativeSubmission();
    await _waitForInstallOperationToSettle();
    await _closeConnection();
    if (!_isGenerationActive(generation)) {
      return;
    }

    late final String uniqueDeviceId;
    try {
      uniqueDeviceId = (await _loadUniqueDeviceId().timeout(
        identityLoadTimeout,
      )).trim();
    } catch (error, stackTrace) {
      if (!_isGenerationActive(generation) ||
          identityLoadSequence != _identityLoadSequence) {
        return;
      }
      AppLogger.error(
        'Read terminal upgrade unique device ID failed',
        error,
        stackTrace,
      );
      final reason = TerminalUpgradeMessage(
        TerminalUpgradeMessageCode.settingsChipIdInvalid,
        detail: _externalErrorDetail(error),
      );
      _started = false;
      _emitFailure(reason);
      if (_nativeInstallActive) {
        _scheduleInstallStatusPoll(generation);
      }
      throw TerminalUpgradeOperationException(reason);
    }
    if (!_isGenerationActive(generation) ||
        identityLoadSequence != _identityLoadSequence) {
      return;
    }
    final loginIdentity = TerminalUpgradeLoginIdentity(
      moduleId: _moduleId,
      dataProtocolIp: _dataProtocolIp,
      chipId: uniqueDeviceId,
    );
    final identityValidationError = loginIdentity.validate();
    if (identityValidationError != null) {
      final reason = TerminalUpgradeMessage(identityValidationError);
      _started = false;
      _emitFailure(reason);
      if (_nativeInstallActive) {
        _scheduleInstallStatusPoll(generation);
      }
      throw TerminalUpgradeOperationException(reason);
    }
    _loginIdentity = loginIdentity;

    try {
      final appVersion = await _device.getAppVersion();
      if (!_isGenerationActive(generation)) {
        return;
      }
      final installStatus = await _device.getInstallStatus();
      if (!_isGenerationActive(generation)) {
        return;
      }
      _appVersion = appVersion;
      _applyInstallStatus(
        installStatus,
        appVersion,
        generation: generation,
        initialRead: true,
      );
    } catch (error, stackTrace) {
      if (!_isGenerationActive(generation)) {
        return;
      }
      AppLogger.error(
        'Read terminal upgrade version failed',
        error,
        stackTrace,
      );
      final reason = TerminalUpgradeMessage(
        TerminalUpgradeMessageCode.readAppVersionFailed,
        detail: _externalErrorDetail(error),
      );
      _emitFailure(reason);
      throw TerminalUpgradeOperationException(reason);
    }

    if (_nativeInstallActive) {
      _scheduleInstallStatusPoll(generation);
      return;
    }

    // 长连接循环由 Repository 自己持有；启动任务只负责调度，不能等待 Socket 结束。
    unawaited(_connect(generation));
  }

  @override
  Future<void> stop() async {
    if (_disposed) {
      return;
    }
    _started = false;
    _identityLoadSequence += 1;
    _generation += 1;
    final generation = _generation;
    _installStatusReadSequence += 1;
    _connecting = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _installStatusPollTimer?.cancel();
    _installStatusPollTimer = null;
    _loginIdentity = null;
    if (_current.offer != null) {
      _emit(
        _current.copyWith(
          clearOffer: true,
          downloadedBytes: 0,
          clearTotalBytes: true,
        ),
      );
    }
    _downloadCancellationToken?.cancel();
    await _cancelUncommittedNativeSubmission();
    await _waitForInstallOperationToSettle();
    await _closeConnection();
    if (_disposed || _started || generation != _generation) {
      return;
    }
    _emit(
      _current.copyWith(
        phase: TerminalUpgradePhase.disabled,
        message: const TerminalUpgradeMessage(
          TerminalUpgradeMessageCode.monitoringDisabled,
        ),
        clearErrorMessage: true,
        downloadedBytes: 0,
        clearTotalBytes: true,
        clearOffer: true,
      ),
    );
    if (_nativeInstallActive) {
      _scheduleInstallStatusPoll(generation);
    } else {
      final leaseId = _maintenanceLeaseId;
      if (leaseId != null) {
        _releaseMaintenanceLease(leaseId);
      }
    }
  }

  @override
  Future<void> requestCheck() async {
    _ensureNotDisposed();
    final settings = _settings;
    if (!_started || settings == null || !settings.enabled) {
      throw const TerminalUpgradeOperationException(
        TerminalUpgradeMessage(TerminalUpgradeMessageCode.monitoringNotEnabled),
      );
    }
    if (_current.offer != null) {
      throw const TerminalUpgradeOperationException(
        TerminalUpgradeMessage(
          TerminalUpgradeMessageCode.pendingOfferRequiresDecision,
        ),
      );
    }
    if (_awaitingOffer) {
      return;
    }
    if (_installing) {
      throw const TerminalUpgradeOperationException(
        TerminalUpgradeMessage(
          TerminalUpgradeMessageCode.checkBlockedByDownload,
        ),
      );
    }
    if (_nativeInstallActive) {
      throw const TerminalUpgradeOperationException(
        TerminalUpgradeMessage(TerminalUpgradeMessageCode.installAlreadyActive),
      );
    }
    if (_authenticated && _protocolClient.isConnected) {
      _sendUpgradeRequest();
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _connect(_generation);
  }

  @override
  Future<void> installAvailableUpdate({
    required TerminalUpgradeOffer confirmedOffer,
    required bool administratorConfirmed,
  }) async {
    _ensureNotDisposed();
    if (!administratorConfirmed) {
      throw const TerminalUpgradeOperationException(
        TerminalUpgradeMessage(
          TerminalUpgradeMessageCode.administratorConfirmationRequired,
        ),
      );
    }
    if (_installing) {
      return;
    }
    if (_nativeInstallActive) {
      throw const TerminalUpgradeOperationException(
        TerminalUpgradeMessage(TerminalUpgradeMessageCode.installAlreadyActive),
      );
    }
    final offer = _current.offer;
    if (offer == null) {
      throw const TerminalUpgradeOperationException(
        TerminalUpgradeMessage(TerminalUpgradeMessageCode.noInstallableOffer),
      );
    }
    // 必须是弹窗打开时捕获的同一个不可变 offer，值相同的新对象也要求重新确认。
    if (!identical(offer, confirmedOffer)) {
      throw const TerminalUpgradeOperationException(
        TerminalUpgradeMessage(
          TerminalUpgradeMessageCode.confirmedOfferChanged,
        ),
      );
    }
    if (!_doorGuard.allDoorsClosed) {
      const reason = TerminalUpgradeMessage(
        TerminalUpgradeMessageCode.doorsNotClosed,
      );
      _emitFailure(reason, preserveOffer: true);
      throw const TerminalUpgradeOperationException(reason);
    }

    final generation = _generation;
    final offerIdentity = offer.identityKey;
    _nextInstallOperation += 1;
    final maintenanceLeaseId =
        'terminal-upgrade:$_operationNonce:$generation:$_nextInstallOperation';
    if (!_doorGuard.tryAcquireMaintenance(maintenanceLeaseId)) {
      const reason = TerminalUpgradeMessage(
        TerminalUpgradeMessageCode.maintenanceUnavailable,
      );
      _emitFailure(reason, preserveOffer: true);
      throw const TerminalUpgradeOperationException(reason);
    }
    _maintenanceLeaseId = maintenanceLeaseId;
    _installing = true;
    _installStatusReadSequence += 1;
    final operationCompleter = Completer<void>();
    _installOperationCompleter = operationCompleter;
    final cancellationToken = TerminalUpgradeDownloadCancellationToken();
    _downloadCancellationToken = cancellationToken;
    DownloadedTerminalUpgradePackage? package;
    var installSubmitted = false;
    try {
      _assertInstallOperationActive(
        generation: generation,
        offerIdentity: offerIdentity,
        maintenanceLeaseId: maintenanceLeaseId,
      );
      _emit(
        _current.copyWith(
          phase: TerminalUpgradePhase.downloading,
          message: TerminalUpgradeMessage(
            TerminalUpgradeMessageCode.downloadingVersion,
            arguments: <String, String>{'version': offer.targetVersion},
          ),
          clearErrorMessage: true,
          downloadedBytes: 0,
          clearTotalBytes: true,
        ),
      );
      package = await _downloader.download(
        offer,
        cancellationToken: cancellationToken,
        onProgress: (downloadedBytes, totalBytes) {
          _assertInstallOperationActive(
            generation: generation,
            offerIdentity: offerIdentity,
            maintenanceLeaseId: maintenanceLeaseId,
          );
          _emit(
            _current.copyWith(
              phase: TerminalUpgradePhase.downloading,
              downloadedBytes: downloadedBytes,
              totalBytes: totalBytes,
            ),
          );
        },
      );
      _assertInstallOperationActive(
        generation: generation,
        offerIdentity: offerIdentity,
        maintenanceLeaseId: maintenanceLeaseId,
      );
      _emit(
        _current.copyWith(
          phase: TerminalUpgradePhase.verifying,
          message: const TerminalUpgradeMessage(
            TerminalUpgradeMessageCode.checksumVerified,
          ),
          downloadedBytes: package.size,
          totalBytes: package.size,
          clearErrorMessage: true,
        ),
      );
      if (!_doorGuard.allDoorsClosed) {
        throw const TerminalUpgradeOperationException(
          TerminalUpgradeMessage(
            TerminalUpgradeMessageCode.doorsChangedDuringDownload,
          ),
        );
      }
      _assertInstallOperationActive(
        generation: generation,
        offerIdentity: offerIdentity,
        maintenanceLeaseId: maintenanceLeaseId,
      );
      _emit(
        _current.copyWith(
          phase: TerminalUpgradePhase.installing,
          message: const TerminalUpgradeMessage(
            TerminalUpgradeMessageCode.submittingInstaller,
          ),
        ),
      );
      _nativeSubmissionOperationId = maintenanceLeaseId;
      late final TerminalInstallSubmission submission;
      try {
        submission = await _device.installApk(
          package.file.path,
          targetVersion: offer.targetVersion,
          operationId: maintenanceLeaseId,
        );
      } finally {
        if (_nativeSubmissionOperationId == maintenanceLeaseId) {
          _nativeSubmissionOperationId = null;
        }
      }
      installSubmitted = true;
      _nativeInstallActive = _isActiveInstallState(submission.state);
      // PackageInstaller.commit 是不可逆提交点；若监控恰在原生调用期间停止，
      // 保留维护租约但不再用旧任务覆盖 disabled/新配置状态。
      if (!_isInstallOperationActive(
        generation: generation,
        offerIdentity: offerIdentity,
        maintenanceLeaseId: maintenanceLeaseId,
      )) {
        return;
      }
      _emit(
        _current.copyWith(
          phase: TerminalUpgradePhase.awaitingRestart,
          message: TerminalUpgradeMessage(
            TerminalUpgradeMessageCode.installSessionSubmitted,
            arguments: <String, String>{'sessionId': '${submission.sessionId}'},
          ),
          installStatus: TerminalInstallStatus(
            state: submission.state,
            sessionId: submission.sessionId,
            targetVersion: offer.targetVersion,
          ),
          clearErrorMessage: true,
        ),
      );
      if (_nativeInstallActive) {
        _scheduleInstallStatusPoll(generation);
      }
    } catch (error, stackTrace) {
      if (_isGenerationActive(generation)) {
        AppLogger.error('Terminal upgrade install failed', error, stackTrace);
        final reason = error is TerminalUpgradeOperationException
            ? error.reason
            : TerminalUpgradeMessage(
                TerminalUpgradeMessageCode.installFailed,
                detail: _externalErrorDetail(error),
              );
        _emitFailure(reason, preserveOffer: true);
      }
      if (error is TerminalUpgradeOperationException) {
        rethrow;
      }
      throw TerminalUpgradeOperationException(
        TerminalUpgradeMessage(
          TerminalUpgradeMessageCode.installFailed,
          detail: _externalErrorDetail(error),
        ),
      );
    } finally {
      _installing = false;
      if (identical(_downloadCancellationToken, cancellationToken)) {
        _downloadCancellationToken = null;
      }
      if (!installSubmitted) {
        _releaseMaintenanceLease(maintenanceLeaseId);
      }
      final directory = package?.file.parent;
      if (directory != null) {
        try {
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        } catch (error, stackTrace) {
          // 安装会话已经提交时，临时文件清理失败不能把结果倒置成“安装失败”。
          AppLogger.error(
            'Clean terminal upgrade package failed',
            error,
            stackTrace,
          );
        }
      }
      if (identical(_installOperationCompleter, operationCompleter)) {
        _installOperationCompleter = null;
      }
      if (!operationCompleter.isCompleted) {
        operationCompleter.complete();
      }
    }
  }

  @override
  Future<void> refreshInstallStatus() async {
    _ensureNotDisposed();
    await _refreshInstallStatus(_generation, automatic: false);
  }

  /// 读取并应用一份仍属于当前 Repository 代际的原生安装状态。
  Future<void> _refreshInstallStatus(
    int generation, {
    required bool automatic,
  }) async {
    final readSequence = ++_installStatusReadSequence;
    try {
      final status = await _device.getInstallStatus();
      final version = await _device.getAppVersion();
      if (!_isGenerationCurrent(generation) ||
          readSequence != _installStatusReadSequence) {
        return;
      }
      _appVersion = version;
      final wasActive = _nativeInstallActive;
      _applyInstallStatus(status, version, generation: generation);
      if (wasActive &&
          !_nativeInstallActive &&
          _started &&
          !_protocolClient.isConnected &&
          !_connecting) {
        unawaited(_connect(generation));
      }
    } catch (error, stackTrace) {
      if (!_isGenerationCurrent(generation) ||
          readSequence != _installStatusReadSequence) {
        return;
      }
      AppLogger.error('Read upgrade install status failed', error, stackTrace);
      if (!automatic) {
        _emitFailure(
          TerminalUpgradeMessage(
            TerminalUpgradeMessageCode.readInstallStatusFailed,
            detail: _externalErrorDetail(error),
          ),
          preserveOffer: true,
        );
      }
    } finally {
      if (_isGenerationCurrent(generation) && _nativeInstallActive) {
        _scheduleInstallStatusPoll(generation);
      }
    }
  }

  /// 建立连接、注册流监听并发送本次连接唯一的 T01。
  Future<void> _connect(int generation) async {
    if (!_isGenerationActive(generation) ||
        _nativeInstallActive ||
        _connecting ||
        _protocolClient.isConnected) {
      return;
    }
    final settings = _settings;
    final loginIdentity = _loginIdentity;
    if (settings == null || loginIdentity == null) {
      return;
    }
    _connecting = true;
    _emit(
      _current.copyWith(
        phase: TerminalUpgradePhase.connecting,
        message: const TerminalUpgradeMessage(
          TerminalUpgradeMessageCode.connectingServer,
        ),
        clearErrorMessage: true,
      ),
    );
    try {
      await _protocolClient.connect(
        settings.host.trim(),
        settings.port,
        timeout: connectTimeout,
      );
      if (!_isGenerationActive(generation) || _nativeInstallActive) {
        await _protocolClient.disconnect();
        return;
      }
      _authenticated = false;
      _loginSerialNumber = _sequence.next();
      _emit(
        _current.copyWith(
          phase: TerminalUpgradePhase.authenticating,
          message: const TerminalUpgradeMessage(
            TerminalUpgradeMessageCode.authenticatingTerminal,
          ),
          clearErrorMessage: true,
        ),
      );
      final loginSerialNumber = _loginSerialNumber!;
      final reply = await _protocolClient.request(
        ascii.encode(
          ZrdStumProtocolCodec.encodeLogin(
            settings,
            identity: loginIdentity,
            serialNumber: loginSerialNumber,
          ),
        ),
        matcher: (message) {
          return message.direction == ZrdStumDirection.server &&
              message.commandCode == '00' &&
              (message.segments['00'] == 'NG0' ||
                  (message.serialNumber == loginSerialNumber &&
                      message.segments.containsKey('01')));
        },
        timeout: loginTimeout,
      );
      if (!_isGenerationActive(generation) || _nativeInstallActive) {
        return;
      }
      _loginSerialNumber = null;
      if (reply.segments['00'] == 'NG0') {
        _emitFailure(
          const TerminalUpgradeMessage(
            TerminalUpgradeMessageCode.serverLoginRejected,
          ),
          preserveOffer: true,
        );
        await _closeConnection();
        _scheduleReconnect(generation);
        return;
      }
      final loginResult = reply.segments['01'];
      if (loginResult != 'OK') {
        _emitFailure(
          TerminalUpgradeMessage(
            TerminalUpgradeMessageCode.serverLoginRejected,
            detail: loginResult ?? '',
          ),
          preserveOffer: true,
        );
        await _closeConnection();
        _scheduleReconnect(generation);
        return;
      }
      _authenticated = true;
      _reconnectAttempt = 0;
      _sendUpgradeRequest();
    } catch (error, stackTrace) {
      if (!_isGenerationActive(generation)) {
        return;
      }
      AppLogger.error('Connect STUM server failed', error, stackTrace);
      await _closeConnection();
      if (!_isGenerationActive(generation)) {
        return;
      }
      if (_reconnectTimer == null) {
        _emitFailure(
          TerminalUpgradeMessage(
            TerminalUpgradeMessageCode.connectFailed,
            detail: _externalErrorDetail(error),
          ),
          preserveOffer: true,
        );
        _scheduleReconnect(generation);
      }
    } finally {
      if (generation == _generation) {
        _connecting = false;
      }
    }
  }

  /// 分发通用 TCP 客户端没有被请求 matcher 消费的 S00 与 S03 消息。
  void _handleProtocolMessage(ZrdStumMessage message) {
    if (!_isGenerationActive(_generation)) {
      return;
    }
    if (message.direction != ZrdStumDirection.server) {
      _sendReply(message, 'NG1');
      return;
    }
    switch (message.commandCode) {
      case '00':
        _handleServerReply(message);
        break;
      case '03':
        _handleUpgradeOffer(message);
        break;
      default:
        _sendReply(message, 'NG1');
    }
  }

  /// 处理 S00 对 T01/T03 的相关应答。
  void _handleServerReply(ZrdStumMessage message) {
    if (message.segments['00'] == 'NG0') {
      _handleConnectionLost(_generation);
      return;
    }
    final requestResult = message.segments['03'];
    if (requestResult != null &&
        message.serialNumber == _upgradeRequestSerialNumber) {
      _upgradeRequestSerialNumber = null;
      if (requestResult != 'OK') {
        _upgradeCheckTimer?.cancel();
        _upgradeCheckTimer = null;
        _awaitingOffer = false;
        if (requestResult == 'NG0') {
          _handleConnectionLost(_generation);
          return;
        }
        _emitFailure(
          TerminalUpgradeMessage(
            TerminalUpgradeMessageCode.serverCheckRejected,
            detail: requestResult,
          ),
          preserveOffer: true,
        );
      } else {
        _emit(
          _current.copyWith(
            phase: TerminalUpgradePhase.checking,
            message: const TerminalUpgradeMessage(
              TerminalUpgradeMessageCode.checkRequestAccepted,
            ),
            clearErrorMessage: true,
          ),
        );
      }
    }
  }

  /// 校验 S03，先回收讫应答，再把合法升级包交给管理员确认。
  void _handleUpgradeOffer(ZrdStumMessage message) {
    // 本项目安全边界只允许当前 T03 等待窗口接收新 offer；窗口外的人工推送
    // 不得创建任务。已接收帧的精确重传仅幂等补发 ACK，不视为接受新 offer。
    if (!_authenticated || _installing || _nativeInstallActive) {
      _sendReply(message, 'NG1');
      return;
    }
    if (!_awaitingOffer) {
      _sendReply(
        message,
        _current.offer != null && _isCurrentOfferRetransmission(message)
            ? 'OK'
            : 'NG1',
      );
      return;
    }
    _upgradeCheckTimer?.cancel();
    _upgradeCheckTimer = null;
    // 一条 S03 无论合法与否都消费本次单飞窗口，避免随后第二条消息替换决策。
    _awaitingOffer = false;
    _upgradeRequestSerialNumber = null;
    try {
      final offer = ZrdStumProtocolCodec.parseUpgradeOffer(
        message,
        currentVersion: _appVersion?.name ?? '',
        expectedPackageTag: _settings?.packageTag ?? '',
      );
      if (offer == null) {
        _sendReply(message, 'OK');
        _emit(
          _current.copyWith(
            phase: TerminalUpgradePhase.upToDate,
            message: const TerminalUpgradeMessage(
              TerminalUpgradeMessageCode.alreadyLatest,
            ),
            clearErrorMessage: true,
            clearOffer: true,
            downloadedBytes: 0,
            clearTotalBytes: true,
          ),
        );
        return;
      }
      _sendReply(message, 'OK');
      _emit(
        _current.copyWith(
          phase: TerminalUpgradePhase.updateAvailable,
          message: TerminalUpgradeMessage(
            TerminalUpgradeMessageCode.updateAvailable,
            arguments: <String, String>{'version': offer.targetVersion},
          ),
          clearErrorMessage: true,
          offer: offer,
          downloadedBytes: 0,
          clearTotalBytes: true,
        ),
      );
      try {
        onOfferAvailable?.call(offer);
      } catch (error, stackTrace) {
        // 通知层异常不能改变已经回给服务端的 OK，也不能使合法 offer 丢失。
        AppLogger.error(
          'Notify terminal upgrade offer failed',
          error,
          stackTrace,
        );
      }
    } on ZrdStumProtocolException catch (error, stackTrace) {
      AppLogger.error('Reject STUM upgrade offer', error, stackTrace);
      _sendReply(message, error.responseValue);
      _emitFailure(
        TerminalUpgradeMessage(
          TerminalUpgradeMessageCode.offerRejected,
          arguments: <String, String>{'responseCode': error.responseValue},
        ),
        preserveOffer: true,
      );
    }
  }

  /// 登录成功后发送单飞 T03 请求。
  void _sendUpgradeRequest() {
    if (!_authenticated ||
        _awaitingOffer ||
        _installing ||
        _nativeInstallActive ||
        !_protocolClient.isConnected) {
      return;
    }
    final pendingOffer = _current.offer;
    if (pendingOffer != null) {
      // 重连只恢复登录，不得在后台静默用新 S03 替换管理员尚未处理的 offer。
      _emit(
        _current.copyWith(
          phase: TerminalUpgradePhase.updateAvailable,
          message: TerminalUpgradeMessage(
            TerminalUpgradeMessageCode.updateAvailable,
            arguments: <String, String>{'version': pendingOffer.targetVersion},
          ),
          clearErrorMessage: true,
        ),
      );
      return;
    }
    final version = _appVersion;
    final settings = _settings;
    if (version == null || settings == null) {
      return;
    }
    final serialNumber = _sequence.next();
    _upgradeRequestSerialNumber = serialNumber;
    _awaitingOffer = true;
    final writeEnqueued = _write(
      ZrdStumProtocolCodec.encodeUpgradeRequest(
        currentVersion: version.name,
        versionDate: _versionDate,
        packageTag: settings.packageTag,
        serialNumber: serialNumber,
      ),
    );
    if (!writeEnqueued) {
      // 同步发现连接已失效时，_write 已进入断线恢复；不能再用 checking 覆盖
      // disconnected 状态，也不能留下一个永远不会收到 S03 的等待窗口。
      _upgradeRequestSerialNumber = null;
      _awaitingOffer = false;
      return;
    }
    final generation = _generation;
    _upgradeCheckTimer?.cancel();
    _upgradeCheckTimer = Timer(upgradeCheckTimeout, () {
      if (!_isGenerationActive(generation) || !_awaitingOffer) {
        return;
      }
      _awaitingOffer = false;
      _upgradeRequestSerialNumber = null;
      _upgradeCheckTimer = null;
      _emitFailure(
        const TerminalUpgradeMessage(TerminalUpgradeMessageCode.checkTimedOut),
        preserveOffer: true,
      );
    });
    _emit(
      _current.copyWith(
        phase: TerminalUpgradePhase.checking,
        message: const TerminalUpgradeMessage(
          TerminalUpgradeMessageCode.checkingVersion,
        ),
        clearErrorMessage: true,
      ),
    );
  }

  /// 对服务端标准消息发送 T00，应答 SN 直接复用原消息 SN。
  void _sendReply(ZrdStumMessage message, String result) {
    final serialNumber = message.serialNumber;
    if (!_protocolClient.isConnected || serialNumber == null) {
      return;
    }
    _write(
      ZrdStumProtocolCodec.encodeTerminalReply(
        serverCommandCode: message.commandCode,
        result: result,
        serialNumber: serialNumber,
      ),
    );
  }

  /// 只发送 ASCII 协议数据，不在日志中输出 ID、IM 或带查询参数的 URL。
  ///
  /// 返回 false 表示入队前已同步发现断线；异步 flush 失败仍由本方法统一触发重连。
  bool _write(String message) {
    final generation = _generation;
    try {
      final write = _protocolClient.send(ascii.encode(message));
      unawaited(
        write.catchError((Object error, StackTrace stackTrace) {
          if (_isGenerationActive(generation)) {
            AppLogger.error('Flush STUM message failed', error, stackTrace);
            _handleConnectionLost(generation);
          }
        }),
      );
      return true;
    } catch (error, stackTrace) {
      if (_isGenerationActive(generation)) {
        AppLogger.error('Flush STUM message failed', error, stackTrace);
        _handleConnectionLost(generation);
      }
      return false;
    }
  }

  /// 收敛当前连接并按指数退避安排下一次登录。
  void _handleConnectionLost(int generation) {
    if (!_isGenerationActive(generation)) {
      return;
    }
    if (_reconnectTimer != null && !_protocolClient.isConnected) {
      return;
    }
    unawaited(_closeConnection());
    _emit(
      _current.copyWith(
        phase: TerminalUpgradePhase.disconnected,
        message: const TerminalUpgradeMessage(
          TerminalUpgradeMessageCode.connectionInterruptedRetrying,
        ),
        clearErrorMessage: true,
      ),
    );
    _scheduleReconnect(generation);
  }

  /// 安排一次有上限的指数退避重连。
  void _scheduleReconnect(int generation) {
    if (!_isGenerationActive(generation) || _reconnectTimer != null) {
      return;
    }
    final multiplier = 1 << _reconnectAttempt.clamp(0, 6).toInt();
    final calculated = Duration(
      milliseconds: initialReconnectDelay.inMilliseconds * multiplier,
    );
    final delay = calculated > maximumReconnectDelay
        ? maximumReconnectDelay
        : calculated;
    _reconnectAttempt += 1;
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      unawaited(_connect(generation));
    });
  }

  /// 关闭当前 Socket，并清除只属于本次连接的 SN 与残帧。
  Future<void> _closeConnection() async {
    final upgradeCheckTimer = _upgradeCheckTimer;
    _upgradeCheckTimer = null;
    upgradeCheckTimer?.cancel();
    _authenticated = false;
    _connecting = false;
    _loginSerialNumber = null;
    _upgradeRequestSerialNumber = null;
    _awaitingOffer = false;
    await _protocolClient.disconnect();
  }

  /// 发布一份完整不可变快照。
  void _emit(TerminalUpgradeSnapshot snapshot) {
    if (_disposed) {
      return;
    }
    _current = snapshot;
    _statesController.add(snapshot);
  }

  /// 发布失败快照，并按调用场景决定是否保留待安装升级包。
  void _emitFailure(
    TerminalUpgradeMessage message, {
    bool preserveOffer = false,
  }) {
    _emit(
      _current.copyWith(
        phase: TerminalUpgradePhase.failed,
        clearMessage: true,
        errorMessage: message,
        clearOffer: !preserveOffer,
      ),
    );
  }

  /// 验证下载/校验仍属于当前启用配置和同一份升级任务。
  void _assertInstallOperationActive({
    required int generation,
    required String offerIdentity,
    required String maintenanceLeaseId,
  }) {
    if (!_isInstallOperationActive(
      generation: generation,
      offerIdentity: offerIdentity,
      maintenanceLeaseId: maintenanceLeaseId,
    )) {
      throw const TerminalUpgradeOperationException(
        TerminalUpgradeMessage(TerminalUpgradeMessageCode.operationCancelled),
      );
    }
  }

  /// 判断下载、校验与原生提交是否仍属于当前配置和同一维护租约。
  bool _isInstallOperationActive({
    required int generation,
    required String offerIdentity,
    required String maintenanceLeaseId,
  }) {
    return _isGenerationActive(generation) &&
        _installing &&
        _current.offer?.identityKey == offerIdentity &&
        _doorGuard.holdsMaintenance(maintenanceLeaseId);
  }

  /// 应用一份已经通过代际检查的原生安装状态。
  ///
  /// 活动态会恢复或接管升级维护租约；只有明确终态才能释放。这样进程重建不会
  /// 过早允许开门，安装失败且应用未重启时也会由自动轮询及时解除维护。
  void _applyInstallStatus(
    TerminalInstallStatus status,
    TerminalAppVersion version, {
    required int generation,
    bool initialRead = false,
  }) {
    final terminal = _isTerminalInstallState(status.state);
    final active =
        _isActiveInstallState(status.state) ||
        (_nativeInstallActive && !terminal);
    _nativeInstallActive = active;

    if (active) {
      final maintenanceRestored = _ensureMaintenanceForActiveInstall(status);
      _emit(
        _current.copyWith(
          phase: TerminalUpgradePhase.awaitingRestart,
          currentVersion: version.name,
          message: TerminalUpgradeMessage(
            status.state == 'pending_user_action'
                ? TerminalUpgradeMessageCode.awaitingUserConfirmation
                : TerminalUpgradeMessageCode.awaitingSystemInstall,
          ),
          errorMessage: !maintenanceRestored
              ? const TerminalUpgradeMessage(
                  TerminalUpgradeMessageCode.maintenanceRestoreFailed,
                )
              : status.confirmationLaunchFailed
              ? const TerminalUpgradeMessage(
                  TerminalUpgradeMessageCode.confirmationLaunchFailed,
                )
              : status.diagnosticCode == 'confirmation_recovery_schedule_failed'
              ? const TerminalUpgradeMessage(
                  TerminalUpgradeMessageCode.confirmationRecoveryFailed,
                )
              : null,
          clearErrorMessage:
              maintenanceRestored &&
              !status.confirmationLaunchFailed &&
              status.diagnosticCode != 'confirmation_recovery_schedule_failed',
          installStatus: status,
        ),
      );
      _scheduleInstallStatusPoll(generation);
      return;
    }

    _installStatusPollTimer?.cancel();
    _installStatusPollTimer = null;
    _releaseMaintenanceForTerminalStatus(status);
    if (status.state == 'success') {
      _emit(
        _current.copyWith(
          phase: TerminalUpgradePhase.upToDate,
          currentVersion: version.name,
          message: TerminalUpgradeMessage(
            TerminalUpgradeMessageCode.installSucceeded,
            arguments: <String, String>{'version': version.name},
          ),
          clearErrorMessage: true,
          installStatus: status,
          clearOffer: true,
        ),
      );
      return;
    }
    if (status.state == 'failed' || status.state == 'failure') {
      _emit(
        _current.copyWith(
          phase: TerminalUpgradePhase.failed,
          currentVersion: version.name,
          clearMessage: true,
          errorMessage: TerminalUpgradeMessage(
            _installFailureMessageCode(status),
          ),
          installStatus: status,
        ),
      );
      return;
    }
    if (initialRead) {
      _emit(
        TerminalUpgradeSnapshot(
          phase: TerminalUpgradePhase.disconnected,
          currentVersion: version.name,
          message: const TerminalUpgradeMessage(
            TerminalUpgradeMessageCode.monitoringReady,
          ),
          installStatus: status,
        ),
      );
      return;
    }
    _emit(
      _current.copyWith(currentVersion: version.name, installStatus: status),
    );
  }

  /// 为进程重建后仍在进行的安装恢复升级维护租约。
  bool _ensureMaintenanceForActiveInstall(TerminalInstallStatus status) {
    final heldLeaseId = _maintenanceLeaseId;
    if (heldLeaseId != null && _doorGuard.holdsMaintenance(heldLeaseId)) {
      return true;
    }
    _maintenanceLeaseId = null;

    // 同一进程内 Repository 被替换时接管旧升级租约，避免产生无人能释放的锁。
    final existingLeaseId = _doorGuard.maintenanceOperationId;
    if (existingLeaseId != null &&
        existingLeaseId.startsWith('terminal-upgrade:')) {
      _maintenanceLeaseId = existingLeaseId;
      return true;
    }

    final restoredLeaseId = 'terminal-upgrade:restore:${status.sessionId ?? 0}';
    if (!_doorGuard.tryAcquireMaintenance(restoredLeaseId)) {
      return false;
    }
    _maintenanceLeaseId = restoredLeaseId;
    return true;
  }

  /// 安排单飞原生状态轮询；活动状态可长期等待用户确认，但不会并发读取。
  void _scheduleInstallStatusPoll(int generation) {
    if (!_isGenerationCurrent(generation) ||
        !_nativeInstallActive ||
        _installStatusPollTimer != null) {
      return;
    }
    _installStatusPollTimer = Timer(installStatusPollInterval, () {
      _installStatusPollTimer = null;
      unawaited(_refreshInstallStatus(generation, automatic: true));
    });
  }

  /// 等待正在取消的下载或原生提交跨过其最终清理边界。
  Future<void> _waitForInstallOperationToSettle() async {
    final completer = _installOperationCompleter;
    if (completer != null) {
      await completer.future;
    }
  }

  /// 通知 Android 取消已经进入原生层、但尚未 commit 的同一提交操作。
  Future<void> _cancelUncommittedNativeSubmission() async {
    final operationId = _nativeSubmissionOperationId;
    if (operationId == null) {
      return;
    }
    try {
      await _device.cancelInstall(operationId);
    } catch (error, stackTrace) {
      // 无法确认是否跨过 commit 时继续保留维护租约，并由原生状态对账决定终态。
      AppLogger.error(
        'Cancel terminal upgrade native submission failed',
        error,
        stackTrace,
      );
    }
  }

  /// 判断迟到 S03 是否为当前已确认帧的精确重传。
  bool _isCurrentOfferRetransmission(ZrdStumMessage message) {
    final offer = _current.offer;
    return offer != null &&
        message.serialNumber == offer.serialNumber &&
        message.segments['VE']?.trim() == offer.targetVersion &&
        message.segments['AD']?.trim() == offer.downloadUrl.toString() &&
        message.segments['MD']?.trim().toLowerCase() ==
            offer.md5.toLowerCase() &&
        (message.segments['PT']?.trim() ?? '') == offer.packageTag;
  }

  /// 未提交安装时释放维护租约；提交后只在 Android 返回终态时释放。
  void _releaseMaintenanceLease(String leaseId) {
    _doorGuard.releaseMaintenance(leaseId);
    if (_maintenanceLeaseId == leaseId) {
      _maintenanceLeaseId = null;
    }
  }

  /// 仅在原生明确报告 idle、成功或失败时释放当前升级维护租约。
  void _releaseMaintenanceForTerminalStatus(TerminalInstallStatus status) {
    if (!_isTerminalInstallState(status.state)) {
      return;
    }
    final leaseId = _maintenanceLeaseId ?? _doorGuard.maintenanceOperationId;
    if (leaseId != null && leaseId.startsWith('terminal-upgrade:')) {
      _releaseMaintenanceLease(leaseId);
    }
  }

  /// 当前代际是否仍存在；安装状态轮询在监控关闭后也需要继续收敛。
  bool _isGenerationCurrent(int generation) {
    return !_disposed && generation == _generation;
  }

  /// 当前代际是否仍处于启用监控状态。
  bool _isGenerationActive(int generation) {
    return _started && _isGenerationCurrent(generation);
  }

  /// 拒绝在 Repository 生命周期结束后继续调用公开操作。
  void _ensureNotDisposed() {
    if (_disposed) {
      throw const TerminalUpgradeOperationException(
        TerminalUpgradeMessage(TerminalUpgradeMessageCode.repositoryDisposed),
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _started = false;
    _disposed = true;
    _identityLoadSequence += 1;
    _generation += 1;
    _installStatusReadSequence += 1;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _installStatusPollTimer?.cancel();
    _installStatusPollTimer = null;
    _loginIdentity = null;
    _downloadCancellationToken?.cancel();
    await _cancelUncommittedNativeSubmission();
    await _waitForInstallOperationToSettle();
    await _closeConnection();
    await _protocolMessagesSubscription.cancel();
    await _protocolClient.dispose();
    if (!_nativeInstallActive) {
      final leaseId = _maintenanceLeaseId;
      if (leaseId != null) {
        _releaseMaintenanceLease(leaseId);
      }
    }
    await _statesController.close();
  }
}

/// 把 STUM 上行 ASCII 帧解析为安全日志结构。
Object? _formatStumOutboundLog(List<int> bytes) {
  final frame = ascii.decode(bytes, allowInvalid: false).trim();
  return _formatStumMessageForLog(ZrdStumProtocolCodec.decode(frame));
}

/// 把 STUM 下行消息转换为安全日志结构。
Object? _formatStumInboundLog(ZrdStumMessage message) {
  return _formatStumMessageForLog(message);
}

/// 隐藏 STUM 终端标识、IMEI、芯片标识和下载地址查询参数。
Map<String, Object?> _formatStumMessageForLog(ZrdStumMessage message) {
  final safeSegments = <String, Object?>{};
  for (final entry in message.segments.entries) {
    final key = entry.key.toUpperCase();
    safeSegments[key] = switch (key) {
      'ID' || 'IM' || 'CD' || 'DP' => '<已脱敏>',
      'AD' => _sanitizeStumAddress(entry.value),
      'SN' ||
      'DT' ||
      'VE' ||
      'PT' ||
      'MD' => _sanitizeStumKnownValue(key, entry.value),
      _ when _stumNumericReplyKey.hasMatch(key) => _sanitizeStumReplyValue(
        entry.value,
      ),
      _ => '<未公开属性已省略>',
    };
  }
  final prefix = message.direction == ZrdStumDirection.terminal ? 'T' : 'S';
  return <String, Object?>{
    'protocol': 'ZRD STUM',
    'keyword': '$prefix${message.commandCode}',
    if (message.serialNumber != null) 'serialNumber': message.serialNumber,
    'segments': safeSegments,
  };
}

/// STUM 两位数字应答属性只承载协议结果，不公开任意扩展属性值。
final RegExp _stumNumericReplyKey = RegExp(r'^\d{2}$');

/// 对协议允许公开的字段继续校验格式，避免服务端把任意文本伪装成已知属性。
String _sanitizeStumKnownValue(String key, String value) {
  final valid = switch (key) {
    'SN' =>
      RegExp(r'^[0-9]{1,4}$').hasMatch(value) &&
          (int.tryParse(value) ?? 0) >= 1,
    'DT' => value == '1',
    'VE' => RegExp(
      r'^(?:V?[0-9]|SL_(?:APP_)?V[0-9])[0-9A-Za-z._-]{0,63}$',
    ).hasMatch(value),
    'PT' => RegExp(r'^[0-9A-Za-z._-]{0,32}$').hasMatch(value),
    'MD' => RegExp(r'^[0-9A-Fa-f]{32}$').hasMatch(value),
    _ => false,
  };
  return valid ? value : '<非法属性值已省略>';
}

/// 仅公开 STUM 当前定义的 OK/NG 应答值。
String _sanitizeStumReplyValue(String value) {
  final valid =
      value == 'OK' || RegExp(r'^NG[0-9A-Z](?:[A-Z]{2})?$').hasMatch(value);
  return valid ? value : '<非法应答已省略>';
}

/// 仅保留升级包地址的 scheme、host 和显式 port，路径及参数全部省略。
String _sanitizeStumAddress(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return '<无效地址已省略>';
  }
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  ).toString();
}

/// 为同一 Android 进程内可能重建的 Dart Repository 生成不重复的安装命名空间。
///
/// Android 会保留有界的完成/取消历史来隔离迟到调用；仅使用代际和本地序号会在
/// Flutter Engine 或 Provider 重建后复用旧 ID，使新任务无法被正确取消。
String _createOperationNonce() {
  final random = Random.secure();
  final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final entropy = random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0');
  return '$timestamp-$entropy';
}

/// 原生安装仍可能写入系统或等待管理员确认的活动状态。
bool _isActiveInstallState(String state) {
  return state == 'validating' ||
      state == 'submitting' ||
      state == 'submitted' ||
      state == 'pending_user_action';
}

/// 允许安全释放升级维护租约的原生终态。
bool _isTerminalInstallState(String state) {
  return state == 'idle' ||
      state == 'success' ||
      state == 'failed' ||
      state == 'failure';
}

/// 把原生稳定诊断码收敛为与界面语言无关的升级消息。
TerminalUpgradeMessageCode _installFailureMessageCode(
  TerminalInstallStatus status,
) {
  return switch (status.diagnosticCode) {
    'validation_failed' => TerminalUpgradeMessageCode.installValidationFailed,
    'session_submission_failed' =>
      TerminalUpgradeMessageCode.installSubmissionFailed,
    'session_missing' => TerminalUpgradeMessageCode.installSessionMissing,
    'stale_uncommitted_session' || 'stale_committed_session' =>
      TerminalUpgradeMessageCode.installSessionExpired,
    'confirmation_launch_failed' =>
      TerminalUpgradeMessageCode.confirmationLaunchFailed,
    'confirmation_recovery_schedule_failed' =>
      TerminalUpgradeMessageCode.confirmationRecoveryFailed,
    'confirmation_timeout' => TerminalUpgradeMessageCode.confirmationTimedOut,
    'package_installer_failure' =>
      TerminalUpgradeMessageCode.packageInstallerFailed,
    _ =>
      status.message.isEmpty
          ? TerminalUpgradeMessageCode.installerReasonUnavailable
          : TerminalUpgradeMessageCode.installFailed,
  };
}

/// 只把原生或外部运行时返回的动态诊断交给展示层。
///
/// Repository 自身的结构化业务异常、下载器固定提示和通道契约校验错误均由
/// [TerminalUpgradeMessageCode] 表达，避免它们绕过四语言映射直接显示。
String _externalErrorDetail(Object error) {
  if (error is TerminalUpgradeOperationException ||
      error is TerminalUpgradeDownloadException ||
      error is StateError) {
    return '';
  }
  return '$error';
}

/// 校验 Repository 定时器参数，避免负时长退化为立即重试或忙轮询。
void _validatePositiveDuration(Duration duration, String name) {
  if (duration <= Duration.zero) {
    throw ArgumentError.value(duration, name, '时间必须大于 0');
  }
}
