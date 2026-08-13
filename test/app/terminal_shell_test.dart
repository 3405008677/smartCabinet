import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/app/shell/app_shell.dart';
import 'package:smart_cabinet/src/core/device/app_version_service.dart';

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
      MaterialApp(
        home: TerminalShell(
          appVersionLoader: () async =>
              const AppVersionInfo(name: '1.2.3', code: 23),
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();

    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .toList();

    expect(labels.any(RegExp(r'^\d{2}:\d{2}$').hasMatch), isTrue);
    expect(labels.any(RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch), isFalse);
    expect(find.text('v1.2.3'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('version footer stays tappable when native version read fails', (
    tester,
  ) async {
    var tapCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TerminalShell(
          appVersionLoader: () =>
              Future<AppVersionInfo>.error(StateError('version unavailable')),
          onVersionTap: () => tapCount += 1,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('v—'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('terminal_version_tap_target')));
    await tester.pump();

    expect(tapCount, 1);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
