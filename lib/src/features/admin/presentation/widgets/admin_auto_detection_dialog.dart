import 'dart:async';

import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/theme/app_theme.dart';
import 'package:smart_cabinet/src/core/camera/cabinet_camera.dart';
import 'package:smart_cabinet/src/features/admin/domain/entities/admin.dart';

/// 自动检测项的当前状态。
enum AdminDetectionState {
  /// 当前正在重新读取设备状态。
  checking,

  /// 设备已连接且状态正常。
  healthy,

  /// 设备未连接、不可用或检测失败。
  abnormal,

  /// 检测能力尚未接入。
  pending,
}

/// 自动检测列表的状态筛选条件。
enum _AdminDetectionFilter { all, healthy, abnormal, pending }

/// 自动恢复当前检测项时可执行的动作。
enum AdminDetectionRecoveryAction {
  /// 重新启动该摄像头的视频推流，并在完成后复检推流状态。
  retryStream,

  /// 不改变设备配置，仅重新读取该设备的真实状态。
  recheck,

  /// 当前系统尚未提供该设备的自动恢复接口。
  unsupported,
}

/// 根据管理员控制台已读取的状态创建当前自动检测项。
///
/// 初始清单包含 WiFi、RJ45、四路摄像头、NFC、指纹、柜控板和扫码器。
/// 后续检测能力可继续向返回列表追加，不需要调整弹窗布局。
List<AdminDetectionItem> buildAdminDetectionItems({
  required BuildContext context,
  required AdminDeviceStatus deviceStatus,
  required bool deviceStatusLoading,
  required String? deviceStatusError,
  required bool cameraConfigLoading,
  required String? cameraConfigError,
  required List<CabinetCameraDevice> availableCameras,
  required Map<CabinetCameraRole, CameraStreamCapability> cameraCapabilities,
  required Map<CabinetCameraRole, String> cameraCapabilityErrors,
  required Map<CabinetCameraRole, String> streamStatusErrors,
  CameraStreamStatus? outsideEnvironmentStreamStatus,
  CameraStreamStatus? operationAreaStreamStatus,
}) {
  final l10n = context.l10n;

  AdminDetectionItem item({
    required String id,
    required String title,
    required String result,
    required IconData icon,
    AdminDetectionState? state,
    AdminDetectionRecoveryAction recoveryAction =
        AdminDetectionRecoveryAction.recheck,
    bool? streamHealthy,
    String recoveryUnavailableReason = '',
  }) {
    return AdminDetectionItem(
      id: id,
      title: title,
      description: l10n
          .t('adminAutoDetectItemDescription', '检查 {name} 的连接状态与运行结果')
          .replaceAll('{name}', title),
      result: result,
      icon: icon,
      state: state ?? _detectionStateFor(result),
      recoveryAction: recoveryAction,
      streamHealthy: streamHealthy,
      recoveryUnavailableReason: recoveryUnavailableReason,
    );
  }

  AdminDetectionItem hardwareItem({
    required String id,
    required String title,
    required String value,
    required IconData icon,
  }) {
    if (deviceStatusLoading) {
      return item(
        id: id,
        title: title,
        result: l10n.t('adminAutoDetectCheckingResult', '正在读取设备状态...'),
        icon: icon,
        state: AdminDetectionState.checking,
      );
    }
    final error = deviceStatusError;
    if (error != null) {
      return item(
        id: id,
        title: title,
        result: l10n.t('adminDeviceStatusReadFailed', '硬件状态读取失败'),
        icon: icon,
        state: AdminDetectionState.abnormal,
      );
    }
    return item(
      id: id,
      title: title,
      result: localizedAdminDeviceStatus(l10n, value),
      icon: icon,
      state: _detectionStateFor(value),
    );
  }

  AdminDetectionItem cameraItem(CabinetCameraRole role) {
    final capability = cameraCapabilities[role];
    final capabilityError = cameraCapabilityErrors[role];
    final enumerated = _findConnectedCamera(availableCameras, role) != null;
    bool? connected;
    late final String connectionResult;
    late final AdminDetectionState connectionState;
    if (capability?.hasConnectionProbeError == true) {
      final code = capability!.errorCode.trim();
      connectionResult = code.isEmpty
          ? l10n.t('adminCameraConnectionProbeError', '连接检测异常')
          : l10n
                .t('adminCameraConnectionProbeErrorCode', '连接检测异常（{code}）')
                .replaceAll('{code}', code);
      connectionState = AdminDetectionState.abnormal;
    } else if (capability != null) {
      connected = capability.available;
      connectionResult = connected
          ? l10n.t('adminAutoDetectConnected', '连接成功')
          : l10n.t('adminAutoDetectDisconnected', '连接失败');
      connectionState = connected
          ? AdminDetectionState.healthy
          : AdminDetectionState.abnormal;
    } else if (capabilityError != null) {
      connectionResult = l10n.t('adminCameraDetectionFailed', '检测失败');
      connectionState = AdminDetectionState.abnormal;
    } else if (cameraConfigLoading) {
      connectionResult = l10n.t('adminAutoDetectCheckingResult', '正在读取设备状态...');
      connectionState = AdminDetectionState.checking;
    } else if (cameraConfigError != null && !enumerated) {
      connectionResult = l10n.t('adminCameraDetectionFailed', '检测失败');
      connectionState = AdminDetectionState.abnormal;
    } else {
      connected = enumerated;
      connectionResult = connected
          ? l10n.t('adminAutoDetectConnected', '连接成功')
          : l10n.t('adminAutoDetectDisconnected', '连接失败');
      connectionState = connected
          ? AdminDetectionState.healthy
          : AdminDetectionState.abnormal;
    }

    final streamStatus = switch (role) {
      CabinetCameraRole.outsideEnvironment => outsideEnvironmentStreamStatus,
      CabinetCameraRole.operationArea => operationAreaStreamStatus,
      _ => null,
    };
    final supportsNativeStream =
        CabinetCameraConfig.bindingFor(role).useMode ==
        CabinetCameraUseMode.rtspStream;
    final connectionSummary = l10n
        .t('adminCameraConnectionSummary', '设备连接：{status}')
        .replaceAll('{status}', connectionResult);
    final streamSummary = l10n
        .t('adminCameraStreamSummary', '视频推流：{status}')
        .replaceAll(
          '{status}',
          localizedAdminCameraStreamStatus(
            l10n,
            streamStatus,
            streamStatusErrors[role],
          ),
        );
    final result = supportsNativeStream
        ? '$connectionSummary\n$streamSummary'
        : connectionSummary;
    final canRetryStream =
        connected == true &&
        streamStatus?.needsUserAttention == true &&
        streamStatus!.enabledProfiles.isNotEmpty;
    final overallState =
        streamStatus?.needsUserAttention == true ||
            streamStatusErrors.containsKey(role)
        ? AdminDetectionState.abnormal
        : connectionState;

    return item(
      id: 'camera_${role.name}',
      title: _cameraRoleLabel(context, role),
      result: result,
      icon: Icons.video_camera_front_outlined,
      state: overallState,
      recoveryAction: canRetryStream
          ? AdminDetectionRecoveryAction.retryStream
          : AdminDetectionRecoveryAction.recheck,
      streamHealthy: supportsNativeStream
          ? streamStatus?.isStreaming == true
          : null,
    );
  }

  return [
    hardwareItem(
      id: 'wifi',
      title: l10n.t('adminDeviceWifi', '连接 WiFi'),
      value: deviceStatus.wifiName,
      icon: Icons.wifi_rounded,
    ),
    hardwareItem(
      id: 'rj45',
      title: l10n.t('adminDeviceRj45', 'RJ45连接'),
      value: deviceStatus.rj45Status,
      icon: Icons.settings_ethernet_rounded,
    ),
    for (final role in CabinetCameraRole.values) cameraItem(role),
    hardwareItem(
      id: 'nfc',
      title: l10n.t('adminDeviceNfc', 'NFC'),
      value: deviceStatus.nfcStatus,
      icon: Icons.contactless_rounded,
    ),
    hardwareItem(
      id: 'fingerprint',
      title: l10n.t('adminDeviceFingerprint', '指纹模块'),
      value: deviceStatus.fingerprintStatus,
      icon: Icons.fingerprint,
    ),
    item(
      id: 'cabinet_board',
      title: l10n.t('adminDeviceCabinetBoard', '柜控板'),
      result: l10n.t('adminAutoDetectPendingDriver', '待接入驱动与检测接口'),
      icon: Icons.developer_board,
      state: AdminDetectionState.pending,
      recoveryAction: AdminDetectionRecoveryAction.unsupported,
      recoveryUnavailableReason: l10n.t(
        'adminAutoDetectCabinetBoardRecoveryUnsupported',
        '系统尚未接入柜控板驱动与重连接口',
      ),
    ),
    item(
      id: 'scanner',
      title: l10n.t('adminDeviceScanner', '扫码器'),
      result: l10n.t('adminAutoDetectPendingDriver', '待接入驱动与检测接口'),
      icon: Icons.qr_code_scanner,
      state: AdminDetectionState.pending,
      recoveryAction: AdminDetectionRecoveryAction.unsupported,
      recoveryUnavailableReason: l10n.t(
        'adminAutoDetectScannerRecoveryUnsupported',
        '系统尚未接入扫码器驱动与重连接口',
      ),
    ),
  ];
}

