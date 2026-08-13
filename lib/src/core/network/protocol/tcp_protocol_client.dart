import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:smart_cabinet/src/core/logging/communication_log_store.dart';
import 'package:smart_cabinet/src/core/network/protocol/tcp_frame_decoder.dart';

/// 建立一条 TCP Socket 的可替换函数。
///
/// 测试可以注入受控 Socket；生产默认使用 [Socket.connect]。
typedef TcpSocketConnector =
    Future<Socket> Function(String host, int port, Duration timeout);

/// 判断一条入站消息是否属于某个请求。
typedef TcpResponseMatcher<TMessage> = bool Function(TMessage message);

/// 把业务协议消息转换为可安全记录的 TCP 通讯日志。
///
/// 格式化器必须只返回已经筛掉原始二进制和业务秘密的结构化内容；统一日志存储还会
/// 再执行一次兜底脱敏。未提供适配器的 TCP 客户端不会产生通讯日志。
class TcpCommunicationLogAdapter<TMessage> {
  /// 创建业务协议日志适配器。
  const TcpCommunicationLogAdapter({
    required this.channel,
    required this.formatOutbound,
    required this.formatInbound,
    this.targetType = CommunicationTargetType.server,
  });

  /// 界面展示的协议通道名称。
  final String channel;

  /// 当前业务协议写入通讯记录时使用的独立记录类型。
  final CommunicationTargetType targetType;

  /// 把上行帧转换为不含敏感数据的结构。
  final Object? Function(List<int> bytes) formatOutbound;

  /// 把已解码下行消息转换为不含敏感数据的结构。
  final Object? Function(TMessage message) formatInbound;
}

/// TCP 协议客户端的基础异常。
class TcpProtocolException implements Exception {
  /// 创建协议客户端异常。
  const TcpProtocolException(this.message);

  /// 可供日志或界面转换使用的稳定说明。
  final String message;

  @override
  String toString() => message;
}

/// 当前没有可用连接，或请求所属连接已经失效。
final class TcpProtocolDisconnectedException extends TcpProtocolException {
  /// 创建断线异常。
  const TcpProtocolDisconnectedException(super.message);
}

/// 请求在期限内没有收到匹配响应。
final class TcpProtocolRequestTimeoutException extends TcpProtocolException {
  /// 创建请求超时异常。
  TcpProtocolRequestTimeoutException(this.timeout)
    : super('TCP 协议请求在 ${timeout.inMilliseconds}ms 内未收到匹配响应');

  /// 本次请求使用的超时时间。
  final Duration timeout;
}

/// 客户端已经释放，不能再建立连接或发送数据。
final class TcpProtocolDisposedException extends TcpProtocolException {
  /// 创建已释放异常。
  const TcpProtocolDisposedException() : super('TCP 协议客户端已经释放');
}

/// 支持请求匹配和主动消息分流的通用 TCP 协议客户端。
///
/// 客户端只处理连接、字节发送和请求生命周期，不依赖任何业务 Feature，也不规定
/// 帧格式。业务协议通过 [TcpFrameDecoder] 把字节转换为强类型消息，再为每个请求
/// 提供能够唯一识别响应的 [TcpResponseMatcher]。
///
/// 每次 [connect] 都表示一次明确的连接配置切换：旧连接和旧 pending 请求会先失效，
/// 即使旧的异步连接稍后才返回，也不能覆盖新连接。
final class TcpProtocolClient<TMessage> {
  /// 创建通用 TCP 协议客户端。
  TcpProtocolClient({
    required this.frameDecoderFactory,
    TcpSocketConnector? socketConnector,
    this.communicationLogAdapter,
    this.connectTimeout = const Duration(seconds: 8),
    this.defaultRequestTimeout = const Duration(seconds: 10),
  }) : _socketConnector = socketConnector ?? _connectSocket {
    _validatePositiveDuration(connectTimeout, 'connectTimeout');
    _validatePositiveDuration(defaultRequestTimeout, 'defaultRequestTimeout');
  }

