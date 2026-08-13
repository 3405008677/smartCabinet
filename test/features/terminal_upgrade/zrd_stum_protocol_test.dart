import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/features/terminal_upgrade/data/protocol/zrd_stum_protocol.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/domain/entities/terminal_upgrade.dart';

void main() {
  group('ZrdStumProtocolCodec encoding', () {
    test('encodes T01 with the exact field order and CRLF terminator', () {
      const settings = TerminalUpgradeSettings(
        enabled: true,
        host: 'upgrade.example.com',
        port: 8001,
        terminalId: '12345678901',
      );
      const identity = TerminalUpgradeLoginIdentity(
        moduleId: '75526065009',
        dataProtocolIp: '47.107.40.88',
        chipId: 'AABBCIID33',
      );

      expect(
        ZrdStumProtocolCodec.encodeLogin(
          settings,
          identity: identity,
          serialNumber: 1,
        ),
        '<T01>|ID:12345678901|IM:75526065009|DP:47.107.40.88|'
        'CD:AABBCIID33|SN:1\r\n',
      );
    });

    test('rejects missing configured DP and unavailable unique device ID', () {
      const settings = TerminalUpgradeSettings(
        enabled: true,
        host: 'upgrade.example.com',
        port: 8001,
        terminalId: '12345678901',
      );

      for (final identity in <TerminalUpgradeLoginIdentity>[
        const TerminalUpgradeLoginIdentity(
          moduleId: '75526065009',
          dataProtocolIp: '',
          chipId: 'AABBCIID33',
        ),
        const TerminalUpgradeLoginIdentity(
          moduleId: '75526065009',
          dataProtocolIp: '47.107.40.88',
          chipId: '未知',
        ),
      ]) {
        expect(
          () => ZrdStumProtocolCodec.encodeLogin(
            settings,
            identity: identity,
            serialNumber: 1,
          ),
          throwsArgumentError,
        );
      }
    });

    test('encodes T03 URL upgrade request exactly', () {
      expect(
        ZrdStumProtocolCodec.encodeUpgradeRequest(
          currentVersion: '1.0.2',
          versionDate: '20260812',
          packageTag: 'MB',
          serialNumber: 3,
        ),
        '<T03>|DT:1|VE:SL_V1.0.2_20260812|PT:MB|SN:3\r\n',
      );
    });

    test('rejects invalid STUM version dates', () {
      for (final versionDate in <String>['20260230', '2026812', '2026-08-12']) {
        expect(
          () => ZrdStumProtocolCodec.encodeUpgradeRequest(
            currentVersion: '1.0.2',
            versionDate: versionDate,
            packageTag: '',
            serialNumber: 3,
          ),
          throwsArgumentError,
        );
      }
    });

    test('encodes T00 replies exactly for OK and attributed NG', () {
      expect(
        ZrdStumProtocolCodec.encodeTerminalReply(
          serverCommandCode: '03',
          result: 'OK',
          serialNumber: 2222,
        ),
        '<T00>|03:OK|SN:2222\r\n',
      );
      expect(
        ZrdStumProtocolCodec.encodeTerminalReply(
          serverCommandCode: '03',
          result: 'NG3AD',
          serialNumber: 2222,
        ),
        '<T00>|03:NG3AD|SN:2222\r\n',
      );
    });

    test('rejects serial numbers outside the protocol range', () {
      for (final serialNumber in <int>[-1, 0, 10000]) {
        expect(
          () => ZrdStumProtocolCodec.encodeUpgradeRequest(
            currentVersion: '1.2.3',
            packageTag: '',
            serialNumber: serialNumber,
          ),
          throwsArgumentError,
        );
      }
    });

    test('supports reserved NG codes and rejects malformed attributes', () {
      expect(
        ZrdStumProtocolCodec.encodeTerminalReply(
          serverCommandCode: '03',
          result: 'NG9',
          serialNumber: 1,
        ),
        '<T00>|03:NG9|SN:1\r\n',
      );
      for (final result in <String>['NG', 'NG3A', 'NG123', 'NG-1']) {
        expect(
          () => ZrdStumProtocolCodec.encodeTerminalReply(
            serverCommandCode: '03',
            result: result,
            serialNumber: 1,
          ),
          throwsArgumentError,
        );
      }
    });
  });

  group('ZrdStumProtocolCodec decoding', () {
    test('decodes a canonical S00 reply', () {
      final message = ZrdStumProtocolCodec.decode('<S00>|03:OK|SN:3');

      expect(message.direction, ZrdStumDirection.server);
      expect(message.commandCode, '00');
      expect(message.serialNumber, 3);
      expect(message.segments, const <String, String>{'03': 'OK', 'SN': '3'});
    });

    test('accepts only the documented unauthenticated S00 without SN', () {
      final message = ZrdStumProtocolCodec.decode('<S00>|00:NG0');

      expect(message.serialNumber, isNull);
      expect(message.segments['00'], 'NG0');
      expect(
        () => ZrdStumProtocolCodec.decode('<S00>|03:OK'),
        throwsA(isA<ZrdStumProtocolException>()),
      );
    });

    test('decodes S03 and preserves colons inside the download URL', () {
      final message = ZrdStumProtocolCodec.decode(
        '<S03>|VE:V1.02.22_20240907|'
        'AD:https://updates.example.com/app.apk?token=a:b|'
        'MD:0123456789abcdef0123456789abcdef|PT:MB|SN:2222',
      );

      expect(message.direction, ZrdStumDirection.server);
      expect(message.commandCode, '03');
      expect(message.serialNumber, 2222);
      expect(message.segments, const <String, String>{
        'VE': 'V1.02.22_20240907',
        'AD': 'https://updates.example.com/app.apk?token=a:b',
        'MD': '0123456789abcdef0123456789abcdef',
        'PT': 'MB',
        'SN': '2222',
      });
    });

    test('accepts case-insensitive keywords and documented comma examples', () {
      final reply = ZrdStumProtocolCodec.decode('<s00>|03,OK|SN:3');
      final offer = ZrdStumProtocolCodec.decode(
        '<S03>|VE,V1.2.3|AD:https://updates.example.com/app.apk|SN:4',
      );

      expect(reply.direction, ZrdStumDirection.server);
      expect(reply.segments['03'], 'OK');
      expect(offer.segments['VE'], 'V1.2.3');
      expect(
        () => ZrdStumProtocolCodec.decode('<T00>|03,OK|SN:3'),
        throwsA(isA<ZrdStumProtocolException>()),
      );
    });

    test('rejects lowercase keys and non-decimal SN text', () {
      expect(
        () => ZrdStumProtocolCodec.decode('<S00>|03:OK|sn:3'),
        throwsA(isA<ZrdStumProtocolException>()),
      );
      expect(
        () => ZrdStumProtocolCodec.decode('<S00>|03:OK|SN:+3'),
        throwsA(isA<ZrdStumProtocolException>()),
      );
      expect(
        () => ZrdStumProtocolCodec.decode('<S03>|V1:bad|SN:3'),
        throwsA(isA<ZrdStumProtocolException>()),
      );
    });
  });

  group('ZrdStumProtocolCodec S03 validation', () {
    test('parses a matching URL offer and preserves URL colons', () {
      final message = ZrdStumProtocolCodec.decode(
        '<S03>|VE:1.2.0|AD:https://updates.example.com:8443/app.apk?x=a:b|'
        'MD:0123456789abcdef0123456789abcdef|PT:APP|SN:10',
      );

      final offer = ZrdStumProtocolCodec.parseUpgradeOffer(
        message,
        currentVersion: '1.0.0',
        expectedPackageTag: 'APP',
      );

      expect(offer?.targetVersion, '1.2.0');
      expect(
        offer?.downloadUrl.toString(),
        'https://updates.example.com:8443/app.apk?x=a:b',
      );
      expect(offer?.md5, '0123456789abcdef0123456789abcdef');
    });

    test('treats SL_V date envelope as the same installed app version', () {
      final message = ZrdStumProtocolCodec.decode(
        '<S03>|VE:SL_V1.0.2_20260812|AD:0|SN:10',
      );

      expect(
        ZrdStumProtocolCodec.parseUpgradeOffer(
          message,
          currentVersion: '1.0.2',
          expectedPackageTag: '',
        ),
        isNull,
      );
    });

    test('treats server SL_APP_V envelope as the installed app version', () {
      final message = ZrdStumProtocolCodec.decode(
        '<S03>|VE:SL_APP_V1.0.2|AD:0|SN:10',
      );

      expect(
        ZrdStumProtocolCodec.parseUpgradeOffer(
          message,
          currentVersion: '1.0.2',
          expectedPackageTag: '',
        ),
        isNull,
      );
    });

    test('accepts the real SL_APP_V1.0.5 response as newer than app 1.0.4', () {
      final message = ZrdStumProtocolCodec.decode(
        '<S03>|VE:SL_APP_V1.0.5|'
        'AD:http://192.168.0.99:18888/group1/M00/00/9C/'
        'wKgAY2p8WueAEEErAYjrJ3dvkSY590.apk|'
        'MD:9C8F95DF76566BF6E8403511F9D9DC0B|SN:9',
      );

      final offer = ZrdStumProtocolCodec.parseUpgradeOffer(
        message,
        currentVersion: '1.0.4',
        expectedPackageTag: '',
      );

      expect(offer, isNotNull);
      expect(offer?.targetVersion, 'SL_APP_V1.0.5');
      expect(offer?.serialNumber, 9);
      expect(
        offer?.downloadUrl.toString(),
        'http://192.168.0.99:18888/group1/M00/00/9C/'
        'wKgAY2p8WueAEEErAYjrJ3dvkSY590.apk',
      );
      expect(offer?.md5, '9C8F95DF76566BF6E8403511F9D9DC0B');
    });

    test('accepts VE zero without optional package fields', () {
      final message = ZrdStumProtocolCodec.decode('<S03>|VE:0|AD:|SN:10');

      expect(
        ZrdStumProtocolCodec.parseUpgradeOffer(
          message,
          currentVersion: '1.0.0',
          expectedPackageTag: 'APP',
        ),
        isNull,
      );
    });

    test('maps invalid PT, AD and MD to the documented attributed NG', () {
      final cases = <(String, String)>[
        (
          '<S03>|VE:1.2.0|AD:https://example.com/app.apk|'
              'MD:0123456789abcdef0123456789abcdef|SN:10',
          'NG2PT',
        ),
        (
          '<S03>|VE:1.2.0|AD:https://example.com/app.apk|'
              'MD:0123456789abcdef0123456789abcdef|PT:OTHER|SN:10',
          'NG3PT',
        ),
        (
          '<S03>|VE:1.2.0|AD:2|'
              'MD:0123456789abcdef0123456789abcdef|PT:APP|SN:10',
          'NG3AD',
        ),
        ('<S03>|VE:1.2.0|AD:https://example.com/app.apk|PT:APP|SN:10', 'NG2MD'),
        (
          '<S03>|VE:1.2.0|AD:https://example.com/app.apk|'
              'MD:abcd|PT:APP|SN:10',
          'NG3MD',
        ),
      ];

      for (final (frame, expectedResponse) in cases) {
        expect(
          () => ZrdStumProtocolCodec.parseUpgradeOffer(
            ZrdStumProtocolCodec.decode(frame),
            currentVersion: '1.0.0',
            expectedPackageTag: 'APP',
          ),
          throwsA(
            isA<ZrdStumProtocolException>().having(
              (error) => error.responseValue,
              'responseValue',
              expectedResponse,
            ),
          ),
        );
      }
    });
  });

  test('message sequence wraps from 9999 back to 1', () {
    final sequence = ZrdStumMessageSequence(initialValue: 9999);

    expect(sequence.next(), 9999);
    expect(sequence.next(), 1);
    expect(sequence.next(), 2);
  });

  group('ZrdStumFrameDecoder', () {
    test('splits sticky packets into all complete frames', () {
      final decoder = ZrdStumFrameDecoder();

      expect(
        decoder.add(
          ascii.encode(
            '<S00>|03:OK|SN:3\r\n'
            '<S03>|VE:0|AD:|SN:4\r\n',
          ),
        ),
        const <String>['<S00>|03:OK|SN:3', '<S03>|VE:0|AD:|SN:4'],
      );
    });

    test('retains a fragmented frame until the final LF arrives', () {
      final decoder = ZrdStumFrameDecoder();

      expect(decoder.add(ascii.encode('<S03>|VE:V1.2.3')), isEmpty);
      expect(
        decoder.add(ascii.encode('|AD:https://example.com/app.apk')),
        isEmpty,
      );
      expect(decoder.add(ascii.encode('|SN:7\r')), isEmpty);
      expect(decoder.add(ascii.encode('\n')), const <String>[
        '<S03>|VE:V1.2.3|AD:https://example.com/app.apk|SN:7',
      ]);
    });

    test('allows an exact-limit frame whose CRLF is split', () {
      final decoder = ZrdStumFrameDecoder(maxFrameBytes: 20);
      final frame = 'A' * 20;

      expect(decoder.add(ascii.encode('$frame\r')), isEmpty);
      expect(decoder.add(const <int>[10]), <String>[frame]);
      expect(() => ZrdStumFrameDecoder(maxFrameBytes: 0), throwsArgumentError);
    });

    test('rejects non-ASCII bytes and direct non-ASCII frames', () {
      final decoder = ZrdStumFrameDecoder();
      final nonAsciiFrame = '<S03>|VE:\u4e2d|SN:1\r\n';

      expect(
        () => decoder.add(utf8.encode(nonAsciiFrame)),
        throwsA(
          isA<ZrdStumProtocolException>().having(
            (error) => error.errorCode,
            'errorCode',
            '1',
          ),
        ),
      );
      expect(
        () => ZrdStumProtocolCodec.decode(
          nonAsciiFrame.substring(0, nonAsciiFrame.length - 2),
        ),
        throwsA(isA<ZrdStumProtocolException>()),
      );
      expect(
        () => ZrdStumProtocolCodec.encodeUpgradeRequest(
          currentVersion: '\u4e2d',
          packageTag: 'MB',
          serialNumber: 1,
        ),
        throwsArgumentError,
      );
    });

    test('rejects complete and unterminated frames over the byte limit', () {
      final completeFrameDecoder = ZrdStumFrameDecoder(maxFrameBytes: 20);
      final unterminatedFrameDecoder = ZrdStumFrameDecoder(maxFrameBytes: 20);

      expect(
        () => completeFrameDecoder.add(
          ascii.encode('<S03>|VE:${'A' * 21}|SN:1\r\n'),
        ),
        throwsA(isA<ZrdStumProtocolException>()),
      );
      expect(
        () => unterminatedFrameDecoder.add(List<int>.filled(21, 0x41)),
        throwsA(isA<ZrdStumProtocolException>()),
      );
    });
  });
}
