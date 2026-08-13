import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/shared/widgets/smart_cabinet_brand_panel.dart';

void main() {
  const expectedCopy = <AppLanguage, (String, String, String)>{
    AppLanguage.simplifiedChinese: ('智能柜', '智享生活，便捷未来', '系统启动中…'),
    AppLanguage.traditionalChinese: ('智慧櫃', '智享生活，便捷未來', '系統啟動中…'),
    AppLanguage.english: (
      'Smart Cabinet',
      'Smarter living, a more convenient future',
      'Starting system…',
    ),
    AppLanguage.japanese: ('スマートキャビネット', 'スマートな暮らし、便利な未来', 'システムを起動しています…'),
  };

  for (final entry in expectedCopy.entries) {
    testWidgets('brand panel renders ${entry.key.code} copy', (tester) async {
      await tester.pumpWidget(
        AppLocalizationsScope(
          localizations: AppLocalizations(entry.key),
          child: const MaterialApp(
            home: Scaffold(body: SmartCabinetBrandPanel(showLoading: true)),
          ),
        ),
      );

      expect(find.text(entry.value.$1), findsOneWidget);
      expect(find.text(entry.value.$2), findsOneWidget);
      expect(find.text(entry.value.$3), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  }
}
