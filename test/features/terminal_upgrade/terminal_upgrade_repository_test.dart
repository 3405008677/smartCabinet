import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/core/device/cabinet_door_guard.dart';
import 'package:smart_cabinet/src/core/logging/communication_log_store.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/data/datasources/terminal_upgrade_package_downloader.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/data/datasources/terminal_upgrade_device.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/data/repositories/terminal_upgrade_repository_impl.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/domain/entities/terminal_upgrade.dart';

const _moduleId = '75526065009';
const _dataProtocolIp = '47.107.40.88';
const _uniqueDeviceId = 'AABBCIID33';

Future<String> _loadUniqueDeviceId() async => _uniqueDeviceId;

/// 终端升级 Repository 的协议、下载、安装与维护租约回归测试。
void main() {
  const settings = TerminalUpgradeSettings(
    enabled: true,
    host: '127.0.0.1',
    port: 8001,
    terminalId: '12345678901',
    packageTag: 'APP',
  );

  test('rejects timer settings that would busy-loop reconnects', () {
    expect(
      () => TerminalUpgradeRepositoryImpl(
        moduleId: _moduleId,
        dataProtocolIp: _dataProtocolIp,
        uniqueDeviceIdLoader: _loadUniqueDeviceId,
        device: const _FakeTerminalUpgradeDevice(),
        doorGuard: CabinetDoorGuard(),
        upgradeCheckTimeout: Duration.zero,
      ),
      throwsArgumentError,
    );
    expect(
      () => TerminalUpgradeRepositoryImpl(
        moduleId: _moduleId,
        dataProtocolIp: _dataProtocolIp,
        uniqueDeviceIdLoader: _loadUniqueDeviceId,
        device: const _FakeTerminalUpgradeDevice(),
        doorGuard: CabinetDoorGuard(),
        initialReconnectDelay: const Duration(seconds: 2),
        maximumReconnectDelay: const Duration(seconds: 1),
      ),
      throwsArgumentError,
    );
  });

  test(
    'rejects an invalid configured STUM module ID before opening a socket',
    () async {
      var connectionAttempted = false;
      final repository = TerminalUpgradeRepositoryImpl(
        moduleId: '123',
        dataProtocolIp: _dataProtocolIp,
        uniqueDeviceIdLoader: _loadUniqueDeviceId,
        device: const _FakeTerminalUpgradeDevice(),
        socketConnector: (_, _, _) {
          connectionAttempted = true;
          throw StateError('socket must not be opened');
        },
        doorGuard: CabinetDoorGuard(),
      );
      try {
        await expectLater(
          repository.start(settings),
          throwsA(
            isA<TerminalUpgradeOperationException>().having(
              (error) => error.reason.code,
              'code',
              TerminalUpgradeMessageCode.settingsModuleIdInvalid,
            ),
          ),
        );
        expect(connectionAttempted, isFalse);
      } finally {
        await repository.dispose();
      }
    },
  );

  test(
    'rejects an unavailable About Device ID before opening a socket',
    () async {
      var connectionAttempted = false;
      final repository = TerminalUpgradeRepositoryImpl(
        moduleId: _moduleId,
        dataProtocolIp: _dataProtocolIp,
        uniqueDeviceIdLoader: () async => '未知',
        device: const _FakeTerminalUpgradeDevice(),
        socketConnector: (_, _, _) {
          connectionAttempted = true;
          throw StateError('socket must not be opened');
        },
        doorGuard: CabinetDoorGuard(),
      );
      try {
        await expectLater(
          repository.start(settings),
          throwsA(
            isA<TerminalUpgradeOperationException>().having(
              (error) => error.reason.code,
              'code',
              TerminalUpgradeMessageCode.settingsChipIdInvalid,
            ),
          ),
        );
        expect(connectionAttempted, isFalse);
      } finally {
        await repository.dispose();
      }
    },
  );

  test(
    'rejects an invalid configured STUM DP before opening a socket',
    () async {
      var connectionAttempted = false;
      final repository = TerminalUpgradeRepositoryImpl(
        moduleId: _moduleId,
        dataProtocolIp: '',
        uniqueDeviceIdLoader: _loadUniqueDeviceId,
        device: const _FakeTerminalUpgradeDevice(),
        socketConnector: (_, _, _) {
          connectionAttempted = true;
          throw StateError('socket must not be opened');
        },
        doorGuard: CabinetDoorGuard(),
      );
      try {
        await expectLater(
          repository.start(settings),
          throwsA(
            isA<TerminalUpgradeOperationException>().having(
              (error) => error.reason.code,
              'code',
              TerminalUpgradeMessageCode.settingsDataProtocolIpInvalid,
            ),
          ),
        );
        expect(connectionAttempted, isFalse);
      } finally {
        await repository.dispose();
      }
    },
  );

  test(
    'times out an unavailable unique device ID before opening a socket',
    () async {
      var connectionAttempted = false;
      final pendingIdentity = Completer<String>();
      final repository = TerminalUpgradeRepositoryImpl(
        moduleId: _moduleId,
        dataProtocolIp: _dataProtocolIp,
        uniqueDeviceIdLoader: () => pendingIdentity.future,
        device: const _FakeTerminalUpgradeDevice(),
        socketConnector: (_, _, _) {
          connectionAttempted = true;
          throw StateError('socket must not be opened');
        },
        doorGuard: CabinetDoorGuard(),
        identityLoadTimeout: const Duration(milliseconds: 20),
      );
      try {
        await expectLater(
          repository.start(settings),
          throwsA(
            isA<TerminalUpgradeOperationException>().having(
              (error) => error.reason.code,
              'code',
              TerminalUpgradeMessageCode.settingsChipIdInvalid,
            ),
          ),
        );
        expect(connectionAttempted, isFalse);
      } finally {
        await repository.dispose();
      }
    },
  );

  test('stop invalidates an identity load that is still pending', () async {
    var connectionAttempted = false;
    final identityRequested = Completer<void>();
    final pendingIdentity = Completer<String>();
    final repository = TerminalUpgradeRepositoryImpl(
      moduleId: _moduleId,
      dataProtocolIp: _dataProtocolIp,
      uniqueDeviceIdLoader: () {
        identityRequested.complete();
        return pendingIdentity.future;
      },
      device: const _FakeTerminalUpgradeDevice(),
      socketConnector: (_, _, _) {
        connectionAttempted = true;
        throw StateError('socket must not be opened');
      },
      doorGuard: CabinetDoorGuard(),
    );
    try {
      final startFuture = repository.start(settings);
      await identityRequested.future.timeout(const Duration(seconds: 3));
      await repository.stop();
      pendingIdentity.complete(_uniqueDeviceId);
      await startFuture;

      expect(connectionAttempted, isFalse);
      expect(repository.current.phase, TerminalUpgradePhase.disabled);
    } finally {
      await repository.dispose();
    }
  });

  test(
    'logs in before requesting a URL upgrade and acknowledges S03',
    () async {
      final downloader = _ControlledTerminalUpgradeDownloader();
      final device = _RecordingTerminalUpgradeDevice();
      TerminalUpgradeOffer? notifiedOffer;
      final harness = await _UpgradeServerHarness.start(
        settings,
        device: device,
        downloader: downloader,
        onOfferAvailable: (offer) => notifiedOffer = offer,
      );
      try {
        expect(
          await harness.nextFrame(),
          '<T01>|ID:12345678901|IM:75526065009|DP:47.107.40.88|'
          'CD:AABBCIID33|SN:1',
        );

        await harness.send('<S00>|01:OK|SN:1');
        expect(
          await harness.nextFrame(),
          '<T03>|DT:1|VE:SL_V1.0.0_20260812|PT:APP|SN:2',
        );

        await harness.send(
          '<S03>|VE:1.1.0|AD:https://updates.example.com/app.apk|'
          'MD:0123456789abcdef0123456789abcdef|PT:APP|SN:10',
        );
        expect(await harness.nextFrame(), '<T00>|03:OK|SN:10');
        expect(
          harness.repository.current.phase,
          TerminalUpgradePhase.updateAvailable,
        );
        expect(harness.repository.current.offer?.targetVersion, '1.1.0');
        expect(
          identical(notifiedOffer, harness.repository.current.offer),
          isTrue,
        );
        // 远端 S03 只能形成待管理员确认的 offer，不能直接跨过安全门禁下载或安装。
        await Future<void>.delayed(Duration.zero);
        expect(downloader.started.isCompleted, isFalse);
        expect(device.installCalls, 0);
      } finally {
        await downloader.dispose();
        await harness.dispose();
      }
    },
  );

  test(
    'records every STUM frame as upgrade command and keeps the real 1.0.5 offer',
    () async {
      CommunicationLogStore.instance.clear();
      const liveSettings = TerminalUpgradeSettings(
        enabled: true,
        host: '127.0.0.1',
        port: 8001,
        terminalId: '867282037661259',
      );
      final harness = await _UpgradeServerHarness.start(
        liveSettings,
        device: const _VersionedTerminalUpgradeDevice('1.0.4', 5),
      );
      try {
        expect(
          await harness.nextFrame(),
          '<T01>|ID:867282037661259|IM:75526065009|DP:47.107.40.88|'
          'CD:AABBCIID33|SN:1',
        );
        await harness.send('<S00>|01:OK|SN:1');
        expect(
          await harness.nextFrame(),
          '<T03>|DT:1|VE:SL_V1.0.4_20260812|SN:2',
        );

        await harness.send(
          '<S03>|VE:SL_APP_V1.0.5|'
          'AD:http://192.168.0.99:18888/group1/M00/00/9C/'
          'wKgAY2p8WueAEEErAYjrJ3dvkSY590.apk|'
          'MD:9C8F95DF76566BF6E8403511F9D9DC0B|SN:9',
        );
        expect(await harness.nextFrame(), '<T00>|03:OK|SN:9');
        expect(
          harness.repository.current.phase,
          TerminalUpgradePhase.updateAvailable,
        );
        expect(
          harness.repository.current.offer?.targetVersion,
          'SL_APP_V1.0.5',
        );

        final protocolEntries = CommunicationLogStore.instance.entries
            .where((entry) => entry.channel == 'ZRD STUM TCP')
            .toList();
        expect(protocolEntries, isNotEmpty);
        expect(
          protocolEntries.every(
            (entry) =>
                entry.targetType == CommunicationTargetType.upgradeCommand,
          ),
          isTrue,
        );
        final protocolBodies = protocolEntries
            .map((entry) => entry.messageBody)
            .join('\n');
        for (final keyword in <String>['T01', 'S00', 'T03', 'S03', 'T00']) {
          expect(protocolBodies, contains(keyword));
        }
        expect(protocolBodies, contains('SL_V1.0.4_20260812'));
        expect(protocolBodies, contains('SL_APP_V1.0.5'));
        expect(
          protocolBodies,
          isNot(contains('wKgAY2p8WueAEEErAYjrJ3dvkSY590')),
        );
      } finally {
        await harness.dispose();
        CommunicationLogStore.instance.clear();
      }
    },
  );

  test(
    'downloads the S03 URL, verifies MD5, and submits the APK after administrator confirmation',
    () async {
      final apkBytes = List<int>.generate(257, (index) => (index * 17) & 0xff);
      final expectedMd5 = md5.convert(apkBytes).toString();
      final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requestCount = 0;
      Uri? requestedUri;
      String? acceptHeader;
      final requestSubscription = httpServer.listen((request) async {
        requestCount += 1;
        requestedUri = request.uri;
        acceptHeader = request.headers.value(HttpHeaders.acceptHeader);
        request.response.contentLength = apkBytes.length;
        request.response.add(apkBytes);
        await request.response.close();
      });
      final device = _RecordingTerminalUpgradeDevice();
      _UpgradeServerHarness? harness;
      try {
        harness = await _UpgradeServerHarness.start(
          settings,
          device: device,
          downloader: const IoTerminalUpgradePackageDownloader(),
        );

        await _authenticate(harness);
        final downloadUrl = Uri(
          scheme: 'http',
          host: httpServer.address.address,
          port: httpServer.port,
          path: '/firmware/app-1.1.0.apk',
          queryParameters: const <String, String>{'token': 'test-only'},
        );
        await harness.send(
          '<S03>|VE:1.1.0|AD:$downloadUrl|MD:$expectedMd5|PT:APP|SN:10',
        );
        expect(await harness.nextFrame(), '<T00>|03:OK|SN:10');
        final confirmedOffer = harness.repository.current.offer!;

        await harness.repository.installAvailableUpdate(
          confirmedOffer: confirmedOffer,
          administratorConfirmed: true,
        );

        expect(requestCount, 1);
        expect(requestedUri?.path, '/firmware/app-1.1.0.apk');
        expect(requestedUri?.queryParameters['token'], 'test-only');
        expect(acceptHeader, 'application/vnd.android.package-archive');
        expect(device.installCalls, 1);
        expect(device.installedTargetVersion, '1.1.0');
        expect(device.installedApkBytes, apkBytes);
        expect(device.installedOperationId, isNotEmpty);
        expect(
          harness.repository.current.phase,
          TerminalUpgradePhase.awaitingRestart,
        );
        expect(harness.repository.current.installStatus?.sessionId, 42);

        // Repository 在 PackageInstaller 已读取文件后立即清理本次私有临时目录。
        final installedApkPath = device.installedApkPath;
        expect(installedApkPath, isNotNull);
        expect(await File(installedApkPath!).exists(), isFalse);
        expect(await File(installedApkPath).parent.exists(), isFalse);
      } finally {
        await harness?.dispose();
        await httpServer.close(force: true);
        await requestSubscription.cancel();
      }
    },
  );

  test('treats one leading uppercase V as the same app version', () async {
    final harness = await _UpgradeServerHarness.start(settings);
    try {
      await _authenticate(harness);
      await harness.send('<S03>|VE:V1.0.0|PT:APP|SN:10');

      expect(await harness.nextFrame(), '<T00>|03:OK|SN:10');
      expect(harness.repository.current.phase, TerminalUpgradePhase.upToDate);
      expect(harness.repository.current.offer, isNull);
    } finally {
      await harness.dispose();
    }
  });

  test('rejects undefined AD=2 packet mode with NG3AD', () async {
    final harness = await _UpgradeServerHarness.start(settings);
    try {
      await harness.nextFrame();
      await harness.send('<S00>|01:OK|SN:1');
      await harness.nextFrame();

      await harness.send(
        '<S03>|VE:1.1.0|AD:2|'
        'MD:0123456789abcdef0123456789abcdef|PT:APP|SN:11',
      );

      expect(await harness.nextFrame(), '<T00>|03:NG3AD|SN:11');
      expect(harness.repository.current.phase, TerminalUpgradePhase.failed);
      expect(
        harness.repository.current.errorMessage?.code,
        TerminalUpgradeMessageCode.offerRejected,
      );
      expect(
        harness.repository.current.errorMessage?.arguments['responseCode'],
        'NG3AD',
      );
    } finally {
      await harness.dispose();
    }
  });

  test('ends an unanswered upgrade check instead of waiting forever', () async {
    final harness = await _UpgradeServerHarness.start(
      settings,
      upgradeCheckTimeout: const Duration(milliseconds: 20),
    );
    try {
      await harness.nextFrame();
      await harness.send('<S00>|01:OK|SN:1');
      await harness.nextFrame();

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(harness.repository.current.phase, TerminalUpgradePhase.failed);
      expect(
        harness.repository.current.errorMessage?.code,
        TerminalUpgradeMessageCode.checkTimedOut,
      );
      final responses = await _sendWithBarrier(
        harness,
        message:
            '<S03>|VE:1.2.0|AD:https://updates.example.com/late.apk|'
            'MD:11111111111111111111111111111111|PT:APP|SN:11',
        barrierSerialNumber: 12,
      );
      expect(responses, contains('<T00>|03:NG1|SN:11'));
      expect(harness.repository.current.offer, isNull);
    } finally {
      await harness.dispose();
    }
  });

  test(
    'a failed connection from an old configuration cannot close the new one',
    () async {
      final oldConnection = Completer<Socket>();
      final oldConnectionStarted = Completer<void>();
      final newServer = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final newPeerFuture = newServer.first;
      final repository = TerminalUpgradeRepositoryImpl(
        moduleId: _moduleId,
        dataProtocolIp: _dataProtocolIp,
        uniqueDeviceIdLoader: _loadUniqueDeviceId,
        device: const _FakeTerminalUpgradeDevice(),
        socketConnector: (host, _, _) {
          if (host == 'old.example.com') {
            if (!oldConnectionStarted.isCompleted) {
              oldConnectionStarted.complete();
            }
            return oldConnection.future;
          }
          if (host == 'new.example.com') {
            return Socket.connect(InternetAddress.loopbackIPv4, newServer.port);
          }
          throw StateError('Unexpected host: $host');
        },
        doorGuard: CabinetDoorGuard(),
        initialReconnectDelay: const Duration(seconds: 30),
      );
      Socket? newPeer;
      StreamIterator<String>? newFrames;
      try {
        await repository.start(
          settings.copyWith(host: 'old.example.com', port: 8001),
        );
        await oldConnectionStarted.future.timeout(const Duration(seconds: 3));

        await repository.start(
          settings.copyWith(host: 'new.example.com', port: newServer.port),
        );
        newPeer = await newPeerFuture.timeout(const Duration(seconds: 3));
        newFrames = StreamIterator<String>(
          ascii.decoder.bind(newPeer).transform(const LineSplitter()),
        );
        expect(
          await _nextFrame(newFrames),
          '<T01>|ID:12345678901|IM:75526065009|DP:47.107.40.88|'
          'CD:AABBCIID33|SN:1',
        );
        await _send(newPeer, '<S00>|01:OK|SN:1');
        expect(
          await _nextFrame(newFrames),
          '<T03>|DT:1|VE:SL_V1.0.0_20260812|PT:APP|SN:2',
        );
        await _send(newPeer, '<S03>|VE:0|PT:APP|SN:10');
        expect(await _nextFrame(newFrames), '<T00>|03:OK|SN:10');
        expect(repository.current.phase, TerminalUpgradePhase.upToDate);

        oldConnection.completeError(
          const SocketException('obsolete connection failed'),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(repository.current.phase, TerminalUpgradePhase.upToDate);
        await repository.requestCheck();
        expect(
          await _nextFrame(newFrames),
          '<T03>|DT:1|VE:SL_V1.0.0_20260812|PT:APP|SN:3',
        );
      } finally {
        if (!oldConnection.isCompleted) {
          oldConnection.completeError(const SocketException('test cleanup'));
        }
        await repository.dispose();
        await newFrames?.cancel();
        newPeer?.destroy();
        await newServer.close();
      }
    },
  );

  test(
    'reconnects and requests the current version again after peer close',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final peers = <Socket>[];
      final secondUpgradeCheck = Completer<void>();
      var connectionCount = 0;
      var identityLoadCount = 0;
      final serverSubscription = server.listen((peer) {
        peers.add(peer);
        connectionCount += 1;
        if (connectionCount == 1) {
          unawaited(() async {
            final frames = StreamIterator<String>(
              ascii.decoder.bind(peer).transform(const LineSplitter()),
            );
            try {
              expect(
                await _nextFrame(frames),
                '<T01>|ID:12345678901|IM:75526065009|DP:47.107.40.88|'
                'CD:AABBCIID33|SN:1',
              );
              await _send(peer, '<S00>|01:OK|SN:1');
              expect(
                await _nextFrame(frames),
                '<T03>|DT:1|VE:SL_V1.0.0_20260812|PT:APP|SN:2',
              );
            } catch (error, stackTrace) {
              if (!secondUpgradeCheck.isCompleted) {
                secondUpgradeCheck.completeError(error, stackTrace);
              }
            } finally {
              await frames.cancel();
              peer.destroy();
            }
          }());
        } else if (!secondUpgradeCheck.isCompleted) {
          unawaited(() async {
            final frames = StreamIterator<String>(
              ascii.decoder.bind(peer).transform(const LineSplitter()),
            );
            try {
              expect(
                await _nextFrame(frames),
                '<T01>|ID:12345678901|IM:75526065009|DP:47.107.40.88|'
                'CD:AABBCIID33|SN:3',
              );
              await _send(peer, '<S00>|01:OK|SN:3');
              expect(
                await _nextFrame(frames),
                '<T03>|DT:1|VE:SL_V1.0.0_20260812|PT:APP|SN:4',
              );
              secondUpgradeCheck.complete();
            } catch (error, stackTrace) {
              if (!secondUpgradeCheck.isCompleted) {
                secondUpgradeCheck.completeError(error, stackTrace);
              }
            } finally {
              await frames.cancel();
            }
          }());
        }
      });
      final repository = TerminalUpgradeRepositoryImpl(
        moduleId: _moduleId,
        dataProtocolIp: _dataProtocolIp,
        uniqueDeviceIdLoader: () async {
          identityLoadCount += 1;
          return _uniqueDeviceId;
        },
        device: const _FakeTerminalUpgradeDevice(),
        socketConnector: (_, _, _) =>
            Socket.connect(InternetAddress.loopbackIPv4, server.port),
        doorGuard: CabinetDoorGuard(),
        initialReconnectDelay: const Duration(milliseconds: 10),
        maximumReconnectDelay: const Duration(milliseconds: 10),
      );

      try {
        await repository.start(settings.copyWith(port: server.port));
        await secondUpgradeCheck.future.timeout(const Duration(seconds: 3));
        expect(connectionCount, greaterThanOrEqualTo(2));
        expect(identityLoadCount, 1);
      } finally {
        await repository.dispose();
        for (final peer in peers) {
          peer.destroy();
        }
        await serverSubscription.cancel();
        await server.close();
      }
    },
  );

  for (final lifecycleAction in <String>['stop', 'dispose']) {
    test(
      '$lifecycleAction during download never submits an APK install',
      () async {
        final downloader = _ControlledTerminalUpgradeDownloader();
        final device = _RecordingTerminalUpgradeDevice();
        final harness = await _UpgradeServerHarness.start(
          settings,
          device: device,
          downloader: downloader,
        );
        try {
          await _authenticateAndOffer(harness);
          final installResult = _capture(
            harness.repository.installAvailableUpdate(
              confirmedOffer: harness.repository.current.offer!,
              administratorConfirmed: true,
            ),
          );
          await downloader.started.future.timeout(const Duration(seconds: 3));
          expect(
            harness.repository.current.phase,
            TerminalUpgradePhase.downloading,
          );

          if (lifecycleAction == 'stop') {
            await harness.repository.stop();
          } else {
            await harness.repository.dispose();
          }
          await downloader.complete();
          await installResult.timeout(const Duration(seconds: 3));

          expect(device.installCalls, 0);
          if (lifecycleAction == 'stop') {
            expect(
              harness.repository.current.phase,
              TerminalUpgradePhase.disabled,
            );
          }
        } finally {
          await downloader.dispose();
          await harness.dispose();
        }
      },
    );
  }

  test('rejects a manual S03 outside the current T03 window', () async {
    final harness = await _UpgradeServerHarness.start(settings);
    try {
      await _authenticate(harness);
      // 协议的 VE=0 示例不包含 PT/MD，AD 也允许为空。
      await harness.send('<S03>|VE:0|AD:|SN:10');
      expect(await harness.nextFrame(), '<T00>|03:OK|SN:10');
      expect(harness.repository.current.phase, TerminalUpgradePhase.upToDate);
      expect(harness.repository.current.offer, isNull);

      final responses = await _sendWithBarrier(
        harness,
        message:
            '<S03>|VE:1.2.0|AD:https://updates.example.com/app-1.2.0.apk|'
            'MD:11111111111111111111111111111111|PT:APP|SN:11',
        barrierSerialNumber: 12,
      );

      expect(responses, contains('<T00>|03:NG1|SN:11'));
      expect(harness.repository.current.offer, isNull);
      expect(harness.repository.current.phase, TerminalUpgradePhase.upToDate);
    } finally {
      await harness.dispose();
    }
  });

  test('a new S03 cannot replace the active offer during download', () async {
    final downloader = _ControlledTerminalUpgradeDownloader();
    final device = _RecordingTerminalUpgradeDevice();
    final harness = await _UpgradeServerHarness.start(
      settings,
      device: device,
      downloader: downloader,
    );
    Future<Object?>? installResult;
    try {
      await _authenticateAndOffer(harness);
      final originalOffer = harness.repository.current.offer!;
      installResult = _capture(
        harness.repository.installAvailableUpdate(
          confirmedOffer: originalOffer,
          administratorConfirmed: true,
        ),
      );
      await downloader.started.future.timeout(const Duration(seconds: 3));

      final responses = await _sendWithBarrier(
        harness,
        message:
            '<S03>|VE:1.2.0|AD:https://updates.example.com/app-1.2.0.apk|'
            'MD:22222222222222222222222222222222|PT:APP|SN:11',
        barrierSerialNumber: 12,
      );

      expect(responses, isNot(contains('<T00>|03:OK|SN:11')));
      expect(
        harness.repository.current.offer?.identityKey,
        originalOffer.identityKey,
      );
      expect(
        harness.repository.current.phase,
        TerminalUpgradePhase.downloading,
      );
    } finally {
      await downloader.complete();
      if (installResult != null) {
        await installResult.timeout(const Duration(seconds: 3));
      }
      await downloader.dispose();
      await harness.dispose();
    }
  });

  test(
    'does not let a new check replace a pending administrator offer',
    () async {
      final harness = await _UpgradeServerHarness.start(settings);
      try {
        await _authenticateAndOffer(harness);

        await expectLater(
          harness.repository.requestCheck(),
          throwsA(
            isA<TerminalUpgradeOperationException>().having(
              (error) => error.reason.code,
              'reason',
              TerminalUpgradeMessageCode.pendingOfferRequiresDecision,
            ),
          ),
        );
        expect(
          harness.repository.current.phase,
          TerminalUpgradePhase.updateAvailable,
        );
        expect(harness.repository.current.offer?.targetVersion, '1.1.0');
      } finally {
        await harness.dispose();
      }
    },
  );

  test('an exact S03 retransmission receives an idempotent OK', () async {
    final harness = await _UpgradeServerHarness.start(settings);
    try {
      await _authenticateAndOffer(harness);

      await harness.send(
        '<S03>|VE:1.1.0|AD:https://updates.example.com/app-1.1.0.apk|'
        'MD:0123456789abcdef0123456789abcdef|PT:APP|SN:10',
      );

      expect(await harness.nextFrame(), '<T00>|03:OK|SN:10');
      expect(
        harness.repository.current.phase,
        TerminalUpgradePhase.updateAvailable,
      );
    } finally {
      await harness.dispose();
    }
  });

  test(
    'binds administrator confirmation to the exact displayed offer',
    () async {
      final harness = await _UpgradeServerHarness.start(settings);
      try {
        await _authenticateAndOffer(harness);
        final currentOffer = harness.repository.current.offer!;
        final equalButReplacedOffer = TerminalUpgradeOffer(
          targetVersion: currentOffer.targetVersion,
          downloadUrl: currentOffer.downloadUrl,
          md5: currentOffer.md5,
          packageTag: currentOffer.packageTag,
          serialNumber: currentOffer.serialNumber,
        );

        await expectLater(
          harness.repository.installAvailableUpdate(
            confirmedOffer: currentOffer,
            administratorConfirmed: false,
          ),
          throwsA(
            isA<TerminalUpgradeOperationException>().having(
              (error) => error.reason.code,
              'reason',
              TerminalUpgradeMessageCode.administratorConfirmationRequired,
            ),
          ),
        );
        await expectLater(
          harness.repository.installAvailableUpdate(
            confirmedOffer: equalButReplacedOffer,
            administratorConfirmed: true,
          ),
          throwsA(
            isA<TerminalUpgradeOperationException>().having(
              (error) => error.reason.code,
              'reason',
              TerminalUpgradeMessageCode.confirmedOfferChanged,
            ),
          ),
        );
      } finally {
        await harness.dispose();
      }
    },
  );

  for (final occupiedBy in <String>['door', 'maintenance']) {
    test(
      'rejects installation while $occupiedBy occupies the door guard',
      () async {
        final guard = CabinetDoorGuard();
        final device = _RecordingTerminalUpgradeDevice();
        if (occupiedBy == 'door') {
          expect(
            guard.requestOpen('A-01', operationId: 'TASK-OPEN'),
            isA<CabinetDoorOpenGranted>(),
          );
        } else {
          expect(guard.tryAcquireMaintenance('OTHER-MAINTENANCE'), isTrue);
        }
        final harness = await _UpgradeServerHarness.start(
          settings,
          device: device,
          doorGuard: guard,
        );
        try {
          await _authenticateAndOffer(harness);

          await expectLater(
            harness.repository.installAvailableUpdate(
              confirmedOffer: harness.repository.current.offer!,
              administratorConfirmed: true,
            ),
            throwsA(
              isA<TerminalUpgradeOperationException>().having(
                (error) => error.reason.code,
                'reason',
                occupiedBy == 'door'
                    ? TerminalUpgradeMessageCode.doorsNotClosed
                    : TerminalUpgradeMessageCode.maintenanceUnavailable,
              ),
            ),
          );
          expect(device.installCalls, 0);
          expect(harness.repository.current.offer, isNotNull);
        } finally {
          if (occupiedBy == 'door') {
            guard.markClosed('A-01', operationId: 'TASK-OPEN');
          } else {
            guard.releaseMaintenance('OTHER-MAINTENANCE');
          }
          await harness.dispose();
        }
      },
    );
  }

  test(
    'reconfiguration invalidates a pending offer before its first await',
    () async {
      final harness = await _UpgradeServerHarness.start(settings);
      try {
        await _authenticateAndOffer(harness);

        final reconfigured = harness.repository.start(
          settings.copyWith(packageTag: 'RECONFIGURED'),
        );
        expect(harness.repository.current.offer, isNull);
        await reconfigured;
      } finally {
        await harness.dispose();
      }
    },
  );

  test('stop cancels an Android submission before commit', () async {
    final guard = CabinetDoorGuard();
    final downloader = _ControlledTerminalUpgradeDownloader();
    final device = _BlockingSubmissionTerminalUpgradeDevice();
    final harness = await _UpgradeServerHarness.start(
      settings,
      device: device,
      downloader: downloader,
      doorGuard: guard,
    );
    try {
      await _authenticateAndOffer(harness);
      final installResult = _capture(
        harness.repository.installAvailableUpdate(
          confirmedOffer: harness.repository.current.offer!,
          administratorConfirmed: true,
        ),
      );
      await downloader.started.future.timeout(const Duration(seconds: 3));
      await downloader.complete();
      await device.installStarted.future.timeout(const Duration(seconds: 3));

      await harness.repository.stop().timeout(const Duration(seconds: 3));
      final error = await installResult.timeout(const Duration(seconds: 3));

      expect(error, isA<TerminalUpgradeOperationException>());
      expect(device.cancelCalls, 1);
      expect(device.cancelledOperationId, device.installOperationId);
      expect(guard.maintenanceActive, isFalse);
      expect(harness.repository.current.phase, TerminalUpgradePhase.disabled);
    } finally {
      await downloader.dispose();
      await harness.dispose();
    }
  });

  test('repository recreation never reuses an Android operation ID', () async {
    final operationIds = <String>[];
    for (var index = 0; index < 2; index += 1) {
      final downloader = _ControlledTerminalUpgradeDownloader();
      final device = _BlockingSubmissionTerminalUpgradeDevice();
      final harness = await _UpgradeServerHarness.start(
        settings,
        device: device,
        downloader: downloader,
      );
      try {
        await _authenticateAndOffer(harness);
        final installResult = _capture(
          harness.repository.installAvailableUpdate(
            confirmedOffer: harness.repository.current.offer!,
            administratorConfirmed: true,
          ),
        );
        await downloader.started.future.timeout(const Duration(seconds: 3));
        await downloader.complete();
        await device.installStarted.future.timeout(const Duration(seconds: 3));
        await harness.repository.stop().timeout(const Duration(seconds: 3));
        await installResult.timeout(const Duration(seconds: 3));
        operationIds.add(device.installOperationId!);
      } finally {
        await downloader.dispose();
        await harness.dispose();
      }
    }

    expect(operationIds.toSet(), hasLength(2));
    expect(
      operationIds,
      everyElement(matches(RegExp(r'^terminal-upgrade:[a-z0-9-]+:\d+:\d+$'))),
    );
  });

  test(
    'automatically releases the door maintenance lease at installation terminal state',
    () async {
      final guard = CabinetDoorGuard();
      final downloader = _ControlledTerminalUpgradeDownloader();
      final device = _RecordingTerminalUpgradeDevice();
      final harness = await _UpgradeServerHarness.start(
        settings,
        device: device,
        downloader: downloader,
        doorGuard: guard,
        installStatusPollInterval: const Duration(milliseconds: 10),
      );
      try {
        await _authenticateAndOffer(harness);
        final installResult = _capture(
          harness.repository.installAvailableUpdate(
            confirmedOffer: harness.repository.current.offer!,
            administratorConfirmed: true,
          ),
        );
        await downloader.started.future.timeout(const Duration(seconds: 3));

        expect(guard.maintenanceActive, isTrue);
        expect(
          guard.requestOpen('A-01', operationId: 'TASK-001'),
          isA<CabinetDoorOpenMaintenanceConflict>(),
        );

        await downloader.complete();
        expect(await installResult.timeout(const Duration(seconds: 3)), isNull);
        expect(guard.maintenanceActive, isTrue);

        device.completeWithFailure();
        await _waitUntil(() => !guard.maintenanceActive);
        expect(guard.maintenanceActive, isFalse);
      } finally {
        await downloader.dispose();
        await harness.dispose();
      }
    },
  );

  test(
    'restores and hands off the maintenance lease for a pending native install',
    () async {
      final guard = CabinetDoorGuard();
      final device = _RecordingTerminalUpgradeDevice(
        initialStatus: const TerminalInstallStatus(
          state: 'pending_user_action',
          message: '等待系统安装确认',
          sessionId: 20,
          targetVersion: '1.1.0',
          requiresUserAction: true,
          confirmationLaunchFailed: true,
        ),
      );
      final repository = TerminalUpgradeRepositoryImpl(
        moduleId: _moduleId,
        dataProtocolIp: _dataProtocolIp,
        uniqueDeviceIdLoader: _loadUniqueDeviceId,
        device: device,
        doorGuard: guard,
        installStatusPollInterval: const Duration(hours: 1),
      );
      TerminalUpgradeRepositoryImpl? restoredRepository;
      try {
        await repository.refreshInstallStatus();

        expect(repository.current.currentVersion, '1.0.0');
        expect(repository.current.phase, TerminalUpgradePhase.awaitingRestart);
        expect(repository.current.installStatus?.sessionId, 20);
        expect(
          repository.current.errorMessage?.code,
          TerminalUpgradeMessageCode.confirmationLaunchFailed,
        );
        expect(guard.maintenanceActive, isTrue);
        final leaseId = guard.maintenanceOperationId;

        await repository.dispose();
        restoredRepository = TerminalUpgradeRepositoryImpl(
          moduleId: _moduleId,
          dataProtocolIp: _dataProtocolIp,
          uniqueDeviceIdLoader: _loadUniqueDeviceId,
          device: device,
          doorGuard: guard,
          installStatusPollInterval: const Duration(hours: 1),
        );
        await restoredRepository.refreshInstallStatus();
        expect(guard.maintenanceOperationId, leaseId);

        device.completeWithFailure();
        await restoredRepository.refreshInstallStatus();
        expect(guard.maintenanceActive, isFalse);
      } finally {
        await repository.dispose();
        await restoredRepository?.dispose();
      }
    },
  );

  test(
    'maps native install diagnostics without exposing its fixed message',
    () async {
      final device = _RecordingTerminalUpgradeDevice(
        initialStatus: const TerminalInstallStatus(
          state: 'failed',
          message: '安装包校验失败',
          diagnosticCode: 'validation_failed',
          sessionId: 21,
          targetVersion: '1.1.0',
        ),
      );
      final repository = TerminalUpgradeRepositoryImpl(
        moduleId: _moduleId,
        dataProtocolIp: _dataProtocolIp,
        uniqueDeviceIdLoader: _loadUniqueDeviceId,
        device: device,
      );
      try {
        await repository.refreshInstallStatus();

        expect(
          repository.current.errorMessage?.code,
          TerminalUpgradeMessageCode.installValidationFailed,
        );
        expect(repository.current.errorMessage?.detail, isEmpty);
      } finally {
        await repository.dispose();
      }
    },
  );
}

