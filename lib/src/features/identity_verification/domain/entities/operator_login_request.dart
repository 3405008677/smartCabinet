import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';

/// 普通操作员支持的登录方式，对应 AFRR 登录协议中的 `logway`。
enum OperatorLoginMethod {
  /// 账号密码登录，对应 `logway = 1`。
  account(1),

  /// 人脸文件 ID 登录，对应 `logway = 2`。
  face(2),

  /// 指纹文件 ID 登录，对应 `logway = 3`。
  fingerprint(3);

  const OperatorLoginMethod(this.protocolValue);

  /// AFRR 登录 JSON 使用的数字编码。
  final int protocolValue;

  /// 生物特征登录对应的身份因子；账号登录没有初始身份因子。
  IdentityFactor? get identityFactor {
    return switch (this) {
      OperatorLoginMethod.account => null,
      OperatorLoginMethod.face => IdentityFactor.face,
      OperatorLoginMethod.fingerprint => IdentityFactor.fingerprint,
    };
  }
}

/// 账号、人脸和指纹登录共用的请求对象。
///
/// 页面和协调器只依赖这个领域对象，不了解 AFRR TCP 或本地硬件识别细节。
/// 生物特征请求允许暂时不带 [identifier]，供现有终端硬件
/// 先完成本地匹配；真正序列化 AFRR 请求前必须补充人脸或指纹文件 ID。
final class OperatorLoginRequest {
  /// 创建账号密码登录请求。
  factory OperatorLoginRequest.account({
    required String username,
    required String password,
  }) {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty || password.isEmpty) {
      throw ArgumentError('账号和密码不能为空');
    }
    return OperatorLoginRequest._(
      method: OperatorLoginMethod.account,
      identifier: normalizedUsername,
      secret: password,
    );
  }

  /// 创建人脸登录请求。
  factory OperatorLoginRequest.face({
    String? faceFileId,
    String? evidencePath,
  }) {
    return OperatorLoginRequest._biometric(
      method: OperatorLoginMethod.face,
      identifier: faceFileId,
      evidencePath: evidencePath,
    );
  }

  /// 创建指纹登录请求。
  factory OperatorLoginRequest.fingerprint({
    String? fingerprintFileId,
    String? evidencePath,
  }) {
    return OperatorLoginRequest._biometric(
      method: OperatorLoginMethod.fingerprint,
      identifier: fingerprintFileId,
      evidencePath: evidencePath,
    );
  }

  /// 创建规范化后的生物特征登录请求。
  factory OperatorLoginRequest._biometric({
    required OperatorLoginMethod method,
    String? identifier,
    String? evidencePath,
  }) {
    return OperatorLoginRequest._(
      method: method,
      identifier: identifier?.trim() ?? '',
      evidencePath: evidencePath?.trim(),
    );
  }

  const OperatorLoginRequest._({
    required this.method,
    required this.identifier,
    this.secret,
    this.evidencePath,
  });

  /// 当前请求使用的登录方式。
  final OperatorLoginMethod method;

  /// 账号，或终端匹配后得到的人脸/指纹文件 ID。
  final String identifier;

  /// 账号登录密码；生物特征登录固定为空。
  final String? secret;

  /// 当前本地识别过程产生的临时证据路径，不参与日志和普通持久化。
  final String? evidencePath;

  /// 是否已经具备序列化为 AFRR 登录请求所需的账号或文件 ID。
  bool get hasProtocolIdentifier => identifier.isNotEmpty;

  /// 为本机生物识别结果补入 AFRR 登录所需的人脸或指纹文件 ID。
  OperatorLoginRequest withProtocolIdentifier(String value) {
    if (method == OperatorLoginMethod.account) {
      throw StateError('账号登录不能替换为生物特征文件 ID');
    }
    final normalizedValue = value.trim();
    if (normalizedValue.isEmpty) {
      throw ArgumentError.value(value, 'value', '生物特征文件 ID 不能为空');
    }
    return OperatorLoginRequest._(
      method: method,
      identifier: normalizedValue,
      evidencePath: evidencePath,
    );
  }
}
