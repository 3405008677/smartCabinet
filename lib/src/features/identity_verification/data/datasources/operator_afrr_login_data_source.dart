import 'dart:async';
import 'dart:io';

import 'package:smart_cabinet/src/core/network/protocol/tcp_protocol.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/datasources/operator_authentication_data_source.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/dtos/operator_login_dto.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/protocol/afrr_app_heartbeat_protocol.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/protocol/afrr_app_logon_protocol.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/protocol/afrr_operator_protocol.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_login_request.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/repositories/operator_identity_repository.dart';

/// 返回当前终端时间的函数类型，测试可注入固定时间。
typedef OperatorProtocolClock = DateTime Function();

/// 生成 APP 登录随机码的函数类型，测试可注入固定值。
typedef AfrrAppLogonRandomCodeFactory = String Function();

/// 返回最近终端 A101/A102 报文透传内容的函数类型。
///
/// 返回 null 表示约定时间内没有收到终端心跳，不能用空数组冒充终端在线。
typedef AfrrHeartbeatPayloadProvider = FutureOr<List<int>?> Function();

/// APP 启动登录失败。
final class AfrrAppLogonException implements Exception {
  /// 创建可直接展示在阻断提示中的错误。
  const AfrrAppLogonException(this.message);

  /// 不包含凭据或签名内容的错误说明。
  final String message;

  @override
  String toString() => message;
}