Future<void> _authenticate(_UpgradeServerHarness harness) async {
  expect(
    await harness.nextFrame(),
    '<T01>|ID:12345678901|IM:75526065009|DP:47.107.40.88|'
    'CD:AABBCIID33|SN:1',
  );
  await harness.send('<S00>|01:OK|SN:1');
  expect(
    await harness.nextFrame(),
    '<T03>|DT:1|VE:SL_V1.0.0_20260812|PT:APP|SN:2',
  );
}

Future<void> _authenticateAndOffer(_UpgradeServerHarness harness) async {
  await _authenticate(harness);
  await harness.send(
    '<S03>|VE:1.1.0|AD:https://updates.example.com/app-1.1.0.apk|'
    'MD:0123456789abcdef0123456789abcdef|PT:APP|SN:10',
  );
  expect(await harness.nextFrame(), '<T00>|03:OK|SN:10');
  expect(
    harness.repository.current.phase,
    TerminalUpgradePhase.updateAvailable,
  );
  expect(harness.repository.current.offer?.targetVersion, '1.1.0');
}

Future<List<String>> _sendWithBarrier(
  _UpgradeServerHarness harness, {
  required String message,
  required int barrierSerialNumber,
}) async {
  await harness.send(message);
  await harness.send('<S99>|SN:$barrierSerialNumber');
  final barrier = '<T00>|99:NG1|SN:$barrierSerialNumber';
  final responses = <String>[];
  while (true) {
    final frame = await harness.nextFrame();
    responses.add(frame);
    if (frame == barrier) {
      return responses;
    }
  }
}