  /// 为每条物理连接创建全新解码上下文。
  final TcpFrameDecoderFactory<TMessage> frameDecoderFactory;
  final TcpSocketConnector _socketConnector;

  /// 当前业务协议的安全日志适配器。
  final TcpCommunicationLogAdapter<TMessage>? communicationLogAdapter;

  /// 建立 Socket 允许等待的最长时间。
  final Duration connectTimeout;

  /// [request] 没有显式传入 timeout 时使用的默认期限。
  final Duration defaultRequestTimeout;

  // 同步分发可保证消息仍绑定于通过 generation 校验的当前 Socket；如果先排入
  // 微任务再通知监听者，调用方在此期间重连，旧连接的主动消息就可能污染新会话。
  final StreamController<TMessage> _unmatchedMessagesController =
      StreamController<TMessage>.broadcast(sync: true);
  final Map<int, _PendingRequest<TMessage>> _pendingRequests =
      <int, _PendingRequest<TMessage>>{};

  Socket? _socket;
  StreamSubscription<List<int>>? _socketSubscription;
  TcpFrameDecoder<TMessage>? _frameDecoder;
  Future<void> _writeQueue = Future<void>.value();
  int _generation = 0;
  int _nextRequestId = 0;
  bool _disposed = false;
  String? _connectedHost;
  int? _connectedPort;

  /// 没有匹配任何 pending 请求的服务端消息。
  ///
  /// 服务端主动推送通常从这里消费。Socket 或解码错误会作为 Stream error 发出，
  /// 随后当前连接会被关闭。
  Stream<TMessage> get unmatchedMessages => _unmatchedMessagesController.stream;

  /// 当前是否持有一条可发送数据的 Socket。
  bool get isConnected => !_disposed && _socket != null;

  /// 当前连接主机；未连接时为 null。
  String? get connectedHost => _connectedHost;

  /// 当前连接端口；未连接时为 null。
  int? get connectedPort => _connectedPort;

  /// 建立新连接，并使旧连接及旧请求失效。
  Future<void> connect(String host, int port, {Duration? timeout}) async {
    _ensureNotDisposed();
    final normalizedHost = host.trim();
    if (normalizedHost.isEmpty) {
      throw ArgumentError.value(host, 'host', 'TCP 主机不能为空');
    }
    if (port < 1 || port > 65535) {
      throw RangeError.range(port, 1, 65535, 'port');
    }
    final effectiveTimeout = timeout ?? connectTimeout;
    _validatePositiveDuration(effectiveTimeout, 'timeout');

    // 先换代再等待旧 Socket 关闭。旧 connector 即使迟到返回，也只能销毁自己
    // 创建的 Socket，不能写入新一代字段或取消新一代请求。
    _generation += 1;
    final generation = _generation;
    _cancelPendingRequests(
      const TcpProtocolDisconnectedException('TCP 连接已被新的连接配置替换'),
    );
    await _detachCurrentConnection();
    if (!_isGenerationCurrent(generation)) {
      throw const TcpProtocolDisconnectedException('TCP 连接请求已被更新的配置替换');
    }

    late final Socket socket;
    try {
      final adapter = communicationLogAdapter;
      socket = adapter == null
          ? await _socketConnector(normalizedHost, port, effectiveTimeout)
          : await CommunicationLogStore.instance.traceExchange<Socket>(
              targetType: adapter.targetType,
              channel: adapter.channel,
              operation: '建立 TCP 连接',
              requestBody: <String, Object?>{
                'host': normalizedHost,
                'port': port,
              },
              action: () =>
                  _socketConnector(normalizedHost, port, effectiveTimeout),
              responseBody: (_) => const <String, Object?>{'connected': true},
            );
    } catch (_) {
      if (!_isGenerationCurrent(generation)) {
        throw const TcpProtocolDisconnectedException('TCP 连接请求已被更新的配置替换');
      }
      rethrow;
    }

    if (!_isGenerationCurrent(generation)) {
      socket.destroy();
      throw const TcpProtocolDisconnectedException('TCP 连接请求已被更新的配置替换');
    }

    try {
      _socket = socket;
      _frameDecoder = frameDecoderFactory();
      _connectedHost = normalizedHost;
      _connectedPort = port;
      _writeQueue = Future<void>.value();
      _socketSubscription = socket.listen(
        (bytes) => _handleBytes(bytes, generation, socket),
        onError: (Object error, StackTrace stackTrace) {
          _handleTransportError(error, stackTrace, generation, socket);
        },
        onDone: () => _handleTransportDone(generation, socket),
        cancelOnError: true,
      );
    } catch (_) {
      if (_ownsConnection(generation, socket)) {
        _generation += 1;
        await _detachCurrentConnection();
      } else {
        socket.destroy();
      }
      rethrow;
    }
  }

