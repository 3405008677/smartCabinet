import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

/// 智能柜摄像头业务角色。
enum CabinetCameraRole {
  /// 人脸识别摄像头。
  faceRecognition,

  /// 柜外环境摄像头。
  outsideEnvironment,

  /// 操作区摄像头。
  operationArea,

  /// 合格证采集摄像头。
  certificateCapture,
}

/// 摄像头当前使用模式。
enum CabinetCameraUseMode { previewAndCapture, rtspStream, stillCapture }

/// 原生推流状态机。
enum CameraStreamState {
  stopped,
  starting,
  streaming,
  reconnecting,
  failed,
  stopping,
  unconfigured,
  unknown,
}

/// 摄像头角色绑定配置。
class CabinetCameraRoleBinding {
  /// 创建摄像头角色绑定配置。
  const CabinetCameraRoleBinding({
    required this.role,
    required this.required,
    required this.useMode,
    this.flutterCameraId,
    this.androidCameraId,
  });

  /// 业务角色。
  final CabinetCameraRole role;

  /// Flutter camera 插件 ID。
  final String? flutterCameraId;

  /// Android Camera2 ID。
  final String? androidCameraId;

  /// 该角色是否为启动必需。
  final bool required;

  /// 摄像头使用模式。
  final CabinetCameraUseMode useMode;

  /// 该角色是否已经配置到可用的摄像头 ID。
  bool get isConfigured {
    return switch (useMode) {
      CabinetCameraUseMode.previewAndCapture ||
      CabinetCameraUseMode.stillCapture => flutterCameraId?.isNotEmpty == true,
      CabinetCameraUseMode.rtspStream => androidCameraId?.isNotEmpty == true,
    };
  }
}

/// 开发时指定的四路摄像头配置。
///
/// 需要更换摄像头时只改这里，不再通过管理员控制台配置。
class CabinetCameraConfig {
  const CabinetCameraConfig._();

  /// 人脸识别摄像头 ID，对应 Flutter camera 插件的 CameraDescription.name。
  static const String faceRecognitionCameraId = 'cameraId_0';

  /// 柜外环境摄像头 ID，对应 Android Camera2 cameraId。
  static const String outsideEnvironmentCameraId = '0';

  /// 操作区域摄像头 ID，对应 Android Camera2 cameraId。
  static const String operationAreaCameraId = '';

  /// 合格证采集摄像头 ID，对应 Flutter camera 插件的 CameraDescription.name。
  static const String certificateCaptureCameraId = 'cameraId_2';

  /// 开发时指定的角色绑定。
  static const List<CabinetCameraRoleBinding> roleBindings = [
    CabinetCameraRoleBinding(
      role: CabinetCameraRole.faceRecognition,
      flutterCameraId: faceRecognitionCameraId,
      required: true,
      useMode: CabinetCameraUseMode.previewAndCapture,
    ),
    CabinetCameraRoleBinding(
      role: CabinetCameraRole.outsideEnvironment,
      androidCameraId: outsideEnvironmentCameraId,
      required: true,
      useMode: CabinetCameraUseMode.rtspStream,
    ),
    CabinetCameraRoleBinding(
      role: CabinetCameraRole.operationArea,
      androidCameraId: operationAreaCameraId,
      required: false,
      useMode: CabinetCameraUseMode.rtspStream,
    ),
    CabinetCameraRoleBinding(
      role: CabinetCameraRole.certificateCapture,
      flutterCameraId: certificateCaptureCameraId,
      required: false,
      useMode: CabinetCameraUseMode.stillCapture,
    ),
  ];

  /// 按业务角色读取绑定配置。
  static CabinetCameraRoleBinding bindingFor(CabinetCameraRole role) {
    return roleBindings.firstWhere((binding) => binding.role == role);
  }
}

/// 业务可展示和可保存的摄像头设备信息。
class CabinetCameraDevice {
  /// 创建摄像头设备信息。
  const CabinetCameraDevice({
    required this.id,
    required this.displayName,
    required this.description,
  });

  /// 摄像头稳定标识，来自 Flutter camera 插件的 [CameraDescription.name]。
  final String id;

  /// 管理员控制台展示名称。
  final String displayName;

  /// Flutter camera 插件返回的原始摄像头描述。
  final CameraDescription description;
}

/// 业务摄像头原生推流状态。
class CameraStreamStatus {
  /// 创建业务摄像头原生推流状态。
  const CameraStreamStatus({
    required this.status,
    required this.url,
    required this.cameraId,
    this.profile = '',
    this.streamMode = '',
    this.role,
    this.state = CameraStreamState.unknown,
    this.recoverable = false,
    this.reconnectAttempts = 0,
  });

  /// 当前推流状态文案。
  final String status;