Future<String> _nextFrame(StreamIterator<String> frames) async {
  final hasFrame = await frames.moveNext().timeout(const Duration(seconds: 3));
  if (!hasFrame) {
    throw StateError(
      'The terminal closed the connection before the next frame',
    );
  }
  return frames.current;
}

Future<void> _send(Socket peer, String frame) async {
  peer.add(ascii.encode('$frame\r\n'));
  await peer.flush();
}

Future<Object?> _capture(Future<void> future) async {
  try {
    await future;
    return null;
  } catch (error) {
    return error;
  }
}

/// 在有界时间内等待异步状态满足断言，避免测试依赖固定长 sleep。
Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('等待测试状态超时', timeout);
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// 用本机 TCP 回环模拟升级监控服务端，验证真实 Socket 拆帧和时序。
final class _UpgradeServerHarness {
  _UpgradeServerHarness._({
    required this.repository,
    required this._server,
    required this._peer,
    required this._frames,
  });

  final TerminalUpgradeRepositoryImpl repository;
  final ServerSocket _server;
  final Socket _peer;
  final StreamIterator<String> _frames;

  static Future<_UpgradeServerHarness> start(
    TerminalUpgradeSettings settings, {
    Duration upgradeCheckTimeout = const Duration(seconds: 30),
    TerminalUpgradeDevice device = const _FakeTerminalUpgradeDevice(),
    TerminalUpgradePackageDownloader? downloader,
    CabinetDoorGuard? doorGuard,
    Duration installStatusPollInterval = const Duration(seconds: 3),
    TerminalUpgradeOfferAvailableCallback? onOfferAvailable,
  }) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final peerFuture = server.first;
    final repository = TerminalUpgradeRepositoryImpl(
      moduleId: _moduleId,
      dataProtocolIp: _dataProtocolIp,
      uniqueDeviceIdLoader: _loadUniqueDeviceId,
      device: device,
      downloader: downloader,
      socketConnector: (_, _, _) =>
          Socket.connect(InternetAddress.loopbackIPv4, server.port),
      doorGuard: doorGuard ?? CabinetDoorGuard(),
      initialReconnectDelay: const Duration(seconds: 30),
      upgradeCheckTimeout: upgradeCheckTimeout,
      installStatusPollInterval: installStatusPollInterval,
      onOfferAvailable: onOfferAvailable,
    );
    await repository.start(settings);
    final peer = await peerFuture.timeout(const Duration(seconds: 3));
    final frames = StreamIterator<String>(
      ascii.decoder.bind(peer).transform(const LineSplitter()),
    );
    return _UpgradeServerHarness._(
      repository: repository,
      server: server,
      peer: peer,
      frames: frames,
    );
  }

  Future<String> nextFrame() async {
    final hasFrame = await _frames.moveNext().timeout(
      const Duration(seconds: 3),
    );
    if (!hasFrame) {
      throw StateError('升级客户端在预期报文前关闭了连接');
    }
    return _frames.current;
  }

  Future<void> send(String frame) async {
    _peer.add(ascii.encode('$frame\r\n'));
    await _peer.flush();
  }

  Future<void> dispose() async {
    await repository.dispose();
    await _frames.cancel();
    _peer.destroy();
    await _server.close();
  }
}

