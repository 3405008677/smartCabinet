import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/features/identity_verification/data/datasources/operator_afrr_login_data_source.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/protocol/afrr_operator_protocol.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_login_request.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/repositories/operator_identity_repository.dart';

/// AFRR A170/B170 帧编解码、TCP 登录和错误映射测试。
void main() {
  const shelfCode = '867282037661259';

  group('AfrrOperatorProtocolCodec', () {
    test('encodes the complete account login frame', () {
      final frame = AfrrOperatorProtocolCodec.encodeLogin(
        request: OperatorLoginRequest.account(
          username: '3405008677',
          password: 'pqj360421...',
        ),
        shelfCode: shelfCode,
        serialNumber: 1,
        timestamp: DateTime(2026, 8, 7, 12, 12, 12),
        timezoneOffset: const Duration(hours: 8),
      );

      expect(
        _hex(frame),
        '7F00A17008672820376612590001007E020009202608071212120800'
        'A000717B2266756E63223A22757365724C6F67696E222C2264617461223A7B'
        '226C6F67776179223A312C226163636E74223A2233343035303038'
        '363737222C22637970686572223A2245323643393045373131433143'
        '31353638324244443234373746344637463245414435464435424622'
        '7D7D0E7F',
      );
    });

    test('encodes face and fingerprint file IDs as logway 2 and 3', () {
      final timestamp = DateTime(2026, 8, 7, 12, 12, 12);
      final face = AfrrOperatorProtocolCodec.decodeFrame(
        AfrrOperatorProtocolCodec.encodeLogin(
          request: OperatorLoginRequest.face(faceFileId: '111'),
          shelfCode: shelfCode,
          serialNumber: 2,
          timestamp: timestamp,
          timezoneOffset: const Duration(hours: 8),
        ),
      );
      final fingerprint = AfrrOperatorProtocolCodec.decodeFrame(
        AfrrOperatorProtocolCodec.encodeLogin(
          request: OperatorLoginRequest.fingerprint(fingerprintFileId: '222'),
          shelfCode: shelfCode,
          serialNumber: 3,
          timestamp: timestamp,
          timezoneOffset: const Duration(hours: 8),
        ),
      );

      expect(face.jsonPayload?['data'], <String, Object>{
        'logway': 2,
        'accnt': '111',
        'cypher': '',
      });
      expect(fingerprint.jsonPayload?['data'], <String, Object>{
        'logway': 3,
        'accnt': '222',
        'cypher': '',
      });
    });

    test('splits fragmented frames and rejects a bad checksum', () {
      final response = _loginResponseFrame(
        shelfCode: shelfCode,
        replySerialNumber: 7,
      );
      final decoder = AfrrOperatorFrameDecoder();

      expect(decoder.add(response.sublist(0, 10)), isEmpty);
      final messages = decoder.add(response.sublist(10));
      expect(messages.single.keyword, 0xB170);
      expect(messages.single.replyToKeyword, isNull);
      expect(messages.single.replyToSerialNumber, 7);
      expect(messages.single.compactReplyResultCode, isNull);

      final invalid = List<int>.of(response);
      invalid[invalid.length - 2] ^= 0x01;
      expect(
        () => AfrrOperatorProtocolCodec.decodeFrame(invalid),
        throwsA(isA<AfrrOperatorProtocolException>()),
      );
    });

    test('decodes the compact B170 response returned by the live server', () {
      final response = AfrrOperatorProtocolCodec.decodeFrame(
        _bytesFromHex('7F00B1700867282037661259000100070105A170000109677F'),
      );

      expect(response.keyword, 0xB170);
      expect(response.replyToKeyword, 0xA170);
      expect(response.replyToSerialNumber, 1);
      expect(response.compactReplyResultCode, 9);
      expect(response.jsonPayload, isNull);
    });
  });

  group('OperatorAfrrLoginDataSource', () {
    test('sends A170 and maps the matching B170 login response', () async {
      final socket = _TestSocket();
      final dataSource = OperatorAfrrLoginDataSource(
        host: '192.0.2.10',
        port: 17000,
        shelfCode: shelfCode,
        socketConnector: (_, _, _) async => socket,
        clock: () => DateTime(2026, 8, 7, 12, 12, 12),
        sequence: AfrrOperatorMessageSequence(initialValue: 7),
      );

      try {
        final login = dataSource.authenticate(
          request: OperatorLoginRequest.account(
            username: '3405008677',
            password: 'pqj360421...',
          ),
        );
        await _waitForWrites(socket, 1);
        final request = AfrrOperatorProtocolCodec.decodeFrame(
          socket.writes.single,
        );
        expect(request.keyword, 0xA170);
        expect(request.serialNumber, 7);
        expect(request.jsonPayload?['func'], 'userLogin');
        expect(request.jsonPayload?.containsKey('cmd'), isFalse);

        socket.emitBytes(
          _loginResponseFrame(
            shelfCode: shelfCode,
            replySerialNumber: request.serialNumber,
          ),
        );
        final response = await login;

        expect(response.account.id, 'user-3405008677');
        expect(response.account.username, '3405008677');
        expect(response.account.name, '测试操作员');
        expect(response.account.organizationId, 'org-001');
        expect(response.account.organizationName, '测试监管机构');
        expect(response.account.position, '监管员');
        expect(response.protocolSerialNumber, 7);
        expect(response.faceFileId, '111');
        expect(response.fingerprintFileId, '222');
        expect(response.serverTime, 1785888000);
      } finally {
        await dataSource.dispose();
        await socket.dispose();
      }
    });

    test('preserves B170 business failure details', () async {
      final socket = _TestSocket();
      final dataSource = OperatorAfrrLoginDataSource(
        host: '192.0.2.10',
        port: 17000,
        shelfCode: shelfCode,
        socketConnector: (_, _, _) async => socket,
        clock: () => DateTime(2026, 8, 7, 12, 12, 12),
      );

      try {
        final login = dataSource.authenticate(
          request: OperatorLoginRequest.account(
            username: '3405008677',
            password: 'wrong-password',
          ),
        );
        await _waitForWrites(socket, 1);
        final request = AfrrOperatorProtocolCodec.decodeFrame(
          socket.writes.single,
        );
        socket.emitBytes(
          _loginResponseFrame(
            shelfCode: shelfCode,
            replySerialNumber: request.serialNumber,
            result: 4,
            data: '账号或密码错误',
          ),
        );

        await expectLater(
          login,
          throwsA(
            isA<OperatorLoginException>()
                .having((error) => error.message, 'message', '账号或密码错误')
                .having((error) => error.code, 'code', 'afrr_rst_4'),
          ),
        );
      } finally {
        await dataSource.dispose();
        await socket.dispose();
      }
    });

    test(
      'maps a compact B170 business failure without waiting for timeout',
      () async {
        final socket = _TestSocket();
        final dataSource = OperatorAfrrLoginDataSource(
          host: '192.0.2.10',
          port: 17000,
          shelfCode: shelfCode,
          socketConnector: (_, _, _) async => socket,
          maximumAttempts: 1,
        );

        try {
          final login = dataSource.authenticate(
            request: OperatorLoginRequest.account(
              username: '3405008677',
              password: 'wrong-password',
            ),
          );
          await _waitForWrites(socket, 1);
          final request = AfrrOperatorProtocolCodec.decodeFrame(
            socket.writes.single,
          );
          socket.emitBytes(
            _compactResponseFrame(
              shelfCode: shelfCode,
              replySerialNumber: request.serialNumber,
              result: 4,
            ),
          );

          await expectLater(
            login,
            throwsA(
              isA<OperatorLoginException>()
                  .having(
                    (error) => error.message,
                    'message',
                    'AFRR userLogin 逻辑校验失败',
                  )
                  .having((error) => error.code, 'code', 'afrr_rst_4'),
            ),
          );
        } finally {
          await dataSource.dispose();
          await socket.dispose();
        }
      },
    );

    test('rejects missing AFRR connection configuration', () async {
      final dataSource = OperatorAfrrLoginDataSource(
        host: '',
        port: 0,
        shelfCode: '',
      );
      try {
        await expectLater(
          dataSource.authenticate(
            request: OperatorLoginRequest.account(
              username: '100001',
              password: '123456',
            ),
          ),
          throwsA(
            isA<OperatorLoginException>().having(
              (error) => error.code,
              'code',
              'invalid_server_config',
            ),
          ),
        );
      } finally {
        await dataSource.dispose();
      }
    });
  });
}

