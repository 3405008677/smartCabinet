import 'package:smart_cabinet/src/core/camera/cabinet_camera.dart';

/// 自助终端模式设备能力抽象。
///
/// Kiosk Mode 通常用于智能柜、收银机等固定用途设备，
/// 可以限制用户离开当前应用，避免误触系统桌面或其它应用。
abstract interface class KioskDevice {
  /// 进入自助终端锁定模式。
  Future<bool> enterKioskMode();

  /// 退出自助终端锁定模式。
  Future<bool> exitKioskMode();

  /// 查询当前是否已经处于自助终端锁定模式。
  Future<bool> isKioskModeActive();

  /// 查询当前应用是否是 Android 设备所有者。
  ///
  /// 某些 Kiosk 能力需要 Device Owner 权限才能完整使用。
  Future<bool> isDeviceOwner();

  /// 打开系统设置页。
  ///
  /// 当需要用户手动授权或排查设备配置时可以调用。
  Future<void> openSystemSettings();

  /// 按业务角色启动原生推流。
  Future<void> startCameraStream(
    CabinetCameraRole role, {
    required List<String> profiles,
  });

  /// 按业务角色停止原生推流。
  Future<void> stopCameraStream(
    CabinetCameraRole role, {
    List<String>? profiles,
  });

  /// 原子地保留当前启用清晰度并重试指定角色的原生推流。
  ///
  /// 返回实际被重试的清晰度；没有可重试配置时抛出平台异常。
  Future<List<String>> retryCameraStream(CabinetCameraRole role);
}
