/// 智能柜硬件设备抽象。
///
/// 这里定义业务层需要关心的柜体设备能力。
/// 具体实现可以来自 Android 原生、串口、蓝牙、网络接口等。
abstract interface class CabinetDevice {
  /// 检查柜体设备当前是否可用。
  Future<bool> isAvailable();
}
