import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/core/device/hardware_recovery_advice.dart';

/// 已转换为当前界面语言的硬件恢复建议。
class LocalizedHardwareRecoveryAdvice {
  /// 创建本地化硬件恢复建议。
  const LocalizedHardwareRecoveryAdvice({
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
}

/// 按核心层生成的稳定建议类型转换为当前界面语言。
LocalizedHardwareRecoveryAdvice localizeHardwareRecoveryAdvice(
  AppLocalizations l10n,
  HardwareRecoveryAdvice advice,
) {
  return switch (advice.title) {
    '摄像头权限异常' => LocalizedHardwareRecoveryAdvice(
      title: l10n.t('hardwareCameraPermissionTitle', '摄像头权限异常'),
      description: l10n.t(
        'hardwareCameraPermissionDescription',
        '当前无法访问摄像头，不能进行人脸拍照校验。',
      ),
      recoverySteps: l10n.t(
        'hardwareCameraPermissionSteps',
        '到系统设置开启摄像头权限，或联系管理员检查终端权限白名单。',
      ),
    ),
    '摄像头不可用' => LocalizedHardwareRecoveryAdvice(
      title: l10n.t('hardwareCameraUnavailableTitle', '摄像头不可用'),
      description: l10n.t(
        'hardwareCameraUnavailableDescription',
        '摄像头启动失败或没有检测到可用摄像头。',
      ),
      recoverySteps: l10n.t(
        'hardwareCameraUnavailableSteps',
        '检查摄像头连接后点击重试；如仍失败，请重启终端并联系运维。',
      ),
    ),
    '指纹模块不可用' => LocalizedHardwareRecoveryAdvice(
      title: l10n.t('hardwareFingerprintUnavailableTitle', '指纹模块不可用'),
      description: l10n.t(
        'hardwareFingerprintUnavailableDescription',
        '当前无法完成指纹认证。',
      ),
      recoverySteps: l10n.t(
        'hardwareFingerprintUnavailableSteps',
        '清洁指纹模块并重新按压；如无响应，请检查指纹模块连接并联系运维。',
      ),
    ),
    'NFC 读取超时' => LocalizedHardwareRecoveryAdvice(
      title: l10n.t('hardwareNfcTimeoutTitle', 'NFC 读取超时'),
      description: l10n.t(
        'hardwareNfcTimeoutDescription',
        '未在规定时间内读取到有效 NFC 凭证。',
      ),
      recoverySteps: l10n.t(
        'hardwareNfcTimeoutSteps',
        '重新贴近 NFC 读卡区域，保持 1 秒以上；仍失败时请使用备用认证或联系管理员。',
      ),
    ),
    'NFC 模块不可用' => LocalizedHardwareRecoveryAdvice(
      title: l10n.t('hardwareNfcUnavailableTitle', 'NFC 模块不可用'),
      description: l10n.t(
        'hardwareNfcUnavailableDescription',
        '当前无法读取 NFC 凭证。',
      ),
      recoverySteps: l10n.t(
        'hardwareNfcUnavailableSteps',
        '重新贴近 NFC 读卡区域；如无响应，请检查 NFC 模块连接并联系运维。',
      ),
    ),
    '柜控板通讯异常' => LocalizedHardwareRecoveryAdvice(
      title: l10n.t('hardwareCabinetControllerTitle', '柜控板通讯异常'),
      description: l10n.t(
        'hardwareCabinetControllerDescription',
        '应用无法确认柜门控制板状态。',
      ),
      recoverySteps: l10n.t(
        'hardwareCabinetControllerSteps',
        '检查柜控板电源和通讯线，确认指示灯正常后重试；仍异常请切换维护模式。',
      ),
    ),
    _ => LocalizedHardwareRecoveryAdvice(
      title: advice.title,
      description: advice.description,
      recoverySteps: advice.recoverySteps,
    ),
  };
}
