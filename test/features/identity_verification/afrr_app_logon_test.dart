import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/core/config/app_config.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/datasources/operator_afrr_login_data_source.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/protocol/afrr_app_heartbeat_protocol.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/protocol/afrr_app_logon_protocol.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/protocol/afrr_operator_protocol.dart';

void main() {
  const imei = '867282037661259';
  const randomCode = 'af2j7gq9sz4d8n1kx6bt3ph0rcm5yu';

  test('splits the fixed credential source using one-based positions', () {
    expect(AppConfig.current.appId, 'ax2fb046zdpjtyu7wl92');
    expect(AppConfig.current.appSecret, '7qk8vrnm3g5h1ceaoqbf');
  });

  test('creates the documented HMAC-SHA256 logon payload', () {
    final request = AfrrAppLogonProtocol.createRequest(
      appId: 'ax2fb046zdpjtyu7wl92',
      appSecret: '7qk8vrnm3g5h1ceaoqbf',
      imei: imei,
      timestampMilliseconds: 1786139245721,
      randomCode: randomCode,
    );

    expect(request, <String, Object?>{
      'func': 'logon',
      'data': <String, Object?>{
        'ts': 1786139245721,
        'rc': randomCode,
        'data':
            '5d21ea7833616dd6b342031a206a3ffbcb521503aca250a71082089384d4e4e4',
      },
    });
  });

  test('creates heartbeat payload without faking missing terminal data', () {
    expect(
      AfrrAppHeartbeatProtocol.createRequest(
        timestamp: DateTime.utc(2026, 8, 8, 12, 12, 12),
      ),
      <String, Object?>{
        'func': 'heartbeat',
        'data': <String, Object?>{'time': '202608081212120000', 'data': null},
      },
    );

    expect(
      AfrrAppHeartbeatProtocol.createRequest(
        timestamp: DateTime.utc(2026, 8, 8, 12, 12, 12),
        terminalFramePayload: <int>[0xA1, 0x02, 0x00, 0x01],
      )['data'],
      <String, Object?>{
        'time': '202608081212120000',
        'data': <int>[0xA1, 0x02, 0x00, 0x01],
      },
    );
  });

  test('sends logon as the first frame and keeps the connection', () async {
    final socket = _TestSocket();
    final dataSource = OperatorAfrrLoginDataSource(
      host: '192.0.2.10',
      port: 16666,
      shelfCode: imei,
      imei: imei,
      appId: 'ax2fb046zdpjtyu7wl92',
      appSecret: '7qk8vrnm3g5h1ceaoqbf',
      socketConnector: (_, _, _) async => socket,
      clock: () => DateTime.fromMillisecondsSinceEpoch(1786139245721),
      randomCodeFactory: () => randomCode,
      sequence: AfrrOperatorMessageSequence(initialValue: 12),
    );

    try {
      final logon = dataSource.logonApp();
      await _waitForWrites(socket, 1);
      final request = AfrrOperatorProtocolCodec.decodeFrame(
        socket.writes.single,
      );

      expect(request.keyword, 0xA170);
      expect(request.serialNumber, 12);
      expect(request.jsonPayload?['func'], 'logon');
      expect(request.jsonPayload?['data'], isA<Map>());

      socket.emitBytes(
        _compactResponseFrame(
          shelfCode: imei,
          replySerialNumber: request.serialNumber,
          result: 9,
        ),
      );
      await logon;

      await dataSource.logonApp();
      expect(socket.writes, hasLength(1));
    } finally {
      await dataSource.dispose();
      await socket.dispose();
    }
  });

  test('preserves the server logon failure detail', () async {
    final socket = _TestSocket();
    final dataSource = OperatorAfrrLoginDataSource(
      host: '192.0.2.10',
      port: 16666,
      shelfCode: imei,
      imei: imei,
      appId: 'ax2fb046zdpjtyu7wl92',
      appSecret: '7qk8vrnm3g5h1ceaoqbf',
      socketConnector: (_, _, _) async => socket,
      randomCodeFactory: () => randomCode,
      maximumAttempts: 1,
    );

    try {
      final logon = dataSource.logonApp();
      await _waitForWrites(socket, 1);
      final request = AfrrOperatorProtocolCodec.decodeFrame(
        socket.writes.single,
      );
      socket.emitBytes(
        _responseFrame(
          shelfCode: imei,
          replySerialNumber: request.serialNumber,
          result: 1,
          data: 'APP 签名错误',
        ),
      );

      await expectLater(
        logon,
        throwsA(
          isA<AfrrAppLogonException>().having(
            (error) => error.message,
            'message',
            'APP 签名错误',
          ),
        ),
      );
    } finally {
      await dataSource.dispose();
      await socket.dispose();
    }
  });

  test(
    'sends heartbeat on the logged-on connection and accepts B170',
    () async {
      final socket = _TestSocket();
      final dataSource = OperatorAfrrLoginDataSource(
        host: '192.0.2.10',
        port: 16666,
        shelfCode: imei,
        imei: imei,
        appId: 'ax2fb046zdpjtyu7wl92',
        appSecret: '7qk8vrnm3g5h1ceaoqbf',
        socketConnector: (_, _, _) async => socket,
        clock: () => DateTime.utc(2026, 8, 8, 12, 12, 12),
        randomCodeFactory: () => randomCode,
        sequence: AfrrOperatorMessageSequence(initialValue: 20),
        heartbeatInterval: const Duration(hours: 1),
      );

      try {
        final logon = dataSource.logonApp();
        await _waitForWrites(socket, 1);
        final logonRequest = AfrrOperatorProtocolCodec.decodeFrame(
          socket.writes.first,
        );
        socket.emitBytes(
          _compactResponseFrame(
            shelfCode: imei,
            replySerialNumber: logonRequest.serialNumber,
            result: 9,
          ),
        );
        await logon;

        final heartbeat = dataSource.sendHeartbeat();
        await _waitForWrites(socket, 2);
        final request = AfrrOperatorProtocolCodec.decodeFrame(
          socket.writes.last,
        );
        expect(request.serialNumber, 21);
        expect(request.jsonPayload, <String, Object?>{
          'func': 'heartbeat',
          'data': <String, Object?>{'time': '202608081212120000', 'data': null},
        });

        socket.emitBytes(
          _responseFrame(
            shelfCode: imei,
            replySerialNumber: request.serialNumber,
            function: 'heartbeat',
            result: 9,
          ),
        );
        await heartbeat;
        expect(dataSource.lastHeartbeatError, isNull);
      } finally {
        await dataSource.dispose();
        await socket.dispose();
      }
    },
  );

  test('starts the one-minute heartbeat loop after logon', () async {
    final socket = _TestSocket();
    final dataSource = OperatorAfrrLoginDataSource(
      host: '192.0.2.10',
      port: 16666,
      shelfCode: imei,
      imei: imei,
      appId: 'ax2fb046zdpjtyu7wl92',
      appSecret: '7qk8vrnm3g5h1ceaoqbf',
      socketConnector: (_, _, _) async => socket,
      randomCodeFactory: () => randomCode,
      heartbeatInterval: const Duration(milliseconds: 1),
    );

    try {
      final logon = dataSource.logonApp();
      await _waitForWrites(socket, 1);
      final request = AfrrOperatorProtocolCodec.decodeFrame(
        socket.writes.first,
      );
      socket.emitBytes(
        _compactResponseFrame(
          shelfCode: imei,
          replySerialNumber: request.serialNumber,
          result: 9,
        ),
      );
      await logon;

      await _waitForWrites(socket, 2);
      expect(
        AfrrOperatorProtocolCodec.decodeFrame(
          socket.writes[1],
        ).jsonPayload?['func'],
        'heartbeat',
      );
    } finally {
      await dataSource.dispose();
      await socket.dispose();
    }
  });

  test(
    'reconnects with logon as the first frame after heartbeat timeout',
    () async {
      final firstSocket = _TestSocket();
      final secondSocket = _TestSocket();
      var connectionCount = 0;
      final dataSource = OperatorAfrrLoginDataSource(
        host: '192.0.2.10',
        port: 16666,
        shelfCode: imei,
        imei: imei,
        appId: 'ax2fb046zdpjtyu7wl92',
        appSecret: '7qk8vrnm3g5h1ceaoqbf',
        socketConnector: (_, _, _) async {
          connectionCount += 1;
          return connectionCount == 1 ? firstSocket : secondSocket;
        },
        randomCodeFactory: () => randomCode,
        heartbeatInterval: const Duration(milliseconds: 1),
        heartbeatRetryDelay: const Duration(milliseconds: 1),
        requestTimeout: const Duration(milliseconds: 20),
        maximumAttempts: 1,
      );

      try {
        final logon = dataSource.logonApp();
        await _waitForWrites(firstSocket, 1);
        final firstLogon = AfrrOperatorProtocolCodec.decodeFrame(
          firstSocket.writes.first,
        );
        firstSocket.emitBytes(
          _compactResponseFrame(
            shelfCode: imei,
            replySerialNumber: firstLogon.serialNumber,
            result: 9,
          ),
        );
        await logon;
        await _waitForWrites(firstSocket, 2);
        expect(
          AfrrOperatorProtocolCodec.decodeFrame(
            firstSocket.writes[1],
          ).jsonPayload?['func'],
          'heartbeat',
        );

        await _waitForWrites(secondSocket, 1);
        final reconnectFirstFrame = AfrrOperatorProtocolCodec.decodeFrame(
          secondSocket.writes.first,
        );
        expect(reconnectFirstFrame.jsonPayload?['func'], 'logon');
        expect(dataSource.lastHeartbeatError, isNotNull);
      } finally {
        await dataSource.dispose();
        await firstSocket.dispose();
        await secondSocket.dispose();
      }
    },
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

Uint8List _responseFrame({
  required String shelfCode,
  required int replySerialNumber,
  required int result,
  String function = 'logon',
  Object? data,
}) {
  final jsonBytes = utf8.encode(
    jsonEncode(<String, Object?>{
      'func': function,
      'rst': result,
      'data': data,
    }),
  );
  return AfrrOperatorProtocolCodec.encodeFrame(
    keyword: AfrrOperatorProtocolCodec.loginResponseKeyword,
    shelfCode: shelfCode,
    serialNumber: 99,
    body: <int>[
      0x01,
      0x02,
      (replySerialNumber >> 8) & 0xFF,
      replySerialNumber & 0xFF,
      0xA0,
      (jsonBytes.length >> 8) & 0xFF,
      jsonBytes.length & 0xFF,
      ...jsonBytes,
    ],
  );
}

/// 等待测试 Socket 收到指定数量的写入，最多等待一秒。
Future<void> _waitForWrites(_TestSocket socket, int count) async {
  final deadline = DateTime.now().add(const Duration(seconds: 1));
  while (socket.writes.length < count && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  if (socket.writes.length < count) {
    throw StateError('AFRR APP logon 测试请求未写入 Socket');
  }
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
