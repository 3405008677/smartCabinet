import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/shell/app_shell.dart';
import 'package:smart_cabinet/src/core/camera/cabinet_camera.dart';
import 'package:smart_cabinet/src/core/device/hardware_status_service.dart';
import 'package:smart_cabinet/src/core/device/kiosk_device.dart';
import 'package:smart_cabinet/src/core/device/method_channel_kiosk_device.dart';
import 'package:smart_cabinet/src/core/storage/app_local_store_provider.dart';
import 'package:smart_cabinet/src/features/admin/domain/entities/admin.dart';
import 'package:smart_cabinet/src/features/admin/presentation/widgets/admin_auto_detection_dialog.dart';
import 'package:smart_cabinet/src/features/admin/presentation/widgets/admin_camera_capability_panel.dart';

/// 管理员控制台页。
class AdminConsolePage extends ConsumerStatefulWidget {
  /// 创建管理员控制台页。
  const AdminConsolePage({super.key});

  @override
  ConsumerState<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends ConsumerState<AdminConsolePage> {
  /// 当前柜体设备状态。
  AdminDeviceStatus _deviceStatus = AdminDeviceStatus.fallback();

  /// 真实硬件状态是否仍在读取。
  bool _deviceStatusLoading = true;

  /// 真实硬件状态读取失败说明。
  String? _deviceStatusError;

  /// 丢弃被后一次刷新覆盖的硬件状态结果。
  int _deviceStatusGeneration = 0;

  /// 终端硬件状态服务。
  final HardwareStatusService _hardwareStatusService =
      const HardwareStatusService();

  /// 摄像头配置加载状态。
  bool _cameraConfigLoading = true;

  /// 摄像头配置加载失败文案。
  String? _cameraConfigError;

  /// 丢弃被后一次刷新覆盖的摄像头检测结果。
  int _cameraConfigGeneration = 0;

  /// 柜外环境摄像头原生推流状态。
  CameraStreamStatus? _outsideEnvironmentStreamStatus;

  /// 操作区摄像头原生 RTSP-H265 推流状态。
  CameraStreamStatus? _operationAreaStreamStatus;

  /// 当前系统枚举到的摄像头列表。
  List<CabinetCameraDevice> _availableCameras = const [];

  /// 各业务摄像头的 Camera2 物理连接与分辨率能力。
  Map<CabinetCameraRole, CameraStreamCapability> _cameraCapabilities = const {};

  /// 各业务摄像头 Camera2 连接检测失败说明。
  Map<CabinetCameraRole, String> _cameraCapabilityErrors = const {};

  /// 两路 RTSP 摄像头推流状态读取失败说明。
  Map<CabinetCameraRole, String> _streamStatusErrors = const {};

  /// 摄像头绑定服务。
  final CabinetCameraService _cameraService = const CabinetCameraService();

  /// 复用原生已封装的摄像头推流启停能力。
  final KioskDevice _kioskDevice = const MethodChannelKioskDevice();

  @override
  void initState() {
    super.initState();
    _loadDeviceStatus();
    _loadCameraConfig();
  }

  /// 加载当前柜体与硬件状态。
  Future<void> _loadDeviceStatus() async {
    final generation = ++_deviceStatusGeneration;
    if (mounted) {
      setState(() {
        _deviceStatusLoading = true;
        _deviceStatusError = null;
      });
    }
    try {
      final store = await ref.read(appLocalStoreProvider.future);
      final localState = await store.state();
      final hardwareStatus = await _hardwareStatusService.fetchHardwareStatus();
      final deviceStatus = AdminDeviceStatus.fromLocalState(
        deviceInfo: localState.deviceInfo,
        hardwareStatus: hardwareStatus,
      );
      if (!mounted || generation != _deviceStatusGeneration) {
        return;
      }
      setState(() {
        _deviceStatus = deviceStatus;
        _deviceStatusLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _deviceStatusGeneration) {
        return;
      }
      setState(() {
        _deviceStatusLoading = false;
        _deviceStatusError = '硬件状态读取失败：$error';
      });
    }
  }

  /// 加载摄像头设备连接、能力与推流状态。
  Future<void> _loadCameraConfig({bool forceReload = false}) async {
    final generation = ++_cameraConfigGeneration;
    if (mounted) {
      setState(() {
        _cameraConfigLoading = true;
        _cameraConfigError = null;
      });
    }

    List<CabinetCameraDevice> availableCameras = const [];
    final errors = <String>[];
    try {
      availableCameras = await _cameraService.loadAvailableCameras(
        forceReload: forceReload,
      );
    } catch (error) {
      errors.add('摄像头枚举失败：$error');
    }

    final capabilityErrors = <CabinetCameraRole, String>{};
    final capabilityEntries = await Future.wait(
      CabinetCameraRole.values.map((role) async {
        try {
          final capability = await _cameraService.readCameraStreamCapability(
            role,
          );
          return MapEntry<CabinetCameraRole, CameraStreamCapability>(
            role,
            capability,
          );
        } catch (error) {
          final message = '${role.name} 连接检测失败：$error';
          errors.add(message);
          capabilityErrors[role] = message;
          return null;
        }
      }),
    );
    final capabilities = <CabinetCameraRole, CameraStreamCapability>{
      for (final entry in capabilityEntries)
        if (entry != null) entry.key: entry.value,
    };

    final streamStatusErrors = <CabinetCameraRole, String>{};
    CameraStreamStatus? outsideEnvironmentStreamStatus;
    CameraStreamStatus? operationAreaStreamStatus;
    try {
      outsideEnvironmentStreamStatus = await _cameraService
          .readOutsideEnvironmentStreamStatus();
    } catch (error) {
      final message = '柜外环境视频流状态读取失败：$error';
      errors.add(message);
      streamStatusErrors[CabinetCameraRole.outsideEnvironment] = message;
    }
    try {
      operationAreaStreamStatus = await _cameraService
          .readOperationAreaStreamStatus();
    } catch (error) {
      final message = '操作区视频流状态读取失败：$error';
      errors.add(message);
      streamStatusErrors[CabinetCameraRole.operationArea] = message;
    }

    if (!mounted || generation != _cameraConfigGeneration) {
      return;
    }
    setState(() {
      _availableCameras = availableCameras;
      _cameraCapabilities = Map.unmodifiable(capabilities);
      _cameraCapabilityErrors = Map.unmodifiable(capabilityErrors);
      _streamStatusErrors = Map.unmodifiable(streamStatusErrors);
      _outsideEnvironmentStreamStatus = outsideEnvironmentStreamStatus;
      _operationAreaStreamStatus = operationAreaStreamStatus;
      _cameraConfigLoading = false;
      _cameraConfigError = errors.isEmpty
          ? null
          : '部分摄像头状态读取失败：${errors.join('；')}';
    });
  }

  /// 打开指定摄像头的实时预览弹窗。
  Future<void> _openCameraPreview(
    CabinetCameraRole role,
    CabinetCameraDevice camera,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) =>
          _AdminCameraPreviewDialog(role: role, camera: camera),
    );
  }