/// 为自动检测弹窗生成独立于设备连接状态的推流摘要。
String localizedAdminCameraStreamStatus(
  AppLocalizations l10n,
  CameraStreamStatus? status,
  String? readError,
) {
  if (status == null) {
    return readError == null
        ? l10n.t('adminCameraStreamNotStarted', '未启动')
        : l10n.t('adminCameraStreamReadFailed', '状态读取失败');
  }
  if (status.isStreaming) {
    return status.profile.isEmpty
        ? l10n.t('adminCameraStreaming', '推流中')
        : l10n
              .t('adminCameraStreamingProfile', '{profile} 推流中')
              .replaceAll('{profile}', status.profile);
  }
  return switch (status.state) {
    CameraStreamState.starting => l10n.t('adminCameraStreamStarting', '启动中'),
    CameraStreamState.reconnecting =>
      status.reconnectAttempts > 0
          ? l10n
                .t('adminCameraStreamReconnectingAttempt', '自动重连中（第 {count} 次）')
                .replaceAll('{count}', '${status.reconnectAttempts}')
          : l10n.t('adminCameraStreamReconnecting', '自动重连中'),
    CameraStreamState.failed => l10n.t(
      'adminCameraStreamFailedSeeDetails',
      '推流失败（详见推流异常提示）',
    ),
    CameraStreamState.stopping => l10n.t('adminCameraStreamStopping', '停止中'),
    CameraStreamState.stopped => l10n.t('adminCameraStreamNotStarted', '未启动'),
    CameraStreamState.unconfigured => l10n.t('adminStatusNotConfigured', '未配置'),
    CameraStreamState.unknown =>
      status.needsUserAttention
          ? l10n.t('adminCameraStreamFailedSeeDetails', '推流失败（详见推流异常提示）')
          : l10n.t('adminCameraStreamUnknown', '状态未知'),
    CameraStreamState.streaming =>
      status.allProfilesStreaming == false
          ? l10n.t('adminCameraStreamStarting', '启动中')
          : l10n.t('adminCameraStreaming', '推流中'),
  };
}

