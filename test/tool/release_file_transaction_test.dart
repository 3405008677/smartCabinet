import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_file_transaction.dart';

void main() {
  test('Windows 原子替换支持含空格路径并保留原内容备份', () async {
    if (!Platform.isWindows) return;
    final directory = await Directory.systemTemp.createTemp(
      'smart cabinet release ',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final source = File(
      '${directory.path}${Platform.pathSeparator}new file.txt',
    );
    final destination = File(
      '${directory.path}${Platform.pathSeparator}pubspec file.yaml',
    );
    final backup = File(
      '${directory.path}${Platform.pathSeparator}backup file.bak',
    );
    await source.writeAsString('new');
    await destination.writeAsString('old');

    final result = await replaceWindowsFile(
      source: source.path,
      destination: destination.path,
      backup: backup.path,
    );

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(await destination.readAsString(), 'new');
    expect(await backup.readAsString(), 'old');
    expect(await source.exists(), isFalse);
  });
}