/// 通过 AFRR TCP A170/B170 完成三种操作员登录的数据源。
final class OperatorAfrrLoginDataSource
    implements OperatorAuthenticationDataSource {
  /// 创建 AFRR 登录数据源。
  OperatorAfrrLoginDataSource({
    required this.host,
    required this.port,
    required this.shelfCode,
    this.imei = '',
    this.appId = '',
    this.appSecret = '',
    TcpSocketConnector? socketConnector,
    OperatorProtocolClock? clock,
    AfrrAppLogonRandomCodeFactory? randomCodeFactory,
    AfrrHeartbeatPayloadProvider? heartbeatPayloadProvider,
    AfrrOperatorMessageSequence? sequence,
    this.connectTimeout = const Duration(seconds: 8),
    this.requestTimeout = const Duration(seconds: 5),
    this.heartbeatInterval = AfrrAppHeartbeatProtocol.interval,
    this.heartbeatRetryDelay = const Duration(seconds: 5),
    this.maximumAttempts = 3,
  }) : _clock = clock ?? DateTime.now,
       _randomCodeFactory =
           randomCodeFactory ?? AfrrAppLogonProtocol.generateRandomCode,
       _heartbeatPayloadProvider = heartbeatPayloadProvider ?? _noHeartbeat,
       _sequence = sequence ?? AfrrOperatorMessageSequence(),
       _client = TcpProtocolClient<AfrrOperatorMessage>(
         frameDecoderFactory: AfrrOperatorFrameDecoder.new,
         socketConnector: socketConnector,
         communicationLogAdapter:
             const TcpCommunicationLogAdapter<AfrrOperatorMessage>(
               channel: 'AFRR TCP',
               formatOutbound: _formatAfrrOutboundLog,
               formatInbound: _formatAfrrInboundLog,
             ),
         connectTimeout: connectTimeout,
         defaultRequestTimeout: requestTimeout,
       ) {
    if (connectTimeout <= Duration.zero ||
        requestTimeout <= Duration.zero ||
        heartbeatInterval <= Duration.zero ||
        heartbeatRetryDelay <= Duration.zero) {
      throw ArgumentError('AFRR 连接、请求、心跳和重连间隔必须大于 0');
    }
    if (maximumAttempts < 1 || maximumAttempts > 3) {
      throw RangeError.range(maximumAttempts, 1, 3, 'maximumAttempts');
    }
  }

  /// AFRR TCP 服务主机。
  final String host;

  /// AFRR TCP 服务端口。
  final int port;

  /// 15 位 IMEI 或补零后的 16 位货架编码。
  final String shelfCode;

  /// APP 登录签名使用的 15 位设备 IMEI。
  final String imei;

  /// APP 登录身份。
  final String appId;

  /// APP 登录 HMAC 签名密钥。
  final String appSecret;

  /// 单次 TCP 连接超时。
  final Duration connectTimeout;

  /// 单次 A170 请求等待 B170 的超时。
  final Duration requestTimeout;

  /// APP 成功登录后相邻两次心跳的目标间隔。
  final Duration heartbeatInterval;

  /// 心跳失败并安全断开后，重新建立 APP 会话前的等待时间。
  final Duration heartbeatRetryDelay;

  /// 包含首次发送在内的最大尝试次数；协议约定最多重发两次。
  final int maximumAttempts;

  final OperatorProtocolClock _clock;
  final AfrrAppLogonRandomCodeFactory _randomCodeFactory;
  final AfrrHeartbeatPayloadProvider _heartbeatPayloadProvider;
  final AfrrOperatorMessageSequence _sequence;
  final TcpProtocolClient<AfrrOperatorMessage> _client;

  Future<void>? _connecting;
  Future<void>? _loggingOn;
  Timer? _heartbeatTimer;
  Future<void>? _heartbeatOperation;
  Object? _lastHeartbeatError;
  bool _appLoggedOn = false;
  bool _disposed = false;

  /// 最近一次后台心跳失败；后续成功心跳会清空该值。
  Object? get lastHeartbeatError => _lastHeartbeatError;

  /// 建立 AFRR TCP 连接，并把 `logon` 作为该连接的第一条消息发送。
  ///
  /// 成功后保留连接供操作员登录和后续协议命令复用；并发调用只执行一次登录。
  Future<void> logonApp() async {
    if (_appLoggedOn && _client.isConnected) {
      _ensureHeartbeatScheduled();
      return;
    }
    final pending = _loggingOn;
    if (pending != null) {
      return pending;
    }

    final operation = _performAppLogon();
    _loggingOn = operation;
    try {
      await operation;
      _lastHeartbeatError = null;
      _scheduleHeartbeat(heartbeatInterval);
    } on AfrrAppLogonException {
      rethrow;
    } on OperatorLoginException catch (error) {
      throw AfrrAppLogonException(error.message);
    } on TcpProtocolRequestTimeoutException {
      throw const AfrrAppLogonException('监管服务 APP 登录响应超时');
    } on TcpProtocolDisconnectedException catch (error) {
      throw AfrrAppLogonException('监管服务连接已断开：${error.message}');
    } on SocketException catch (error) {
      throw AfrrAppLogonException('无法连接监管服务：${error.message}');
    } on TimeoutException {
      throw const AfrrAppLogonException('连接监管服务超时');
    } on AfrrOperatorProtocolException catch (error) {
      throw AfrrAppLogonException('监管服务 APP 登录回复无效：${error.message}');
    } on ArgumentError catch (error) {
      throw AfrrAppLogonException('监管服务 APP 登录配置无效：${error.message}');
    } finally {
      if (identical(_loggingOn, operation)) {
        _loggingOn = null;
      }
    }
  }

  /// 立即发送一次 AFRR APP 心跳并等待 B170 专用回复。
  ///
  /// 心跳复用当前长连接和 A170/B170 流水号匹配；单次等待 5 秒，最多按协议
  /// 重发两次。若连接尚未登录，会先完成 `logon`，确保它仍是新连接首帧。
  Future<void> sendHeartbeat() async {
    _ensureConfigured();
    if (!_appLoggedOn || !_client.isConnected) {
      await logonApp();
    }

    final serialNumber = _sequence.next();
    final timestamp = _clock();
    final terminalPayload = await _heartbeatPayloadProvider();
    final frame = AfrrOperatorProtocolCodec.encodeJsonRequest(
      jsonPayload: AfrrAppHeartbeatProtocol.createRequest(
        timestamp: timestamp,
        terminalFramePayload: terminalPayload,
      ),
      shelfCode: shelfCode,
      serialNumber: serialNumber,
      timestamp: timestamp,
    );

    final response = await _requestHeartbeatWithRetry(
      frame,
      serialNumber: serialNumber,
    );
    final compactResult = response.compactReplyResultCode;
    if (compactResult != null) {
      if (compactResult != 9) {
        throw AfrrAppLogonException('监管服务拒绝 APP 心跳：处理状态 $compactResult');
      }
      _lastHeartbeatError = null;
      return;
    }

    final payload = response.jsonPayload;
    if (payload == null ||
        _responseFunction(payload) != AfrrAppHeartbeatProtocol.function) {
      throw const AfrrOperatorProtocolException('B170 回复缺少 heartbeat JSON');
    }
    final result = _intValue(payload['rst']);
    if (result != 9) {
      final detail = payload['data'];
      final detailText = detail is String ? detail.trim() : '';
      throw AfrrAppLogonException(
        detailText.isEmpty
            ? '监管服务拒绝 APP 心跳：处理状态${result == null ? '未知' : ' $result'}'
            : detailText,
      );
    }
    _lastHeartbeatError = null;
  }

  Future<void> _performAppLogon() async {
    _ensureConfigured();
    if (appId.isEmpty || appSecret.isEmpty) {
      throw const AfrrAppLogonException('尚未配置 APP 登录凭据');
    }
    if (!RegExp(r'^\d{15}$').hasMatch(imei.trim())) {
      throw const AfrrAppLogonException('尚未配置有效的 15 位设备 IMEI');
    }

    final serialNumber = _sequence.next();
    final timestamp = _clock();
    final request = AfrrAppLogonProtocol.createRequest(
      appId: appId,
      appSecret: appSecret,
      imei: imei.trim(),
      timestampMilliseconds: timestamp.millisecondsSinceEpoch,
      randomCode: _randomCodeFactory(),
    );
    final frame = AfrrOperatorProtocolCodec.encodeJsonRequest(
      jsonPayload: request,
      shelfCode: shelfCode,
      serialNumber: serialNumber,
      timestamp: timestamp,
    );

    Object? lastError;
    StackTrace? lastStackTrace;
    for (var attempt = 1; attempt <= maximumAttempts; attempt += 1) {
      try {
        await _ensureConnected();
        final response = await _client.request(
          frame,
          timeout: requestTimeout,
          matcher: (message) {
            if (message.keyword !=
                    AfrrOperatorProtocolCodec.loginResponseKeyword ||
                message.replyToSerialNumber != serialNumber) {
              return false;
            }
            final compactResult = message.compactReplyResultCode;
            if (compactResult != null) {
              return message.replyToKeyword ==
                  AfrrOperatorProtocolCodec.loginRequestKeyword;
            }
            return _responseFunction(message.jsonPayload) ==
                AfrrAppLogonProtocol.function;
          },
        );
        final compactResult = response.compactReplyResultCode;
        if (compactResult != null) {
          if (compactResult != 9) {
            throw AfrrAppLogonException(
              _appLogonFailureMessage(compactResult, null),
            );
          }
          _appLoggedOn = true;
          return;
        }
        final payload = response.jsonPayload;
        if (payload == null ||
            _responseFunction(payload) != AfrrAppLogonProtocol.function) {
          throw const AfrrOperatorProtocolException('B170 回复缺少 logon JSON');
        }
        final result = _intValue(payload['rst']);
        if (result != 9) {
          throw AfrrAppLogonException(
            _appLogonFailureMessage(result, payload['data']),
          );
        }
        _appLoggedOn = true;
        return;
      } on TcpProtocolRequestTimeoutException catch (error, stackTrace) {
        _appLoggedOn = false;
        lastError = error;
        lastStackTrace = stackTrace;
      } on TcpProtocolDisconnectedException catch (error, stackTrace) {
        _appLoggedOn = false;
        lastError = error;
        lastStackTrace = stackTrace;
      } on SocketException catch (error, stackTrace) {
        _appLoggedOn = false;
        lastError = error;
        lastStackTrace = stackTrace;
      } on TimeoutException catch (error, stackTrace) {
        _appLoggedOn = false;
        lastError = error;
        lastStackTrace = stackTrace;
      }
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  @override
  Future<OperatorLoginResponseDto> authenticate({
    required OperatorLoginRequest request,
  }) async {
    _ensureConfigured();
    await _ensureBusinessConnection();
    final serialNumber = _sequence.next();
    final frame = AfrrOperatorProtocolCodec.encodeLogin(
      request: request,
      shelfCode: shelfCode,
      serialNumber: serialNumber,
      timestamp: _clock(),
    );

    try {
      final response = await _requestWithRetry(
        frame,
        serialNumber: serialNumber,
      );
      final compactResult = response.compactReplyResultCode;
      if (compactResult != null) {
        if (compactResult != 9) {
          throw OperatorLoginException(
            _compactReplyFailureMessage(compactResult),
            code: 'afrr_rst_$compactResult',
          );
        }
        throw const AfrrOperatorProtocolException(
          'B170 userLogin 精简回复缺少人员资料 JSON',
        );
      }
      final payload = response.jsonPayload;
      if (payload == null || _responseFunction(payload) != 'userLogin') {
        throw const AfrrOperatorProtocolException('B170 回复缺少 userLogin JSON');
      }
      final result = _intValue(payload['rst']);
      if (result != 9) {
        final detail = payload['data'];
        throw OperatorLoginException(
          _failureMessage(result, detail),
          code: result == null ? 'invalid_protocol_result' : 'afrr_rst_$result',
        );
      }
      final data = _mapValue(payload['data']);
      if (data == null) {
        throw const AfrrOperatorProtocolException('AFRR 登录成功回复缺少 data');
      }
      return OperatorLoginResponseDto.fromProtocolData(
        data: data,
        request: request,
        protocolSerialNumber: serialNumber,
      );
    } on OperatorLoginException {
      rethrow;
    } on TcpProtocolRequestTimeoutException {
      throw const OperatorLoginException(
        'AFRR 登录请求超时，请检查柜机网络和协议服务',
        code: 'timeout',
      );
    } on TcpProtocolDisconnectedException {
      throw const OperatorLoginException(
        'AFRR 登录连接已断开，请检查协议服务',
        code: 'network_unavailable',
      );
    } on SocketException catch (error) {
      throw OperatorLoginException(
        '无法连接 AFRR 登录服务：${error.message}',
        code: 'network_unavailable',
      );
    } on TimeoutException {
      throw const OperatorLoginException('连接 AFRR 登录服务超时', code: 'timeout');
    } on AfrrOperatorProtocolException catch (error) {
      throw OperatorLoginException(
        'AFRR 登录回复无效：${error.message}',
        code: 'invalid_login_response',
      );
    } on FormatException {
      throw const OperatorLoginException(
        'AFRR 登录回复中的人员资料不完整',
        code: 'invalid_login_response',
      );
    }
  }

  /// 按协议约定在 5 秒超时后重发，最多重发两次，并保留原流水号不变。
  Future<AfrrOperatorMessage> _requestWithRetry(
    List<int> frame, {
    required int serialNumber,
  }) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    for (var attempt = 1; attempt <= maximumAttempts; attempt += 1) {
      try {
        await _ensureBusinessConnection();
        return await _client.request(
          frame,
          timeout: requestTimeout,
          matcher: (message) {
            if (message.keyword !=
                    AfrrOperatorProtocolCodec.loginResponseKeyword ||
                message.replyToSerialNumber != serialNumber) {
              return false;
            }
            final compactResult = message.compactReplyResultCode;
            if (compactResult != null) {
              return message.replyToKeyword ==
                  AfrrOperatorProtocolCodec.loginRequestKeyword;
            }
            final payload = message.jsonPayload;
            return _responseFunction(payload) == 'userLogin';
          },
        );
      } on TcpProtocolRequestTimeoutException catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      } on TcpProtocolDisconnectedException catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      }
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  /// 按 A170/B170 专用回复规则发送心跳，重发时保持原流水号和原报文不变。
  Future<AfrrOperatorMessage> _requestHeartbeatWithRetry(
    List<int> frame, {
    required int serialNumber,
  }) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    for (var attempt = 1; attempt <= maximumAttempts; attempt += 1) {
      try {
        return await _client.request(
          frame,
          timeout: requestTimeout,
          matcher: (message) {
            if (message.keyword !=
                    AfrrOperatorProtocolCodec.loginResponseKeyword ||
                message.replyToSerialNumber != serialNumber) {
              return false;
            }
            final compactResult = message.compactReplyResultCode;
            if (compactResult != null) {
              return message.replyToKeyword ==
                  AfrrOperatorProtocolCodec.loginRequestKeyword;
            }
            return _responseFunction(message.jsonPayload) ==
                AfrrAppHeartbeatProtocol.function;
          },
        );
      } on TcpProtocolRequestTimeoutException catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      } on TcpProtocolDisconnectedException catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        break;
      }
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  void _ensureHeartbeatScheduled() {
    if (_heartbeatTimer == null && _heartbeatOperation == null) {
      _scheduleHeartbeat(heartbeatInterval);
    }
  }

  /// 使用单次 Timer 串行调度心跳，避免慢响应与下一周期形成并发请求。
  void _scheduleHeartbeat(Duration delay) {
    if (_disposed) {
      return;
    }
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer(delay, () {
      _heartbeatTimer = null;
      final operation = _runHeartbeatCycle();
      _heartbeatOperation = operation;
      unawaited(
        operation.whenComplete(() {
          if (identical(_heartbeatOperation, operation)) {
            _heartbeatOperation = null;
          }
        }),
      );
    });
  }

  /// 执行一次后台心跳；失败时先废弃会话，再延时重建首帧为 logon 的连接。
  Future<void> _runHeartbeatCycle() async {
    try {
      if (!_appLoggedOn || !_client.isConnected) {
        await logonApp();
        return;
      }
      await sendHeartbeat();
      _scheduleHeartbeat(heartbeatInterval);
    } catch (error) {
      _lastHeartbeatError = error;
      _appLoggedOn = false;
      try {
        await _client.disconnect();
      } catch (disconnectError) {
        // 旧连接清理失败同样只保留诊断信息；后台循环不能形成未处理异步异常。
        _lastHeartbeatError = disconnectError;
      }
      _scheduleHeartbeat(heartbeatRetryDelay);
    }
  }

  Future<void> _ensureBusinessConnection() async {
    if (appId.isEmpty && appSecret.isEmpty && imei.isEmpty) {
      await _ensureConnected();
      return;
    }
    try {
      await logonApp();
    } on AfrrAppLogonException catch (error) {
      throw OperatorLoginException(error.message, code: 'app_not_logged_on');
    }
  }

  Future<void> _ensureConnected() async {
    if (_disposed) {
      throw const TcpProtocolDisposedException();
    }
    if (_client.isConnected) {
      return;
    }
    final pending = _connecting;
    if (pending != null) {
      return pending;
    }
    final connecting = _client.connect(host.trim(), port);
    _connecting = connecting;
    try {
      await connecting;
      _appLoggedOn = false;
    } finally {
      if (identical(_connecting, connecting)) {
        _connecting = null;
      }
    }
  }

  void _ensureConfigured() {
    if (_disposed) {
      throw const OperatorLoginException(
        'AFRR 登录数据源已释放',
        code: 'repository_disposed',
      );
    }
    if (host.trim().isEmpty || port < 1 || port > 65535) {
      throw const OperatorLoginException(
        '尚未配置有效的 AFRR TCP 主机和端口',
        code: 'invalid_server_config',
      );
    }
    if (!RegExp(r'^\d{15,16}$').hasMatch(shelfCode.trim())) {
      throw const OperatorLoginException(
        '尚未配置有效的 AFRR 货架编码或 IMEI',
        code: 'invalid_device_config',
      );
    }
  }

  /// 释放 TCP 连接和所有待处理登录请求；重复调用安全。
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _appLoggedOn = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _client.dispose();
  }
}

