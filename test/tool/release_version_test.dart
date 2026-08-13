import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_version.dart';

void main() {
  group('release version', () {
    test('默认同时增加补丁版本和 Android 构建号', () {
      final document = parsePubspecVersion('name: app\nversion: 1.0.0+1\n');

      expect(document.version.nextPatch().pubspecValue, '1.0.1+2');
    });

    test('补丁版本按整数递增而不是按单个字符进位', () {
      final document = parsePubspecVersion('version: 1.0.9+9\n');

      expect(document.version.nextPatch().pubspecValue, '1.0.10+10');
    });

    test('替换版本时保留 CRLF 和其它 pubspec 内容', () {
      const source = 'name: app\r\nversion: 1.2.3+4\r\ndependencies:\r\n';
      final document = parsePubspecVersion(source);

      expect(
        document.replaceVersion(document.version.nextPatch()),
        'name: app\r\nversion: 1.2.4+5\r\ndependencies:\r\n',
      );
    });

    test('拒绝缺失、重复或非标准版本声明', () {
      expect(
        () => parsePubspecVersion('name: app\n'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parsePubspecVersion('version: 1.0.0+1\nversion: 1.0.1+2\n'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parsePubspecVersion('version: 1.0+1\n'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parsePubspecVersion('  version: 1.0.0+1\n'),
        throwsA(isA<FormatException>()),
      );
    });

    test('人工指定版本时名称和构建号都必须严格递增', () {
      final current = parsePubspecVersion('version: 1.0.3+8\n').version;

      expect(
        parseExplicitReleaseVersion(
          current: current,
          versionName: '1.1.0',
          versionCode: 9,
        ).pubspecValue,
        '1.1.0+9',
      );
      expect(
        () => parseExplicitReleaseVersion(
          current: current,
          versionName: '1.0.3',
          versionCode: 9,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseExplicitReleaseVersion(
          current: current,
          versionName: '1.1.0',
          versionCode: 8,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('拒绝超过 Android 发布范围的构建号', () {
      expect(
        () => parsePubspecVersion('version: 1.0.0+2100000001\n'),
        throwsA(isA<FormatException>()),
      );
      final current = parsePubspecVersion(
        'version: 1.0.0+$maxAndroidVersionCode\n',
      ).version;
      expect(current.nextPatch, throwsA(isA<FormatException>()));
    });
  });
}
