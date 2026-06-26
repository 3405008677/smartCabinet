/// 智能柜硬件类型。
enum CabinetHardware { camera, fingerprint, nfc, cabinetController }

/// 硬件失败类型。
enum HardwareFailure { permissionDenied, unavailable, timeout, disconnected }

/// 硬件异常恢复建议。
class HardwareRecoveryAdvice {
  /// 创建硬件异常恢复建议。
  const HardwareRecoveryAdvice({
    required this.title,
    required this.description,
    required this.recoverySteps,
  });

  /// 异常标题。
  final String title;

  /// 异常说明。
  final String description;

  /// 现场恢复步骤。
  final String recoverySteps;

  /// 根据硬件和失败类型生成恢复建议。
  factory HardwareRecoveryAdvice.forFailure({
    required CabinetHardware hardware,
    required HardwareFailure failure,
  }) {
    return switch ((hardware, failure)) {
      (CabinetHardware.camera, HardwareFailure.permissionDenied) =>
        const HardwareRecoveryAdvice(
          title: '摄像头权限异常',
          description: '当前无法访问摄像头，不能进行人脸拍照校验。',
          recoverySteps: '到系统设置开启摄像头权限，或联系管理员检查终端权限白名单。',
        ),
      (CabinetHardware.camera, _) => const HardwareRecoveryAdvice(
        title: '摄像头不可用',
        description: '摄像头启动失败或没有检测到可用摄像头。',
        recoverySteps: '检查摄像头连接后点击重试；如仍失败，请重启终端并联系运维。',
      ),
      (CabinetHardware.fingerprint, _) => const HardwareRecoveryAdvice(
        title: '指纹模块不可用',
        description: '当前无法完成指纹认证。',
        recoverySteps: '清洁指纹模块并重新按压；如无响应，请检查指纹模块连接并联系运维。',
      ),
      (CabinetHardware.nfc, HardwareFailure.timeout) =>
        const HardwareRecoveryAdvice(
          title: 'NFC 读取超时',
          description: '未在规定时间内读取到有效 NFC 凭证。',
          recoverySteps: '重新贴近 NFC 读卡区域，保持 1 秒以上；仍失败时请使用备用认证或联系管理员。',
        ),
      (CabinetHardware.nfc, _) => const HardwareRecoveryAdvice(
        title: 'NFC 模块不可用',
        description: '当前无法读取 NFC 凭证。',
        recoverySteps: '重新贴近 NFC 读卡区域；如无响应，请检查 NFC 模块连接并联系运维。',
      ),
      (CabinetHardware.cabinetController, _) => const HardwareRecoveryAdvice(
        title: '柜控板通讯异常',
        description: '应用无法确认柜门控制板状态。',
        recoverySteps: '检查柜控板电源和通讯线，确认指示灯正常后重试；仍异常请切换维护模式。',
      ),
    };
  }
}