/// 把 AFRR 上行帧转换为不包含凭据、设备标识和人员资料的日志结构。
Object? _formatAfrrOutboundLog(List<int> bytes) {
  return _formatAfrrMessageForLog(AfrrOperatorProtocolCodec.decodeFrame(bytes));
}

/// 把已解码 AFRR 下行消息转换为安全日志结构。
Object? _formatAfrrInboundLog(AfrrOperatorMessage message) {
  return _formatAfrrMessageForLog(message);
}

/// 仅保留 AFRR 命令、流水号、登录方式和处理结果等诊断字段。
Map<String, Object?> _formatAfrrMessageForLog(AfrrOperatorMessage message) {
  Map<String, Object?>? payload;
  try {
    final source = message.jsonPayload;
    if (source != null) {
      final rawFunction = source['func'];
      final function =
          rawFunction is String && _safeAfrrLogFunctions.contains(rawFunction)
          ? rawFunction
          : null;
      final data = source['data'];
      final result = _intValue(source['rst']);
      final logway = data is Map ? _intValue(data['logway']) : null;
      payload = <String, Object?>{
        'func': ?function,
        if (rawFunction != null && function == null) 'func': '<未公开命令已省略>',
        if (source.containsKey('rst')) 'rst': result ?? '<非法结果已省略>',
        if (function == 'userLogin' && data is Map)
          'logway': const <int>{1, 2, 3}.contains(logway)
              ? logway
              : '<非法方式已省略>',
        if (source.containsKey('data')) 'data': '<业务数据已脱敏>',
      };
    }
  } catch (_) {
    payload = const <String, Object?>{'data': '<无法解析的业务数据已省略>'};
  }
  return <String, Object?>{
    'protocol': 'AFRR',
    'keyword': message.keyword.toRadixString(16).toUpperCase().padLeft(4, '0'),
    'serialNumber': message.serialNumber,
    if (message.replyToSerialNumber != null)
      'replyToSerialNumber': message.replyToSerialNumber,
    if (message.replyToKeyword != null)
      'replyToKeyword': message.replyToKeyword!
          .toRadixString(16)
          .toUpperCase()
          .padLeft(4, '0'),
    if (message.compactReplyResultCode != null)
      'resultCode': message.compactReplyResultCode,
    'payload': ?payload,
  };
}