  /// 打开自动检测面板。
  Future<void> _openAutoDetection() {
    return showDialog<void>(
      context: context,
      builder: (context) => AdminAutoDetectionDialog(
        initialItems: _buildAutoDetectionItems(context),
        onInitialLoad: _loadInitialAutoDetectionItems,
        onReconnect: _recoverAutoDetectionItem,
      ),
    );
  }

  /// 弹窗打开时读取一次全部设备的最新检测状态。
  Future<List<AdminDetectionItem>> _loadInitialAutoDetectionItems() async {
    await Future.wait<void>([
      _loadDeviceStatus(),
      _loadCameraConfig(forceReload: true),
    ]);
    if (!mounted) {
      throw StateError('管理员控制台已关闭');
    }
    return _buildAutoDetectionItems(context);
  }

  /// 对当前检测项执行真实恢复动作，并返回该项的最新复检结果。
  Future<AdminDetectionItem> _recoverAutoDetectionItem(
    AdminDetectionItem item,
  ) async {
    switch (item.recoveryAction) {
      case AdminDetectionRecoveryAction.retryStream:
        final role = _cameraRoleFromDetectionItem(item);
        if (role == null) {
          throw StateError('无法识别要重试的视频流');
        }
        await _retryCameraStream(role);
        await _loadCameraConfig(forceReload: true);
        break;
      case AdminDetectionRecoveryAction.recheck:
        if (_cameraRoleFromDetectionItem(item) != null) {
          await _loadCameraConfig(forceReload: true);
        } else {
          await _loadDeviceStatus();
        }
        break;
      case AdminDetectionRecoveryAction.unsupported:
        throw StateError(
          item.recoveryUnavailableReason.isEmpty
              ? '当前设备不支持自动恢复'
              : item.recoveryUnavailableReason,
        );
    }

    if (!mounted) {
      throw StateError('管理员控制台已关闭');
    }
    for (final latestItem in _buildAutoDetectionItems(context)) {
      if (latestItem.id == item.id) {
        return latestItem;
      }
    }
    throw StateError('未找到 ${item.title} 的最新检测结果');
  }

