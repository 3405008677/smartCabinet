/// 终端升级连接与处理阶段。
enum TerminalUpgradePhase {
  /// 尚未启用升级监控。
  disabled,

  /// 已启用但当前未连接。
  disconnected,

  /// 正在连接升级服务端。
  connecting,

  /// TCP 已连接，正在等待 T01 登录应答。
  authenticating,

  /// 已登录，正在等待升级检查结果。
  checking,

  /// 服务端当前没有可下发的升级包。
  ///
  /// 该状态对应协议 `S03.VE=0`，只能说明本次任务没有匹配到升级包，
  /// 不能据此断言客户端版本一定是平台上的最新版本。
  upToDate,

  /// 服务端提供了可安装的 URL 升级包。
  updateAvailable,

  /// 正在下载升级包。
  downloading,

  /// 正在校验升级包 MD5。
  verifying,

  /// 正在把升级包提交给 Android PackageInstaller。
  installing,

  /// 安装任务已经提交，等待系统完成安装并重启应用。
  awaitingRestart,

  /// 当前操作失败，可由管理员修正配置或重试。
  failed,
}

/// 升级流程交给展示层解析的稳定消息码。
///
/// Domain 与 Data 层只传递消息语义、占位参数和外部动态详情，不直接决定界面
/// 使用哪种语言。展示层必须为每个枚举值提供完整的四语言映射。
enum TerminalUpgradeMessageCode {
  /// 升级服务地址为空。
  settingsHostRequired,

  /// 升级服务端口超出有效范围。
  settingsPortInvalid,

  /// 终端 ID 不符合协议长度或首位要求。
  settingsTerminalIdInvalid,

  /// STUM 模块标识不符合现场兼容长度要求。
  settingsModuleIdInvalid,

  /// STUM 数据通讯地址为空或包含非法协议字符。
  settingsDataProtocolIpInvalid,

  /// “关于设备”的唯一设备 ID 不能作为 STUM CD 使用。
  settingsChipIdInvalid,

  /// 可选协议字段包含不安全字符。
  settingsProtocolValueInvalid,

  /// 升级监控当前未启用。
  monitoringDisabled,

  /// 已启用监控，准备建立服务连接。
  monitoringReady,

  /// 正在连接升级服务端。
  connectingServer,

  /// 已连接，正在验证终端身份。
  authenticatingTerminal,

  /// 正在检查新版本。
  checkingVersion,

  /// 服务端已经接收升级检查请求。
  checkRequestAccepted,

  /// 服务端以 `S03.VE=0` 表示当前没有可下发升级包。
  alreadyLatest,

  /// 发现指定目标版本，等待管理员确认。
  updateAvailable,

  /// 正在下载指定目标版本。
  downloadingVersion,

  /// 升级包完整性校验已经通过。
  checksumVerified,

  /// 正在向 Android 提交安装会话。
  submittingInstaller,

  /// 安装会话已经提交。
  installSessionSubmitted,

  /// 系统安装器正在等待管理员确认。
  awaitingUserConfirmation,

  /// 系统正在继续处理安装。
  awaitingSystemInstall,

  /// 终端已经成功升级到指定版本。
  installSucceeded,

  /// 连接已经中断，Repository 将自动重连。
  connectionInterruptedRetrying,

  /// 无法读取当前应用版本或初始安装状态。
  readAppVersionFailed,

  /// 手工操作前尚未保存并启用监控。
  monitoringNotEnabled,

  /// 下载或校验进行中，不能重复检查。
  checkBlockedByDownload,

  /// 系统安装仍在进行，不能发起新的检查或安装。
  installAlreadyActive,

  /// 当前没有可以安装的升级包。
  noInstallableOffer,

  /// 安装入口没有携带本次管理员明确确认。
  administratorConfirmationRequired,

  /// 管理员确认后待安装升级包已经发生变化。
  confirmedOfferChanged,

  /// 当前已有待管理员处理的升级包，不能被后台检查替换。
  pendingOfferRequiresDecision,

  /// 柜门尚未全部确认关闭。
  doorsNotClosed,

  /// 柜门或其他维护操作占用了设备。
  maintenanceUnavailable,

  /// 下载期间柜门状态发生变化。
  doorsChangedDuringDownload,

  /// 下载、校验或原生提交安装失败。
  installFailed,

  /// 无法读取系统安装状态。
  readInstallStatusFailed,

  /// 服务端拒绝终端登录。
  serverLoginRejected,

  /// 无法连接升级服务端。
  connectFailed,

  /// 服务端拒绝升级检查请求。
  serverCheckRejected,

  /// 服务端升级包未通过协议校验。
  offerRejected,

  /// 等待升级检查结果超时。
  checkTimedOut,

