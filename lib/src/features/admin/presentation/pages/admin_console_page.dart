import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/shell/app_shell.dart';
import 'package:smart_cabinet/src/core/camera/cabinet_camera.dart';
import 'package:smart_cabinet/src/core/device/hardware_status_service.dart';
import 'package:smart_cabinet/src/core/storage/app_local_store_provider.dart';
import 'package:smart_cabinet/src/features/admin/domain/entities/admin.dart';

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

  /// 终端硬件状态服务。
  final HardwareStatusService _hardwareStatusService =
      const HardwareStatusService();

  /// 摄像头配置加载状态。
  bool _cameraConfigLoading = true;

  /// 摄像头配置加载失败文案。
  String? _cameraConfigError;

  /// 柜外环境摄像头原生推流状态。
  CameraStreamStatus? _outsideEnvironmentStreamStatus;

  /// 操作区摄像头原生 RTSP-H265 推流状态。
  CameraStreamStatus? _operationAreaStreamStatus;

  /// 当前系统枚举到的摄像头列表。
  List<CabinetCameraDevice> _availableCameras = const [];

  /// 摄像头绑定服务。
  final CabinetCameraService _cameraService = const CabinetCameraService();

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
    final deviceStatus = AdminDeviceStatus.fromLocalState(
      deviceInfo: localState.deviceInfo,
      hardwareStatus: hardwareStatus,
    );
    if (!mounted) {
      return;
    }
    setState(() => _deviceStatus = deviceStatus);
  }

  /// 加载摄像头推流状态。
  Future<void> _loadCameraConfig() async {
    try {
      final availableCameras = await _cameraService.loadAvailableCameras();
      final outsideEnvironmentStreamStatus = await _cameraService
          .readOutsideEnvironmentStreamStatus();
      final operationAreaStreamStatus = await _cameraService
          .readOperationAreaStreamStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _availableCameras = availableCameras;
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
                cameraConfigLoading: _cameraConfigLoading,
                cameraConfigError: _cameraConfigError,
                availableCameras: _availableCameras,
                outsideEnvironmentStreamStatus: _outsideEnvironmentStreamStatus,
                operationAreaStreamStatus: _operationAreaStreamStatus,
                onOpenCameraPreview: _openCameraPreview,
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
    required this.cameraConfigLoading,
    required this.cameraConfigError,
    required this.availableCameras,
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
    final gridChildren = <Widget>[
      for (final item in items) _DeviceStatusTile(item),
      _OutsideEnvironmentStreamControls(status: outsideEnvironmentStreamStatus),
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
    if (role == CabinetCameraRole.outsideEnvironment) {
      final streamStatus = outsideEnvironmentStreamStatus?.status ?? '未启动';
      return '${_cameraConnectionText(role)}\nRTSP-H265：$streamStatus';
    }
    if (role == CabinetCameraRole.operationArea) {
      if (!CabinetCameraConfig.bindingFor(role).isConfigured) {
        return '未配置\nRTSP-H265：未启用';
      }
      final streamStatus = operationAreaStreamStatus?.status ?? '未启动';
      return '${_cameraConnectionText(role)}\nRTSP-H265：$streamStatus';
    }
    return _cameraConnectionText(role);
  }

  /// 判断开发绑定的摄像头当前是否能被系统枚举到。
  String _cameraConnectionText(CabinetCameraRole role) {
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _lifecycleActive =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    if (_lifecycleActive) {
      unawaited(_initializePreview());
    }
  }

  @override
  void didUpdateWidget(covariant _AdminCameraPreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.camera.id != widget.camera.id && _lifecycleActive) {
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
    unawaited(_releaseControllers(invalidate: true));
    super.dispose();
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
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      candidate = controller;
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
        _message = '预览已启动';
      });
    } catch (error) {
      if (identical(_initializingController, candidate)) {
        _initializingController = null;
      }
      await _disposeControllerSerially(candidate);
      if (_isPreviewRequestCurrent(generation)) {
        setState(() => _message = '预览启动失败：$error');
      }
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
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(24),
      ),
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
                    color: Color(0xFF17213D),
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
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Color(0xFF10182E)),
                child: controller != null && controller.value.isInitialized
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
          Text(
            '摄像头ID：${widget.camera.id} · $_message',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6877A2),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 柜外环境按需推流控制区。
class _OutsideEnvironmentStreamControls extends StatelessWidget {
  /// 创建柜外环境按需推流控制区。
  const _OutsideEnvironmentStreamControls({required this.status});

  /// 当前柜外环境推流状态。
  final CameraStreamStatus? status;

  @override
  Widget build(BuildContext context) {
    final activeProfile = status?.profile ?? '';
    final statusText = status?.status ?? '未启动';
    final dualMode = status?.streamMode == 'dual_active_profiles';
    final modeText = dualMode ? 'MQTT指令已触发双路推流' : '仅允许MQTT指令触发推流';

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
            '柜外环境推流由MQTT控制',
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
          const Text(
            '管理员控制台仅查看状态，不提供推流启动入口',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFF9B6B87),
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