Uint8List _loginResponseFrame({
  required String shelfCode,
  required int replySerialNumber,
  int result = 9,
  Object? data,
}) {
  final responseData =
      data ??
      <String, Object?>{
        'uid': 'user-3405008677',
        'accnt': '3405008677',
        'uname': '测试操作员',
        'rname': '监管员',
        'uorgId': 'org-001',
        'uorg': '测试监管机构',
        'faceId': 111,
        'fgerId': 222,
        'time': 1785888000,
      };
  final jsonBytes = utf8.encode(
    jsonEncode(<String, Object?>{
      'func': 'userLogin',
      'rst': result,
      'data': responseData,
    }),
  );
  final body = <int>[
    0x01,
    0x02,
    (replySerialNumber >> 8) & 0xFF,
    replySerialNumber & 0xFF,
    0xA0,
    (jsonBytes.length >> 8) & 0xFF,
    jsonBytes.length & 0xFF,
    ...jsonBytes,
  ];
  return AfrrOperatorProtocolCodec.encodeFrame(
    keyword: AfrrOperatorProtocolCodec.loginResponseKeyword,
    shelfCode: shelfCode,
    serialNumber: 99,
    body: body,
  );
}

Uint8List _compactResponseFrame({
  required String shelfCode,
  required int replySerialNumber,
  required int result,
}) {
  return AfrrOperatorProtocolCodec.encodeFrame(
    keyword: AfrrOperatorProtocolCodec.loginResponseKeyword,
    shelfCode: shelfCode,
    serialNumber: 99,
    body: <int>[
      0x01,
      0x05,
      (AfrrOperatorProtocolCodec.loginRequestKeyword >> 8) & 0xFF,
      AfrrOperatorProtocolCodec.loginRequestKeyword & 0xFF,
      (replySerialNumber >> 8) & 0xFF,
      replySerialNumber & 0xFF,
      result,
    ],
  );
}

Future<void> _waitForWrites(_TestSocket socket, int count) async {
  for (
    var attempt = 0;
    attempt < 20 && socket.writes.length < count;
    attempt++
  ) {
    await Future<void>.delayed(Duration.zero);
  }
  if (socket.writes.length < count) {
    throw StateError('AFRR 测试请求未写入 Socket');
  }
}

String _hex(List<int> bytes) {
  return bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();
}

Uint8List _bytesFromHex(String value) {
  return Uint8List.fromList(<int>[
    for (var index = 0; index < value.length; index += 2)
      int.parse(value.substring(index, index + 2), radix: 16),
  ]);
}

final class _TestSocket implements Socket {
  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  final List<List<int>> writes = <List<int>>[];

  void emitBytes(List<int> bytes) {
    _incoming.add(Uint8List.fromList(bytes));
  }

  @override
  void add(List<int> data) {
    writes.add(List<int>.of(data));
  }

  @override
  Future<void> flush() async {}

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _incoming.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  void destroy() {}

  Future<void> dispose() async {
    if (!_incoming.isClosed) {
      await _incoming.close();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
