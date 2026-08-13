import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/core/device/hardware_recovery_advice.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_identity_profile.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/repositories/operator_identity_repository.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/identity_result_localizer.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/operator_login_error_localizer.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/widgets/localized_hardware_recovery_advice.dart';

const _account = OperatorAccount(
  id: 'operator-localization',
  username: '100001',
  name: '测试操作员',
  organizationId: 'org-localization',
  organizationName: '测试机构',
);

const _profile = OperatorIdentityProfile(
  account: _account,
  status: OperatorIdentityProfileStatus.ready,
  remoteFactors: <IdentityFactor>{...IdentityFactor.values},
  localFactors: <IdentityFactor>{...IdentityFactor.values},
);

void main() {
  group('identity result localization', () {
    for (final language in AppLanguage.values) {
      test('${language.name} maps known and unknown verification results', () {
        final l10n = AppLocalizations(language);

        final success = localizeIdentityVerificationResult(
          l10n,
          factor: IdentityFactor.face,
          result: const IdentityFactorVerificationResult(
            success: true,
            message: '人脸识别通过',
          ),
        );
        expect(
          success,
          l10n
              .t('operatorFactorVerificationSucceeded', '{factor}识别通过')
              .replaceAll('{factor}', l10n.t('operatorFactorFaceName', '人脸')),
        );

        const unknownMessage = '后端返回的未知中文认证错误';
        final unknownFailure = localizeIdentityVerificationResult(
          l10n,
          factor: IdentityFactor.fingerprint,
          result: const IdentityFactorVerificationResult(
            success: false,
            message: unknownMessage,
          ),
        );
        expect(unknownFailure, isNot(unknownMessage));
        expect(
          unknownFailure,
          l10n.t('operatorFactorVerificationFailed', '身份识别失败，请重试或改用其他方式'),
        );
      });

      test('${language.name} maps known and unknown enrollment results', () {
        final l10n = AppLocalizations(language);

        final success = localizeIdentityEnrollmentResult(
          l10n,
          factor: IdentityFactor.fingerprint,
          result: const IdentityEnrollmentResult(
            success: true,
            message: '指纹录入成功',
            profile: _profile,
          ),
        );
        expect(
          success,
          l10n
              .t('operatorEnrollmentFactorResultSucceeded', '{factor}录入成功')
              .replaceAll(
                '{factor}',
                l10n.t('operatorFactorFingerprintName', '指纹'),
              ),
        );

        const unknownMessage = '后端返回的未知中文录入错误';
        final unknownFailure = localizeIdentityEnrollmentResult(
          l10n,
          factor: IdentityFactor.face,
          result: const IdentityEnrollmentResult(
            success: false,
            message: unknownMessage,
            profile: _profile,
          ),
        );
        expect(unknownFailure, isNot(unknownMessage));
        expect(
          unknownFailure,
          l10n.t('operatorEnrollmentFailed', '身份资料录入失败，请检查设备后重试'),
        );
      });
    }
  });

  test('hardware recovery advice follows the selected language', () {
    const nonChineseLanguages = <AppLanguage>[
      AppLanguage.traditionalChinese,
      AppLanguage.english,
      AppLanguage.japanese,
    ];
    const failures = <(CabinetHardware, HardwareFailure)>[
      (CabinetHardware.camera, HardwareFailure.permissionDenied),
      (CabinetHardware.camera, HardwareFailure.unavailable),
      (CabinetHardware.fingerprint, HardwareFailure.unavailable),
      (CabinetHardware.nfc, HardwareFailure.timeout),
      (CabinetHardware.nfc, HardwareFailure.unavailable),
      (CabinetHardware.cabinetController, HardwareFailure.disconnected),
    ];

    for (final language in nonChineseLanguages) {
      final l10n = AppLocalizations(language);
      for (final failure in failures) {
        final raw = HardwareRecoveryAdvice.forFailure(
          hardware: failure.$1,
          failure: failure.$2,
        );
        final localized = localizeHardwareRecoveryAdvice(l10n, raw);
        expect(localized.title, isNot(raw.title));
        expect(localized.description, isNot(raw.description));
        expect(localized.recoverySteps, isNot(raw.recoverySteps));
      }
    }
  });

  test('local login failures are localized while server messages are kept', () {
    for (final language in AppLanguage.values) {
      final l10n = AppLocalizations(language);
      expect(
        localizeOperatorLoginError(
          l10n,
          const OperatorLoginException('本机超时消息', code: 'timeout'),
        ),
        l10n.t('operatorLoginTimeout', '连接 AFRR 登录服务超时，请检查柜机网络后重试'),
      );
      expect(
        localizeOperatorLoginError(
          l10n,
          const OperatorLoginException('本机配置消息', code: 'invalid_server_config'),
        ),
        l10n.t('operatorLoginInvalidServerConfig', 'AFRR 登录参数无效，请联系管理员检查终端配置'),
      );
      expect(
        localizeOperatorLoginError(
          l10n,
          const OperatorLoginException('本机断线消息', code: 'network_unavailable'),
        ),
        l10n.t(
          'operatorLoginNetworkUnavailable',
          '无法连接 AFRR 登录服务，请检查柜机网络和服务状态',
        ),
      );
      expect(
        localizeOperatorLoginError(
          l10n,
          const OperatorLoginException(
            'platform-message-for-requested-language',
            code: 'E1001',
          ),
        ),
        'platform-message-for-requested-language',
      );
    }
  });
}
