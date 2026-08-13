import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cabinet/src/core/network/protocol/tcp_protocol.dart';

void main() {
  group('TcpProtocolClient request routing', () {
    test(
      'matches concurrent responses and publishes unmatched messages',
      () async {
        final socket = _TestSocket();
        final client = _createClient((_, _, _) async => socket);
        await client.connect('protocol.example.com', 9000);
        try {
          final unmatched = client.unmatchedMessages.first;
          final first = client.request(
            ascii.encode('REQ:1\n'),
            matcher: (message) => message == 'RES:1',
          );
          final second = client.request(
            ascii.encode('REQ:2\n'),
            matcher: (message) => message == 'RES:2',
          );
          await _nextEventTurn();

          socket.emitText('EVENT\nRES:');
          socket.emitText('2\nRES:1\n');

          expect(await unmatched, 'EVENT');
          expect(await second, 'RES:2');
          expect(await first, 'RES:1');
          expect(socket.writes.map(ascii.decode), ['REQ:1\n', 'REQ:2\n']);
        } finally {
          await client.dispose();
          await socket.dispose();
        }
      },
    );

    test('registers matcher before the request flush completes', () async {
      final socket = _TestSocket(controlFlush: true);
      final client = _createClient((_, _, _) async => socket);
      await client.connect('protocol.example.com', 9000);
      try {
        final response = client.request(
          ascii.encode('REQ\n'),
          matcher: (message) => message == 'RES',
        );
        await _nextEventTurn();
        expect(socket.writes, hasLength(1));

        socket.emitText('RES\n');
        expect(await response, 'RES');

        socket.completeNextFlush();
        await _nextEventTurn();
      } finally {
        await client.dispose();
        await socket.dispose();
      }
    });

    test('times out a queued request without sending it later', () async {
      final socket = _TestSocket(controlFlush: true);
      final client = _createClient((_, _, _) async => socket);
      await client.connect('protocol.example.com', 9000);
      try {
        final blockingWrite = client.send(const <int>[1]);
        await _nextEventTurn();
        expect(socket.writes, [
          const <int>[1],
        ]);

        final timedOut = client.request(
          const <int>[2],
          matcher: (_) => true,
          timeout: const Duration(milliseconds: 20),
        );
        await expectLater(
          timedOut,
          throwsA(isA<TcpProtocolRequestTimeoutException>()),
        );

        socket.completeNextFlush();
        await blockingWrite;
        await _nextEventTurn();
        expect(socket.writes, [
          const <int>[1],
        ]);
      } finally {
        await client.dispose();
        await socket.dispose();
      }
    });
  });

  group('TcpProtocolClient connection lifecycle', () {
    test('serializes socket add and flush operations', () async {
      final socket = _TestSocket(controlFlush: true);
      final client = _createClient((_, _, _) async => socket);
      await client.connect('protocol.example.com', 9000);
      try {
        final first = client.send(const <int>[1]);
        final second = client.send(const <int>[2]);
        await _nextEventTurn();

        expect(socket.writes, [
          const <int>[1],
        ]);
        expect(socket.maximumConcurrentFlushes, 1);

        socket.completeNextFlush();
        await first;
        await _nextEventTurn();
        expect(socket.writes, [
          const <int>[1],
          const <int>[2],
        ]);

        socket.completeNextFlush();
        await second;
        expect(socket.maximumConcurrentFlushes, 1);
      } finally {
        await client.dispose();
        await socket.dispose();
      }
    });

    test(
      'disconnect cancels pending requests and destroys the socket',
      () async {
        final socket = _TestSocket();
        final client = _createClient((_, _, _) async => socket);
        await client.connect('protocol.example.com', 9000);
        try {
          final pending = client.request(
            ascii.encode('REQ\n'),
            matcher: (_) => true,
            timeout: const Duration(minutes: 1),
          );
          final cancelled = expectLater(
            pending,
            throwsA(isA<TcpProtocolDisconnectedException>()),
          );

          await client.disconnect();

          await cancelled;
          expect(client.isConnected, isFalse);
          expect(socket.destroyed, isTrue);
        } finally {
          await client.dispose();
          await socket.dispose();
        }
      },
    );

    test(
      'reconfiguration isolates old callbacks and cancels old requests',
      () async {
        final oldSocket = _TestSocket(ignoreSubscriptionCancellation: true);
        final newSocket = _TestSocket();
        final decoders = <_LineFrameDecoder>[];
        final client = TcpProtocolClient<String>(
          frameDecoderFactory: () {
            final decoder = _LineFrameDecoder();
            decoders.add(decoder);
            return decoder;
          },
          socketConnector: (host, _, _) async =>
              host == 'old.example.com' ? oldSocket : newSocket,
        );
        await client.connect('old.example.com', 9000);
        try {
          final oldRequest = client.request(
            ascii.encode('OLD\n'),
            matcher: (message) => message == 'RES',
            timeout: const Duration(minutes: 1),
          );
          final oldCancelled = expectLater(
            oldRequest,
            throwsA(isA<TcpProtocolDisconnectedException>()),
          );

          await client.connect('new.example.com', 9001);
          await oldCancelled;
          expect(oldSocket.destroyed, isTrue);
          expect(decoders.first.resetCount, 1);
          expect(client.connectedHost, 'new.example.com');

          var newRequestCompleted = false;
          final newRequest = client.request(
            ascii.encode('NEW\n'),
            matcher: (message) => message == 'RES',
          )..then((_) => newRequestCompleted = true);
          await _nextEventTurn();

          oldSocket.emitText('RES\n');
          await _nextEventTurn();
          expect(newRequestCompleted, isFalse);

          newSocket.emitText('RES\n');
          expect(await newRequest, 'RES');
        } finally {
          await client.dispose();
          await oldSocket.dispose();
          await newSocket.dispose();
        }
      },
    );

    test('a late old connector cannot replace the newer connection', () async {
      final oldConnectorStarted = Completer<void>();
      final oldConnector = Completer<Socket>();
      final oldSocket = _TestSocket();
      final newSocket = _TestSocket();
      final client = _createClient((host, _, _) {
        if (host == 'old.example.com') {
          oldConnectorStarted.complete();
          return oldConnector.future;
        }
        return Future<Socket>.value(newSocket);
      });

      final oldConnect = client.connect('old.example.com', 9000);
      await oldConnectorStarted.future;
      final oldSuperseded = expectLater(
        oldConnect,
        throwsA(isA<TcpProtocolDisconnectedException>()),
      );
      await client.connect('new.example.com', 9001);

      oldConnector.complete(oldSocket);
      await oldSuperseded;

      expect(oldSocket.destroyed, isTrue);
      expect(client.isConnected, isTrue);
      expect(client.connectedHost, 'new.example.com');
      expect(client.connectedPort, 9001);

      await client.dispose();
      await oldSocket.dispose();
      await newSocket.dispose();
    });

    test(
      'decode failure errors the stream and invalidates the connection',
      () async {
        final socket = _TestSocket();
        final client = _createClient((_, _, _) async => socket);
        await client.connect('protocol.example.com', 9000);
        try {
          final streamError = expectLater(
            client.unmatchedMessages,
            emitsError(isA<FormatException>()),
          );
          final pending = client.request(
            ascii.encode('REQ\n'),
            matcher: (_) => true,
            timeout: const Duration(minutes: 1),
          );
          final requestError = expectLater(
            pending,
            throwsA(isA<TcpProtocolDisconnectedException>()),
          );

          socket.emitText('!INVALID\n');

          await streamError;
          await requestError;
          expect(client.isConnected, isFalse);
          expect(socket.destroyed, isTrue);
        } finally {
          await client.dispose();
          await socket.dispose();
        }
      },
    );

    test('peer close is observable even when no request is pending', () async {
      final socket = _TestSocket();
      final client = _createClient((_, _, _) async => socket);
      await client.connect('protocol.example.com', 9000);
      try {
        final disconnected = expectLater(
          client.unmatchedMessages,
          emitsError(isA<TcpProtocolDisconnectedException>()),
        );

        await socket.closeFromPeer();

        await disconnected;
        expect(client.isConnected, isFalse);
      } finally {
        await client.dispose();
        await socket.dispose();
      }
    });

    test(
      'dispose cancels pending requests and permanently closes the client',
      () async {
        final socket = _TestSocket();
        final client = _createClient((_, _, _) async => socket);
        await client.connect('protocol.example.com', 9000);
        final pending = client.request(
          ascii.encode('REQ\n'),
          matcher: (_) => true,
          timeout: const Duration(minutes: 1),
        );
        final requestError = expectLater(
          pending,
          throwsA(isA<TcpProtocolDisposedException>()),
        );
        final streamDone = expectLater(client.unmatchedMessages, emitsDone);

        await client.dispose();

        await requestError;
        await streamDone;
        expect(socket.destroyed, isTrue);
        expect(
          () => client.send(const <int>[1]),
          throwsA(isA<TcpProtocolDisposedException>()),
        );
        await expectLater(
          client.connect('protocol.example.com', 9000),
          throwsA(isA<TcpProtocolDisposedException>()),
        );
        await socket.dispose();
      },
    );
  });

  test(
    'validates endpoint, timeout, connection, and payload arguments',
    () async {
      final socket = _TestSocket();
      final client = _createClient((_, _, _) async => socket);
      try {
        await expectLater(
          client.connect(' ', 9000),
          throwsA(isA<ArgumentError>()),
        );
        await expectLater(
          client.connect('host', 0),
          throwsA(isA<RangeError>()),
        );
        expect(
          () => client.send(const <int>[1]),
          throwsA(isA<TcpProtocolDisconnectedException>()),
        );

        await client.connect('host', 9000);
        expect(() => client.send(const <int>[]), throwsA(isA<ArgumentError>()));
        expect(
          () => client.send(const <int>[256]),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => client.request(
            const <int>[1],
            matcher: (_) => true,
            timeout: Duration.zero,
          ),
          throwsA(isA<ArgumentError>()),
        );
      } finally {
        await client.dispose();
        await socket.dispose();
      }
    },
  );
}

