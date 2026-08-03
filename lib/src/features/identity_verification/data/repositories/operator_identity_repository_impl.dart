import 'package:flutter/foundation.dart';

import 'package:smart_cabinet/src/features/identity_verification/data/datasources/fake_operator_identity_data_source.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_identity_profile.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/repositories/operator_identity_repository.dart';

/// 普通操作员身份仓库的演示实现。
class OperatorIdentityRepositoryImpl implements OperatorIdentityRepository {
  /// 使用指定 Fake DataSource 创建仓库。
  OperatorIdentityRepositoryImpl(this._dataSource);

  final FakeOperatorIdentityDataSource _dataSource;

  @override
  Future<OperatorAccount?> login({
    required String username,
    required String password,
  }) {
    return _dataSource.authenticate(username: username, password: password);
  }

  @override
  Future<OperatorAccount?> identifyAccount({
    required IdentityFactor factor,
    String? evidencePath,
  }) {
    return _dataSource.identifyAccount(
      factor: factor,
      evidencePath: evidencePath,
    );
  }

  @override
  Future<OperatorIdentityProfile> loadProfile(OperatorAccount account) {
    return _dataSource.loadProfile(account);
  }

  @override
  Future<OperatorIdentityProfile> syncProfile(OperatorAccount account) {
    return _dataSource.syncProfile(account);
  }

  @override
  Future<IdentityFactorVerificationResult> verifyFactor({
    required OperatorAccount account,
    required IdentityFactor factor,
    String? evidencePath,
  }) {
    return _dataSource.verifyFactor(
      account: account,
      factor: factor,
      evidencePath: evidencePath,
    );
  }

  @override
  Future<OperatorIdentityProfile> reportAbnormalProfile(
    OperatorAccount account,
  ) {
    return _dataSource.reportAbnormalProfile(account);
  }

  @override
  Future<IdentityEnrollmentResult> enrollFactor({
    required OperatorAccount account,
    required IdentityFactor factor,
    String? evidencePath,
  }) {
    return _dataSource.enrollFactor(
      account: account,
      factor: factor,
      evidencePath: evidencePath,
    );
  }

  /// 将全局演示仓库恢复到初始账号与资料状态。
  @visibleForTesting
  void resetForTesting() {
    _dataSource.reset();
  }
}

final FakeOperatorIdentityDataSource _operatorIdentityDataSource =
    FakeOperatorIdentityDataSource();

/// 应用普通操作员身份流程使用的全局仓库。
final OperatorIdentityRepositoryImpl operatorIdentityRepository =
    OperatorIdentityRepositoryImpl(_operatorIdentityDataSource);

/// 将全局身份仓库恢复到初始演示状态，避免测试之间共享录入结果。
@visibleForTesting
void resetOperatorIdentityRepositoryForTesting() {
  operatorIdentityRepository.resetForTesting();
}
