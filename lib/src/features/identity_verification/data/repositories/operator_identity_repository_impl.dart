import 'package:flutter/foundation.dart';

import 'package:smart_cabinet/src/core/config/app_config.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/datasources/fake_operator_identity_data_source.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/datasources/operator_afrr_login_data_source.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/datasources/operator_authentication_data_source.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/datasources/operator_login_strategy.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_identity_profile.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_login_request.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_login_session.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/repositories/operator_identity_repository.dart';

/// 组合 AFRR 远程登录与当前身份资料模拟实现的操作员身份仓库。
class OperatorIdentityRepositoryImpl implements OperatorIdentityRepository {
  /// 使用统一登录数据源和身份资料数据源创建仓库。
  factory OperatorIdentityRepositoryImpl({
    required OperatorAuthenticationDataSource authenticationDataSource,
    required FakeOperatorIdentityDataSource identityDataSource,
    Map<OperatorLoginMethod, OperatorLoginStrategy>? loginStrategies,
  }) {
    final effectiveStrategies = <OperatorLoginMethod, OperatorLoginStrategy>{
      OperatorLoginMethod.account: OperatorProtocolLoginStrategy(
        method: OperatorLoginMethod.account,
        dataSource: authenticationDataSource,
      ),
      OperatorLoginMethod.face: OperatorProtocolLoginStrategy(
        method: OperatorLoginMethod.face,
        dataSource: authenticationDataSource,
        biometricIdentifierResolver:
            identityDataSource.resolveBiometricIdentifier,
      ),
      OperatorLoginMethod.fingerprint: OperatorProtocolLoginStrategy(
        method: OperatorLoginMethod.fingerprint,
        dataSource: authenticationDataSource,
        biometricIdentifierResolver:
            identityDataSource.resolveBiometricIdentifier,
      ),
      ...?loginStrategies,
    };
    return OperatorIdentityRepositoryImpl._(
      identityDataSource,
      effectiveStrategies,
    );
  }

  OperatorIdentityRepositoryImpl._(
    this._identityDataSource,
    this._loginStrategies,
  );

  final FakeOperatorIdentityDataSource _identityDataSource;
  final Map<OperatorLoginMethod, OperatorLoginStrategy> _loginStrategies;
  OperatorLoginSession? _activeSession;

  @override
  OperatorLoginSession? get activeSession => _activeSession;

  @override
  void clearSession() {
    _activeSession = null;
  }

  @override
  Future<OperatorAccount?> authenticateLogin({
    required OperatorLoginRequest request,
  }) async {
    clearSession();
    final strategy = _loginStrategies[request.method];
    if (strategy == null) {
      throw OperatorLoginException(
        '当前未配置 ${request.method.name} 登录策略',
        code: 'missing_login_strategy',
      );
    }
    final result = await strategy.authenticate(request: request);
    if (result == null) {
      return null;
    }
    _activeSession = result.session;
    return result.account;
  }

  @override
  Future<OperatorAccount?> login({
    required String username,
    required String password,
  }) async {
    return authenticateLogin(
      request: OperatorLoginRequest.account(
        username: username,
        password: password,
      ),
    );
  }

  @override
  Future<OperatorAccount?> identifyAccount({
    required IdentityFactor factor,
    String? evidencePath,
  }) async {
    final request = switch (factor) {
      IdentityFactor.face => OperatorLoginRequest.face(
        evidencePath: evidencePath,
      ),
      IdentityFactor.fingerprint => OperatorLoginRequest.fingerprint(
        evidencePath: evidencePath,
      ),
      IdentityFactor.nfc => null,
    };
    if (request != null) {
      return authenticateLogin(request: request);
    }
    clearSession();
    return _identityDataSource.identifyAccount(
      factor: factor,
      evidencePath: evidencePath,
    );
  }

  @override
  Future<OperatorIdentityProfile> loadProfile(OperatorAccount account) {
    return _identityDataSource.loadProfile(account);
  }

  @override
  Future<OperatorIdentityProfile> syncProfile(OperatorAccount account) {
    return _identityDataSource.syncProfile(account);
  }

  @override
  Future<IdentityFactorVerificationResult> verifyFactor({
    required OperatorAccount account,
    required IdentityFactor factor,
    String? evidencePath,
  }) {
    return _identityDataSource.verifyFactor(
      account: account,
      factor: factor,
      evidencePath: evidencePath,
    );
  }

  @override
  Future<OperatorIdentityProfile> reportAbnormalProfile(
    OperatorAccount account,
  ) {
    return _identityDataSource.reportAbnormalProfile(account);
  }

  @override
  Future<IdentityEnrollmentResult> enrollFactor({
    required OperatorAccount account,
    required IdentityFactor factor,
    String? evidencePath,
  }) {
    return _identityDataSource.enrollFactor(
      account: account,
      factor: factor,
      evidencePath: evidencePath,
    );
  }

  /// 将全局仓库切换到可控 Fake 登录并恢复初始身份资料。
  @visibleForTesting
  void resetForTesting() {
    clearSession();
    _identityDataSource.reset();
    for (final method in OperatorLoginMethod.values) {
      _loginStrategies[method] = OperatorProtocolLoginStrategy(
        method: method,
        dataSource: _identityDataSource,
        biometricIdentifierResolver: method == OperatorLoginMethod.account
            ? null
            : _identityDataSource.resolveBiometricIdentifier,
      );
    }
  }
}

final FakeOperatorIdentityDataSource _operatorIdentityDataSource =
    FakeOperatorIdentityDataSource();

/// APP 启动登录与操作员登录共用的 AFRR 长连接。
final OperatorAfrrLoginDataSource operatorAfrrLoginDataSource =
    OperatorAfrrLoginDataSource(
      host: AppConfig.current.operatorProtocolHost,
      port: AppConfig.current.operatorProtocolPort,
      shelfCode: AppConfig.current.operatorShelfCode,
      imei: AppConfig.current.afrrDeviceImei,
      appId: AppConfig.current.appId,
      appSecret: AppConfig.current.appSecret,
    );

/// 应用普通操作员身份流程使用的全局仓库。
///
/// 账号、人脸和指纹均通过 AFRR TCP A170/B170 登录；当前人脸和指纹硬件文件 ID
/// 仍由 Feature 内 Fake DataSource 提供，NFC 和身份资料能力继续保留模拟边界。
final OperatorIdentityRepositoryImpl operatorIdentityRepository =
    OperatorIdentityRepositoryImpl(
      authenticationDataSource: operatorAfrrLoginDataSource,
      identityDataSource: _operatorIdentityDataSource,
    );

/// 将全局身份仓库恢复到初始演示状态，避免测试之间共享录入结果。
@visibleForTesting
void resetOperatorIdentityRepositoryForTesting() {
  operatorIdentityRepository.resetForTesting();
}