  /// 当前原生层使用的 RTSP 推流地址。
  final String url;

  /// 当前绑定的摄像头 ID。
  final String cameraId;

  /// 当前正在推流的清晰度。
  final String profile;

  /// 当前推流能力模式，例如单路按需或多路并发。
  final String streamMode;

  /// 当前推流所属摄像头角色。
  final CabinetCameraRole? role;

  /// 结构化推流状态。
  final CameraStreamState state;

  /// 当前异常是否可恢复。
  final bool recoverable;

  /// 已重连次数。
  final int reconnectAttempts;

  /// 当前状态是否表示推流失败或正在重连。
  bool get needsUserAttention {
    return state == CameraStreamState.failed ||
        state == CameraStreamState.reconnecting ||
        recoverable ||
        isFailureStatus(status);
  }

  /// 当前角色是否未配置。
  bool get isUnconfigured => state == CameraStreamState.unconfigured;

  /// 判断状态文案是否表示推流失败或重连中。
  static bool isFailureStatus(String status) {
    return status.contains('失败') ||
        status.contains('错误') ||
        status.contains('断开') ||
        status.contains('重连') ||
        status.toLowerCase().contains('failed') ||
        status.toLowerCase().contains('error') ||
        status.toLowerCase().contains('reconnect');
  }

  /// 从原生通道返回的 Map 创建状态对象。
  factory CameraStreamStatus.fromMap(Map<String, Object?> map) {
    final status = map['status']?.toString() ?? '未知';
    return CameraStreamStatus(
      status: status,
      url: map['url']?.toString() ?? '',
      cameraId: map['cameraId']?.toString() ?? '',
      profile: map['profile']?.toString() ?? '',
      streamMode: map['streamMode']?.toString() ?? '',
      role: _parseRole(map['role']?.toString()),
      state: _parseState(map['state']?.toString(), status),
      recoverable:
          map['recoverable'] == true ||
          map['recoverable']?.toString().toLowerCase() == 'true',
      reconnectAttempts:
          int.tryParse(map['reconnectAttempts']?.toString() ?? '') ?? 0,
    );
  }

  static CabinetCameraRole? _parseRole(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    for (final role in CabinetCameraRole.values) {
      if (role.name == value) {
        return role;
      }
    }
    return null;
  }

  static CameraStreamState _parseState(String? value, String status) {
    if (value != null && value.isNotEmpty) {
      for (final state in CameraStreamState.values) {
        if (state.name == value) {
          return state;
        }
      }
    }
    if (status.contains('未指定') || status.contains('未配置')) {
      return CameraStreamState.unconfigured;
    }
    if (status.contains('重连') || status.toLowerCase().contains('reconnect')) {
      return CameraStreamState.reconnecting;
    }
    if (isFailureStatus(status)) {
      return CameraStreamState.failed;
    }
    if (status.contains('启动中') || status.contains('打开中')) {
      return CameraStreamState.starting;
    }
    if (status.contains('停止')) {
      return CameraStreamState.stopped;
    }
    if (status.contains('推流中') || status.contains('已开始')) {
      return CameraStreamState.streaming;
    }
    if (status.contains('未启动')) {
      return CameraStreamState.stopped;
    }
    return CameraStreamState.unknown;
  }
}

/// 摄像头枚举和开发时指定摄像头解析服务。
class CabinetCameraService {
  /// 创建摄像头服务。
  const CabinetCameraService();

  /// Android 原生存储通道。
  static const MethodChannel _channel = MethodChannel('smart_cabinet/kiosk');

  /// 测试环境覆盖的摄像头列表。
  static List<CameraDescription>? _debugCameras;

  /// 测试环境覆盖的柜外环境推流状态。
  static CameraStreamStatus? _debugOutsideEnvironmentStreamStatus;

  /// 测试环境覆盖的操作区推流状态。
  static CameraStreamStatus? _debugOperationAreaStreamStatus;

  /// 启动阶段缓存的真实摄像头列表。
  static List<CabinetCameraDevice>? _cachedCameras;

  /// 枚举当前系统真实摄像头列表。
  Future<List<CabinetCameraDevice>> loadAvailableCameras({
    bool forceReload = false,
  }) async {
    final debugCameras = _debugCameras;
    if (debugCameras != null) {
      return _mapCameraDescriptions(debugCameras);
    }

    final cachedCameras = _cachedCameras;
    if (!forceReload && cachedCameras != null) {
      return List<CabinetCameraDevice>.unmodifiable(cachedCameras);
    }

    final cameras = _mapCameraDescriptions(await availableCameras());
    _cachedCameras = List<CabinetCameraDevice>.unmodifiable(cameras);
    return cameras;
  }