final class _FakeTerminalUpgradeDevice implements TerminalUpgradeDevice {
  const _FakeTerminalUpgradeDevice();

  @override
  Future<TerminalAppVersion> getAppVersion() async {
    return const TerminalAppVersion(name: '1.0.0', code: 1);
  }

  @override
  Future<TerminalInstallStatus> getInstallStatus() async {
    return const TerminalInstallStatus(state: 'idle');
  }

  @override
  Future<TerminalInstallSubmission> installApk(
    String apkPath, {
    required String targetVersion,
    required String operationId,
  }) {
    throw UnsupportedError('该协议测试不会提交 APK');
  }

  @override
  Future<bool> cancelInstall(String operationId) async => false;
}

/// 返回指定已安装版本的测试设备，用于复现真实 S03 版本判断。
final class _VersionedTerminalUpgradeDevice implements TerminalUpgradeDevice {
  const _VersionedTerminalUpgradeDevice(this.name, this.code);

  final String name;
  final int code;

  @override
  Future<TerminalAppVersion> getAppVersion() async {
    return TerminalAppVersion(name: name, code: code);
  }

  @override
  Future<TerminalInstallStatus> getInstallStatus() async {
    return const TerminalInstallStatus(state: 'idle');
  }

  @override
  Future<TerminalInstallSubmission> installApk(
    String apkPath, {
    required String targetVersion,
    required String operationId,
  }) {
    throw UnsupportedError('该响应解析测试不会提交 APK');
  }