/// 将领域层的稳定状态值转换为当前界面语言；动态设备名保持原样。
String localizedAdminDeviceStatus(AppLocalizations l10n, String value) {
  return switch (value.trim()) {
    '正在读取' => l10n.t('adminStatusReading', '正在读取'),
    '正在检测' => l10n.t('adminStatusDetecting', '正在检测'),
    '待接入' || '待配置' => l10n.t('adminStatusPending', '待接入'),
    '已连接' => l10n.t('adminStatusConnected', '已连接'),
    '未连接' => l10n.t('adminStatusDisconnected', '未连接'),
    '可用' => l10n.t('adminStatusAvailable', '可用'),
    '不可用' => l10n.t('adminStatusUnavailable', '不可用'),
    '未知设备' => l10n.t('adminStatusUnknownDevice', '未知设备'),
    '未配置' => l10n.t('adminStatusNotConfigured', '未配置'),
    '已连接 WiFi' => l10n.t('adminStatusWifiConnected', '已连接 WiFi'),
    _ => value,
  };
}

/// 避免把原生固定中文异常直接拼进其他语言界面。
String _localizedAdminOperationError(BuildContext context, Object error) {
  final l10n = context.l10n;
  if (error is AdminDetectionOperationException) {
    return error.message;
  }
  final raw = error
      .toString()
      .replaceFirst(RegExp(r'^(Bad state|Exception):\s*'), '')
      .trim();
  final containsCjk = RegExp(r'[\u3400-\u9fff\u3040-\u30ff]').hasMatch(raw);
  if (raw.isNotEmpty &&
      (!containsCjk || l10n.language == AppLanguage.simplifiedChinese)) {
    return raw;
  }
  return l10n.t('adminAutoDetectOperationFailedDetail', '设备操作未完成，请重试');
}

/// 将已有状态文案映射为统一的检测状态。
AdminDetectionState _detectionStateFor(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty ||
      normalized.contains('待接入') ||
      normalized.contains('待配置') ||
      normalized.contains('pending')) {
    return AdminDetectionState.pending;
  }
  if (normalized.contains('未连接') ||
      normalized.contains('不可用') ||
      normalized.contains('失败') ||
      normalized.contains('异常') ||
      normalized.contains('错误') ||
      normalized.contains('not connected') ||
      normalized.contains('unavailable') ||
      normalized.contains('failed') ||
      normalized.contains('error')) {
    return AdminDetectionState.abnormal;
  }
  return AdminDetectionState.healthy;
}

/// 获取四路业务摄像头的多语言名称。
String _cameraRoleLabel(BuildContext context, CabinetCameraRole role) {
  final l10n = context.l10n;
  return switch (role) {
    CabinetCameraRole.faceRecognition => l10n.t(
      'adminCameraFaceRecognition',
      '人脸识别摄像头',
    ),
    CabinetCameraRole.outsideEnvironment => l10n.t(
      'adminCameraOutsideEnvironment',
      '柜外环境摄像头',
    ),
    CabinetCameraRole.operationArea => l10n.t(
      'adminCameraOperationArea',
      '操作区摄像头',
    ),
    CabinetCameraRole.certificateCapture => l10n.t(
      'adminCameraCertificateCapture',
      '合格证采集摄像头',
    ),
  };
}

