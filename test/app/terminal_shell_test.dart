import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/app/shell/app_shell.dart';

void main() {
  test('clock delay targets the next minute boundary', () {
    expect(
      terminalClockDelayUntilNextMinute(DateTime(2026, 7, 13, 12, 34)),
      const Duration(minutes: 1),
    );
    expect(
      terminalClockDelayUntilNextMinute(DateTime(2026, 7, 13, 12, 34, 56, 750)),
      const Duration(milliseconds: 3250),
    );
    expect(
      terminalClockDelayUntilNextMinute(DateTime(2026, 7, 13, 23, 59, 59, 999)),
      const Duration(milliseconds: 1),
    );
  });

  testWidgets('terminal clock displays minute precision', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TerminalShell(child: SizedBox.expand())),
    );
    await tester.pump();

    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .toList();

    expect(labels.any(RegExp(r'^\d{2}:\d{2}$').hasMatch), isTrue);
    expect(labels.any(RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch), isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
