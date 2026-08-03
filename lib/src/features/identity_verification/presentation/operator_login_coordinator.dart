import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/routing/app_routes.dart';
import 'package:smart_cabinet/src/core/config/app_config.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/repositories/operator_identity_repository_impl.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_identity_navigation.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_identity_profile.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/repositories/operator_identity_repository.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/widgets/operator_account_login_dialog.dart';
import 'package:smart_cabinet/src/features/task_center/presentation/pages/task_center_page.dart';

/// 打开普通账号登录，并按身份资料状态继续验证、同步或录入流程。
///
/// [replaceCurrent] 用于“身份因子无法识别账号”的兜底入口，避免在旧验证页之上
/// 再堆叠一张新的验证页。
Future<OperatorAccount?> coordinateOperatorAccountLogin(
  BuildContext context, {
  bool replaceCurrent = false,
  OperatorIdentityRepository? repository,
  AppConfig appConfig = AppConfig.current,
}) async {
  final effectiveRepository = repository ?? operatorIdentityRepository;
  final account = await showOperatorAccountLoginDialog(
    context,
    repository: effectiveRepository,
  );
  if (account == null || !context.mounted) {
    return null;
  }
  if (appConfig.isTestMode) {
    await _navigateOperatorFlow(
      context,
      routeName: AppRoutes.taskCenter,
      arguments: TaskCenterArguments(
        account: account.copyWith(
          verifiedFactors: requiredOperatorIdentityFactors,
        ),
      ),
      replaceCurrent: replaceCurrent,
    );
    return account;
  }
  await continueOperatorAccountLogin(
    context,
    account: account,
    replaceCurrent: replaceCurrent,
    repository: effectiveRepository,
  );
  return account;
}

/// 根据指定账号的服务端和本机资料状态继续登录流程。
Future<void> continueOperatorAccountLogin(
  BuildContext context, {
  required OperatorAccount account,
  bool replaceCurrent = false,
  OperatorIdentityRepository? repository,
  AppConfig appConfig = AppConfig.current,
}) async {
  final effectiveRepository = repository ?? operatorIdentityRepository;
  try {
    var profile = await effectiveRepository.loadProfile(account);
    if (!context.mounted) {
      return;
    }

    if (profile.status == OperatorIdentityProfileStatus.requiresSync) {
      profile = await effectiveRepository.syncProfile(account);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.t(
              'operatorIdentitySyncSucceeded',
              '身份资料已同步到本机，请完成人脸、指纹与 NFC 三项认证',
            ),
          ),
        ),
      );
    }

    switch (profile.status) {
      case OperatorIdentityProfileStatus.ready:
        await _navigateOperatorFlow(
          context,
          routeName: AppRoutes.operatorVerification,
          arguments: OperatorVerificationArguments(account: account),
          replaceCurrent: replaceCurrent,
        );
        return;
      case OperatorIdentityProfileStatus.synced:
        await _navigateOperatorFlow(
          context,
          routeName: AppRoutes.operatorVerification,
          arguments: OperatorVerificationArguments(
            account: account,
            requiredFactors: requiredOperatorIdentityFactors,
          ),
          replaceCurrent: replaceCurrent,
        );
        return;
      case OperatorIdentityProfileStatus.missing:
        await _navigateOperatorFlow(
          context,
          routeName: AppRoutes.identityEnrollment,
          arguments: IdentityEnrollmentArguments(
            account: account,
            factors: profile.enrollmentFactors,
          ),
          replaceCurrent: replaceCurrent,
        );
        return;
      case OperatorIdentityProfileStatus.abnormal:
        await _navigateOperatorFlow(
          context,
          routeName: AppRoutes.operatorVerification,
          arguments: OperatorVerificationArguments(
            account: account,
            requiredFactors: requiredOperatorIdentityFactors,
            abnormalRecovery: true,
          ),
          replaceCurrent: replaceCurrent,
        );
        return;
      case OperatorIdentityProfileStatus.requiresSync:
        // 前面已经完成同步；保留分支防止后端仍返回不一致状态时误入验证。
        throw StateError('身份资料同步后仍不可用');
    }
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.t('operatorIdentityFlowFailed', '身份资料处理失败，请稍后重试'),
        ),
      ),
    );
  }
}

/// 按调用来源选择压栈或替换当前身份流程页面。
Future<void> _navigateOperatorFlow(
  BuildContext context, {
  required String routeName,
  required Object arguments,
  required bool replaceCurrent,
}) async {
  if (replaceCurrent) {
    await Navigator.of(
      context,
    ).pushReplacementNamed(routeName, arguments: arguments);
    return;
  }
  await Navigator.of(context).pushNamed(routeName, arguments: arguments);
}
