import '../core/device/hardware_status_service.dart';

/// 管理员登录结果模型。
class AdminLoginModel {
  /// 创建管理员登录结果。
  const AdminLoginModel({
    required this.authorized,
    required this.adminName,
    required this.permissionLevel,
    required this.message,
  });

  /// 是否具备管理员权限。
  final bool authorized;

  /// 当前管理员姓名。
  final String adminName;

  /// 管理员权限等级。
  final String permissionLevel;

  /// 权限校验返回说明。
  final String message;

  /// 从接口数据创建登录结果模型。
  factory AdminLoginModel.fromMap(Map<String, Object> map) {
    return AdminLoginModel(
      authorized: map['authorized'] as bool,
      adminName: map['adminName'] as String,
      permissionLevel: map['permissionLevel'] as String,
      message: map['message'] as String,
    );
  }
}

/// 管理员控制台设备状态模型。
class AdminDeviceStatusModel {
  /// 创建设备状态模型。
  const AdminDeviceStatusModel({
    required this.cabinetCode,
    required this.region,
    required this.wifiName,
    required this.rj45Status,
    required this.nfcStatus,
    required this.fingerprintStatus,
    required this.cabinetBoardStatus,
    required this.scannerStatus,
  });

  /// 页面首帧兜底展示数据。
  factory AdminDeviceStatusModel.fallback() {
    return const AdminDeviceStatusModel(
      cabinetCode: 'CAB-A01',
      region: 'A · B 区',
      wifiName: 'SmartCabinet-5G',
      rj45Status: '未连接',
      nfcStatus: '正常 · 读卡器在线',
      fingerprintStatus: '正常 · 指纹模块在线',
      cabinetBoardStatus: '正常 · 12 路柜控板已连接',
      scannerStatus: '正常 · 扫码器待命',
    );
  }

  /// 柜体编号。
  final String cabinetCode;

  /// 柜体所在区域。
  final String region;

  /// 当前连接 WiFi 名称。
  final String wifiName;

  /// 当前 RJ45 连接状态。
  final String rj45Status;

  /// NFC 模块运行状态。
  final String nfcStatus;

  /// 指纹模块运行状态。
  final String fingerprintStatus;

  /// 柜控板连接状态。
  final String cabinetBoardStatus;

  /// 扫码器连接状态。
  final String scannerStatus;

  /// 从接口数据创建设备状态模型。
  factory AdminDeviceStatusModel.fromMap(Map<String, Object> map) {
    return AdminDeviceStatusModel(
      cabinetCode: map['cabinetCode'] as String,
      region: map['region'] as String,
      wifiName: map['wifiName'] as String,
      rj45Status: map['rj45Status'] as String,
      nfcStatus: map['nfcStatus'] as String,
      fingerprintStatus: map['fingerprintStatus'] as String,
      cabinetBoardStatus: map['cabinetBoardStatus'] as String,
      scannerStatus: map['scannerStatus'] as String,
    );
  }

  /// 从本地 Store 和真实硬件状态创建管理员控制台设备状态。
  factory AdminDeviceStatusModel.fromLocalState({
    required Map<String, Object?> deviceInfo,
    required DeviceHardwareStatus hardwareStatus,
  }) {
    final cabinetCode = deviceInfo['唯一设备ID']?.toString() ?? '';
    final wifiName = hardwareStatus.wifiConnected
        ? (hardwareStatus.wifiName.isEmpty
              ? '已连接 WiFi'
              : hardwareStatus.wifiName)
        : '未连接';

    return AdminDeviceStatusModel(
      cabinetCode: cabinetCode.isEmpty ? '未知设备' : cabinetCode,
      region: '未配置',
      wifiName: wifiName,
      rj45Status: hardwareStatus.ethernetConnected ? '已连接' : '未连接',
      nfcStatus: hardwareStatus.nfcAvailable ? '可用' : '不可用',
      fingerprintStatus: hardwareStatus.fingerprintAvailable ? '可用' : '不可用',
      cabinetBoardStatus: '待接入',
      scannerStatus: '待接入',
    );
  }
}