  /// 将插件摄像头描述转换为业务摄像头对象。
  List<CabinetCameraDevice> _mapCameraDescriptions(
    List<CameraDescription> cameras,
  ) {
    return [
      for (var index = 0; index < cameras.length; index += 1)
        CabinetCameraDevice(
          id: cameras[index].name,
          displayName: _buildDisplayName(index, cameras[index]),
          description: cameras[index],
        ),
    ];
  }

  /// 读取柜外环境摄像头原生推流状态。
  Future<CameraStreamStatus> readOutsideEnvironmentStreamStatus() async {
    final debugStatus = _debugOutsideEnvironmentStreamStatus;
    if (debugStatus != null) {
      return debugStatus;
    }
    if (_debugCameras != null) {
      return const CameraStreamStatus(status: '未启动', url: '', cameraId: '');
    }
    final rawStatus = await _channel.invokeMapMethod<String, Object?>(
      'readOutsideEnvironmentStreamStatus',
    );
    return CameraStreamStatus.fromMap(
      rawStatus == null
          ? const <String, Object?>{}
          : Map<String, Object?>.of(rawStatus),
    );
  }

  /// 按角色读取原生推流状态。
  Future<CameraStreamStatus> readStreamStatus(CabinetCameraRole role) {
    return switch (role) {
      CabinetCameraRole.outsideEnvironment =>
        readOutsideEnvironmentStreamStatus(),
      CabinetCameraRole.operationArea => readOperationAreaStreamStatus(),
      _ => Future.value(
        CameraStreamStatus(
          role: role,
          state: CameraStreamState.unconfigured,
          status: '该摄像头角色不支持原生推流',
          url: '',
          cameraId: '',
        ),
      ),
    };
  }

  /// 读取操作区摄像头原生 RTSP-H265 推流状态。
  Future<CameraStreamStatus> readOperationAreaStreamStatus() async {
    final debugStatus = _debugOperationAreaStreamStatus;
    if (debugStatus != null) {
      return debugStatus;
    }
    if (_debugCameras != null) {
      return const CameraStreamStatus(status: '未启动', url: '', cameraId: '');
    }
    final rawStatus = await _channel.invokeMapMethod<String, Object?>(
      'readOperationAreaStreamStatus',
    );
    return CameraStreamStatus.fromMap(
      rawStatus == null
          ? const <String, Object?>{}
          : Map<String, Object?>.of(rawStatus),
    );
  }

  /// 选择人脸识别应使用的摄像头。
  Future<CameraDescription?> resolveFaceRecognitionCamera() async {
    final cameras = await loadAvailableCameras();
    if (cameras.isEmpty) {
      return null;
    }

    final configuredCamera = _findById(
      cameras,
      CabinetCameraConfig.faceRecognitionCameraId,
    );
    if (configuredCamera != null) {
      return configuredCamera.description;
    }

    final frontCamera = cameras.where(
      (camera) => camera.description.lensDirection == CameraLensDirection.front,
    );
    return frontCamera.isNotEmpty
        ? frontCamera.first.description
        : cameras.first.description;
  }

  /// 设置测试摄像头列表和推流状态。
  static void debugUseCameraData({
    required List<CameraDescription> cameras,
    CameraStreamStatus? outsideEnvironmentStreamStatus,
    CameraStreamStatus? operationAreaStreamStatus,
  }) {
    _debugCameras = cameras;
    _debugOutsideEnvironmentStreamStatus = outsideEnvironmentStreamStatus;
    _debugOperationAreaStreamStatus = operationAreaStreamStatus;
  }

  /// 清理测试摄像头覆盖数据。
  static void debugReset() {
    _debugCameras = null;
    _debugOutsideEnvironmentStreamStatus = null;
    _debugOperationAreaStreamStatus = null;
    _cachedCameras = null;
  }

  /// 按摄像头 ID 查找设备。
  CabinetCameraDevice? _findById(
    List<CabinetCameraDevice> cameras,
    String cameraId,
  ) {
    if (cameraId.isEmpty) {
      return null;
    }
    for (final camera in cameras) {
      if (camera.id == cameraId) {
        return camera;
      }
    }
    return null;
  }

  /// 将原始摄像头信息转换成管理员可读的名称。
  String _buildDisplayName(int index, CameraDescription camera) {
    final directionName = switch (camera.lensDirection) {
      CameraLensDirection.front => '前置',
      CameraLensDirection.back => '后置',
      CameraLensDirection.external => '外接',
    };
    final lensTypeName = switch (camera.lensType) {
      CameraLensType.wide => '广角',
      CameraLensType.telephoto => '长焦',
      CameraLensType.ultraWide => '超广角',
      CameraLensType.unknown => '标准',
    };
    return '${camera.name} · $directionName · $lensTypeName · ${camera.sensorOrientation}° · #${index + 1}';
  }
}
