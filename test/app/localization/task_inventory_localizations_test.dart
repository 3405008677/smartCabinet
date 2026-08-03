import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/localization/values/task_inventory_localizations.dart';

void main() {
  group('盘点多语言文案', () {
    test('包含盘点任务执行页使用的步骤和操作 key', () {
      expect(
        taskInventoryLocalizations.keys,
        containsAll(const {
          'taskStepVerifyInventoryCode',
          'taskActionVerifyInventoryCode',
          'taskStepInventoryBySlot',
          'taskActionInventoryBySlot',
        }),
      );
    });

    test('每个 key 都提供四种非空翻译', () {
      expect(taskInventoryLocalizations, isNotEmpty);

      for (final entry in taskInventoryLocalizations.entries) {
        expect(
          entry.value.keys,
          unorderedEquals(AppLanguage.values),
          reason: '盘点文案缺少语言：${entry.key}',
        );
        for (final language in AppLanguage.values) {
          expect(
            entry.value[language]?.trim(),
            isNotEmpty,
            reason: '盘点文案为空：${entry.key} / ${language.name}',
          );
        }
      }
    });

    test('四种语言的占位符与简体中文完全一致', () {
      for (final entry in taskInventoryLocalizations.entries) {
        final expected = _sortedPlaceholders(
          entry.value[AppLanguage.simplifiedChinese]!,
        );

        for (final language in AppLanguage.values) {
          expect(
            _sortedPlaceholders(entry.value[language]!),
            expected,
            reason: '盘点文案占位符不一致：${entry.key} / ${language.name}',
          );
        }
      }
    });
  });
}

/// 提取并排序文案中的命名占位符，重复占位符也会保留以便发现数量差异。
List<String> _sortedPlaceholders(String value) {
  final placeholders = RegExp(
    r'\{[A-Za-z][A-Za-z0-9_]*\}',
  ).allMatches(value).map((match) => match.group(0)!).toList();
  placeholders.sort();
  return placeholders;
}