  /// 活动安装无法恢复柜门维护租约。
  maintenanceRestoreFailed,

  /// 系统安装确认页未能打开。
  confirmationLaunchFailed,

  /// 系统安装器没有提供失败原因。
  installerReasonUnavailable,

  /// 当前升级操作已经取消。
  operationCancelled,

  /// Repository 生命周期已经结束。
  repositoryDisposed,

  /// Android 在校验升级包时拒绝安装。
  installValidationFailed,

  /// Android 创建或提交安装会话失败。
  installSubmissionFailed,

  /// 持久化安装记录对应的系统会话已经不存在。
  installSessionMissing,

  /// 安装会话已陈旧并被安全终止。
  installSessionExpired,

  /// 安装确认超时恢复任务无法调度。
  confirmationRecoveryFailed,

  /// 等待管理员确认安装超时。
  confirmationTimedOut,

  /// Android PackageInstaller 返回安装失败。
  packageInstallerFailed,
}

/// 一条与界面语言无关的升级流程消息。
final class TerminalUpgradeMessage {
  /// 创建结构化升级消息。
  const TerminalUpgradeMessage(
    this.code, {
    this.arguments = const <String, String>{},
    this.detail = '',
  });

  /// 固定业务语义，由展示层映射本地化文案。
  final TerminalUpgradeMessageCode code;

  /// 替换本地化模板中 `{name}` 占位符的非敏感参数。
  final Map<String, String> arguments;

  /// 原生系统或服务端返回的动态诊断详情；为空表示没有外部详情。
  final String detail;
}

/// 公开升级操作因可预期业务条件被拒绝。
final class TerminalUpgradeOperationException implements Exception {
  /// 创建携带结构化失败原因的操作异常。
  const TerminalUpgradeOperationException(this.reason);

  /// 可由展示层按当前语言解析的失败原因。
  final TerminalUpgradeMessage reason;

  @override
  String toString() {
    final detail = reason.detail.trim();
    return detail.isEmpty ? reason.code.name : '${reason.code.name}: $detail';
  }
}

/// ZRD STUM 协议连接配置。
class TerminalUpgradeSettings {
  /// 创建一份终端升级配置。
  const TerminalUpgradeSettings({
    this.enabled = false,
    this.host = '',
    this.port = 0,
    this.terminalId = '',
    this.packageTag = '',
  });

  /// 是否在应用启动后连接升级监控服务。
  final bool enabled;

  /// 升级监控服务主机名或 IP。
  final String host;

  /// 升级监控服务 TCP 端口。
  final int port;

  /// T01 的 ID，协议要求为非零开头的 11 位或 15 位数字。
  final String terminalId;

  /// 一机多包场景使用的 PT；为空表示当前平台未启用包标记。
  final String packageTag;

  /// 从本地 JSON 配置恢复升级参数。
  factory TerminalUpgradeSettings.fromJson(
    Map<String, Object?> json, {
    String defaultHost = '',
    int defaultPort = 0,
  }) {
    final storedHost = json['host']?.toString().trim() ?? '';
    final storedPortText = json['port']?.toString().trim() ?? '';
    final storedPort = int.tryParse(storedPortText);
    return TerminalUpgradeSettings(
      enabled: json['enabled'] == true,
      // 兼容旧版本落盘的空地址；非空现场配置继续优先于应用默认值。
      host: storedHost.isEmpty ? defaultHost : storedHost,
      port: storedPortText.isEmpty || storedPort == 0
          ? defaultPort
          : storedPort ?? 0,
      terminalId: json['terminalId']?.toString() ?? '',
      packageTag: json['packageTag']?.toString() ?? '',
    );
  }

  /// 转成可持久化的本地 JSON Map。
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'enabled': enabled,
      'host': host.trim(),
      'port': port,
      'terminalId': terminalId.trim(),
      'packageTag': packageTag.trim(),
    };
  }

  /// 返回第一个不符合协议的结构化校验码；全部有效时返回 null。
  TerminalUpgradeMessageCode? validate() {
    if (host.trim().isEmpty) {
      return TerminalUpgradeMessageCode.settingsHostRequired;
    }
    if (port < 1 || port > 65535) {
      return TerminalUpgradeMessageCode.settingsPortInvalid;
    }
    if (!RegExp(r'^(?:[1-9]\d{10}|[1-9]\d{14})$').hasMatch(terminalId.trim())) {
      return TerminalUpgradeMessageCode.settingsTerminalIdInvalid;
    }
    if (!_isProtocolValue(packageTag)) {
      return TerminalUpgradeMessageCode.settingsProtocolValueInvalid;
    }
    return null;
  }

  /// 复制配置并覆盖指定字段。
  TerminalUpgradeSettings copyWith({
    bool? enabled,
    String? host,
    int? port,
    String? terminalId,
    String? packageTag,
  }) {
    return TerminalUpgradeSettings(
      enabled: enabled ?? this.enabled,
      host: host ?? this.host,
      port: port ?? this.port,
      terminalId: terminalId ?? this.terminalId,
      packageTag: packageTag ?? this.packageTag,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TerminalUpgradeSettings &&
        other.enabled == enabled &&
        other.host == host &&
        other.port == port &&
        other.terminalId == terminalId &&
        other.packageTag == packageTag;
  }

  @override
  int get hashCode => Object.hash(enabled, host, port, terminalId, packageTag);
}

