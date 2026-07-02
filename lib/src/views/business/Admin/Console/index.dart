import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../components/Layout/TerminalShell/index.dart';
import '../../../../core/camera/camera_binding_service.dart';
import '../../../../core/device/hardware_status_service.dart';
import '../../../../core/device/kiosk_device_provider.dart';
import '../../../../core/storage/app_local_store_provider.dart';
import '../../../../models/admin_model.dart';

/// 管理员控制台页。
class AdminConsolePage extends ConsumerStatefulWidget {
  /// 创建管理员控制台页。
  const AdminConsolePage({super.key});

  @override
  ConsumerState<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends ConsumerState<AdminConsolePage> {
  /// 当前柜体设备状态。
  AdminDeviceStatusModel _deviceStatus = AdminDeviceStatusModel.fallback();

  /// 终端硬件状态服务。
  final HardwareStatusService _hardwareStatusService =
      const HardwareStatusService();

  /// 当前柜体四路摄像头角色绑定。
  Map<CabinetCameraRole, String> _cameraBindings = const {};

  /// 当前系统可选真实摄像头列表。
  List<CabinetCameraDevice> _availableCameras = const [];

  /// 摄像头配置加载状态。
  bool _cameraConfigLoading = true;

  /// 摄像头配置加载失败文案。
  String? _cameraConfigError;

  /// 柜外环境摄像头原生推流状态。
  CameraStreamStatus? _outsideEnvironmentStreamStatus;

  /// 操作区摄像头原生 RTSP-H265 推流状态。
  CameraStreamStatus? _operationAreaStreamStatus;

  /// 摄像头绑定服务。
  final CameraBindingService _cameraBindingService = CameraBindingService();

  /// 当前正在执行的推流控制动作。
  String? _streamProfileAction;

  @override
  void initState() {
    super.initState();
    _loadDeviceStatus();
    _loadCameraConfig();
  }

  /// 加载当前柜体与硬件状态。
  Future<void> _loadDeviceStatus() async {
    final store = await ref.read(appLocalStoreProvider.future);
    final localState = await store.state();
    final hardwareStatus = await _hardwareStatusService.fetchHardwareStatus();
    final deviceStatus = AdminDeviceStatusModel.fromLocalState(
      deviceInfo: localState.deviceInfo,
      hardwareStatus: hardwareStatus,
    );
    if (!mounted) {
      return;
    }
    setState(() => _deviceStatus = deviceStatus);
  }

  /// 加载真实摄像头列表和已保存绑定关系。
  Future<void> _loadCameraConfig() async {
    try {
      final cameras = await _cameraBindingService.loadAvailableCameras();
      final bindings = await _cameraBindingService.loadBindings();
      final outsideEnvironmentStreamStatus = await _cameraBindingService
          .readOutsideEnvironmentStreamStatus();
      final operationAreaStreamStatus = await _cameraBindingService
          .readOperationAreaStreamStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _availableCameras = cameras;
        _cameraBindings = bindings;
        _outsideEnvironmentStreamStatus = outsideEnvironmentStreamStatus;
        _operationAreaStreamStatus = operationAreaStreamStatus;
        _cameraConfigLoading = false;
        _cameraConfigError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraConfigLoading = false;
        _cameraConfigError = '摄像头读取失败：$error';
      });
    }
  }

  /// 打开摄像头角色配置弹窗。
  Future<void> _configureCameraRole(CabinetCameraRole role) async {
    if (_availableCameras.isEmpty) {
      return;
    }

    final selectedCamera = await showDialog<String>(
      context: context,
      builder: (context) => _CameraRoleConfigDialog(
        role: role,
        selectedCameraId: _cameraBindings[role] ?? _availableCameras.first.id,
        availableCameras: _availableCameras,
      ),
    );

    if (selectedCamera == null || !mounted) {
      return;
    }

    await _cameraBindingService.saveBinding(role, selectedCamera);
    final outsideEnvironmentStreamStatus =
        role == CabinetCameraRole.outsideEnvironment
        ? await _cameraBindingService.readOutsideEnvironmentStreamStatus()
        : _outsideEnvironmentStreamStatus;
    final operationAreaStreamStatus = role == CabinetCameraRole.operationArea
        ? await _cameraBindingService.readOperationAreaStreamStatus()
        : _operationAreaStreamStatus;
    if (!mounted) {
      return;
    }
    setState(() {
      _cameraBindings = {..._cameraBindings, role: selectedCamera};
      _outsideEnvironmentStreamStatus = outsideEnvironmentStreamStatus;
      _operationAreaStreamStatus = operationAreaStreamStatus;
    });
  }

  /// 按清晰度启动柜外环境推流。
  Future<void> _startOutsideEnvironmentStreamProfile(String profile) async {
    if (_streamProfileAction != null) {
      return;
    }
    setState(() => _streamProfileAction = 'start:$profile');
    try {
      await ref.read(kioskDeviceProvider).startStreamProfile(profile);
      final status = await _cameraBindingService
          .readOutsideEnvironmentStreamStatus();
      if (!mounted) {
        return;
      }
      setState(() => _outsideEnvironmentStreamStatus = status);
    } finally {
      if (mounted) {
        setState(() => _streamProfileAction = null);
      }
    }
  }

  /// 停止柜外环境当前清晰度推流。
  Future<void> _stopOutsideEnvironmentStreamProfile(String profile) async {
    if (_streamProfileAction != null) {
      return;
    }
    setState(() => _streamProfileAction = 'stop:$profile');
    try {
      await ref.read(kioskDeviceProvider).stopStreamProfile(profile);
      final status = await _cameraBindingService
          .readOutsideEnvironmentStreamStatus();
      if (!mounted) {
        return;
      }
      setState(() => _outsideEnvironmentStreamStatus = status);
    } finally {
      if (mounted) {
        setState(() => _streamProfileAction = null);
      }
    }
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
            colors: [Color(0xFFF8F2F6), Color(0xFFF7FAFF)],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: _DeviceInfoPanel(
                status: _deviceStatus,
                cameraBindings: _cameraBindings,
                availableCameras: _availableCameras,
                cameraConfigLoading: _cameraConfigLoading,
                cameraConfigError: _cameraConfigError,
                outsideEnvironmentStreamStatus: _outsideEnvironmentStreamStatus,
                operationAreaStreamStatus: _operationAreaStreamStatus,
                streamProfileAction: _streamProfileAction,
                onConfigureCamera: _configureCameraRole,
                onStartOutsideEnvironmentStreamProfile:
                    _startOutsideEnvironmentStreamProfile,
                onStopOutsideEnvironmentStreamProfile:
                    _stopOutsideEnvironmentStreamProfile,
              ),
            ),
            const SizedBox(width: 24),
            const Expanded(flex: 4, child: _AdminFunctionPanel()),
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
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF17213D)),
        ),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF17213D),
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
    required this.cameraBindings,
    required this.availableCameras,
    required this.cameraConfigLoading,
    required this.cameraConfigError,
    required this.outsideEnvironmentStreamStatus,
    required this.operationAreaStreamStatus,
    required this.streamProfileAction,
    required this.onConfigureCamera,
    required this.onStartOutsideEnvironmentStreamProfile,
    required this.onStopOutsideEnvironmentStreamProfile,
  });

  /// 当前柜体设备状态。
  final AdminDeviceStatusModel status;

  /// 摄像头角色绑定关系。
  final Map<CabinetCameraRole, String> cameraBindings;

  /// 当前系统可用摄像头列表。
  final List<CabinetCameraDevice> availableCameras;

  /// 摄像头配置是否正在加载。
  final bool cameraConfigLoading;

  /// 摄像头配置加载错误。
  final String? cameraConfigError;

  /// 柜外环境摄像头原生推流状态。
  final CameraStreamStatus? outsideEnvironmentStreamStatus;

  /// 操作区摄像头原生 RTSP-H265 推流状态。
  final CameraStreamStatus? operationAreaStreamStatus;

  /// 当前正在执行的推流控制动作。
  final String? streamProfileAction;

  /// 配置摄像头角色时执行的动作。
  final ValueChanged<CabinetCameraRole> onConfigureCamera;

  /// 按清晰度启动柜外环境推流。
  final ValueChanged<String> onStartOutsideEnvironmentStreamProfile;

  /// 停止柜外环境指定清晰度推流。
  final ValueChanged<String> onStopOutsideEnvironmentStreamProfile;

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
      ...CabinetCameraRole.values.map(
        (role) => _DeviceInfoItem(
          role.label(context),
          _cameraStatusText(context, role),
          Icons.video_camera_front_outlined,
          key: ValueKey('admin_camera_role_${role.name}'),
          onTap: cameraConfigLoading || availableCameras.isEmpty
              ? null
              : () => onConfigureCamera(role),
        ),
      ),
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
    final gridChildren = <Widget>[
      for (final item in items) _DeviceStatusTile(item),
      _OutsideEnvironmentStreamControls(
        status: outsideEnvironmentStreamStatus,
        action: streamProfileAction,
        cameraConfigured:
            cameraBindings[CabinetCameraRole.outsideEnvironment] != null,
        onStartProfile: onStartOutsideEnvironmentStreamProfile,
        onStopProfile: onStopOutsideEnvironmentStreamProfile,
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
              itemCount: gridChildren.length,
              itemBuilder: (context, index) => gridChildren[index],
            ),
          ),
        ],
      ),
    );
  }

  /// 获取摄像头角色卡片状态文案。
  String _cameraStatusText(BuildContext context, CabinetCameraRole role) {
    final l10n = context.l10n;
    if (cameraConfigLoading) {
      return l10n.t('adminCameraLoading', '正在读取摄像头...');
    }
    final error = cameraConfigError;
    if (error != null) {
      return error;
    }
    if (availableCameras.isEmpty) {
      return l10n.t('adminCameraNoDevice', '未检测到可用摄像头');
    }
    final cameraId = cameraBindings[role];
    if (cameraId == null) {
      return l10n.t('adminCameraUnconfigured', '未配置');
    }
    for (final camera in availableCameras) {
      if (camera.id == cameraId) {
        if (role == CabinetCameraRole.outsideEnvironment) {
          final streamStatus = outsideEnvironmentStreamStatus?.status ?? '未启动';
          return '${camera.displayName}\nRTSP-H265：$streamStatus';
        }
        if (role == CabinetCameraRole.operationArea) {
          final streamStatus = operationAreaStreamStatus?.status ?? '未启动';
          return '${camera.displayName}\nRTSP-H265：$streamStatus';
        }
        return camera.displayName;
      }
    }
    return l10n.t('adminCameraMissing', '已绑定摄像头未连接');
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

  /// 点击状态项时执行的动作。
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
    final content = Container(
      key: item.key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EAF6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF8A2364).withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: const Color(0xFF8A2364), size: 28),
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
                    color: Color(0xFF6877A2),
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
                    color: Color(0xFF17213D),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (item.onTap != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    context.l10n.t('adminCameraTapToConfigure', '点击配置'),
                    style: const TextStyle(
                      color: Color(0xFF8A2364),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (item.onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: item.onTap,
        child: content,
      ),
    );
  }
}