  @override
  Future<bool> cancelInstall(String operationId) async => false;
}

final class _RecordingTerminalUpgradeDevice implements TerminalUpgradeDevice {
  _RecordingTerminalUpgradeDevice({
    TerminalInstallStatus initialStatus = const TerminalInstallStatus(
      state: 'idle',
    ),
  }) : _installStatus = initialStatus;

  int installCalls = 0;
  int cancelCalls = 0;
  String? installedApkPath;
  String? installedTargetVersion;
  String? installedOperationId;
  List<int>? installedApkBytes;
  TerminalInstallStatus _installStatus;

  @override
  Future<TerminalAppVersion> getAppVersion() async {
    return const TerminalAppVersion(name: '1.0.0', code: 1);
  }

  @override
  Future<TerminalInstallStatus> getInstallStatus() async {
    return _installStatus;
  }

  @override
  Future<TerminalInstallSubmission> installApk(
    String apkPath, {
    required String targetVersion,
    required String operationId,
  }) async {
    installCalls += 1;
    installedApkPath = apkPath;
    installedTargetVersion = targetVersion;
    installedOperationId = operationId;
    installedApkBytes = await File(apkPath).readAsBytes();
    _installStatus = TerminalInstallStatus(
      state: 'submitted',
      sessionId: 42,
      targetVersion: targetVersion,
    );
    return const TerminalInstallSubmission(sessionId: 42, state: 'submitted');
  }

