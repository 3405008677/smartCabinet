import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';

/// 操作员身份资料在当前终端上的可用状态。
enum OperatorIdentityProfileStatus {
  /// 服务端与本机资料均可直接认证。
  ready,

  /// 服务端缺少需要录入的人脸或指纹资料。
  missing,

  /// 服务端已有资料，但当前终端尚未同步。
  requiresSync,

  /// 资料刚刚同步到当前终端，可以继续认证。
  synced,

  /// 本机资料存在异常，需要报备并重新录入。
  abnormal,
}

/// 操作员在服务端与当前终端上的身份资料快照。
class OperatorIdentityProfile {
  /// 创建身份资料快照。
  const OperatorIdentityProfile({
    required this.account,
    required this.status,
    required this.remoteFactors,
    required this.localFactors,
    this.abnormalFactors = const <IdentityFactor>{},
    this.abnormalReported = false,
  });

  /// 当前资料所属账号。
  final OperatorAccount account;

  /// 当前资料状态。
  final OperatorIdentityProfileStatus status;

  /// 服务端已经登记的身份因子。
  final Set<IdentityFactor> remoteFactors;

  /// 当前终端已经安全导入或录入的身份因子。
  final Set<IdentityFactor> localFactors;

  /// 当前终端上识别异常的身份因子。
  final Set<IdentityFactor> abnormalFactors;

  /// 是否已经向平台报备过本机资料异常。
  final bool abnormalReported;

  /// 当前流程需要录入或重录的人脸、指纹因子。
  Set<IdentityFactor> get enrollmentFactors {
    const enrollableFactors = <IdentityFactor>{
      IdentityFactor.face,
      IdentityFactor.fingerprint,
    };
    return Set<IdentityFactor>.unmodifiable(
      enrollableFactors.where(
        (factor) =>
            !remoteFactors.contains(factor) ||
            !localFactors.contains(factor) ||
            abnormalFactors.contains(factor),
      ),
    );
  }

  /// 指定身份因子当前是否可用于本机认证。
  bool canVerify(IdentityFactor factor) {
    return localFactors.contains(factor) && !abnormalFactors.contains(factor);
  }
}

/// 单个身份因子的认证结果。
class IdentityFactorVerificationResult {
  /// 创建身份因子认证结果。
  const IdentityFactorVerificationResult({
    required this.success,
    required this.message,
  });

  /// 当前因子是否认证通过。
  final bool success;

  /// 可向操作员展示的结果说明。
  final String message;
}

/// 单个身份因子的录入结果。
class IdentityEnrollmentResult {
  /// 创建身份因子录入结果。
  const IdentityEnrollmentResult({
    required this.success,
    required this.message,
    required this.profile,
  });

  /// 本次录入是否成功。
  final bool success;

  /// 可向操作员展示的结果说明。
  final String message;

  /// 录入完成后的最新身份资料。
  final OperatorIdentityProfile profile;
}