/// 管理员通讯日志允许公开的 AFRR 功能名。
const Set<String> _safeAfrrLogFunctions = <String>{
  'logon',
  'heartbeat',
  'userLogin',
};

FutureOr<List<int>?> _noHeartbeat() => null;

String? _responseFunction(Map<String, Object?>? payload) {
  return (payload?['func'] ?? payload?['cmd'])?.toString();
}

Map<String, Object?>? _mapValue(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map<String, Object?>((key, item) {
      return MapEntry<String, Object?>(key.toString(), item);
    });
  }
  return null;
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

String _failureMessage(int? result, Object? detail) {
  final detailText = detail is String ? detail.trim() : '';
  if (detailText.isNotEmpty) {
    return detailText;
  }
  if (result != null) {
    return _currentProtocolFailureMessage('userLogin', result);
  }
  return 'AFRR 登录返回未知处理状态';
}

String _compactReplyFailureMessage(int result) {
  return _currentProtocolFailureMessage('userLogin', result);
}

String _currentProtocolFailureMessage(String function, int result) {
  return switch (result) {
    0 => 'AFRR 服务拒绝 $function：APP 未登录',
    1 => 'AFRR 服务拒绝 $function：消息验证失败',
    2 => 'AFRR 服务无法解析 $function 消息',
    3 => 'AFRR 服务无法识别当前终端号或 $function 指令',
    4 => 'AFRR $function 逻辑校验失败',
    5 => 'AFRR 服务当前忙碌',
    _ => 'AFRR $function 返回未知处理状态：$result',
  };
}

String _appLogonFailureMessage(int? result, Object? detail) {
  final detailText = detail is String ? detail.trim() : '';
  if (detailText.isNotEmpty) {
    return detailText;
  }
  return switch (result) {
    0 => '监管服务拒绝 APP 登录：APP 未登录',
    1 => '监管服务拒绝 APP 登录：消息签名验证失败',
    2 => '监管服务拒绝 APP 登录：消息解析错误',
    3 => '监管服务无法识别当前终端号或 logon 指令',
    4 => '监管服务 APP 登录逻辑校验失败',
    5 => '监管服务当前忙碌',
    _ => '监管服务 APP 登录返回未知处理状态${result == null ? '' : '：$result'}',
  };
}