/// 查找指定业务角色已绑定且能被系统枚举到的摄像头。
CabinetCameraDevice? _findConnectedCamera(
  List<CabinetCameraDevice> availableCameras,
  CabinetCameraRole role,
) {
  final binding = CabinetCameraConfig.bindingFor(role);
  final boundCameraIds = switch (binding.useMode) {
    CabinetCameraUseMode.previewAndCapture ||
    CabinetCameraUseMode.stillCapture => _cameraIdAliases(
      binding.flutterCameraId,
    ),
    CabinetCameraUseMode.rtspStream => _cameraIdAliases(
      binding.androidCameraId,
    ),
  };
  for (final camera in availableCameras) {
    if (boundCameraIds.contains(camera.id)) {
      return camera;
    }
  }
  return null;
}

/// 兼容 Android Camera2 原生 ID 和 Flutter camera 插件包装 ID。
Set<String> _cameraIdAliases(String? cameraId) {
  final id = cameraId ?? '';
  if (id.isEmpty) {
    return const {};
  }
  if (id.startsWith('cameraId_')) {
    return {id, id.replaceFirst('cameraId_', '')};
  }
  return {id, CabinetCameraConfig.toFlutterCameraId(id)};
}

/// 管理员控制台中的单个自动检测项。
class AdminDetectionItem {
  /// 创建自动检测项。
  const AdminDetectionItem({
    required this.id,
    required this.title,
    required this.description,
    required this.result,
    required this.icon,
    required this.state,
    this.recoveryAction = AdminDetectionRecoveryAction.recheck,
    this.streamHealthy,
    this.recoveryUnavailableReason = '',
  });

  /// 稳定标识，后续新增检测项时用于保持当前选中项。
  final String id;

  /// 检测项名称。
  final String title;

  /// 检测范围说明。
  final String description;

  /// 最近一次检测结果。
  final String result;

  /// 检测项图标。
  final IconData icon;

  /// 当前检测状态。
  final AdminDetectionState state;

  /// 用户点击恢复按钮时应执行的动作。
  final AdminDetectionRecoveryAction recoveryAction;

  /// 最近一次复检是否确认视频流已经进入稳定推流状态。
  ///
  /// 仅用于 [AdminDetectionRecoveryAction.retryStream]。值为 `null` 或
  /// `false` 均表示尚未通过恢复复检，不能向用户提示重试成功。
  final bool? streamHealthy;

  /// 当前设备无法自动恢复时向管理员展示的原因。
  final String recoveryUnavailableReason;

  /// 使用发起恢复时的动作验证最新状态，避免刷新过程中动作类型变化造成误判。
  bool recoveryVerifiedFor(AdminDetectionRecoveryAction action) {
    return switch (action) {
      AdminDetectionRecoveryAction.retryStream => streamHealthy == true,
      AdminDetectionRecoveryAction.recheck =>
        state == AdminDetectionState.healthy,
      AdminDetectionRecoveryAction.unsupported => false,
    };
  }
}

/// 管理员检测操作中可直接安全展示的本地化失败原因。
class AdminDetectionOperationException implements Exception {
  /// 创建本地化检测失败。
  const AdminDetectionOperationException(this.message);

  /// 当前语言下的可操作提示。
  final String message;

  @override
  String toString() => message;
}

/// 弹窗打开后读取最新的自动检测项。
typedef AdminDetectionInitialLoader =
    Future<List<AdminDetectionItem>> Function();

/// 恢复并复检当前选中的自动检测设备，返回该设备的最新状态。
typedef AdminDetectionItemReconnectHandler =
    Future<AdminDetectionItem> Function(AdminDetectionItem item);

/// 管理员控制台自动检测弹窗。
///
/// 左侧检测项使用可滚动的数据列表。后续增加检测能力时只需追加
/// [AdminDetectionItem]，无需改变弹窗结构。
class AdminAutoDetectionDialog extends StatefulWidget {
  /// 创建自动检测弹窗。
  const AdminAutoDetectionDialog({
    super.key,
    required this.initialItems,
    required this.onInitialLoad,
    this.onReconnect,
  });

  /// 打开弹窗时已有的设备状态。
  final List<AdminDetectionItem> initialItems;

  /// 弹窗打开后自动读取最新设备状态。
  final AdminDetectionInitialLoader onInitialLoad;

  /// 恢复并复检当前选中设备；为空时展示能力待接入提示。
  final AdminDetectionItemReconnectHandler? onReconnect;

  @override
  State<AdminAutoDetectionDialog> createState() =>
      _AdminAutoDetectionDialogState();
}

class _AdminAutoDetectionDialogState extends State<AdminAutoDetectionDialog> {
  final ScrollController _itemScrollController = ScrollController();

