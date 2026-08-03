import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cabinet/src/core/camera/cabinet_camera.dart';
import 'package:smart_cabinet/src/core/device/kiosk_device.dart';
import 'package:smart_cabinet/src/core/mqtt/mqtt_service.dart';

void main() {
  test('builds default mqtt connection options', () {
    const options = SmartCabinetMqttOptions.defaults;

    expect(options.host, '192.168.2.222');
    expect(options.port, 1883);
    expect(options.clientId, 'smart-cabinet-b1cf98b759900d71');
    expect(options.deviceId, 'b1cf98b759900d71');
    expect(options.clean, isTrue);
    expect(options.keepAlive, const Duration(seconds: 30));
    expect(options.reconnectPeriod, const Duration(seconds: 5));
    expect(options.connectTimeout, const Duration(seconds: 5));
    expect(
      options.commandTopic,
      'ata/smartCabinet/b1cf98b759900d71/video/command',
    );
  });

  test('connects and subscribes command topic through gateway', () async {
    final gateway = _FakeMqttGateway();
    final service = SmartCabinetMqttService(gateway: gateway);

    await service.connectAndSubscribe();

    expect(gateway.connectedOptions, SmartCabinetMqttOptions.defaults);
    expect(gateway.subscribedTopics, [
      'ata/smartCabinet/b1cf98b759900d71/video/command',
    ]);
  });

  test('starts 720p outside environment stream from video command', () async {
    final device = _FakeKioskDevice();
    final handler = SmartCabinetMqttCommandHandler(kioskDevice: device);

    await handler.handleMessage('''
{
  "commandId": "5c7ae549-93da-4a4a-8cca-a9956de467c1",
  "type": "video",
  "payload": {"videoType": "720p"},
  "traceId": "a7c20592-c46d-4311-955d-b55bb4b75065",
  "expireAt": "2026-07-09T03:20:00.000Z"
}
''');

    expect(device.startedStreams, hasLength(1));
    expect(
      device.startedStreams.single.role,
      CabinetCameraRole.outsideEnvironment,
    );
    expect(device.startedStreams.single.profiles, ['720p']);
  });

  test('starts 1080p outside environment stream from video command', () async {
    final device = _FakeKioskDevice();
    final handler = SmartCabinetMqttCommandHandler(kioskDevice: device);

    await handler.handleMessage('''
{
  "commandId": "5c7ae549-93da-4a4a-8cca-a9956de467c1",
  "type": "video",
  "payload": {"videoType": "1080p"}
}
''');

    expect(device.startedStreams, hasLength(1));
    expect(
      device.startedStreams.single.role,
      CabinetCameraRole.outsideEnvironment,
    );
    expect(device.startedStreams.single.profiles, ['1080p']);
  });

  test('ignores unsupported mqtt command type and video profile', () async {
    final device = _FakeKioskDevice();
    final handler = SmartCabinetMqttCommandHandler(kioskDevice: device);

    await handler.handleMessage(
      '{"type":"door","payload":{"videoType":"720p"}}',
    );
    await handler.handleMessage(
      '{"type":"video","payload":{"videoType":"360p"}}',
    );

    expect(device.startedStreams, isEmpty);
  });
}

class _FakeMqttGateway implements SmartCabinetMqttGateway {
  SmartCabinetMqttOptions? connectedOptions;
  final List<String> subscribedTopics = [];
  final StreamController<SmartCabinetMqttMessage> _messagesController =
      StreamController<SmartCabinetMqttMessage>.broadcast();

  @override
  Stream<SmartCabinetMqttMessage> get messages => _messagesController.stream;

  @override
  Future<void> connect(SmartCabinetMqttOptions options) async {
    connectedOptions = options;
  }

  @override
  void subscribe(String topic) {
    subscribedTopics.add(topic);
  }
}

class _FakeKioskDevice implements KioskDevice {
  final List<({CabinetCameraRole role, List<String> profiles})> startedStreams =
      [];

  @override
  Future<bool> enterKioskMode() async => true;

  @override
  Future<bool> exitKioskMode() async => true;

  @override
  Future<bool> isDeviceOwner() async => true;

  @override
  Future<bool> isKioskModeActive() async => true;

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<void> startCameraStream(
    CabinetCameraRole role, {
    required List<String> profiles,
  }) async {
    startedStreams.add((role: role, profiles: profiles));
  }

  @override
  Future<void> stopCameraStream(
    CabinetCameraRole role, {
    List<String>? profiles,
  }) async {}

  @override
  Future<List<String>> retryCameraStream(CabinetCameraRole role) async {
    return const <String>[];
  }
}
