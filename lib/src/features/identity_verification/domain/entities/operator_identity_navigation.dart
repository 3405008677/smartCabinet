import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';

/// 统一身份校验页的公开路由参数。
class OperatorVerificationArguments {
  /// 创建身份校验路由参数。
  const OperatorVerificationArguments({
    this.account,
    this.initialVerifiedFactors = const <IdentityFactor>{},
    this.requiredFactors,
    this.abnormalRecovery = false,
  });

  /// 已通过账号登录确认的操作员；为空时由首个身份因子识别账号。
  final OperatorAccount? account;

  /// 进入页面前已经通过的身份因子。
  final Set<IdentityFactor> initialVerifiedFactors;

  /// 必须全部通过的身份因子；为空时执行人脸、指纹与 NFC 三项全验策略。
  final Set<IdentityFactor>? requiredFactors;

  /// 是否正在复核本机异常资料。
  ///
  /// 该模式下只有所有必选因子均再次失败，才会报备并转入重新录入。
  final bool abnormalRecovery;
}

/// 人脸、指纹录入页的公开路由参数。
class IdentityEnrollmentArguments {
  /// 创建身份资料录入路由参数。
  const IdentityEnrollmentArguments({
    required this.account,
    required this.factors,
    this.abnormalReported = false,
  });

  /// 需要录入身份资料的操作员。
  final OperatorAccount account;

  /// 本次需要录入或重录的人脸、指纹因子。
  final Set<IdentityFactor> factors;

  /// 进入录入页前是否已经完成异常报备。
  final bool abnormalReported;
}