  /// 主动断开连接并取消当前全部 pending 请求。
  Future<void> disconnect() async {
    if (_disposed) {
      return;
    }
    _generation += 1;
    _cancelPendingRequests(
      const TcpProtocolDisconnectedException('TCP 连接已主动断开'),
    );
    await _detachCurrentConnection();
  }

  /// 按调用顺序发送一段完整协议帧。
  ///
  /// 客户端会复制 [bytes]，调用者后续修改原 List 不会改变已经排队的数据。
  Future<void> send(List<int> bytes) {
    _ensureNotDisposed();
    final payload = _copyPayload(bytes);
    final connection = _requireConnection();
    return _enqueueWrite(
      payload,
      generation: connection.generation,
      socket: connection.socket,
    );
  }

  /// 发送请求，并等待第一条满足 [matcher] 的入站消息。
  ///
  /// 多个请求可以并发等待，但 matcher 应包含协议流水号等唯一上下文。入站消息按
  /// 请求注册顺序寻找第一个匹配项；没有匹配项的消息进入 [unmatchedMessages]。
  /// 超时从调用本方法时开始，仍在写队列中尚未发送的超时请求会被直接跳过。
  Future<TMessage> request(
    List<int> bytes, {
    required TcpResponseMatcher<TMessage> matcher,
    Duration? timeout,
  }) {
    _ensureNotDisposed();
    final effectiveTimeout = timeout ?? defaultRequestTimeout;
    _validatePositiveDuration(effectiveTimeout, 'timeout');
    final payload = _copyPayload(bytes);
    final connection = _requireConnection();
    _nextRequestId += 1;
    final requestId = _nextRequestId;
    final pending = _PendingRequest<TMessage>(matcher);
    _pendingRequests[requestId] = pending;
    pending.timer = Timer(effectiveTimeout, () {
      if (!_removePending(requestId, pending)) {
        return;
      }
      final communicationLogId = pending.communicationLogId;
      if (communicationLogId != null) {
        CommunicationLogStore.instance.tryUpdateResult(
          communicationLogId,
          '失败：请求超时',
        );
      }
      pending.completer.completeError(
        TcpProtocolRequestTimeoutException(effectiveTimeout),
        StackTrace.current,
      );
    });

    final write = _enqueueWrite(
      payload,
      generation: connection.generation,
      socket: connection.socket,
      shouldWrite: () => identical(_pendingRequests[requestId], pending),
      onLogRecorded: (id) => pending.communicationLogId = id,
    );
    unawaited(
      write.then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          if (_removePending(requestId, pending)) {
            pending.completer.completeError(error, stackTrace);
          }
        },
      ),
    );
    return pending.completer.future;
  }

  Future<void> _enqueueWrite(
    Uint8List payload, {
    required int generation,
    required Socket socket,
    bool Function()? shouldWrite,
    void Function(int id)? onLogRecorded,
  }) {
    final operation = _writeQueue.then<void>((_) async {
      if (!_ownsConnection(generation, socket)) {
        throw const TcpProtocolDisconnectedException('请求所属 TCP 连接已经失效');
      }
      if (shouldWrite != null && !shouldWrite()) {
        return;
      }
      final adapter = communicationLogAdapter;
      final logId = adapter == null
          ? null
          : CommunicationLogStore.instance.tryRecord(
              targetType: adapter.targetType,
              direction: CommunicationDirection.outbound,
              channel: adapter.channel,
              operation: '发送 TCP 协议消息',
              messageBody: _safeFormatOutbound(adapter, payload),
              result: '处理中',
            );
      if (logId != null) {
        onLogRecorded?.call(logId);
      }
      try {
        socket.add(payload);
        await socket.flush();
        if (logId != null) {
          CommunicationLogStore.instance.tryUpdateResult(logId, '成功');
        }
      } catch (error, stackTrace) {
        if (logId != null) {
          CommunicationLogStore.instance.tryUpdateResult(
            logId,
            '失败：${error.runtimeType}',
          );
        }
        _handleTransportError(error, stackTrace, generation, socket);
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
    // 某次写失败不能毒化队列；它自己的 Future 仍保留原异常，而后续操作会通过
    // generation/socket 检查得到明确的断线错误。
    _writeQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  void _handleBytes(List<int> bytes, int generation, Socket socket) {
    if (!_ownsConnection(generation, socket)) {
      return;
    }
    try {
      final decoder = _frameDecoder;
      if (decoder == null) {
        throw StateError('当前 TCP 连接缺少帧解码器');
      }
      for (final message in decoder.add(bytes)) {
        _routeMessage(message);
      }
    } catch (error, stackTrace) {
      _handleTransportError(error, stackTrace, generation, socket);
    }
  }

  void _routeMessage(TMessage message) {
    final adapter = communicationLogAdapter;
    if (adapter != null) {
      CommunicationLogStore.instance.tryRecord(
        targetType: adapter.targetType,
        direction: CommunicationDirection.inbound,
        channel: adapter.channel,
        operation: '接收 TCP 协议消息',
        messageBody: _safeFormatInbound(adapter, message),
        result: '成功',
      );
    }
    for (final entry in List<MapEntry<int, _PendingRequest<TMessage>>>.of(
      _pendingRequests.entries,
    )) {
      final requestId = entry.key;
      final pending = entry.value;
      bool matches;
      try {
        matches = pending.matcher(message);
      } catch (error, stackTrace) {
        if (_removePending(requestId, pending)) {
          final communicationLogId = pending.communicationLogId;
          if (communicationLogId != null) {
            CommunicationLogStore.instance.tryUpdateResult(
              communicationLogId,
              '失败：响应匹配异常',
            );
          }
          pending.completer.completeError(error, stackTrace);
        }
        continue;
      }
      if (!matches || !_removePending(requestId, pending)) {
        continue;
      }
      final communicationLogId = pending.communicationLogId;
      if (communicationLogId != null) {
        CommunicationLogStore.instance.tryUpdateResult(
          communicationLogId,
          '成功：收到响应',
        );
      }
      pending.completer.complete(message);
      return;
    }
    if (!_unmatchedMessagesController.isClosed) {
      _unmatchedMessagesController.add(message);
    }
  }

  void _handleTransportError(
    Object error,
    StackTrace stackTrace,
    int generation,
    Socket socket,
  ) {
    if (!_ownsConnection(generation, socket)) {
      return;
    }
    if (!_unmatchedMessagesController.isClosed) {
      _unmatchedMessagesController.addError(error, stackTrace);
    }
    _invalidateConnection(
      generation,
      socket,
      const TcpProtocolDisconnectedException('TCP 连接发生异常'),
    );
  }

  void _handleTransportDone(int generation, Socket socket) {
    if (!_ownsConnection(generation, socket)) {
      return;
    }
    const error = TcpProtocolDisconnectedException('TCP 连接已被对端关闭');
    if (!_unmatchedMessagesController.isClosed) {
      _unmatchedMessagesController.addError(error, StackTrace.current);
    }
    _invalidateConnection(generation, socket, error);
  }

  void _invalidateConnection(
    int generation,
    Socket socket,
    TcpProtocolException pendingError,
  ) {
    if (!_ownsConnection(generation, socket)) {
      return;
    }
    // 在启动异步清理前同步换代和清空字段，避免 onError/onDone 连续到达时重复
    // 取消请求，也避免迟到回调关闭之后刚建立的新 Socket。
    _generation += 1;
    _cancelPendingRequests(pendingError);
    unawaited(_detachCurrentConnection());
  }

  Future<void> _detachCurrentConnection() async {
    final subscription = _socketSubscription;
    final socket = _socket;
    final decoder = _frameDecoder;
    _socketSubscription = null;
    _socket = null;
    _frameDecoder = null;
    _connectedHost = null;
    _connectedPort = null;
    _writeQueue = Future<void>.value();
    decoder?.reset();

    final cancellation = subscription?.cancel();
    socket?.destroy();
    await cancellation;
  }

  void _cancelPendingRequests(Object error) {
    if (_pendingRequests.isEmpty) {
      return;
    }
    final pending = List<_PendingRequest<TMessage>>.of(_pendingRequests.values);
    _pendingRequests.clear();
    final stackTrace = StackTrace.current;
    for (final request in pending) {
      request.timer?.cancel();
      final communicationLogId = request.communicationLogId;
      if (communicationLogId != null) {
        CommunicationLogStore.instance.tryUpdateResult(
          communicationLogId,
          '失败：${error.runtimeType}',
        );
      }
      if (!request.completer.isCompleted) {
        request.completer.completeError(error, stackTrace);
      }
    }
  }

  bool _removePending(int requestId, _PendingRequest<TMessage> pending) {
    if (!identical(_pendingRequests[requestId], pending)) {
      return false;
    }
    _pendingRequests.remove(requestId);
    pending.timer?.cancel();
    return true;
  }

  ({int generation, Socket socket}) _requireConnection() {
    final socket = _socket;
    if (socket == null) {
      throw const TcpProtocolDisconnectedException('TCP 协议客户端尚未连接');
    }
    return (generation: _generation, socket: socket);
  }

  bool _ownsConnection(int generation, Socket socket) {
    return _isGenerationCurrent(generation) && identical(socket, _socket);
  }

  bool _isGenerationCurrent(int generation) {
    return !_disposed && generation == _generation;
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw const TcpProtocolDisposedException();
    }
  }

  /// 取消 pending 请求、关闭 Socket 和消息流；重复调用安全。
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _generation += 1;
    _cancelPendingRequests(const TcpProtocolDisposedException());
    try {
      await _detachCurrentConnection();
    } finally {
      await _unmatchedMessagesController.close();
    }
  }
}

Object? _safeFormatOutbound<TMessage>(
  TcpCommunicationLogAdapter<TMessage> adapter,
  List<int> payload,
) {
  try {
    return adapter.formatOutbound(payload);
  } catch (_) {
    return <String, Object?>{'byteLength': payload.length};
  }
}

Object? _safeFormatInbound<TMessage>(
  TcpCommunicationLogAdapter<TMessage> adapter,
  TMessage message,
) {
  try {
    return adapter.formatInbound(message);
  } catch (_) {
    return <String, Object?>{'messageType': message.runtimeType.toString()};
  }
}

final class _PendingRequest<TMessage> {
  _PendingRequest(this.matcher);

  final TcpResponseMatcher<TMessage> matcher;
  final Completer<TMessage> completer = Completer<TMessage>();
  Timer? timer;
  int? communicationLogId;
}

Future<Socket> _connectSocket(String host, int port, Duration timeout) {
  return Socket.connect(host, port, timeout: timeout);
}

Uint8List _copyPayload(List<int> bytes) {
  if (bytes.isEmpty) {
    throw ArgumentError.value(bytes, 'bytes', 'TCP 协议帧不能为空');
  }
  if (bytes.any((byte) => byte < 0 || byte > 255)) {
    throw ArgumentError.value(bytes, 'bytes', 'TCP 字节必须在 0 到 255 之间');
  }
  return Uint8List.fromList(bytes);
}

void _validatePositiveDuration(Duration duration, String name) {
  if (duration <= Duration.zero) {
    throw ArgumentError.value(duration, name, '超时时间必须大于 0');
  }
}
