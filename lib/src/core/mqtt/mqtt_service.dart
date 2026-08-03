import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'package:smart_cabinet/src/core/camera/cabinet_camera.dart';
import 'package:smart_cabinet/src/core/device/kiosk_device.dart';
import 'package:smart_cabinet/src/core/device/method_channel_kiosk_device.dart';
import 'package:smart_cabinet/src/core/logging/app_logger.dart';

/// 智能柜 MQTT 连接配置。
class SmartCabinetMqttOptions {
  /// 创建 MQTT 连接配置。
  const SmartCabinetMqttOptions({
    required this.host,
    required this.port,
    required this.clientId,
    required this.clean,
    required this.keepAlive,
    required this.reconnectPeriod,
    required this.connectTimeout,
  });

  /// 默认 MQTT 连接配置。
  static const defaults = SmartCabinetMqttOptions(
    host: '192.168.2.222',
    port: 1883,
    clientId: 'smart-cabinet-b1cf98b759900d71',
    clean: true,
    keepAlive: Duration(seconds: 30),
    reconnectPeriod: Duration(seconds: 5),
    connectTimeout: Duration(seconds: 5),
  );

  /// MQTT broker 主机。
  final String host;

  /// MQTT broker 端口。
  final int port;

  /// MQTT 客户端 ID，同时作为当前设备 ID 使用。
  final String clientId;

  /// 业务设备 ID。
  String get deviceId => clientId.startsWith('smart-cabinet-')
      ? clientId.replaceFirst('smart-cabinet-', '')
      : clientId;

  /// 是否使用 clean session。
  final bool clean;

  /// MQTT keep alive 周期。
  final Duration keepAlive;

  /// 断线自动重连周期。
  final Duration reconnectPeriod;

  /// 首次连接超时时间。
  final Duration connectTimeout;

  /// 当前设备接收视频流控制命令的主题。
  String get commandTopic => 'ata/smartCabinet/$deviceId/video/command';

  @override
  bool operator ==(Object other) {
    return other is SmartCabinetMqttOptions &&
        other.host == host &&
        other.port == port &&
        other.clientId == clientId &&
        other.clean == clean &&
        other.keepAlive == keepAlive &&
        other.reconnectPeriod == reconnectPeriod &&
        other.connectTimeout == connectTimeout;
  }

  @override
  int get hashCode => Object.hash(
    host,
    port,
    clientId,
    clean,
    keepAlive,
    reconnectPeriod,
    connectTimeout,
  );
}

/// MQTT 启动连接接口。
abstract interface class SmartCabinetMqttConnector {
  /// 连接 MQTT 并订阅启动阶段必需主题。
  Future<void> connectAndSubscribe();
}

/// MQTT 网关接口，隔离第三方客户端，便于测试启动逻辑。
abstract interface class SmartCabinetMqttGateway {
  /// 按指定配置连接 MQTT broker。
  Future<void> connect(SmartCabinetMqttOptions options);

  /// 订阅指定主题。
  void subscribe(String topic);

  /// MQTT 消息流。
  Stream<SmartCabinetMqttMessage> get messages;
}

/// MQTT 收到的原始业务消息。
class SmartCabinetMqttMessage {
  /// 创建 MQTT 原始业务消息。
  const SmartCabinetMqttMessage({required this.topic, required this.payload});

  /// 消息主题。
  final String topic;

  /// 消息负载。
  final String payload;
}

/// 智能柜 MQTT 服务。
class SmartCabinetMqttService implements SmartCabinetMqttConnector {
  /// 创建智能柜 MQTT 服务。
  const SmartCabinetMqttService({
    this.gateway,
    this.options = SmartCabinetMqttOptions.defaults,
    this.commandHandler = const SmartCabinetMqttCommandHandler(),
  });

  /// MQTT 网关。
  final SmartCabinetMqttGateway? gateway;

  /// MQTT 连接配置。
  final SmartCabinetMqttOptions options;

  /// MQTT 命令处理器。
  final SmartCabinetMqttCommandHandler commandHandler;

  @override
  Future<void> connectAndSubscribe() async {
    final mqttGateway = gateway ?? MqttClientGateway();
    await mqttGateway.connect(options);
    mqttGateway.subscribe(options.commandTopic);
    mqttGateway.messages.listen((message) {
      unawaited(commandHandler.handleMessage(message.payload));
    });
  }
}

