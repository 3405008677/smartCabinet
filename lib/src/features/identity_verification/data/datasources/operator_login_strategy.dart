import 'package:smart_cabinet/src/features/identity_verification/data/datasources/operator_authentication_data_source.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_login_request.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_login_session.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/repositories/operator_identity_repository.dart';

/// 从本机人脸或指纹模块取得 AFRR 文件 ID 的函数类型。
typedef OperatorBiometricIdentifierResolver =
    Future<String?> Function({
      required IdentityFactor factor,
      String? evidencePath,
    });

/// 一次统一登录策略的返回结果。
final class OperatorLoginStrategyResult {
  /// 创建包含账号和可选平台会话的登录结果。
  const OperatorLoginStrategyResult({required this.account, this.session});

  /// 当前登录方式识别出的账号。
  final OperatorAccount account;

  /// AFRR 服务端确认成功后建立的会话。
  final OperatorLoginSession? session;
}

/// 可按登录方式替换的统一登录策略。
abstract interface class OperatorLoginStrategy {
  /// 当前策略处理的登录方式。
  OperatorLoginMethod get method;

  /// 执行登录请求并返回账号；凭据无法匹配时返回 null。
  Future<OperatorLoginStrategyResult?> authenticate({
    required OperatorLoginRequest request,
  });
}

/// 把账号、人脸和指纹统一提交到 AFRR 登录数据源的策略。
///
/// 账号请求已经直接携带账号和密码；人脸和指纹请求若尚无文件 ID，会先调用本机
/// 解析器取得文件 ID，再发送 `logway = 2/3` 的 A170 报文。服务端没有确认成功时
/// 不会创建会话。
final class OperatorProtocolLoginStrategy implements OperatorLoginStrategy {
  /// 创建指定登录方式的远程协议策略。
  const OperatorProtocolLoginStrategy({
    required this.method,
    required this.dataSource,
    this.biometricIdentifierResolver,
  });

  @override
  final OperatorLoginMethod method;

  /// 当前策略提交统一请求的远程数据源。
  final OperatorAuthenticationDataSource dataSource;

  /// 生物登录缺少文件 ID 时使用的本机解析器。
  final OperatorBiometricIdentifierResolver? biometricIdentifierResolver;

  @override
  Future<OperatorLoginStrategyResult?> authenticate({
    required OperatorLoginRequest request,
  }) async {
    if (request.method != method) {
      throw const OperatorLoginException(
        '登录策略收到不支持的登录方式',
        code: 'unsupported_login_method',
      );
    }

    var effectiveRequest = request;
    if (method != OperatorLoginMethod.account &&
        !effectiveRequest.hasProtocolIdentifier) {
      final factor = method.identityFactor!;
      final resolver = biometricIdentifierResolver;
      if (resolver == null) {
        throw const OperatorLoginException(
          '当前未配置生物特征文件 ID 解析器',
          code: 'missing_biometric_identifier_resolver',
        );
      }
      final identifier = await resolver(
        factor: factor,
        evidencePath: request.evidencePath,
      );
      if (identifier == null || identifier.trim().isEmpty) {
        return null;
      }
      effectiveRequest = request.withProtocolIdentifier(identifier);
    }

    final response = await dataSource.authenticate(request: effectiveRequest);
    if (response == null) {
      return null;
    }
    return OperatorLoginStrategyResult(
      account: response.account,
      session: response.toSession(),
    );
  }
}