  /// 复用原生启停能力，保留当前启用清晰度并等待真实推流恢复。
  Future<void> _retryCameraStream(CabinetCameraRole role) async {
    final capability = await _cameraService.readCameraStreamCapability(role);
    if (capability.hasConnectionProbeError) {
      throw StateError(
        capability.errorMessage.isEmpty
            ? '设备连接检测异常，无法重试视频推流'
            : capability.errorMessage,
      );
    }
    if (!capability.available) {
      throw StateError('设备未连接，无法重试视频推流');
    }

    final profiles = await _kioskDevice.retryCameraStream(role);
    if (profiles.isEmpty) {
      throw StateError('当前没有可恢复的推流清晰度，请由手机端重新发起推流');
    }

    var latest = await _cameraService.readStreamStatus(role);
    for (var attempt = 0; attempt < 24; attempt += 1) {
      if (latest.isStreaming && !latest.needsUserAttention) {
        return;
      }
      if (latest.state == CameraStreamState.failed && !latest.recoverable) {
        throw StateError(
          latest.displayStatus.isEmpty ? '视频推流启动失败' : latest.displayStatus,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
      latest = await _cameraService.readStreamStatus(role);
    }
    throw StateError(
      latest.displayStatus.isEmpty
          ? '等待视频推流恢复超时'
          : '等待视频推流恢复超时：${latest.displayStatus}',
    );
  }

  /// 从自动检测项 ID 解析摄像头业务角色。
  CabinetCameraRole? _cameraRoleFromDetectionItem(AdminDetectionItem item) {
    const prefix = 'camera_';
    if (!item.id.startsWith(prefix)) {
      return null;
    }
    final roleName = item.id.substring(prefix.length);
    for (final role in CabinetCameraRole.values) {
      if (role.name == roleName) {
        return role;
      }
    }
    return null;
  }

  /// 使用控制台已经读取的真实设备状态生成检测项。
  List<AdminDetectionItem> _buildAutoDetectionItems(BuildContext context) {
    return buildAdminDetectionItems(
      context: context,
      deviceStatus: _deviceStatus,
      deviceStatusLoading: _deviceStatusLoading,
      deviceStatusError: _deviceStatusError,
      cameraConfigLoading: _cameraConfigLoading,
      cameraConfigError: _cameraConfigError,
      availableCameras: _availableCameras,
      cameraCapabilities: _cameraCapabilities,
      cameraCapabilityErrors: _cameraCapabilityErrors,
      outsideEnvironmentStreamStatus: _outsideEnvironmentStreamStatus,
      operationAreaStreamStatus: _operationAreaStreamStatus,
      streamStatusErrors: _streamStatusErrors,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return TerminalShell(
      topBarLeading: _AdminConsoleHeader(
        title: l10n.t('adminConsoleTitle', '管理员控制台'),
        onBack: () => Navigator.of(context).pop(),
      ),
      topRightBadge: FlowStatusBadge(
        text: l10n.t('adminConsoleBadge', '设备管理 · 管理员'),
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primarySoftColor, AppTheme.surfaceColor],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: _DeviceInfoPanel(
                status: _deviceStatus,
                cameraConfigLoading: _cameraConfigLoading,
                cameraConfigError: _cameraConfigError,
                availableCameras: _availableCameras,
                cameraCapabilities: _cameraCapabilities,
                cameraCapabilityErrors: _cameraCapabilityErrors,
                streamStatusErrors: _streamStatusErrors,
                outsideEnvironmentStreamStatus: _outsideEnvironmentStreamStatus,
                operationAreaStreamStatus: _operationAreaStreamStatus,
                onOpenCameraPreview: _openCameraPreview,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 4,
              child: _AdminFunctionPanel(
                onOpenAutoDetection: _openAutoDetection,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 管理员控制台头部。
class _AdminConsoleHeader extends StatelessWidget {
  /// 创建管理员控制台头部。
  const _AdminConsoleHeader({required this.title, required this.onBack});

  /// 标题文本。
  final String title;

  /// 返回按钮回调。
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimaryColor,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

/// 左侧柜体与硬件状态面板。
class _DeviceInfoPanel extends StatelessWidget {
  /// 创建设备信息面板。
  const _DeviceInfoPanel({
    required this.status,
    required this.cameraConfigLoading,
    required this.cameraConfigError,
    required this.availableCameras,
    required this.cameraCapabilities,
    required this.cameraCapabilityErrors,
    required this.streamStatusErrors,
    required this.outsideEnvironmentStreamStatus,
    required this.operationAreaStreamStatus,
    required this.onOpenCameraPreview,
  });

  /// 当前柜体设备状态。
  final AdminDeviceStatus status;

  /// 摄像头配置是否正在加载。
  final bool cameraConfigLoading;

  /// 摄像头配置加载错误。
  final String? cameraConfigError;

  /// 当前系统枚举到的摄像头列表。
  final List<CabinetCameraDevice> availableCameras;

  /// 各业务摄像头最新一次 Camera2 物理连接检测结果。
  final Map<CabinetCameraRole, CameraStreamCapability> cameraCapabilities;

  /// Camera2 连接检测失败说明，避免将检测异常误报为物理断开。
  final Map<CabinetCameraRole, String> cameraCapabilityErrors;

  /// 两路 RTSP 摄像头各自的推流状态读取失败说明。
  final Map<CabinetCameraRole, String> streamStatusErrors;

  /// 柜外环境摄像头原生推流状态。
  final CameraStreamStatus? outsideEnvironmentStreamStatus;

  /// 操作区摄像头原生 RTSP-H265 推流状态。
  final CameraStreamStatus? operationAreaStreamStatus;

  /// 打开摄像头预览弹窗。
  final void Function(CabinetCameraRole role, CabinetCameraDevice camera)
  onOpenCameraPreview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      _DeviceInfoItem(
        l10n.t('adminDeviceCabinetCode', '柜体编号'),
        status.cabinetCode,
        Icons.inventory_2_outlined,
      ),
      _DeviceInfoItem(
        l10n.t('adminDeviceRegion', '所在区域'),
        status.region,
        Icons.grid_view_rounded,
      ),
      _DeviceInfoItem(
        l10n.t('adminDeviceWifi', '连接 WiFi'),
        status.wifiName,
        Icons.wifi_rounded,
      ),
      _DeviceInfoItem(
        l10n.t('adminDeviceRj45', 'RJ45连接'),
        status.rj45Status,
        Icons.settings_ethernet_rounded,
      ),
      ...CabinetCameraRole.values.map((role) {
        final camera = _connectedCameraForRole(role);
        return _DeviceInfoItem(
          role.label(context),
          _cameraStatusText(context, role),
          Icons.video_camera_front_outlined,
          key: ValueKey('admin_camera_role_${role.name}'),
          onTap: camera == null
              ? null
              : () => onOpenCameraPreview(role, camera),
        );
      }),
      _DeviceInfoItem(
        l10n.t('adminDeviceNfc', 'NFC'),
        status.nfcStatus,
        Icons.contactless_rounded,
      ),
      _DeviceInfoItem(
        l10n.t('adminDeviceFingerprint', '指纹模块'),
        status.fingerprintStatus,
        Icons.fingerprint,
      ),
      _DeviceInfoItem(
        l10n.t('adminDeviceCabinetBoard', '柜控板'),
        status.cabinetBoardStatus,
        Icons.developer_board,
      ),
      _DeviceInfoItem(
        l10n.t('adminDeviceScanner', '扫码器'),
        status.scannerStatus,
        Icons.qr_code_scanner,
      ),
    ];
    return _ConsoleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelTitle(
            icon: Icons.dns_outlined,
            title: l10n.t('adminDevicePanelTitle', '当前柜体所有信息'),
            subtitle: l10n.t('adminDevicePanelSubtitle', '柜体、网络、摄像头、NFC 与外设状态'),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              key: const ValueKey('admin_device_info_grid'),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 2.35,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) => _DeviceStatusTile(items[index]),
            ),
          ),
        ],
      ),
    );
  }

  /// 获取摄像头角色卡片状态文案。
  String _cameraStatusText(BuildContext context, CabinetCameraRole role) {
    final l10n = context.l10n;
    final capability = cameraCapabilities[role];
    if (cameraConfigLoading && capability == null) {
      return l10n.t('adminCameraLoading', '正在读取摄像头...');
    }

    final connection = _cameraConnectionText(role);
    final binding = CabinetCameraConfig.bindingFor(role);
    if (binding.useMode != CabinetCameraUseMode.rtspStream) {
      return '设备连接：$connection';
    }

    final streamStatus = switch (role) {
      CabinetCameraRole.outsideEnvironment => outsideEnvironmentStreamStatus,
      CabinetCameraRole.operationArea => operationAreaStreamStatus,
      _ => null,
    };
    return '设备连接：$connection\n视频推流：${_streamStatusText(streamStatus, streamStatusErrors[role])}';
  }

  /// 摄像头卡片中的推流摘要；详细错误由独立推流异常提示展示。
  String _streamStatusText(CameraStreamStatus? status, String? readError) {
    if (status == null) {
      return readError == null ? '未启动' : '状态读取失败';
    }
    if (status.isStreaming) {
      return status.profile.isEmpty ? '推流中' : '${status.profile} 推流中';
    }
    return switch (status.state) {
      CameraStreamState.starting => '启动中',
      CameraStreamState.reconnecting =>
        status.reconnectAttempts > 0
            ? '自动重连中（第 ${status.reconnectAttempts} 次）'
            : '自动重连中',
      CameraStreamState.failed => '推流失败（详见推流异常提示）',
      CameraStreamState.stopping => '停止中',
      CameraStreamState.stopped => '未启动',
      CameraStreamState.unconfigured => '未配置',
      CameraStreamState.unknown =>
        status.needsUserAttention ? '推流失败（详见推流异常提示）' : status.status,
      CameraStreamState.streaming =>
        status.allProfilesStreaming == false ? '启动中' : '推流中',
    };
  }

  /// 判断开发绑定的物理摄像头当前是否能被 Camera2 枚举到。
  String _cameraConnectionText(CabinetCameraRole role) {
    final capability = cameraCapabilities[role];
    if (capability != null) {
      if (capability.hasConnectionProbeError) {
        return '检测失败';
      }
      return capability.available ? '连接成功' : '连接失败';
    }
    if (cameraCapabilityErrors.containsKey(role)) {
      return '检测失败';
    }
    return _connectedCameraForRole(role) == null ? '连接失败' : '连接成功';
  }

  /// 查找当前角色已经连接的摄像头。
  CabinetCameraDevice? _connectedCameraForRole(CabinetCameraRole role) {
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
}

/// 单项设备状态。
class _DeviceInfoItem {
  /// 创建设备状态项。
  const _DeviceInfoItem(
    this.label,
    this.value,
    this.icon, {
    this.key,
    this.onTap,
  });

  /// 状态标签。
  final String label;

  /// 状态值。
  final String value;

  /// 状态图标。
  final IconData icon;

  /// 状态卡片 key。
  final Key? key;

  /// 点击状态卡片时触发。
  final VoidCallback? onTap;
}

/// 设备状态卡片。
class _DeviceStatusTile extends StatelessWidget {
  /// 创建设备状态卡片。
  const _DeviceStatusTile(this.item);

  /// 当前状态项。
  final _DeviceInfoItem item;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      key: item.key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: AppTheme.primaryColor, size: 28),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (item.onTap == null) {
      return card;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: item.onTap,
        child: card,
      ),
    );
  }
}