  @override
  Future<bool> cancelInstall(String operationId) async {
    cancelCalls += 1;
    return false;
  }

  void completeWithFailure() {
    _installStatus = const TerminalInstallStatus(
      state: 'failed',
      message: 'test failure',
      sessionId: 42,
      targetVersion: '1.1.0',
    );
  }
}

/// 模拟 Android 已进入耗时校验、但还没有跨过 PackageInstaller.commit 的窗口。
final class _BlockingSubmissionTerminalUpgradeDevice
    implements TerminalUpgradeDevice {
  final Completer<void> installStarted = Completer<void>();
  final Completer<TerminalInstallSubmission> _submission =
      Completer<TerminalInstallSubmission>();

  int cancelCalls = 0;
  String? installOperationId;
  String? cancelledOperationId;

  @override
  Future<TerminalAppVersion> getAppVersion() async {
    return const TerminalAppVersion(name: '1.0.0', code: 1);
  }

  @override
  Future<TerminalInstallStatus> getInstallStatus() async {
    return const TerminalInstallStatus(state: 'idle');
  }

  @override
  Future<TerminalInstallSubmission> installApk(
    String apkPath, {
    required String targetVersion,
    required String operationId,
  }) {
    installOperationId = operationId;
    if (!installStarted.isCompleted) {
      installStarted.complete();
    }
    return _submission.future;
  }

  @override
  Future<bool> cancelInstall(String operationId) async {
    cancelCalls += 1;
    cancelledOperationId = operationId;
    if (!_submission.isCompleted) {
      _submission.completeError(StateError('cancelled before commit'));
    }
    return true;
  }
}

