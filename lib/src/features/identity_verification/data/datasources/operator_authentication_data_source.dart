import 'package:smart_cabinet/src/features/identity_verification/data/dtos/operator_login_dto.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_login_request.dart';

/// 普通操作员账号、人脸和指纹认证共用的数据源边界。
abstract interface class OperatorAuthenticationDataSource {
  /// 提交统一登录请求并返回平台人员资料；凭据不匹配的 Fake 场景可返回 null。
  Future<OperatorLoginResponseDto?> authenticate({
    required OperatorLoginRequest request,
  });
}
