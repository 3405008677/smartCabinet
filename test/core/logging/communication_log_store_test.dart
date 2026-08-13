import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cabinet/src/core/logging/communication_log_store.dart';

void main() {
  group('CommunicationLogStore', () {
    test('按时间倒序保留有界且不可变的日志快照', () async {
      final store = CommunicationLogStore(maximumEntries: 2);
      addTearDown(store.dispose);

      store.record(
        targetType: CommunicationTargetType.server,
        direction: CommunicationDirection.outbound,
        channel: 'test',
        operation: 'first',
        messageBody: const <String, Object?>{'value': 1},
        requestTime: DateTime(2026, 1, 1, 8),
        result: '成功',
      );
      store.record(
        targetType: CommunicationTargetType.hardware,
        direction: CommunicationDirection.inbound,
        channel: 'test',
        operation: 'latest',
        messageBody: const <String, Object?>{'value': 2},
        requestTime: DateTime(2026, 1, 1, 10),
        result: '成功',
      );
      store.record(
        targetType: CommunicationTargetType.server,
        direction: CommunicationDirection.inbound,
        channel: 'test',
        operation: 'middle',
        messageBody: const <String, Object?>{'value': 3},
        requestTime: DateTime(2026, 1, 1, 9),
        result: '成功',
      );

      expect(store.entries.map((entry) => entry.operation), <String>[
        'latest',
        'middle',
      ]);
      expect(
        () => store.entries.add(store.entries.first),
        throwsUnsupportedError,
      );
    });

    test('请求应答会更新上报结果并新增下发日志', () async {
      final store = CommunicationLogStore();
      addTearDown(store.dispose);

      final value = await store.traceExchange<int>(
        targetType: CommunicationTargetType.hardware,
        channel: 'test-channel',
        operation: 'readStatus',
        requestBody: const <String, Object?>{'role': 'outside'},
        action: () async => 9,
        responseBody: (result) => <String, Object?>{'value': result},
      );

      expect(value, 9);
      expect(store.entries, hasLength(2));
      expect(
        store.entries.map((entry) => entry.direction),
        containsAll(<CommunicationDirection>[
          CommunicationDirection.outbound,
          CommunicationDirection.inbound,
        ]),
      );
      expect(store.entries.every((entry) => entry.result == '成功'), isTrue);
    });

    test('失败只记录安全的异常类型并保留原异常', () async {
      final store = CommunicationLogStore();
      addTearDown(store.dispose);

      await expectLater(
        store.traceExchange<void>(
          targetType: CommunicationTargetType.server,
          channel: 'test-channel',
          operation: 'send',
          requestBody: const <String, Object?>{'token': 'private-token'},
          action: () async => throw StateError('password=private-password'),
        ),
        throwsStateError,
      );

      expect(store.entries, hasLength(1));
      expect(store.entries.single.result, '失败：StateError');
      expect(
        store.entries.single.completeInformation,
        isNot(contains('private')),
      );
    });

    test('日志消息或响应格式化异常不会改变真实通讯结果', () async {
      final store = CommunicationLogStore();
      addTearDown(store.dispose);

      final value = await store.traceExchange<int>(
        targetType: CommunicationTargetType.hardware,
        channel: 'test-channel',
        operation: 'readStatus',
        requestBody: const _ThrowingToString(),
        action: () async => 42,
        responseBody: (_) => throw StateError('formatter failed'),
      );

      expect(value, 42);
      expect(store.entries, hasLength(1));
      expect(store.entries.single.direction, CommunicationDirection.inbound);
      expect(store.entries.single.messageBody, contains('responseType'));
      expect(store.entries.single.messageBody, contains('int'));
    });

    test('诊断时钟异常不会阻止真实通讯执行', () async {
      final store = CommunicationLogStore(
        clock: () => throw StateError('clock unavailable'),
      );
      addTearDown(store.dispose);

      final value = await store.traceExchange<int>(
        targetType: CommunicationTargetType.server,
        channel: 'test-channel',
        operation: 'heartbeat',
        requestBody: const <String, Object?>{'kind': 'heartbeat'},
        action: () async => 7,
      );

      expect(value, 7);
      expect(store.entries, isEmpty);
    });

    test('消息进入内存前会脱敏凭据、唯一标识、路径、URL 和二进制', () async {
      final store = CommunicationLogStore();
      addTearDown(store.dispose);

      store.record(
        targetType: CommunicationTargetType.server,
        direction: CommunicationDirection.outbound,
        channel: 'security-test',
        operation: 'sanitize',
        messageBody: <String, Object?>{
          'password': 'password-value',
          'token': 'token-value',
          'appId': 'app-id-value',
          'IMEI': '123456789012345',
          'ID': 'terminal-id-value',
          'operationId': 'operation-id-value',
          'apkPath': '/private/update.apk',
          'url': 'https://user:pass@example.test/file.apk?token=query#part',
          'streamUrl':
              'rtsp://camera:secret@192.0.2.10:8554/live/device-unique-id?token=query',
          'lastErrorMessage':
              'RTSP failed at rtsp://192.0.2.10:8554/live/device-unique-id',
          'downloadsLogFile': r'C:\private\SmartCabinetLogs\error.log',
          'payload': Uint8List.fromList(<int>[1, 2, 3, 4]),
        },
        result: '成功',
      );

      final text = store.entries.single.completeInformation;
      for (final secret in <String>[
        'password-value',
        'token-value',
        'app-id-value',
        '123456789012345',
        'terminal-id-value',
        'operation-id-value',
        '/private/update.apk',
        'user:pass',
        'token=query',
        '#part',
        '/file.apk',
        '/live/device-unique-id',
        r'C:\private\SmartCabinetLogs\error.log',
      ]) {
        expect(text, isNot(contains(secret)));
      }
      expect(text, contains('https://example.test'));
      expect(text, contains('rtsp://192.0.2.10:8554'));
      expect(text, contains('4 字节二进制数据'));
    });
  });
}

/// 模拟无法安全字符串化的第三方平台对象。
final class _ThrowingToString {
  const _ThrowingToString();

  @override
  String toString() => throw StateError('cannot stringify');
}