final class _ControlledTerminalUpgradeDownloader
    implements TerminalUpgradePackageDownloader {
  final Completer<void> started = Completer<void>();
  final Completer<DownloadedTerminalUpgradePackage> _completion =
      Completer<DownloadedTerminalUpgradePackage>();

  Directory? _directory;
  bool _completed = false;

  @override
  Future<DownloadedTerminalUpgradePackage> download(
    TerminalUpgradeOffer offer, {
    required TerminalUpgradeDownloadProgress onProgress,
    TerminalUpgradeDownloadCancellationToken? cancellationToken,
  }) {
    if (!started.isCompleted) {
      started.complete();
    }
    onProgress(1, 2);
    final token = cancellationToken;
    if (token != null) {
      unawaited(
        token.whenCancelled.then((_) {
          if (!_completion.isCompleted) {
            _completed = true;
            _completion.completeError(
              const TerminalUpgradeDownloadException('升级包下载已取消'),
            );
          }
        }),
      );
    }
    return _completion.future;
  }

  Future<void> complete() async {
    if (_completed || _completion.isCompleted) {
      return;
    }
    _completed = true;
    final directory = await Directory.systemTemp.createTemp(
      'terminal_upgrade_repository_test_',
    );
    _directory = directory;
    final file = File('${directory.path}${Platform.pathSeparator}update.apk');
    await file.writeAsBytes(const <int>[1, 2, 3], flush: true);
    _completion.complete(
      DownloadedTerminalUpgradePackage(
        file: file,
        md5: '0123456789abcdef0123456789abcdef',
        size: 3,
      ),
    );
  }

  Future<void> dispose() async {
    final directory = _directory;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
