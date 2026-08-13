import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/core/logging/communication_log_store.dart';
import 'package:smart_cabinet/src/core/logging/native_communication_log_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const snapshotChannel = MethodChannel('test/communication_log_snapshot');
  const eventsChannelName = 'test/communication_log_events';
  const eventsMethodChannel = MethodChannel(eventsChannelName);

  test('导入原生快照时去重，并忽略异常事件而不污染后续同 ID 记录', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(eventsMethodChannel, (_) async => null);
    messenger.setMockMethodCallHandler(snapshotChannel, (call) async {
      expect(call.method, 'snapshot');
      return <Object?>[
        _nativeEvent(
          nativeId: 1,
          targetType: 'server',
          direction: 'outbound',
          endpoint: 'rtsp://user:secret@example.test/live/device-id?token=x',
        ),
        _nativeEvent(
          nativeId: 1,
          targetType: 'server',
          direction: 'outbound',
          endpoint: 'rtsp://duplicate.invalid/private',
        ),
        _nativeEvent(
          nativeId: 2,
          targetType: 'hardware',
          direction: 'inbound',
          epochMilliseconds: 1 << 62,
        ),
        _nativeEvent(nativeId: 2, targetType: 'hardware', direction: 'inbound'),
      ];
    });
    addTearDown(() async {
      messenger.setMockMethodCallHandler(snapshotChannel, null);
      messenger.setMockMethodCallHandler(eventsMethodChannel, null);
    });

    final store = CommunicationLogStore();
    final bridge = NativeCommunicationLogBridge(
      store: store,
      methodChannel: snapshotChannel,
      eventChannel: const EventChannel(eventsChannelName),
    );
    addTearDown(bridge.dispose);
    addTearDown(store.dispose);

    await bridge.ensureStarted();

    expect(store.entries, hasLength(2));
    final text = store.entries
        .map((entry) => entry.completeInformation)
        .join('\n');
    expect(text, contains('rtsp://example.test'));
    expect(text, isNot(contains('/live/device-id')));
    expect(text, isNot(contains('secret')));
    expect(text, isNot(contains('duplicate.invalid')));
  });
}

/// 构造与 Android 原生通道契约一致的测试事件。
Map<String, Object?> _nativeEvent({
  required int nativeId,
  required String targetType,
  required String direction,
  String endpoint = 'https://hardware.example.test/status',
  int epochMilliseconds = 1786410000000,
}) {
  return <String, Object?>{
    'nativeId': nativeId,
    'targetType': targetType,
    'direction': direction,
    'channel': 'test',
    'operation': 'test operation',
    'messageBody': <String, Object?>{'endpoint': endpoint},
    'requestTimeEpochMs': epochMilliseconds,
    'result': '成功',
  };
}