TcpProtocolClient<String> _createClient(TcpSocketConnector connector) {
  return TcpProtocolClient<String>(
    frameDecoderFactory: _LineFrameDecoder.new,
    socketConnector: connector,
    connectTimeout: const Duration(seconds: 1),
    defaultRequestTimeout: const Duration(seconds: 1),
  );
}

Future<void> _nextEventTurn() => Future<void>.delayed(Duration.zero);

final class _LineFrameDecoder implements TcpFrameDecoder<String> {
  final List<int> _buffer = <int>[];
  int resetCount = 0;

  @override
  List<String> add(List<int> bytes) {
    _buffer.addAll(bytes);
    final messages = <String>[];
    while (true) {
      final newline = _buffer.indexOf(10);
      if (newline < 0) {
        return messages;
      }
      final frame = _buffer.sublist(0, newline);
      _buffer.removeRange(0, newline + 1);
      if (frame.isNotEmpty && frame.last == 13) {
        frame.removeLast();
      }
      final message = ascii.decode(frame);
      if (message.startsWith('!')) {
        throw const FormatException('测试协议帧无效');
      }
      messages.add(message);
    }
  }

  @override
  void reset() {
    resetCount += 1;
    _buffer.clear();
  }
}

final class _TestSocket implements Socket {
  _TestSocket({
    this.controlFlush = false,
    this.ignoreSubscriptionCancellation = false,
  });