/// 管理员控制台摄像头预览弹窗。
class _AdminCameraPreviewDialog extends StatelessWidget {
  /// 创建管理员控制台摄像头预览弹窗。
  const _AdminCameraPreviewDialog({required this.role, required this.camera});

  /// 当前预览的摄像头角色。
  final CabinetCameraRole role;

  /// 当前预览的摄像头设备。
  final CabinetCameraDevice camera;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: _AdminCameraPreviewPanel(role: role, camera: camera),
    );
  }
}

/// 管理员控制台摄像头预览面板。
class _AdminCameraPreviewPanel extends StatefulWidget {
  /// 创建管理员控制台摄像头预览面板。
  const _AdminCameraPreviewPanel({required this.role, required this.camera});

  /// 当前预览的摄像头角色。
  final CabinetCameraRole role;

  /// 当前预览的摄像头设备。
  final CabinetCameraDevice camera;

  @override
  State<_AdminCameraPreviewPanel> createState() =>
      _AdminCameraPreviewPanelState();
}

class _AdminCameraPreviewPanelState extends State<_AdminCameraPreviewPanel>
    with WidgetsBindingObserver {
  /// 当前预览控制器。
  CameraController? _controller;

  /// 正在初始化、尚未发布到界面的预览控制器。
  CameraController? _initializingController;

  Future<void> _releaseChain = Future<void>.value();

  /// 预览异步请求代次，用于丢弃过期结果。
  int _previewGeneration = 0;

  /// 当前页面是否处于可使用摄像头的前台状态。
  bool _lifecycleActive = true;

  /// 当前预览状态文案。
  String _message = '正在启动预览...';

  /// Camera2 能力只用于弹窗下方诊断，不参与预览控制。
  final CabinetCameraService _cameraService = const CabinetCameraService();

  CameraStreamCapability? _capability;
  bool _capabilityLoading = true;
  String _capabilityError = '';
  int _capabilityGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _lifecycleActive =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    unawaited(_loadCapability());
    if (_lifecycleActive) {
      unawaited(_initializePreview());
    }
  }

  @override
  void didUpdateWidget(covariant _AdminCameraPreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final cameraChanged = oldWidget.camera.id != widget.camera.id;
    if (cameraChanged || oldWidget.role != widget.role) {
      unawaited(_loadCapability());
    }
    if (cameraChanged && _lifecycleActive) {
      unawaited(_initializePreview());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lifecycleActive = state == AppLifecycleState.resumed;
    if (_lifecycleActive == lifecycleActive) {
      return;
    }
    _lifecycleActive = lifecycleActive;
    if (lifecycleActive) {
      unawaited(_loadCapability());
      unawaited(_initializePreview());
      return;
    }
    unawaited(_releaseControllers(invalidate: true));
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycleActive = false;
    _capabilityGeneration++;
    unawaited(_releaseControllers(invalidate: true));
    super.dispose();
  }

  /// 独立读取 Camera2 能力；失败不会停止或替换实时预览。
  Future<void> _loadCapability() async {
    final generation = ++_capabilityGeneration;
    if (mounted) {
      setState(() {
        _capabilityLoading = true;
        _capabilityError = '';
      });
    }
    try {
      final capability = await _cameraService.readCameraStreamCapability(
        widget.role,
      );
      if (!mounted || generation != _capabilityGeneration) {
        return;
      }
      setState(() {
        _capability = capability;
        _capabilityLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _capabilityGeneration) {
        return;
      }
      setState(() {
        _capabilityLoading = false;
        _capabilityError = '读取失败：$error';
      });
    }
  }

  /// 初始化摄像头实时预览。
  Future<void> _initializePreview() async {
    final generation = ++_previewGeneration;
    await _releaseControllers(invalidate: false);
    if (!_isPreviewRequestCurrent(generation)) {
      return;
    }
    setState(() => _message = '正在启动预览...');

    CameraController? candidate;
    try {
      final controller = CameraController(
        widget.camera.description,
        adminCameraPreviewResolutionPreset,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      candidate = controller;
      controller.addListener(_handleControllerValueChanged);
      _initializingController = controller;
      await controller.initialize();
      if (identical(_initializingController, controller)) {
        _initializingController = null;
      }

      if (!_isPreviewRequestCurrent(generation)) {
        await _disposeControllerSerially(controller);
        return;
      }
      setState(() {
        _controller = controller;
        _message = controller.value.hasError
            ? adminCameraPreviewErrorMessage(controller.value.errorDescription)
            : '预览已启动';
      });
    } catch (error) {
      if (identical(_initializingController, candidate)) {
        _initializingController = null;
      }
      await _disposeControllerSerially(candidate);
      if (_isPreviewRequestCurrent(generation)) {
        setState(() => _message = adminCameraPreviewErrorMessage(error));
      }
    }
  }

  void _handleControllerValueChanged() {
    final controller = _controller ?? _initializingController;
    if (!mounted || controller == null || !controller.value.hasError) {
      return;
    }
    final nextMessage = adminCameraPreviewErrorMessage(
      controller.value.errorDescription,
    );
    if (_message != nextMessage) {
      setState(() => _message = nextMessage);
    }
  }

  bool _isPreviewRequestCurrent(int generation) {
    return mounted && _lifecycleActive && generation == _previewGeneration;
  }

  Future<void> _releaseControllers({required bool invalidate}) {
    if (invalidate) {
      _previewGeneration++;
    }
    final controller = _controller;
    final initializingController = _initializingController;
    _controller = null;
    _initializingController = null;
    var release = _disposeControllerSerially(controller);
    if (!identical(initializingController, controller)) {
      release = _disposeControllerSerially(initializingController);
    }
    return release;
  }

  Future<void> _disposeControllerSerially(CameraController? controller) {
    if (controller == null) {
      return _releaseChain;
    }
    _releaseChain = _releaseChain.then(
      (_) => _safeDisposeController(controller),
    );
    return _releaseChain;
  }

  Future<void> _safeDisposeController(CameraController? controller) async {
    if (controller == null) {
      return;
    }
    controller.removeListener(_handleControllerValueChanged);
    try {
      await controller.dispose();
    } catch (_) {
      // The platform may already have released the camera.
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Container(
      key: const ValueKey('admin_camera_preview_panel'),
      width: 620,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.role.label(context)}预览',
                    style: const TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('admin_camera_preview_close'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              key: const ValueKey('admin_camera_preview_frame'),
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: adminCameraPreviewAspectRatio,
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Color(0xFF10182E)),
                  child:
                      controller != null &&
                          controller.value.isInitialized &&
                          !controller.value.hasError
                      ? CameraPreview(controller)
                      : Center(
                          child: Text(
                            _message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            AdminCameraCapabilityPanel(
              previewCameraId: widget.camera.id,
              previewStatus: _message,
              loading: _capabilityLoading,
              capability: _capability,
              loadError: _capabilityError,
            ),
          ],
        ),
      ),
    );
  }
}

extension _CabinetCameraRoleLabel on CabinetCameraRole {
  /// 当前角色的显示名称。
  String label(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
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
}

/// 右侧管理员功能面板。
class _AdminFunctionPanel extends StatelessWidget {
  /// 创建管理员功能面板。
  const _AdminFunctionPanel({required this.onOpenAutoDetection});

  /// 打开自动检测面板。
  final VoidCallback onOpenAutoDetection;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final functions = [
      _AdminFunctionItem(
        l10n.t('adminFunctionInitializeData', '初始化数据'),
        l10n.t('adminFunctionInitializeDataDescription', '清理本地演示数据并重新拉取柜体配置'),
        Icons.restart_alt,
      ),
      _AdminFunctionItem(
        l10n.t('adminFunctionResetDevice', '重置设备'),
        l10n.t('adminFunctionResetDeviceDescription', '重启外设连接、柜控板与终端运行状态'),
        Icons.power_settings_new,
      ),
      _AdminFunctionItem(
        l10n.t('adminFunctionAutoDetect', '自动检测'),
        l10n.t('adminFunctionAutoDetectDescription', '自动检查网络、摄像头、NFC、柜控板与扫码器'),
        Icons.health_and_safety,
        onPressed: onOpenAutoDetection,
      ),
    ];

    return _ConsoleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelTitle(
            icon: Icons.tune_rounded,
            title: l10n.t('adminFunctionPanelTitle', '功能列表'),
            subtitle: l10n.t(
              'adminFunctionPanelSubtitle',
              '当前为演示入口，后续接入真实设备能力',
            ),
          ),
          const SizedBox(height: 22),
          Expanded(
            child: ListView.separated(
              itemCount: functions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return _AdminFunctionTile(
                  index: index + 1,
                  item: functions[index],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 管理员功能项。
class _AdminFunctionItem {
  /// 创建管理员功能项。
  const _AdminFunctionItem(
    this.title,
    this.description,
    this.icon, {
    this.onPressed,
  });

  /// 功能标题。
  final String title;

  /// 功能说明。
  final String description;

  /// 功能图标。
  final IconData icon;

  /// 功能项的独立操作；为空时继续展示待接入提示。
  final VoidCallback? onPressed;
}

/// 管理员功能按钮卡片。
class _AdminFunctionTile extends StatelessWidget {
  /// 创建管理员功能按钮卡片。
  const _AdminFunctionTile({required this.index, required this.item});

  /// 功能序号。
  final int index;

  /// 功能配置。
  final _AdminFunctionItem item;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed:
          item.onPressed ??
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.l10n
                      .t('adminFunctionPendingMessage', '{name} 功能待接入真实设备接口')
                      .replaceAll('{name}', item.title),
                ),
              ),
            );
          },
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(18),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimaryColor,
        side: const BorderSide(color: AppTheme.outlineColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(item.icon, color: AppTheme.primaryColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n
                      .t('adminFunctionIndexTitle', '{index}、{title}')
                      .replaceAll('{index}', '$index')
                      .replaceAll('{title}', item.title),
                  style: const TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.description,
                  style: const TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFA7B0CC)),
        ],
      ),
    );
  }
}

/// 控制台通用卡片容器。
class _ConsoleCard extends StatelessWidget {
  /// 创建控制台通用卡片。
  const _ConsoleCard({required this.child});

  /// 卡片内容。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.outlineColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18111B3D),
            blurRadius: 28,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 面板标题。
class _PanelTitle extends StatelessWidget {
  /// 创建面板标题。
  const _PanelTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  /// 标题图标。
  final IconData icon;

  /// 主标题。
  final String title;

  /// 副标题。
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Icon(icon, color: Colors.white, size: 25),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 22,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
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
