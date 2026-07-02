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

  /// 当前状态是否表示推流失败或正在重连。
  bool get needsUserAttention {
    return isFailureStatus(status);
  }

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
    return CameraStreamStatus(
      status: map['status']?.toString() ?? '未知',
      url: map['url']?.toString() ?? '',
      cameraId: map['cameraId']?.toString() ?? '',
      profile: map['profile']?.toString() ?? '',
      streamMode: map['streamMode']?.toString() ?? '',
    );
  }
}

/// 摄像头枚举、绑定读取和绑定保存服务。
class CameraBindingService {
  /// 创建摄像头绑定服务。
  const CameraBindingService();

  /// Android 原生存储通道。
  static const MethodChannel _channel = MethodChannel('smart_cabinet/kiosk');

  /// 测试环境覆盖的摄像头列表。
  static List<CameraDescription>? _debugCameras;

  /// 测试环境覆盖的绑定关系。
  static Map<CabinetCameraRole, String>? _debugBindings;

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

  /// 读取当前四路摄像头角色绑定关系。
  Future<Map<CabinetCameraRole, String>> loadBindings() async {
    final debugBindings = _debugBindings;
    if (debugBindings != null) {
      return Map<CabinetCameraRole, String>.of(debugBindings);
    }

    final rawBindings = await _channel.invokeMapMethod<String, String>(
      'readCameraBindings',
    );
    final bindings = <CabinetCameraRole, String>{};
    rawBindings?.forEach((roleName, cameraId) {
      final role = _roleFromName(roleName);
      if (role != null && cameraId.isNotEmpty) {
        bindings[role] = cameraId;
      }
    });
    return bindings;
  }

  /// 保存指定业务角色和物理摄像头的绑定关系。
  Future<void> saveBinding(CabinetCameraRole role, String cameraId) async {
    final debugBindings = _debugBindings;
    if (debugBindings != null) {
      debugBindings[role] = cameraId;
      return;
    }

    await _channel.invokeMethod<void>('writeCameraBinding', {
      'role': role.name,
      'cameraId': cameraId,
    });
  }

  /// 读取柜外环境摄像头原生推流状态。
  Future<CameraStreamStatus> readOutsideEnvironmentStreamStatus() async {
    final debugStatus = _debugOutsideEnvironmentStreamStatus;
    if (debugStatus != null) {
      return debugStatus;
    }
    if (_debugBindings != null) {
      return CameraStreamStatus(
        status: '未启动',
        url: '',
        cameraId: _debugBindings?[CabinetCameraRole.outsideEnvironment] ?? '',
      );
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

  /// 读取操作区摄像头原生 RTSP-H265 推流状态。
  Future<CameraStreamStatus> readOperationAreaStreamStatus() async {
    final debugStatus = _debugOperationAreaStreamStatus;
    if (debugStatus != null) {
      return debugStatus;
    }
    if (_debugBindings != null) {
      return CameraStreamStatus(
        status: '未启动',
        url: '',
        cameraId: _debugBindings?[CabinetCameraRole.operationArea] ?? '',
      );
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

    final bindings = await loadBindings();
    final configuredCameraId = bindings[CabinetCameraRole.faceRecognition];
    if (configuredCameraId != null) {
      final configuredCamera = _findById(cameras, configuredCameraId);
      if (configuredCamera != null) {
        return configuredCamera.description;
      }
    }

    final frontCamera = cameras.where(
      (camera) => camera.description.lensDirection == CameraLensDirection.front,
    );
    return frontCamera.isNotEmpty
        ? frontCamera.first.description
        : cameras.first.description;
  }

  /// 设置测试摄像头列表和绑定关系。
  static void debugUseCameraData({
    required List<CameraDescription> cameras,
    Map<CabinetCameraRole, String> bindings = const {},
    CameraStreamStatus? outsideEnvironmentStreamStatus,
    CameraStreamStatus? operationAreaStreamStatus,
  }) {
    _debugCameras = cameras;
    _debugBindings = Map<CabinetCameraRole, String>.of(bindings);
    _debugOutsideEnvironmentStreamStatus = outsideEnvironmentStreamStatus;
    _debugOperationAreaStreamStatus = operationAreaStreamStatus;
  }

  /// 清理测试摄像头覆盖数据。
  static void debugReset() {
    _debugCameras = null;
    _debugBindings = null;
    _debugOutsideEnvironmentStreamStatus = null;
    _debugOperationAreaStreamStatus = null;
    _cachedCameras = null;
  }

  /// 按摄像头 ID 查找设备。
  CabinetCameraDevice? _findById(
    List<CabinetCameraDevice> cameras,
    String cameraId,
  ) {
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

  /// 根据持久化名称还原摄像头角色。
  CabinetCameraRole? _roleFromName(String roleName) {
    for (final role in CabinetCameraRole.values) {
      if (role.name == roleName) {
        return role;
      }
    }
    return null;
  }
}
