import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/features/identity_verification/data/datasources/fake_operator_identity_data_source.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/datasources/operator_login_strategy.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/dtos/operator_login_dto.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/repositories/operator_identity_repository_impl.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_login_request.dart';

/// 统一登录请求、AFRR JSON 包装和默认登录策略测试。
void main() {
  group('OperatorProtocolLoginRequestDto', () {
    test('packages account login with logway 1 and SHA-1 cypher', () {
      final dto = OperatorProtocolLoginRequestDto.fromRequest(
        OperatorLoginRequest.account(username: ' 100001 ', password: '123456'),
      );

      expect(dto.toJson(), <String, Object>{
        'func': 'userLogin',
        'data': <String, Object>{
          'logway': 1,
          'accnt': '100001',
          'cypher': '7C4A8D09CA3762AF61E59520943DC26494F8941B',
        },
      });
    });

    test('packages face and fingerprint file IDs without password', () {
      final face = OperatorProtocolLoginRequestDto.fromRequest(
        OperatorLoginRequest.face(faceFileId: 'face-file-111'),
      );
      final fingerprint = OperatorProtocolLoginRequestDto.fromRequest(
        OperatorLoginRequest.fingerprint(fingerprintFileId: 'finger-file-222'),
      );

      expect(face.toJson(), <String, Object>{
        'func': 'userLogin',
        'data': <String, Object>{
          'logway': 2,
          'accnt': 'face-file-111',
          'cypher': '',
        },
      });
      expect(fingerprint.toJson(), <String, Object>{
        'func': 'userLogin',
        'data': <String, Object>{
          'logway': 3,
          'accnt': 'finger-file-222',
          'cypher': '',
        },
      });
    });

    test('rejects biometric protocol requests before a file ID is known', () {
      expect(
        () => OperatorProtocolLoginRequestDto.fromRequest(
          OperatorLoginRequest.face(),
        ),
        throwsFormatException,
      );
    });
  });

  group('OperatorIdentityRepositoryImpl unified login', () {
    test(
      'routes account, face and fingerprint through one request API',
      () async {
        final fakeDataSource = FakeOperatorIdentityDataSource();
        final repository = OperatorIdentityRepositoryImpl(
          authenticationDataSource: fakeDataSource,
          identityDataSource: fakeDataSource,
        );

        final account = await repository.authenticateLogin(
          request: OperatorLoginRequest.account(
            username: '666666',
            password: '666666',
          ),
        );
        expect(account?.username, '666666');
        expect(
          repository.activeSession?.loginMethod,
          OperatorLoginMethod.account,
        );

        final faceAccount = await repository.authenticateLogin(
          request: OperatorLoginRequest.face(),
        );
        expect(faceAccount?.username, '666666');
        expect(repository.activeSession?.loginMethod, OperatorLoginMethod.face);
        expect(repository.activeSession?.faceFileId, '111');

        final fingerprintAccount = await repository.authenticateLogin(
          request: OperatorLoginRequest.fingerprint(),
        );
        expect(fingerprintAccount?.username, '666666');
        expect(
          repository.activeSession?.loginMethod,
          OperatorLoginMethod.fingerprint,
        );
        expect(repository.activeSession?.fingerprintFileId, '222');
      },
    );

    test(
      'allows a login method strategy to replace the default rule',
      () async {
        final fakeDataSource = FakeOperatorIdentityDataSource();
        final repository = OperatorIdentityRepositoryImpl(
          authenticationDataSource: fakeDataSource,
          identityDataSource: fakeDataSource,
          loginStrategies: const <OperatorLoginMethod, OperatorLoginStrategy>{
            OperatorLoginMethod.face: _ReplacementFaceLoginStrategy(),
          },
        );

        final account = await repository.authenticateLogin(
          request: OperatorLoginRequest.face(faceFileId: 'face-rule-v2'),
        );

        expect(account?.id, 'replacement-face-user');
        expect(account?.username, 'face-rule-v2');
        expect(repository.activeSession, isNull);
      },
    );
  });
}

final class _ReplacementFaceLoginStrategy implements OperatorLoginStrategy {
  const _ReplacementFaceLoginStrategy();

  @override
  OperatorLoginMethod get method => OperatorLoginMethod.face;

  @override
  Future<OperatorLoginStrategyResult?> authenticate({
    required OperatorLoginRequest request,
  }) async {
    return OperatorLoginStrategyResult(
      account: OperatorAccount(
        id: 'replacement-face-user',
        username: request.identifier,
        name: 'Replacement Face Rule',
        organizationId: 'replacement-org',
        organizationName: 'Replacement Organization',
      ),
    );
  }
}
