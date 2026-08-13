import 'dart:io';

/// 不依赖 Flutter 测试运行器的本地化源码门禁。
///
/// Codex 的受保护工作区可能让提权后的 flutter_tester 看到加密文件视图；本工具
/// 直接在工作区内运行，补充检查未定义 key 和直接写入界面的中日韩/拉丁文案。
void main() {
  final errors = <String>[];
  final keyOwners = <String, String>{};
  final catalogFiles = Directory('lib/src/app/localization/values')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('_localizations.dart'));
  final catalogKeyPattern = RegExp(
    r'''^\s*['"]([A-Za-z][A-Za-z0-9_]*)['"]\s*:\s*\{''',
    multiLine: true,
  );

  for (final file in catalogFiles) {
    final source = file.readAsStringSync();
    for (final match in catalogKeyPattern.allMatches(source)) {
      final key = match.group(1)!;
      final previous = keyOwners[key];
      if (previous != null) {
        errors.add('重复 key：$key（$previous / ${file.path}）');
      } else {
        keyOwners[key] = file.path;
      }
    }
  }

  final keyUsagePatterns = <RegExp>[
    RegExp(r'''\.t\s*\(\s*['"]([A-Za-z][A-Za-z0-9_]*)['"]''', multiLine: true),
    RegExp(
      r'''_documentText\s*\(\s*[^,]+,\s*['"]([A-Za-z][A-Za-z0-9_]*)['"]''',
      multiLine: true,
    ),
    RegExp(
      r'''_upgradeActionErrorText\s*\([\s\S]*?key\s*:\s*['"]([A-Za-z][A-Za-z0-9_]*)['"]''',
      multiLine: true,
    ),
  ];
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));

  for (final file in dartFiles) {
    final source = file.readAsStringSync();
    for (final pattern in keyUsagePatterns) {
      for (final match in pattern.allMatches(source)) {
        final key = match.group(1)!;
        if (!keyOwners.containsKey(key)) {
          errors.add(
            '${file.path}:${_lineOf(source, match.start)} 未定义 key：$key',
          );
        }
      }
    }

    const bakedTextRasterAssets = <String>{'assets/images/智能柜启动.png'};
    for (final asset in bakedTextRasterAssets) {
      if (source.contains(asset)) {
        errors.add(
          '${file.path}:${_lineOf(source, source.indexOf(asset))} '
          '引用了内嵌可翻译文字的图片：$asset',
        );
      }
    }
  }

  final directPatterns = <RegExp>[
    RegExp(
      r'''(?:const\s+)?Text\s*\(\s*['"][^'"\r\n]*[\u3400-\u9fff\u3040-\u30ff]''',
    ),
    RegExp(
      r'''(?:tooltip|semanticsLabel|labelText|hintText|helperText|errorText)\s*:\s*['"][^'"\r\n]*[\u3400-\u9fff\u3040-\u30ff]''',
    ),
    RegExp(
      r'''Message\.(?:info|success|warning|error|loading|showInOverlay)\s*\(\s*[^,\r\n]+,\s*['"][^'"\r\n]*[\u3400-\u9fff\u3040-\u30ff]''',
    ),
  ];
  final directLatinPatterns = <RegExp>[
    RegExp(
      r'''(?:const\s+)?Text\s*\(\s*['"]([^'"\r\n]*[A-Za-z][^'"\r\n]*)['"]''',
    ),
    RegExp(
      r'''(?:tooltip|semanticsLabel|labelText|hintText|helperText|errorText)\s*:\s*['"]([^'"\r\n]*[A-Za-z][^'"\r\n]*)['"]''',
    ),
    RegExp(
      r'''Message\.(?:info|success|warning|error|loading|showInOverlay)\s*\(\s*[^,\r\n]+,\s*['"]([^'"\r\n]*[A-Za-z][^'"\r\n]*)['"]''',
    ),
  ];

  final uiFiles = Directory('lib/src')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) {
        final path = file.path.replaceAll('\\', '/');
        return file.path.endsWith('.dart') &&
            !path.contains('/app/localization/') &&
            (path.contains('/presentation/') ||
                path.contains('/app/') ||
                path.contains('/shared/'));
      });
  for (final file in uiFiles) {
    final source = file.readAsStringSync();
    for (final pattern in directPatterns) {
      for (final match in pattern.allMatches(source)) {
        errors.add('${file.path}:${_lineOf(source, match.start)} 存在直接界面文案');
      }
    }
    for (final pattern in directLatinPatterns) {
      for (final match in pattern.allMatches(source)) {
        if (_isNonTranslatableUiLiteral(match.group(1)!)) {
          continue;
        }
        errors.add('${file.path}:${_lineOf(source, match.start)} 存在直接拉丁界面文案');
      }
    }
  }

  if (errors.isNotEmpty) {
    stderr.writeln('本地化源码审计失败（${errors.length} 项）：');
    for (final error in errors) {
      stderr.writeln('- $error');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln(
    '本地化源码审计通过：${keyOwners.length} 个唯一 key，'
    '未发现未定义引用或直接界面文案。',
  );
}

int _lineOf(String source, int offset) {
  return '\n'.allMatches(source.substring(0, offset)).length + 1;
}

bool _isNonTranslatableUiLiteral(String value) {
  if (value.contains(r'$')) {
    return true;
  }
  final trimmed = value.trim();
  return RegExp(r'^[A-Z0-9._/+:-]{2,}$').hasMatch(trimmed) ||
      RegExp(r'^v?\d+(?:\.\d+)+(?:[-+][A-Za-z0-9.]+)?$').hasMatch(trimmed) ||
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(trimmed);
}
