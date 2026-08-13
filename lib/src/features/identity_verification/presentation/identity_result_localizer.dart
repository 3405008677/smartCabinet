import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_identity_profile.dart';

/// 将身份因子认证结果转换为当前界面语言。
String localizeIdentityVerificationResult(
  AppLocalizations l10n, {
  required IdentityFactor factor,
  required IdentityFactorVerificationResult result,
}) {
  if (result.success) {
    return l10n
        .t('operatorFactorVerificationSucceeded', '{factor}识别通过')
        .replaceAll('{factor}', _localizedFactorName(l10n, factor));
  }
  if (result.message == '当前身份资料不可用，请改用其他方式或重新录入') {
    return l10n.t('operatorFactorProfileUnavailable', '当前身份资料不可用，请改用其他方式或重新录入');
  }
  return l10n.t('operatorFactorVerificationFailed', '身份识别失败，请重试或改用其他方式');
}

/// 将身份因子录入结果转换为当前界面语言。
String localizeIdentityEnrollmentResult(
  AppLocalizations l10n, {
  required IdentityFactor factor,
  required IdentityEnrollmentResult result,
}) {
  if (result.success) {
    return l10n
        .t('operatorEnrollmentFactorResultSucceeded', '{factor}录入成功')
        .replaceAll('{factor}', _localizedFactorName(l10n, factor));
  }
  if (result.message == 'NFC 凭证不在本次录入范围内') {
    return l10n.t('operatorEnrollmentNfcUnsupported', 'NFC 凭证不在本次录入范围内');
  }
  return l10n.t('operatorEnrollmentFailed', '身份资料录入失败，请检查设备后重试');
}

/// 返回身份因子的当前语言短名称。
String _localizedFactorName(AppLocalizations l10n, IdentityFactor factor) {
  return switch (factor) {
    IdentityFactor.face => l10n.t('operatorFactorFaceName', '人脸'),
    IdentityFactor.fingerprint => l10n.t('operatorFactorFingerprintName', '指纹'),
    IdentityFactor.nfc => 'NFC',
  };
}