/// 智能柜 MQTT 命令处理器。
class SmartCabinetMqttCommandHandler {
  /// 创建智能柜 MQTT 命令处理器。
  const SmartCabinetMqttCommandHandler({
    this.kioskDevice = const MethodChannelKioskDevice(),
  });

  /// 自助终端设备能力。
  final KioskDevice kioskDevice;

  /// 处理 MQTT 消息负载。
  Future<void> handleMessage(String payload) async {
    final command = _parseCommand(payload);
    if (command == null || command.type != 'video') {
      return;
    }
    final videoType = command.videoType;
    if (videoType != '720p' && videoType != '1080p') {
      AppLogger.business('Ignore unsupported MQTT videoType: $videoType');
      return;
    }
    await kioskDevice.startCameraStream(
      CabinetCameraRole.outsideEnvironment,
      profiles: [videoType],
    );
  }

  _MqttVideoCommand? _parseCommand(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      final payloadValue = decoded['payload'];
      if (payloadValue is! Map<String, Object?>) {
        return _MqttVideoCommand(type: decoded['type']?.toString() ?? '');
      }
      return _MqttVideoCommand(
        type: decoded['type']?.toString() ?? '',
        videoType: payloadValue['videoType']?.toString() ?? '',
      );
    } catch (error, stackTrace) {
      AppLogger.error('MQTT command parse failed', error, stackTrace);
      return null;
    }
  }
}

class _MqttVideoCommand {
  const _MqttVideoCommand({required this.type, this.videoType = ''});

  final String type;
  final String videoType;
}

/// 基于 `mqtt_client` 的 MQTT 网关。
class MqttClientGateway implements SmartCabinetMqttGateway {
  /// 创建 MQTT 网关。
  MqttClientGateway();

  MqttServerClient? _client;
  final StreamController<SmartCabinetMqttMessage> _messagesController =
      StreamController<SmartCabinetMqttMessage>.broadcast();

  @override
  Stream<SmartCabinetMqttMessage> get messages => _messagesController.stream;

  @override
  Future<void> connect(SmartCabinetMqttOptions options) async {
    final client = MqttServerClient.withPort(
      options.host,
      options.clientId,
      options.port,
    );
    client.logging(on: false);
    client.setProtocolV311();
    client.keepAlivePeriod = options.keepAlive.inSeconds;
    client.connectTimeoutPeriod = options.connectTimeout.inMilliseconds;
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;
    client.onConnected = () => AppLogger.business('MQTT connected');
    client.onDisconnected = () => AppLogger.business('MQTT disconnected');
    client.onAutoReconnect = () => AppLogger.business('MQTT reconnecting');
    client.onAutoReconnected = () => AppLogger.business('MQTT reconnected');
    client.onSubscribed = (topic) =>
        AppLogger.business('MQTT subscribed: $topic');
    client.connectionMessage = options.clean
        ? (MqttConnectMessage()
            ..withClientIdentifier(options.clientId)
            ..startClean())
        : (MqttConnectMessage()..withClientIdentifier(options.clientId));

    final status = await client.connect();
    if (status?.state != MqttConnectionState.connected) {
      client.disconnect();
      throw StateError('MQTT 连接失败：${status?.state} / ${status?.returnCode}');
    }
    client.updates?.listen((messages) {
      for (final receivedMessage in messages) {
        final mqttMessage = receivedMessage.payload;
        if (mqttMessage is! MqttPublishMessage) {
          continue;
        }
        final payload = MqttPublishPayload.bytesToStringAsString(
          mqttMessage.payload.message,
        );
        _messagesController.add(
          SmartCabinetMqttMessage(
            topic: receivedMessage.topic,
            payload: payload,
          ),
        );
      }
    });
    _client = client;
  }

  @override
  void subscribe(String topic) {
    final client = _client;
    if (client == null ||
        client.connectionStatus?.state != MqttConnectionState.connected) {
      throw StateError('MQTT 尚未连接，无法订阅：$topic');
    }
    client.subscribe(topic, MqttQos.atMostOnce);
  }
}