/// 单次 STUM 监控代际绑定的登录身份。
///
/// IM 和 DP 来自 `AppConfig` 的构建配置，CD 来自“关于设备”展示的唯一设备
/// ID。三者都不属于管理员可编辑或本地持久化的升级设置。
final class TerminalUpgradeLoginIdentity {
  /// 创建一份不可变登录身份快照。
  const TerminalUpgradeLoginIdentity({
    required this.moduleId,
    required this.dataProtocolIp,
    required this.chipId,
  });

  /// T01.IM；现场服务兼容非零开头的 11 位或 15 位数字。
  final String moduleId;

  /// T01.DP；服务端登记的数据通讯地址，而非当前局域网地址。
  final String dataProtocolIp;

  /// T01.CD；按现场约定使用 Android “关于设备”的唯一设备 ID。
  final String chipId;

  /// 返回第一个身份配置错误；全部可编码时返回 null。
  TerminalUpgradeMessageCode? validate() {
    if (!RegExp(r'^(?:[1-9]\d{10}|[1-9]\d{14})$').hasMatch(moduleId.trim())) {
      return TerminalUpgradeMessageCode.settingsModuleIdInvalid;
    }
    final normalizedDataProtocolIp = dataProtocolIp.trim();
    if (normalizedDataProtocolIp != dataProtocolIp ||
        !_isIpv4List(normalizedDataProtocolIp)) {
      return TerminalUpgradeMessageCode.settingsDataProtocolIpInvalid;
    }
    final normalizedChipId = chipId.trim();
    if (normalizedChipId.isEmpty ||
        normalizedChipId == '未知' ||
        normalizedChipId.toLowerCase() == 'unknown' ||
        !_isProtocolValue(normalizedChipId)) {
      return TerminalUpgradeMessageCode.settingsChipIdInvalid;
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    return other is TerminalUpgradeLoginIdentity &&
        other.moduleId == moduleId &&
        other.dataProtocolIp == dataProtocolIp &&
        other.chipId == chipId;
  }

  @override
  int get hashCode => Object.hash(moduleId, dataProtocolIp, chipId);
}

/// 服务端 S03 下发的 URL 升级包信息。
class TerminalUpgradeOffer {
  /// 创建升级包信息。
  const TerminalUpgradeOffer({
    required this.targetVersion,
    required this.downloadUrl,
    required this.md5,
    required this.packageTag,
    required this.serialNumber,
  });

  /// 服务端 VE 目标版本标记。
  final String targetVersion;

  /// 服务端 AD 下载地址。
  final Uri downloadUrl;

  /// 服务端 MD 文件完整性校验值。
  final String md5;

  /// 服务端返回的一机多包 PT 标记。
  final String packageTag;

  /// 服务端 S03 的 SN，用于应答和幂等识别。
  final int serialNumber;

  /// 不包含 URL 查询参数的安全展示地址。
  String get safeDownloadAddress => '${downloadUrl.origin}${downloadUrl.path}';

  /// 用于识别服务端重复下发同一升级任务的稳定键。
  String get identityKey => '$targetVersion|$packageTag|$md5|$downloadUrl';
}

/// Android 当前应用版本。
class TerminalAppVersion {
  /// 创建应用版本信息。
  const TerminalAppVersion({required this.name, required this.code});

  /// Android versionName；T03 会按现场约定包装为 `SL_V版本_yyyyMMdd`。
  final String name;

  /// Android versionCode，用于原生安装防降级校验。
  final int code;
}

/// Android PackageInstaller 的最近状态。
class TerminalInstallStatus {
  /// 创建安装状态。
  const TerminalInstallStatus({
    required this.state,
    this.message = '',
    this.sessionId,
    this.targetVersion = '',
    this.silentInstallRequested = false,
    this.requiresUserAction = false,
    this.confirmationLaunchFailed = false,
    this.diagnosticCode = '',
  });

  /// 原生状态：idle、submitted、pending_user_action、success 或 failure/failed。
  final String state;

  /// 系统安装器返回的安全动态详情；固定业务文案不得放入该字段。
  final String message;

