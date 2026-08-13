import 'package:smart_cabinet/src/features/identity_verification/data/datasources/operator_authentication_data_source.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/dtos/operator_login_dto.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_identity_profile.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_login_request.dart';

/// 普通操作员账号与身份资料的内存演示数据源。
///
/// 该实现只保存模板是否存在、是否同步等演示元数据，不保存人脸照片或指纹模板。
class FakeOperatorIdentityDataSource
    implements OperatorAuthenticationDataSource {
  /// 创建并初始化演示数据源。
  FakeOperatorIdentityDataSource() {
    reset();
  }

  late Map<String, _FakeOperatorRecord> _recordsByUsername;

  /// 使用统一请求模拟 AFRR 登录，凭据或文件 ID 不匹配时返回 null。
  @override
  Future<OperatorLoginResponseDto?> authenticate({
    required OperatorLoginRequest request,
  }) async {
    final record = switch (request.method) {
      OperatorLoginMethod.account => _recordsByUsername[request.identifier],
      OperatorLoginMethod.face => _recordByBiometricIdentifier(
        request.identifier,
        factor: IdentityFactor.face,
      ),
      OperatorLoginMethod.fingerprint => _recordByBiometricIdentifier(
        request.identifier,
        factor: IdentityFactor.fingerprint,
      ),
    };
    if (record == null ||
        (request.method == OperatorLoginMethod.account &&
            record.password != request.secret)) {
      return null;
    }
    return OperatorLoginResponseDto(
      account: record.account.copyWith(
        verifiedFactors: const <IdentityFactor>{},
      ),
      protocolSerialNumber: 1,
      loginMethod: request.method,
      faceFileId: record.faceFileId,
      fingerprintFileId: record.fingerprintFileId,
    );
  }

  /// 模拟本机人脸或指纹模块返回已经登记的 AFRR 文件 ID。
  Future<String?> resolveBiometricIdentifier({
    required IdentityFactor factor,
    String? evidencePath,
  }) async {
    final record = _recordsByUsername['666666'];
    if (record == null || !record.localFactors.contains(factor)) {
      return null;
    }
    return switch (factor) {
      IdentityFactor.face => record.faceFileId,
      IdentityFactor.fingerprint => record.fingerprintFileId,
      IdentityFactor.nfc => null,
    };
  }

  /// 使用首个身份因子模拟识别账号。
  ///
  /// 演示环境统一识别为资料正常的 `666666` 账号；无法识别分支由页面上的
  /// “使用账号登录”入口显式触发，真实接入时由后端比对结果替换。
  Future<OperatorAccount?> identifyAccount({
    required IdentityFactor factor,
    String? evidencePath,
  }) async {
    final record = _recordsByUsername['666666'];
    if (record == null || !record.localFactors.contains(factor)) {
      return null;
    }
    return record.account.copyWith(verifiedFactors: const <IdentityFactor>{});
  }

  /// 读取账号当前身份资料快照。
  Future<OperatorIdentityProfile> loadProfile(OperatorAccount account) async {
    return _profileFor(_recordFor(account));
  }

  /// 模拟把服务端身份资料同步到当前终端。
  Future<OperatorIdentityProfile> syncProfile(OperatorAccount account) async {
    final record = _recordFor(account);
    record.localFactors.addAll(record.remoteFactors);
    record.wasSynced = true;
    return _profileFor(record);
  }

  /// 模拟校验当前终端上的一个身份因子。
  Future<IdentityFactorVerificationResult> verifyFactor({
    required OperatorAccount account,
    required IdentityFactor factor,
    String? evidencePath,
  }) async {
    final profile = _profileFor(_recordFor(account));
    if (!profile.canVerify(factor)) {
      return const IdentityFactorVerificationResult(
        success: false,
        message: '当前身份资料不可用，请改用其他方式或重新录入',
      );
    }
    return IdentityFactorVerificationResult(
      success: true,
      message: '${_factorLabel(factor)}识别通过',
    );
  }

  /// 模拟向平台报备本机身份资料异常。
  Future<OperatorIdentityProfile> reportAbnormalProfile(
    OperatorAccount account,
  ) async {
    final record = _recordFor(account);
    record.abnormalReported = true;
    return _profileFor(record);
  }

  /// 模拟在当前终端录入或重录人脸、指纹。
  Future<IdentityEnrollmentResult> enrollFactor({
    required OperatorAccount account,
    required IdentityFactor factor,
    String? evidencePath,
  }) async {
    final record = _recordFor(account);
    if (factor == IdentityFactor.nfc) {
      return IdentityEnrollmentResult(
        success: false,
        message: 'NFC 凭证不在本次录入范围内',
        profile: _profileFor(record),
      );
    }

    record.remoteFactors.add(factor);
    record.localFactors.add(factor);
    record.abnormalFactors.remove(factor);
    record.wasSynced = false;
    return IdentityEnrollmentResult(
      success: true,
      message: '${_factorLabel(factor)}录入成功',
      profile: _profileFor(record),
    );
  }

  /// 把演示数据恢复到首次启动状态。
  void reset() {
    _recordsByUsername = <String, _FakeOperatorRecord>{
      '666666': _FakeOperatorRecord(
        account: const OperatorAccount(
          id: 'operator-666666',
          username: '666666',
          name: '张晓明',
          organizationId: 'org-001',
          organizationName: '市市场监督管理局',
          position: '监管专员',
          phoneNumber: '138****6666',
          gender: '男',
          age: 35,
        ),
        password: '666666',
        faceFileId: '111',
        fingerprintFileId: '222',
        remoteFactors: <IdentityFactor>{...IdentityFactor.values},
        localFactors: <IdentityFactor>{...IdentityFactor.values},
      ),
      '100001': _FakeOperatorRecord(
        account: const OperatorAccount(
          id: 'operator-100001',
          username: '100001',
          name: '李晨',
          organizationId: 'org-001',
          organizationName: '市市场监督管理局',
          position: '监管员',
          phoneNumber: '136****1001',
          gender: '男',
          age: 29,
        ),
        password: '123456',
        faceFileId: '1000011',
        fingerprintFileId: '1000012',
        remoteFactors: <IdentityFactor>{IdentityFactor.nfc},
        localFactors: <IdentityFactor>{IdentityFactor.nfc},
      ),
      '100002': _FakeOperatorRecord(
        account: const OperatorAccount(
          id: 'operator-100002',
          username: '100002',
          name: '王敏',
          organizationId: 'org-002',
          organizationName: '市公安局',
          position: '档案管理员',
          phoneNumber: '137****1002',
          gender: '女',
          age: 32,
        ),
        password: '123456',
        faceFileId: '1000021',
        fingerprintFileId: '1000022',
        remoteFactors: <IdentityFactor>{...IdentityFactor.values},
        localFactors: <IdentityFactor>{IdentityFactor.nfc},
      ),
      '100003': _FakeOperatorRecord(
        account: const OperatorAccount(
          id: 'operator-100003',
          username: '100003',
          name: '赵磊',
          organizationId: 'org-003',
          organizationName: '市司法局',
          position: '业务专员',
          phoneNumber: '139****1003',
          gender: '男',
          age: 38,
        ),
        password: '123456',
        faceFileId: '1000031',
        fingerprintFileId: '1000032',
        remoteFactors: <IdentityFactor>{...IdentityFactor.values},
        localFactors: <IdentityFactor>{...IdentityFactor.values},
        abnormalFactors: <IdentityFactor>{
          IdentityFactor.face,
          IdentityFactor.fingerprint,
        },
      ),
    };
  }

  /// 按账号读取内部可变记录，不存在时终止当前演示流程。
  _FakeOperatorRecord _recordFor(OperatorAccount account) {
    final record = _recordsByUsername[account.username];
    if (record == null || record.account.id != account.id) {
      throw StateError('未找到操作员身份资料');
    }
    return record;
  }

  _FakeOperatorRecord? _recordByBiometricIdentifier(
    String identifier, {
    required IdentityFactor factor,
  }) {
    for (final record in _recordsByUsername.values) {
      final expected = factor == IdentityFactor.face
          ? record.faceFileId
          : record.fingerprintFileId;
      if (expected == identifier) {
        return record;
      }
    }
    return null;
  }

  /// 根据内部记录计算对外只读的资料状态快照。
  OperatorIdentityProfile _profileFor(_FakeOperatorRecord record) {
    final missingRequiredFactor = const <IdentityFactor>{
      IdentityFactor.face,
      IdentityFactor.fingerprint,
    }.any((factor) => !record.remoteFactors.contains(factor));
    final needsSync = record.remoteFactors.any(
      (factor) => !record.localFactors.contains(factor),
    );
    final status = record.abnormalFactors.isNotEmpty
        ? OperatorIdentityProfileStatus.abnormal
        : missingRequiredFactor
        ? OperatorIdentityProfileStatus.missing
        : needsSync
        ? OperatorIdentityProfileStatus.requiresSync
        : record.wasSynced
        ? OperatorIdentityProfileStatus.synced
        : OperatorIdentityProfileStatus.ready;

    return OperatorIdentityProfile(
      account: record.account.copyWith(verifiedFactors: const {}),
      status: status,
      remoteFactors: Set<IdentityFactor>.unmodifiable(record.remoteFactors),
      localFactors: Set<IdentityFactor>.unmodifiable(record.localFactors),
      abnormalFactors: Set<IdentityFactor>.unmodifiable(record.abnormalFactors),
      abnormalReported: record.abnormalReported,
    );
  }

  /// 返回身份因子的中文展示名称。
  String _factorLabel(IdentityFactor factor) {
    return switch (factor) {
      IdentityFactor.face => '人脸',
      IdentityFactor.fingerprint => '指纹',
      IdentityFactor.nfc => 'NFC',
    };
  }
}

/// Fake DataSource 内部维护的可变账号记录。
class _FakeOperatorRecord {
  /// 创建演示账号记录。
  _FakeOperatorRecord({
    required this.account,
    required this.password,
    required this.faceFileId,
    required this.fingerprintFileId,
    required this.remoteFactors,
    required this.localFactors,
    Set<IdentityFactor>? abnormalFactors,
  }) : abnormalFactors = abnormalFactors ?? <IdentityFactor>{};

  final OperatorAccount account;
  final String password;
  final String faceFileId;
  final String fingerprintFileId;
  final Set<IdentityFactor> remoteFactors;
  final Set<IdentityFactor> localFactors;
  final Set<IdentityFactor> abnormalFactors;
  bool abnormalReported = false;
  bool wasSynced = false;
}