  late List<AdminDetectionItem> _items;
  String? _selectedItemId;
  _AdminDetectionFilter _filter = _AdminDetectionFilter.all;
  bool _initialLoading = true;
  String? _reconnectingItemId;

  @override
  void initState() {
    super.initState();
    _items = List<AdminDetectionItem>.of(widget.initialItems);
    _selectedItemId = _items.isEmpty ? null : _items.first.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_loadInitialItems());
      }
    });
  }

  @override
  void dispose() {
    _itemScrollController.dispose();
    super.dispose();
  }

  /// 弹窗打开时自动获取一次最新状态，不提供重复触发的批量检测入口。
  Future<void> _loadInitialItems() async {
    try {
      final latestItems = await widget.onInitialLoad();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = List<AdminDetectionItem>.of(latestItems);
        _initialLoading = false;
        _keepSelectionInsideFilter();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _initialLoading = false);
      final message = context.l10n
          .t('adminAutoDetectInitialLoadFailed', '自动检测失败：{error}')
          .replaceAll('{error}', _localizedAdminOperationError(context, error));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// 恢复当前选中的设备，并只更新该设备的复检结果。
  Future<void> _reconnectSelectedItem() async {
    final item = _selectedItem;
    if (item == null || _initialLoading || _reconnectingItemId != null) {
      return;
    }

    if (item.recoveryAction == AdminDetectionRecoveryAction.unsupported) {
      final reason = item.recoveryUnavailableReason.isEmpty
          ? context.l10n.t('adminAutoDetectRecoveryUnsupported', '当前设备不支持自动恢复')
          : item.recoveryUnavailableReason;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(reason)));
      return;
    }

    final reconnect = widget.onReconnect;
    if (reconnect == null) {
      final message = context.l10n
          .t('adminAutoDetectRecoveryPending', '{name} 的恢复处理尚未接入')
          .replaceAll('{name}', item.title);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    setState(() => _reconnectingItemId = item.id);
    try {
      final verifiedItem = await reconnect(item);
      if (!mounted) {
        return;
      }
      setState(() {
        final itemIndex = _items.indexWhere(
          (currentItem) => currentItem.id == item.id,
        );
        if (itemIndex >= 0) {
          _items[itemIndex] = verifiedItem;
        }
        _reconnectingItemId = null;
        _keepSelectionInsideFilter();
      });

      if (verifiedItem.recoveryVerifiedFor(item.recoveryAction)) {
        final message =
            item.recoveryAction == AdminDetectionRecoveryAction.retryStream
            ? context.l10n
                  .t('adminAutoDetectStreamRecovered', '{name} 推流已恢复')
                  .replaceAll('{name}', item.title)
            : context.l10n
                  .t('adminAutoDetectRecheckSucceeded', '{name} 重新检测通过')
                  .replaceAll('{name}', item.title);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      final verificationReason =
          item.recoveryAction == AdminDetectionRecoveryAction.retryStream
          ? context.l10n.t(
              'adminAutoDetectStreamVerificationFailed',
              '复检后视频流仍未进入推流中状态',
            )
          : context.l10n.t(
              'adminAutoDetectDeviceVerificationFailed',
              '复检后设备状态仍未恢复正常',
            );
      final result = verifiedItem.result.trim();
      final message = result.isEmpty
          ? context.l10n
                .t('adminAutoDetectRecoveryFailed', '{name} 恢复失败：{reason}')
                .replaceAll('{name}', item.title)
                .replaceAll('{reason}', verificationReason)
          : context.l10n
                .t(
                  'adminAutoDetectRecoveryFailedWithResult',
                  '{name} 恢复失败：{reason}（{result}）',
                )
                .replaceAll('{name}', item.title)
                .replaceAll('{reason}', verificationReason)
                .replaceAll('{result}', result);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _reconnectingItemId = null);
      final message = context.l10n
          .t('adminAutoDetectReconnectFailed', '{name} 重连失败：{error}')
          .replaceAll('{name}', item.title)
          .replaceAll('{error}', _localizedAdminOperationError(context, error));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  AdminDetectionItem? get _selectedItem {
    for (final item in _filteredItems) {
      if (item.id == _selectedItemId) {
        return item;
      }
    }
    return null;
  }

  /// 当前筛选条件下需要展示的左侧检测项。
  List<AdminDetectionItem> get _filteredItems => [
    for (final item in _items)
      if (_matchesFilter(item)) item,
  ];

  /// 判断检测项是否符合当前状态筛选。
  bool _matchesFilter(AdminDetectionItem item) {
    return switch (_filter) {
      _AdminDetectionFilter.all => true,
      _AdminDetectionFilter.healthy =>
        item.state == AdminDetectionState.healthy,
      _AdminDetectionFilter.abnormal =>
        item.state == AdminDetectionState.abnormal,
      _AdminDetectionFilter.pending =>
        item.state == AdminDetectionState.pending,
    };
  }

  /// 切换筛选条件，并将详情同步到筛选结果中的首项。
  void _selectFilter(_AdminDetectionFilter filter) {
    if (_filter == filter) {
      return;
    }
    setState(() {
      _filter = filter;
      _keepSelectionInsideFilter();
    });
  }

  /// 避免筛选或复检后继续显示已不在左侧列表中的项目。
  void _keepSelectionInsideFilter() {
    final filteredItems = _filteredItems;
    final selectionVisible = filteredItems.any(
      (item) => item.id == _selectedItemId,
    );
    if (!selectionVisible) {
      _selectedItemId = filteredItems.isEmpty ? null : filteredItems.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;

    return Dialog(
      key: const ValueKey('admin_auto_detection_dialog'),
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: SizedBox(
        width: 1080,
        height: 720,
        child: Column(
          children: [
            _DetectionDialogHeader(
              items: _items,
              selectedFilter: _filter,
              onFilterSelected: _selectFilter,
              onClose: () => Navigator.of(context).pop(),
            ),
            const Divider(height: 1, color: AppTheme.outlineColor),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final listWidth = constraints.maxWidth < 860 ? 250.0 : 310.0;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: listWidth,
                        child: _DetectionItemList(
                          items: filteredItems,
                          selectedItemId: _selectedItemId,
                          controller: _itemScrollController,
                          onSelected: (item) {
                            setState(() => _selectedItemId = item.id);
                          },
                        ),
                      ),
                      const VerticalDivider(
                        width: 1,
                        color: AppTheme.outlineColor,
                      ),
                      Expanded(
                        child: _DetectionDetailPanel(
                          item: _selectedItem,
                          initialLoading: _initialLoading,
                          recoveryInProgress: _reconnectingItemId != null,
                          reconnecting:
                              _reconnectingItemId == _selectedItem?.id,
                          recoveryHandlerAvailable: widget.onReconnect != null,
                          onReconnectSelected: _reconnectSelectedItem,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 自动检测弹窗标题区，集中展示状态筛选和关闭入口。
class _DetectionDialogHeader extends StatelessWidget {
  const _DetectionDialogHeader({
    required this.items,
    required this.selectedFilter,
    required this.onFilterSelected,
    required this.onClose,
  });

  final List<AdminDetectionItem> items;
  final _AdminDetectionFilter selectedFilter;
  final ValueChanged<_AdminDetectionFilter> onFilterSelected;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filters = _DetectionFilterBar(
      items: items,
      selectedFilter: selectedFilter,
      onSelected: onFilterSelected,
    );
    final closeButton = IconButton(
      key: const ValueKey('admin_auto_detection_close'),
      tooltip: l10n.t('adminAutoDetectClose', '关闭'),
      onPressed: onClose,
      icon: const Icon(Icons.close_rounded),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(child: _DetectionHeaderIdentity()),
                    closeButton,
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: filters,
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 14, 18),
          child: Row(
            children: [
              const Expanded(child: _DetectionHeaderIdentity()),
              const SizedBox(width: 18),
              filters,
              const SizedBox(width: 8),
              closeButton,
            ],
          ),
        );
      },
    );
  }
}

/// 自动检测弹窗标题和说明。
class _DetectionHeaderIdentity extends StatelessWidget {
  const _DetectionHeaderIdentity();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.health_and_safety_rounded,
            color: Colors.white,
            size: 25,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('adminAutoDetectTitle', '自动检测'),
                style: const TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 22,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                l10n.t('adminAutoDetectSubtitle', '按状态筛选并选择左侧项目查看设备详情'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 自动检测状态筛选栏。
class _DetectionFilterBar extends StatelessWidget {
  const _DetectionFilterBar({
    required this.items,
    required this.selectedFilter,
    required this.onSelected,
  });

  final List<AdminDetectionItem> items;
  final _AdminDetectionFilter selectedFilter;
  final ValueChanged<_AdminDetectionFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filters =
        <
          ({
            _AdminDetectionFilter filter,
            String label,
            int count,
            Color color,
            IconData icon,
          })
        >[
          (
            filter: _AdminDetectionFilter.all,
            label: l10n.t('adminAutoDetectAllCount', '全部'),
            count: items.length,
            color: AppTheme.primaryColor,
            icon: Icons.format_list_bulleted_rounded,
          ),
          (
            filter: _AdminDetectionFilter.healthy,
            label: l10n.t('adminAutoDetectHealthyCount', '正常'),
            count: items
                .where((item) => item.state == AdminDetectionState.healthy)
                .length,
            color: const Color(0xFF15803D),
            icon: Icons.check_circle_rounded,
          ),
          (
            filter: _AdminDetectionFilter.abnormal,
            label: l10n.t('adminAutoDetectAbnormalCount', '异常'),
            count: items
                .where((item) => item.state == AdminDetectionState.abnormal)
                .length,
            color: const Color(0xFFDC2626),
            icon: Icons.error_rounded,
          ),
          (
            filter: _AdminDetectionFilter.pending,
            label: l10n.t('adminAutoDetectPendingCount', '待接入'),
            count: items
                .where((item) => item.state == AdminDetectionState.pending)
                .length,
            color: const Color(0xFFB45309),
            icon: Icons.schedule_rounded,
          ),
        ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < filters.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          _DetectionFilterChip(
            filter: filters[index].filter,
            label: filters[index].label,
            count: filters[index].count,
            color: filters[index].color,
            icon: filters[index].icon,
            selected: filters[index].filter == selectedFilter,
            onTap: () => onSelected(filters[index].filter),
          ),
        ],
      ],
    );
  }
}

/// 可点击的单个状态筛选按钮。
class _DetectionFilterChip extends StatelessWidget {
  const _DetectionFilterChip({
    required this.filter,
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final _AdminDetectionFilter filter;
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label $count',
      child: Material(
        color: selected ? color.withValues(alpha: .1) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          key: ValueKey('admin_auto_detection_filter_${filter.name}'),
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? color : AppTheme.outlineColor,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(
                  '$label $count',
                  style: TextStyle(
                    color: selected ? color : AppTheme.textPrimaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 自动检测项左侧列表。
class _DetectionItemList extends StatelessWidget {
  const _DetectionItemList({
    required this.items,
    required this.selectedItemId,
    required this.controller,
    required this.onSelected,
  });

  final List<AdminDetectionItem> items;
  final String? selectedItemId;
  final ScrollController controller;
  final ValueChanged<AdminDetectionItem> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ColoredBox(
      color: AppTheme.primarySoftColor.withValues(alpha: .38),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 10, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                l10n.t('adminAutoDetectItemsTitle', '检测项目'),
                style: const TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        l10n.t('adminAutoDetectEmpty', '暂无检测项'),
                        style: const TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : Scrollbar(
                      controller: controller,
                      thumbVisibility: true,
                      interactive: true,
                      child: ListView.separated(
                        key: const ValueKey('admin_auto_detection_item_list'),
                        controller: controller,
                        padding: const EdgeInsets.only(right: 8),
                        physics: const BouncingScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _DetectionItemTile(
                            index: index,
                            item: item,
                            selected: item.id == selectedItemId,
                            onTap: () => onSelected(item),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 左侧单个检测项。
class _DetectionItemTile extends StatelessWidget {
  const _DetectionItemTile({
    required this.index,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final AdminDetectionItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stateStyle = _DetectionStateStyle.resolve(context, item.state);
    return Semantics(
      selected: selected,
      button: true,
      label: '${index + 1}. ${item.title}, ${stateStyle.label}',
      child: Material(
        color: selected ? Colors.white : Colors.white.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey('admin_auto_detection_item_${item.id}'),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppTheme.primaryColor : AppTheme.outlineColor,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primarySoftColor
                        : AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    item.icon,
                    color: selected
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondaryColor,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '${index + 1}、${item.title}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? AppTheme.primaryStrongColor
                          : AppTheme.textPrimaryColor,
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(stateStyle.icon, color: stateStyle.color, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 右侧检测详情。
class _DetectionDetailPanel extends StatelessWidget {
  const _DetectionDetailPanel({
    required this.item,
    required this.initialLoading,
    required this.recoveryInProgress,
    required this.reconnecting,
    required this.recoveryHandlerAvailable,
    required this.onReconnectSelected,
  });

  final AdminDetectionItem? item;
  final bool initialLoading;
  final bool recoveryInProgress;
  final bool reconnecting;
  final bool recoveryHandlerAvailable;
  final VoidCallback onReconnectSelected;

  @override
  Widget build(BuildContext context) {
    final selectedItem = item;
    if (selectedItem == null) {
      return const _DetectionEmptyDetail();
    }

    final l10n = context.l10n;
    final stateStyle = _DetectionStateStyle.resolve(
      context,
      selectedItem.state,
    );
    final recoverySupported =
        selectedItem.recoveryAction != AdminDetectionRecoveryAction.unsupported;
    final reconnectEnabled =
        recoverySupported &&
        recoveryHandlerAvailable &&
        selectedItem.state != AdminDetectionState.checking &&
        !initialLoading &&
        !recoveryInProgress;
    final recoveryUnavailableReason = !recoverySupported
        ? (selectedItem.recoveryUnavailableReason.isEmpty
              ? l10n.t('adminAutoDetectRecoveryUnsupported', '当前设备不支持自动恢复')
              : selectedItem.recoveryUnavailableReason)
        : !recoveryHandlerAvailable
        ? l10n.t('adminAutoDetectDeviceRecoveryPending', '当前设备的恢复处理尚未接入')
        : '';
    final recoveryActionLabel = switch (selectedItem.recoveryAction) {
      AdminDetectionRecoveryAction.retryStream =>
        reconnecting
            ? l10n.t('adminAutoDetectStreamRetrying', '推流重试中...')
            : l10n.t('adminAutoDetectRetryStream', '立即重试推流'),
      AdminDetectionRecoveryAction.recheck =>
        reconnecting
            ? l10n.t('adminAutoDetectDeviceChecking', '检测中...')
            : l10n.t('adminAutoDetectRecheckDevice', '重新检测该设备'),
      AdminDetectionRecoveryAction.unsupported => l10n.t(
        'adminAutoDetectAutomaticRecoveryUnsupported',
        '暂不支持自动恢复',
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.primarySoftColor,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        selectedItem.icon,
                        color: AppTheme.primaryColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedItem.title,
                            style: const TextStyle(
                              color: AppTheme.textPrimaryColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            selectedItem.description,
                            style: const TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 13,
                              height: 1.45,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _DetectionStatusChip(style: stateStyle),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.outlineColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.t('adminAutoDetectCurrentResult', '当前检测结果'),
                        style: const TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            stateStyle.icon,
                            color: stateStyle.color,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              selectedItem.result,
                              style: const TextStyle(
                                color: AppTheme.textPrimaryColor,
                                fontSize: 16,
                                height: 1.45,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppTheme.outlineColor)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final hint = Text(
                recoveryUnavailableReason.isNotEmpty
                    ? recoveryUnavailableReason
                    : l10n.t(
                        'adminAutoDetectSelectedActionHint',
                        '恢复操作仅作用于当前选中设备',
                      ),
                style: const TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              );
              final action = Tooltip(
                message: recoveryUnavailableReason.isNotEmpty
                    ? recoveryUnavailableReason
                    : selectedItem.recoveryAction ==
                          AdminDetectionRecoveryAction.retryStream
                    ? l10n.t(
                        'adminAutoDetectRetryStreamTooltip',
                        '仅重新启动当前摄像头的视频推流，并在完成后复检',
                      )
                    : l10n.t('adminAutoDetectRecheckTooltip', '仅重新检测当前左侧选中的设备'),
                child: OutlinedButton.icon(
                  key: const ValueKey(
                    'admin_auto_detection_reconnect_selected',
                  ),
                  onPressed: reconnectEnabled ? onReconnectSelected : null,
                  icon: reconnecting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(recoveryActionLabel),
                ),
              );

              if (constraints.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [hint, const SizedBox(height: 12), action],
                );
              }
              return Row(
                children: [
                  Expanded(child: hint),
                  const SizedBox(width: 16),
                  action,
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 没有检测项时的右侧占位。
class _DetectionEmptyDetail extends StatelessWidget {
  const _DetectionEmptyDetail();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.fact_check_outlined,
              color: AppTheme.primaryColor,
              size: 58,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.t('adminAutoDetectFilteredEmpty', '当前筛选条件下暂无检测项'),
              style: const TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 检测状态标签。
class _DetectionStatusChip extends StatelessWidget {
  const _DetectionStatusChip({required this.style});

  final _DetectionStateStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.color.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, color: style.color, size: 15),
          const SizedBox(width: 5),
          Text(
            style.label,
            style: TextStyle(
              color: style.color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// 检测状态对应的视觉样式。
class _DetectionStateStyle {
  const _DetectionStateStyle({
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.icon,
  });

  final String label;
  final Color color;
  final Color backgroundColor;
  final IconData icon;

  static _DetectionStateStyle resolve(
    BuildContext context,
    AdminDetectionState state,
  ) {
    final l10n = context.l10n;
    return switch (state) {
      AdminDetectionState.checking => _DetectionStateStyle(
        label: l10n.t('adminAutoDetectStatusChecking', '检测中'),
        color: AppTheme.primaryColor,
        backgroundColor: AppTheme.primarySoftColor,
        icon: Icons.sync_rounded,
      ),
      AdminDetectionState.healthy => _DetectionStateStyle(
        label: l10n.t('adminAutoDetectStatusHealthy', '正常'),
        color: const Color(0xFF15803D),
        backgroundColor: const Color(0xFFEAF7EE),
        icon: Icons.check_circle_rounded,
      ),
      AdminDetectionState.abnormal => _DetectionStateStyle(
        label: l10n.t('adminAutoDetectStatusAbnormal', '异常'),
        color: const Color(0xFFDC2626),
        backgroundColor: const Color(0xFFFDECEC),
        icon: Icons.error_rounded,
      ),
      AdminDetectionState.pending => _DetectionStateStyle(
        label: l10n.t('adminAutoDetectStatusPending', '待接入'),
        color: const Color(0xFFB45309),
        backgroundColor: const Color(0xFFFFF4E5),
        icon: Icons.schedule_rounded,
      ),
    };
  }
}