  final bool controlFlush;
  final bool ignoreSubscriptionCancellation;
  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  final Queue<Completer<void>> _pendingFlushes = Queue<Completer<void>>();
  final List<List<int>> writes = <List<int>>[];

  bool destroyed = false;
  int _activeFlushes = 0;
  int maximumConcurrentFlushes = 0;

  void emitText(String text) {
    _incoming.add(Uint8List.fromList(ascii.encode(text)));
  }

  void completeNextFlush() {
    if (_pendingFlushes.isEmpty) {
      throw StateError('当前没有待完成的 flush');
    }
    _pendingFlushes.removeFirst().complete();
  }

  Future<void> closeFromPeer() => _incoming.close();

  @override
  void add(List<int> data) {
    writes.add(List<int>.of(data));
  }

  @override
  Future<void> flush() {
    _activeFlushes += 1;
    if (_activeFlushes > maximumConcurrentFlushes) {
      maximumConcurrentFlushes = _activeFlushes;
    }
    final future = controlFlush
        ? (_pendingFlushes..add(Completer<void>())).last.future
        : Future<void>.value();
    return future.whenComplete(() => _activeFlushes -= 1);
  }

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final subscription = _incoming.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    if (!ignoreSubscriptionCancellation) {
      return subscription;
    }
    return _NonCancellingSubscription<Uint8List>(subscription);
  }

  @override
  void destroy() {
    destroyed = true;
  }

  Future<void> dispose() async {
    for (final flush in _pendingFlushes) {
      if (!flush.isCompleted) {
        flush.completeError(StateError('测试 Socket 已释放'));
      }
    }
    _pendingFlushes.clear();
    await _incoming.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _NonCancellingSubscription<T> implements StreamSubscription<T> {
  _NonCancellingSubscription(this._delegate);

  final StreamSubscription<T> _delegate;

  @override
  Future<void> cancel() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      _delegate.noSuchMethod(invocation);
}
