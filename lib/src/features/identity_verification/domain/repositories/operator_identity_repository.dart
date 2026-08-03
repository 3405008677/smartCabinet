import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_identity_profile.dart';

/// 普通操作员账号与身份资料的数据边界。
abstract interface class OperatorIdentityRepository {
  /// 使用账号和密码登录，凭据不匹配时返回 null。
  Future<OperatorAccount?> login({
    required String username,
    required String password,
  });

  /// 使用首个身份因子识别操作员账号，无法识别时返回 null。
  Future<OperatorAccount?> identifyAccount({
    required IdentityFactor factor,
    String? evidencePath,
  });

  /// 读取指定账号的服务端与本机身份资料状态。
  Future<OperatorIdentityProfile> loadProfile(OperatorAccount account);

  /// 把服务端已有身份资料同步到当前终端。
  Future<OperatorIdentityProfile> syncProfile(OperatorAccount account);

  /// 校验指定账号的一个身份因子。
  Future<IdentityFactorVerificationResult> verifyFactor({
    required OperatorAccount account,
    required IdentityFactor factor,
    String? evidencePath,
  });

  /// 向平台报备当前终端上的身份资料异常。
  Future<OperatorIdentityProfile> reportAbnormalProfile(
    OperatorAccount account,
  );

  /// 在当前终端录入或重录一个人脸、指纹因子。
  Future<IdentityEnrollmentResult> enrollFactor({
    required OperatorAccount account,
    required IdentityFactor factor,
    String? evidencePath,
  });
}