/// 柜外环境按需推流控制区。
class _OutsideEnvironmentStreamControls extends StatelessWidget {
  /// 创建柜外环境按需推流控制区。
  const _OutsideEnvironmentStreamControls({
    required this.status,
    required this.action,
    required this.cameraConfigured,
    required this.onStartProfile,
    required this.onStopProfile,
  });

  /// 当前柜外环境推流状态。
  final CameraStreamStatus? status;

  /// 当前正在执行的推流动作。
  final String? action;

  /// 柜外环境摄像头是否已配置。
  final bool cameraConfigured;

  /// 启动指定清晰度推流。
  final ValueChanged<String> onStartProfile;

  /// 停止指定清晰度推流。
  final ValueChanged<String> onStopProfile;

  @override
  Widget build(BuildContext context) {
    final activeProfile = status?.profile ?? '';
    final activeProfiles = activeProfile
        .split(',')
        .map((profile) => profile.trim())
        .where((profile) => profile.isNotEmpty)
        .toSet();
    final statusText = status?.status ?? '未启动';
    final dualMode = status?.streamMode == 'dual_active_profiles';
    final modeText = dualMode ? '双路按需，同时推送720p和1080p' : '独立按需，720p和1080p可分别开关';
    final profiles = const ['720p', '1080p'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9D7E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '柜外环境推流按需加载',
            style: TextStyle(
              color: Color(0xFF17213D),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '当前：${activeProfile.isEmpty ? '未选择清晰度' : activeProfile} · $statusText',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6877A2),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            modeText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF9B6B87),
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: [
              for (final profile in profiles)
                _StreamProfileMiniButton(
                  key: ValueKey('admin_stream_start_$profile'),
                  onPressed: !cameraConfigured || action != null
                      ? null
                      : activeProfiles.contains(profile)
                      ? () => onStopProfile(profile)
                      : () => onStartProfile(profile),
                  label: action == 'start:$profile'
                      ? '启动中'
                      : action == 'stop:$profile'
                      ? '停止中'
                      : activeProfiles.contains(profile)
                      ? '$profile运行中'
                      : profile,
                ),
              _StreamProfileMiniButton(
                key: const ValueKey('admin_stream_stop_active'),
                onPressed: activeProfiles.length != 1 || action != null
                    ? null
                    : () => onStopProfile(activeProfiles.first),
                label:
                    activeProfiles.length == 1 &&
                        action == 'stop:${activeProfiles.first}'
                    ? '停止中'
                    : '停止',
                outlined: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 推流清晰度小按钮。
class _StreamProfileMiniButton extends StatelessWidget {
  /// 创建推流清晰度小按钮。
  const _StreamProfileMiniButton({
    required this.label,
    required this.onPressed,
    this.outlined = false,
    super.key,
  });

  /// 按钮文案。
  final String label;

  /// 点击动作。
  final VoidCallback? onPressed;

  /// 是否使用描边样式。
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final child = Text(label, style: const TextStyle(fontSize: 10));
    final style = ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: const WidgetStatePropertyAll(Size(42, 28)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );

    if (outlined) {
      return OutlinedButton(onPressed: onPressed, style: style, child: child);
    }
    return FilledButton.tonal(onPressed: onPressed, style: style, child: child);
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

/// 摄像头角色配置弹窗。
class _CameraRoleConfigDialog extends StatefulWidget {
  /// 创建摄像头角色配置弹窗。
  const _CameraRoleConfigDialog({
    required this.role,
    required this.selectedCameraId,
    required this.availableCameras,
  });

  /// 正在配置的摄像头角色。
  final CabinetCameraRole role;

  /// 当前已选摄像头 ID。
  final String selectedCameraId;

  /// 当前可选摄像头列表。
  final List<CabinetCameraDevice> availableCameras;

  @override
  State<_CameraRoleConfigDialog> createState() =>
      _CameraRoleConfigDialogState();
}

class _CameraRoleConfigDialogState extends State<_CameraRoleConfigDialog> {
  /// 当前弹窗中选中的摄像头。
  late String _selectedCamera;

  /// 当前预览摄像头控制器。
  CameraController? _previewController;

  /// 当前正在初始化预览的摄像头 ID。
  String? _previewingCameraId;

  /// 预览是否正在初始化。
  bool _previewLoading = false;

  /// 预览初始化失败文案。
  String? _previewError;

  /// 当前是否正在保存配置。
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedCamera = widget.selectedCameraId;
    _initializePreview(_selectedCamera);
  }

  @override
  void dispose() {
    _previewController?.dispose();
    super.dispose();
  }

  /// 保存配置前释放 Flutter 预览，避免原生推流抢占同一路摄像头失败。
  Future<void> _saveSelection() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    final selectedCamera = _selectedCamera;
    final controller = _previewController;
    _previewController = null;
    await controller?.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(selectedCamera);
  }

  /// 初始化当前选中摄像头的实时预览。
  Future<void> _initializePreview(String cameraId) async {
    final camera = _findCamera(cameraId);
    if (camera == null) {
      setState(() {
        _previewLoading = false;
        _previewError = '未找到当前摄像头';
      });
      return;
    }

    setState(() {
      _previewLoading = true;
      _previewError = null;
      _previewingCameraId = cameraId;
    });

    final previousController = _previewController;
    _previewController = null;
    await previousController?.dispose();

    try {
      final controller = CameraController(
        camera.description,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted || _previewingCameraId != cameraId) {
        await controller.dispose();
        return;
      }
      setState(() {
        _previewController = controller;
        _previewLoading = false;
        _previewError = null;
      });
    } catch (error) {
      if (!mounted || _previewingCameraId != cameraId) {
        return;
      }
      setState(() {
        _previewController = null;
        _previewLoading = false;
        _previewError = '摄像头预览启动失败：$error';
      });
    }
  }

  /// 根据摄像头 ID 查找摄像头。
  CabinetCameraDevice? _findCamera(String cameraId) {
    for (final camera in widget.availableCameras) {
      if (camera.id == cameraId) {
        return camera;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final screenSize = MediaQuery.sizeOf(context);
    final maxDialogWidth = screenSize.width - 48;
    final maxDialogHeight = screenSize.height - 48;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxDialogWidth > 760 ? 760 : maxDialogWidth,
          maxHeight: maxDialogHeight,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n
                      .t('adminCameraConfigTitle', '配置 {role}')
                      .replaceAll('{role}', widget.role.label(context)),
                  style: const TextStyle(
                    color: Color(0xFF111936),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.t(
                    'adminCameraConfigSubtitle',
                    '请选择该业务场景要使用的物理摄像头，保存后业务流程会按角色读取配置。',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF6877A2),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: const ValueKey('admin_camera_config_dropdown'),
                  initialValue: _selectedCamera,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.t('adminCameraPhysicalCamera', '物理摄像头'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: widget.availableCameras
                      .map(
                        (camera) => DropdownMenuItem<String>(
                          value: camera.id,
                          child: Text(
                            camera.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  selectedItemBuilder: (context) => widget.availableCameras
                      .map(
                        (camera) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            camera.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _selectedCamera = value);
                    _initializePreview(value);
                  },
                ),
                const SizedBox(height: 12),
                _CameraPreviewPanel(
                  controller: _previewController,
                  loading: _previewLoading,
                  error: _previewError,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.t('adminCameraCancel', '取消')),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _saving ? null : _saveSelection,
                      child: Text(
                        _saving
                            ? l10n.t('adminCameraSaving', '正在保存...')
                            : l10n.t('adminCameraSave', '保存配置'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 摄像头配置弹窗中的实时预览面板。
class _CameraPreviewPanel extends StatelessWidget {
  /// 创建摄像头预览面板。
  const _CameraPreviewPanel({
    required this.controller,
    required this.loading,
    required this.error,
  });

  /// 当前预览控制器。
  final CameraController? controller;

  /// 是否正在初始化预览。
  final bool loading;

  /// 预览错误文案。
  final String? error;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    Widget child;
    if (loading) {
      child = const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(height: 12),
          Text(
            '正在打开摄像头预览...',
            style: TextStyle(
              color: Color(0xFF6877A2),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
    } else if (error != null) {
      child = Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          error!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFE05252),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    } else if (controller != null && controller.value.isInitialized) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: _NaturalCameraPreview(controller: controller),
      );
    } else {
      child = const Text(
        '请选择摄像头后查看实时预览',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF6877A2),
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    return ConstrainedBox(
      key: const ValueKey('admin_camera_preview_panel'),
      constraints: const BoxConstraints(maxHeight: 260),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FBFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4EAF6)),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }
}

/// 按摄像头原始比例显示预览，避免拉伸和误旋转。
class _NaturalCameraPreview extends StatelessWidget {
  /// 创建自然比例摄像头预览。
  const _NaturalCameraPreview({required this.controller});

  /// 当前摄像头控制器。
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    final previewAspectRatio = previewSize == null || previewSize.isEmpty
        ? controller.value.aspectRatio
        : previewSize.width / previewSize.height;

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 640,
          height: 640 / previewAspectRatio,
          child: AspectRatio(
            aspectRatio: previewAspectRatio,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

/// 右侧管理员功能面板。
class _AdminFunctionPanel extends StatelessWidget {
  /// 创建管理员功能面板。
  const _AdminFunctionPanel();

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
  const _AdminFunctionItem(this.title, this.description, this.icon);

  /// 功能标题。
  final String title;

  /// 功能说明。
  final String description;

  /// 功能图标。
  final IconData icon;
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
      onPressed: () {
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
        foregroundColor: const Color(0xFF17213D),
        side: const BorderSide(color: Color(0xFFE4EAF6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF8A2364).withValues(alpha: .08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(item.icon, color: const Color(0xFF8A2364), size: 24),
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
                    color: Color(0xFF17213D),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.description,
                  style: const TextStyle(
                    color: Color(0xFF6877A2),
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
        border: Border.all(color: const Color(0xFFE4EAF6)),
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
            color: const Color(0xFF8A2364),
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
                  color: Color(0xFF111936),
                  fontSize: 22,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF6877A2),
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