  /// PackageInstaller 会话 ID。
  final int? sessionId;

  /// 会话关联的目标版本。
  final String targetVersion;

  /// 原生层是否向系统请求了无交互安装。
  final bool silentInstallRequested;

  /// 系统是否要求管理员确认安装。
  final bool requiresUserAction;

  /// 系统确认页是否因后台或 Kiosk 限制未能打开。
  final bool confirmationLaunchFailed;

  /// 原生安装器持久化的稳定诊断码；固定文案由展示层按此码本地化。
  final String diagnosticCode;
}

/// 提交给 Android PackageInstaller 后的结果。
class TerminalInstallSubmission {
  /// 创建安装提交结果。
  const TerminalInstallSubmission({
    required this.sessionId,
    required this.state,
  });

  /// PackageInstaller 会话 ID。
  final int sessionId;

  /// 原生提交状态。
  final String state;
}

/// 升级流程对 UI 暴露的不可变快照。
class TerminalUpgradeSnapshot {
  /// 创建升级状态快照。
  const TerminalUpgradeSnapshot({
    this.phase = TerminalUpgradePhase.disabled,
    this.currentVersion = '',
    this.message,
    this.errorMessage,
    this.downloadedBytes = 0,
    this.totalBytes,
    this.offer,
    this.installStatus,
  });

  /// 当前升级阶段。
  final TerminalUpgradePhase phase;

  /// 当前真实 Android 应用版本。
  final String currentVersion;

  /// 展示层按当前语言解析的流程说明。
  final TerminalUpgradeMessage? message;

  /// 展示层按当前语言解析的最近一次失败原因。
  final TerminalUpgradeMessage? errorMessage;

  /// 已下载字节数。
  final int downloadedBytes;

  /// 服务端声明的总字节数；未知时为 null。
  final int? totalBytes;

  /// 当前待管理员确认安装的升级包。
  final TerminalUpgradeOffer? offer;

  /// Android 安装器最近状态。
  final TerminalInstallStatus? installStatus;

  /// 下载百分比；服务端未提供总长度时返回 null。
  double? get downloadProgress {
    final total = totalBytes;
    if (total == null || total <= 0) {
      return null;
    }
    return (downloadedBytes / total).clamp(0, 1).toDouble();
  }

  /// 当前是否正在执行不可重复提交的升级动作。
  bool get busy => switch (phase) {
    TerminalUpgradePhase.connecting ||
    TerminalUpgradePhase.authenticating ||
    TerminalUpgradePhase.checking ||
    TerminalUpgradePhase.downloading ||
    TerminalUpgradePhase.verifying ||
    TerminalUpgradePhase.installing => true,
    _ => false,
  };

  /// 复制状态并精确控制可空字段是否清除。
  TerminalUpgradeSnapshot copyWith({
    TerminalUpgradePhase? phase,
    String? currentVersion,
    TerminalUpgradeMessage? message,
    bool clearMessage = false,
    TerminalUpgradeMessage? errorMessage,
    bool clearErrorMessage = false,
    int? downloadedBytes,
    int? totalBytes,
    bool clearTotalBytes = false,
    TerminalUpgradeOffer? offer,
    bool clearOffer = false,
    TerminalInstallStatus? installStatus,
  }) {
    return TerminalUpgradeSnapshot(
      phase: phase ?? this.phase,
      currentVersion: currentVersion ?? this.currentVersion,
      message: clearMessage ? null : message ?? this.message,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: clearTotalBytes ? null : totalBytes ?? this.totalBytes,
      offer: clearOffer ? null : offer ?? this.offer,
      installStatus: installStatus ?? this.installStatus,
    );
  }
}

/// 检查可选协议值是否能安全放入 ASCII 键值段。
bool _isProtocolValue(String value) {
  return !value.contains('|') &&
      !value.contains('\r') &&
      !value.contains('\n') &&
      value.codeUnits.every((unit) => unit <= 0x7f);
}

/// 检查 DP 是否为一个或多个以英文逗号分隔的规范 IPv4 地址。
bool _isIpv4List(String value) {
  if (value.isEmpty) {
    return false;
  }
  return value.split(',').every(_isIpv4Address);
}

/// 检查单个 IPv4 地址的四段十进制数值和范围。
bool _isIpv4Address(String value) {
  final segments = value.split('.');
  if (segments.length != 4) {
    return false;
  }
  for (final segment in segments) {
    if (segment.isEmpty ||
        !RegExp(r'^\d{1,3}$').hasMatch(segment) ||
        segment.length > 1 && segment.startsWith('0')) {
      return false;
    }
    final octet = int.parse(segment);
    if (octet > 255) {
      return false;
    }
  }
  return true;
}
