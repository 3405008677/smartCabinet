import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/localization/values/admin_localizations.dart';
import 'package:smart_cabinet/src/app/localization/values/terminal_upgrade_localizations.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/domain/entities/terminal_upgrade.dart';

/// 终端升级静态标签与运行态消息的四语言完整性测试。
void main() {
  test('every terminal upgrade key has four complete translations', () {
    final duplicateKeys = adminLocalizations.keys.toSet().intersection(
      terminalUpgradeRuntimeLocalizations.keys.toSet(),
    );
    expect(duplicateKeys, isEmpty, reason: '升级文案 key 重复：$duplicateKeys');

    final allUpgradeLocalizations = <String, Map<AppLanguage, String>>{
      ...adminLocalizations,
      ...terminalUpgradeRuntimeLocalizations,
    };
    final upgradeEntries = allUpgradeLocalizations.entries.where(
      (entry) =>
          entry.key.startsWith('adminUpgrade') ||
          entry.key.startsWith('adminFunctionTerminalUpgrade'),
    );

    expect(upgradeEntries, isNotEmpty);
    for (final entry in upgradeEntries) {
      expect(
        entry.value.keys,
        unorderedEquals(AppLanguage.values),
        reason: '升级文案缺少语言：${entry.key}',
      );
      final expectedPlaceholders = _placeholders(
        entry.value[AppLanguage.simplifiedChinese]!,
      );
      for (final language in AppLanguage.values) {
        final value = entry.value[language];
        expect(value?.trim(), isNotEmpty, reason: '升级文案为空：${entry.key}');
        expect(
          _placeholders(value!),
          expectedPlaceholders,
          reason: '升级文案占位符不一致：${entry.key} / ${language.name}',
        );
        if (language != AppLanguage.simplifiedChinese) {
          expect(
            AppLocalizations(language).t(entry.key, '__missing__'),
            value,
            reason: '升级文案未聚合到 AppLocalizations：${entry.key}',
          );
        }
      }
    }
  });

  test('every upgrade localization key referenced by the page exists', () {
    final pageSource = File(
      'lib/src/features/terminal_upgrade/presentation/pages/'
      'admin_terminal_upgrade_page.dart',
    ).readAsStringSync();
    final referencedKeys = RegExp(
      r'''['"](adminUpgrade[A-Za-z0-9]+)['"]''',
    ).allMatches(pageSource).map((match) => match.group(1)!).toSet();
    final availableKeys = <String>{
      ...adminLocalizations.keys,
      ...terminalUpgradeRuntimeLocalizations.keys,
    };

    expect(referencedKeys, isNotEmpty);
    expect(
      availableKeys,
      containsAll(referencedKeys),
      reason: '升级页面引用了未注册的本地化 key',
    );
  });

  test('settings validation returns stable codes instead of UI text', () {
    const valid = TerminalUpgradeSettings(
      enabled: true,
      host: '127.0.0.1',
      port: 8001,
      terminalId: '12345678901',
    );
    const validIdentity = TerminalUpgradeLoginIdentity(
      moduleId: '75526065009',
      dataProtocolIp: '47.107.40.88',
      chipId: 'AABBCIID33',
    );

    expect(
      valid.copyWith(host: '').validate(),
      TerminalUpgradeMessageCode.settingsHostRequired,
    );
    expect(
      valid.copyWith(port: 0).validate(),
      TerminalUpgradeMessageCode.settingsPortInvalid,
    );
    expect(
      valid.copyWith(terminalId: '01234567890').validate(),
      TerminalUpgradeMessageCode.settingsTerminalIdInvalid,
    );
    expect(
      const TerminalUpgradeLoginIdentity(
        moduleId: '123',
        dataProtocolIp: '47.107.40.88',
        chipId: 'AABBCIID33',
      ).validate(),
      TerminalUpgradeMessageCode.settingsModuleIdInvalid,
    );
    expect(
      const TerminalUpgradeLoginIdentity(
        moduleId: '123456789012345',
        dataProtocolIp: '47.107.40.88',
        chipId: 'AABBCIID33',
      ).validate(),
      isNull,
    );
    expect(
      const TerminalUpgradeLoginIdentity(
        moduleId: '75526065009',
        dataProtocolIp: '120.79.160.23,47.107.40.88',
        chipId: 'AABBCIID33',
      ).validate(),
      isNull,
    );
    expect(
      const TerminalUpgradeLoginIdentity(
        moduleId: '75526065009',
        dataProtocolIp: '',
        chipId: 'AABBCIID33',
      ).validate(),
      TerminalUpgradeMessageCode.settingsDataProtocolIpInvalid,
    );
    for (final invalidDataProtocolIp in <String>[
      'upgrade.example.com',
      '999.1.1.1',
      '1.2.3.4,',
      '1.2.3.4, 5.6.7.8',
      '01.2.3.4',
    ]) {
      expect(
        TerminalUpgradeLoginIdentity(
          moduleId: '75526065009',
          dataProtocolIp: invalidDataProtocolIp,
          chipId: 'AABBCIID33',
        ).validate(),
        TerminalUpgradeMessageCode.settingsDataProtocolIpInvalid,
        reason: invalidDataProtocolIp,
      );
    }
    expect(
      valid.copyWith(packageTag: 'APP|BAD').validate(),
      TerminalUpgradeMessageCode.settingsProtocolValueInvalid,
    );
    expect(valid.validate(), isNull);
    expect(validIdentity.validate(), isNull);
  });
}

List<String> _placeholders(String value) {
  final values = RegExp(
    r'\{[A-Za-z][A-Za-z0-9_]*\}',
  ).allMatches(value).map((match) => match.group(0)!).toList();
  values.sort();
  return values;
}
