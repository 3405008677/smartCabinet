import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/features/terminal_upgrade/data/datasources/terminal_upgrade_package_downloader.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/domain/entities/terminal_upgrade.dart';

void main() {
  test('streams a URL package, reports progress, and verifies MD5', () async {
    final bytes = List<int>.generate(64, (index) => index);
    final server = await _serve(bytes);
    final progress = <({int downloaded, int? total})>[];
    final offer = _offer(server, md5Value: md5.convert(bytes).toString());
    const downloader = IoTerminalUpgradePackageDownloader();

    DownloadedTerminalUpgradePackage? package;
    try {
      package = await downloader.download(
        offer,
        onProgress: (downloaded, total) {
          progress.add((downloaded: downloaded, total: total));
        },
      );

      expect(await package.file.readAsBytes(), bytes);
      expect(package.size, bytes.length);
      expect(package.md5, offer.md5);
      expect(progress, isNotEmpty);
      expect(progress.last.downloaded, bytes.length);
      expect(progress.last.total, bytes.length);
    } finally {
      await server.close(force: true);
      final directory = package?.file.parent;
      if (directory != null && await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  });

  test('rejects a package whose complete-file MD5 does not match', () async {
    final server = await _serve(<int>[1, 2, 3, 4]);
    final offer = _offer(server, md5Value: '00000000000000000000000000000000');
    const downloader = IoTerminalUpgradePackageDownloader();

    try {
      await expectLater(
        downloader.download(offer, onProgress: (_, _) {}),
        throwsA(
          isA<TerminalUpgradeDownloadException>().having(
            (error) => error.message,
            'message',
            contains('MD5'),
          ),
        ),
      );
    } finally {
      await server.close(force: true);
    }
  });

  test('rejects a declared package larger than the configured limit', () async {
    final bytes = <int>[1, 2, 3, 4];
    final server = await _serve(bytes);
    final offer = _offer(server, md5Value: md5.convert(bytes).toString());
    const downloader = IoTerminalUpgradePackageDownloader(maxPackageBytes: 3);

    try {
      await expectLater(
        downloader.download(offer, onProgress: (_, _) {}),
        throwsA(
          isA<TerminalUpgradeDownloadException>().having(
            (error) => error.message,
            'message',
            contains('最大大小'),
          ),
        ),
      );
    } finally {
      await server.close(force: true);
    }
  });

  test('actively cancels an in-flight response stream', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final token = TerminalUpgradeDownloadCancellationToken();
    server.listen((request) async {
      try {
        request.response.contentLength = 2;
        request.response.add(const <int>[1]);
        await request.response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        request.response.add(const <int>[2]);
        await request.response.close();
      } on HttpException {
        // 客户端取消后服务端写入失败是本测试预期路径。
      }
    });
    final offer = _offer(
      server,
      md5Value: md5.convert(const <int>[1, 2]).toString(),
    );
    const downloader = IoTerminalUpgradePackageDownloader();

    try {
      await expectLater(
        downloader.download(
          offer,
          cancellationToken: token,
          onProgress: (_, _) => token.cancel(),
        ),
        throwsA(
          isA<TerminalUpgradeDownloadException>().having(
            (error) => error.message,
            'message',
            contains('取消'),
          ),
        ),
      );
    } finally {
      await server.close(force: true);
    }
  });

  test(
    'enforces a whole-package deadline in addition to idle timeout',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        try {
          request.response.contentLength = 1;
          await request.response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 300));
          request.response.add(const <int>[1]);
          await request.response.close();
        } on HttpException {
          // 整包截止时间关闭连接后，服务端迟到写入失败属于预期。
        }
      });
      final offer = _offer(
        server,
        md5Value: md5.convert(const <int>[1]).toString(),
      );
      const downloader = IoTerminalUpgradePackageDownloader(
        timeout: Duration(seconds: 1),
        totalTimeout: Duration(milliseconds: 50),
      );

      try {
        await expectLater(
          downloader.download(offer, onProgress: (_, _) {}),
          throwsA(
            isA<TerminalUpgradeDownloadException>().having(
              (error) => error.message,
              'message',
              contains('整包时间上限'),
            ),
          ),
        );
      } finally {
        await server.close(force: true);
      }
    },
  );

  test('rejects an invalid downloader limit before starting I/O', () async {
    const downloader = IoTerminalUpgradePackageDownloader(
      totalTimeout: Duration.zero,
    );
    final offer = TerminalUpgradeOffer(
      targetVersion: '1.1.0',
      downloadUrl: Uri.parse('https://updates.example.com/app.apk'),
      md5: '0123456789abcdef0123456789abcdef',
      packageTag: 'APP',
      serialNumber: 10,
    );

    await expectLater(
      downloader.download(offer, onProgress: (_, _) {}),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.name,
          'name',
          'totalTimeout',
        ),
      ),
    );
  });

  test('redacts URL credentials, query, and fragment for display', () {
    final offer = TerminalUpgradeOffer(
      targetVersion: '1.1.0',
      downloadUrl: Uri(
        scheme: 'https',
        userInfo: 'user:secret',
        host: 'updates.example.com',
        path: '/app.apk',
        query: 'token=secret',
        fragment: 'private',
      ),
      md5: '0123456789abcdef0123456789abcdef',
      packageTag: 'APP',
      serialNumber: 10,
    );

    expect(offer.safeDownloadAddress, 'https://updates.example.com/app.apk');
  });
}

/// 启动只服务一次 APK 字节的本机 HTTP 服务。
Future<HttpServer> _serve(List<int> bytes) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    request.response.contentLength = bytes.length;
    request.response.add(bytes);
    await request.response.close();
  });
  return server;
}

TerminalUpgradeOffer _offer(HttpServer server, {required String md5Value}) {
  return TerminalUpgradeOffer(
    targetVersion: '1.1.0',
    downloadUrl: Uri.parse(
      'http://${server.address.address}:${server.port}/app.apk?token=secret',
    ),
    md5: md5Value,
    packageTag: 'APP',
    serialNumber: 10,
  );
}
