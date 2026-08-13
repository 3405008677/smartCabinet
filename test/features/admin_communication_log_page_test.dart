import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/routing/app_router.dart';
import 'package:smart_cabinet/src/app/routing/app_routes.dart';
import 'package:smart_cabinet/src/app/theme/app_theme.dart';
import 'package:smart_cabinet/src/core/logging/communication_log_store.dart';
import 'package:smart_cabinet/src/features/admin/presentation/pages/admin_communication_log_page.dart';

void main() {
  setUp(CommunicationLogStore.instance.clear);
  tearDown(CommunicationLogStore.instance.clear);

  testWidgets('admin communication log route opens the page', (tester) async {
    await _pumpRoute(tester);

    expect(
      find.byKey(const ValueKey('admin_communication_log_page')),
      findsOneWidget,
    );
    expect(find.text('通讯日志'), findsOneWidget);
    expect(find.text('设备通讯 · 管理员'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin communication log page shows an injected empty state', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      initialEntries: const <CommunicationLogEntry>[],
      changes: const Stream<List<CommunicationLogEntry>>.empty(),
    );

    expect(
      find.byKey(const ValueKey('admin_communication_log_empty')),
      findsOneWidget,
    );
    expect(find.text('暂无通讯日志'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('communication table updates live and opens full information', (
    tester,
  ) async {
    final changes = StreamController<List<CommunicationLogEntry>>.broadcast(
      sync: true,
    );
    addTearDown(changes.close);
    const longHardwareBody =
        '硬件返回：ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZ'
        'ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final serverEntry = CommunicationLogEntry(
      id: 1,
      targetType: CommunicationTargetType.server,
      direction: CommunicationDirection.outbound,
      channel: 'TCP',
      operation: 'heartbeat',
      messageBody: '{"func":"heartbeat"}',
      requestTime: DateTime(2026, 8, 11, 9, 8, 7, 6),
      result: '发送成功',
      completeInformation: '服务器完整信息',
    );
    final hardwareEntry = CommunicationLogEntry(
      id: 2,
      targetType: CommunicationTargetType.hardware,
      direction: CommunicationDirection.inbound,
      channel: 'MethodChannel',
      operation: 'getHardwareStatus',
      messageBody: longHardwareBody,
      requestTime: DateTime(2026, 8, 11, 10, 9, 8, 7),
      result: '接收成功',
      completeInformation: '硬件完整信息\n第二行完整内容',
    );
    final upgradeEntry = CommunicationLogEntry(
      id: 3,
      targetType: CommunicationTargetType.upgradeCommand,
      direction: CommunicationDirection.outbound,
      channel: 'ZRD STUM TCP',
      operation: '发送 TCP 协议消息',
      messageBody: '{"keyword":"T03","SN":2}',
      requestTime: DateTime(2026, 8, 11, 11, 10, 9, 8),
      result: '成功',
      completeInformation: '升级指令完整信息',
    );

    await _pumpPage(
      tester,
      initialEntries: [serverEntry],
      changes: changes.stream,
    );

    expect(
      find.byKey(const ValueKey('admin_communication_log_table')),
      findsOneWidget,
    );
    expect(find.text('类型'), findsOneWidget);
    expect(find.text('发送类型'), findsOneWidget);
    expect(find.text('消息体'), findsOneWidget);
    expect(find.text('请求时间'), findsOneWidget);
    expect(find.text('请求结果'), findsOneWidget);
    expect(find.text('服务器'), findsOneWidget);
    expect(find.text('上报'), findsOneWidget);
    expect(find.text('发送成功'), findsOneWidget);

    changes.add([upgradeEntry, hardwareEntry, serverEntry]);
    await tester.pumpAndSettle();

    expect(find.text('当前共 3 条记录'), findsOneWidget);
    expect(find.text('硬件'), findsOneWidget);
    expect(find.text('升级指令'), findsOneWidget);
    expect(find.text('下发'), findsOneWidget);
    expect(find.text('2026-08-11 10:09:08.007'), findsOneWidget);
    final previewText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('admin_communication_log_message_2')),
        matching: find.byType(Text),
      ),
    );
    expect(previewText.maxLines, 1);
    expect(previewText.overflow, TextOverflow.ellipsis);

    await tester.tap(
      find.byKey(const ValueKey('admin_communication_log_message_2')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin_communication_log_detail_dialog')),
      findsOneWidget,
    );
    expect(find.text('通讯日志详情'), findsOneWidget);
    expect(find.text('硬件完整信息\n第二行完整内容'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// 使用命名路由打开通讯日志页。
Future<void> _pumpRoute(WidgetTester tester) async {
  _setTerminalViewport(tester);
  await tester.pumpWidget(
    AppLocalizationsScope(
      localizations: const AppLocalizations(AppLanguage.simplifiedChinese),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        initialRoute: AppRoutes.adminCommunicationLog,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 注入可控日志快照和流，验证页面实时交互。
Future<void> _pumpPage(
  WidgetTester tester, {
  required List<CommunicationLogEntry> initialEntries,
  required Stream<List<CommunicationLogEntry>> changes,
}) async {
  _setTerminalViewport(tester);
  await tester.pumpWidget(
    AppLocalizationsScope(
      localizations: const AppLocalizations(AppLanguage.simplifiedChinese),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: AdminCommunicationLogPage(
          initialEntries: initialEntries,
          changes: changes,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 固定为柜机目标画布，确保表格和详情弹窗没有布局溢出。
void _setTerminalViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
