/// 智能柜支持的操作员身份因子。
enum IdentityFactor { face, fingerprint, nfc }

/// 普通操作员进入任务流程前必须完成的全部身份因子。
const Set<IdentityFactor> requiredOperatorIdentityFactors = <IdentityFactor>{
  IdentityFactor.face,
  IdentityFactor.fingerprint,
  IdentityFactor.nfc,
};

/// 已登录或已被身份因子识别出的普通操作员账号。
class OperatorAccount {
  /// 创建普通操作员账号。
  const OperatorAccount({
    required this.id,
    required this.username,
    required this.name,
    required this.organizationId,
    required this.organizationName,
    this.position = '—',
    this.phoneNumber = '—',
    this.gender = '—',
    this.age,
    this.verifiedFactors = const <IdentityFactor>{},
  });

  /// 平台侧稳定账号 ID。
  final String id;

  /// 操作员用于账号登录的用户名。
  final String username;

  /// 操作员展示姓名。
  final String name;

  /// 操作员所属监管机构 ID。
  final String organizationId;

  /// 操作员所属监管机构名称。
  final String organizationName;

  /// 操作员职位。
  final String position;

  /// 操作员手机号码。
  final String phoneNumber;

  /// 操作员性别。
  final String gender;

  /// 操作员年龄；未提供时在界面展示占位符。
  final int? age;

  /// 当前认证会话已经通过的不同身份因子。
  final Set<IdentityFactor> verifiedFactors;

  /// 返回带有最新认证因子集合的账号副本。
  OperatorAccount copyWith({Set<IdentityFactor>? verifiedFactors}) {
    return OperatorAccount(
      id: id,
      username: username,
      name: name,
      organizationId: organizationId,
      organizationName: organizationName,
      position: position,
      phoneNumber: phoneNumber,
      gender: gender,
      age: age,
      verifiedFactors: Set<IdentityFactor>.unmodifiable(
        verifiedFactors ?? this.verifiedFactors,
      ),
    );
  }
}
