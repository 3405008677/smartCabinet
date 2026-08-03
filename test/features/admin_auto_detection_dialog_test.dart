import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/features/admin/presentation/widgets/admin_auto_detection_dialog.dart';

void main() {
  AdminDetectionItem item({
    String id = 'camera_outsideEnvironment',
    String title = '柜外环境摄像头',
    AdminDetectionState state = AdminDetectionState.healthy,
    AdminDetectionRecoveryAction recoveryAction =
        AdminDetectionRecoveryAction.recheck,
    bool? streamHealthy,
    String result = '设备连接成功',
    String recoveryUnavailableReason = '',
  }) {
    return AdminDetectionItem(
      id: id,
      title: title,
      description: '检测摄像头',
      result: result,
      icon: Icons.videocam_outlined,
      state: state,
      recoveryAction: recoveryAction,
      streamHealthy: streamHealthy,
      recoveryUnavailableReason: recoveryUnavailableReason,
    );
  }

  Future<void> pumpDialog(
    WidgetTester tester, {
    required List<AdminDetectionItem> initialItems,
    Size physicalSize = const Size(1280, 900),
    AdminDetectionInitialLoader? onInitialLoad,
    AdminDetectionItemReconnectHandler? onReconnect,
  }) async {
    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminAutoDetectionDialog(
            initialItems: initialItems,
            onInitialLoad: onInitialLoad ?? () async => initialItems,
            onReconnect: onReconnect,
          ),
        ),
      ),
    );
  }

  testWidgets('opening dialog loads latest status once without batch action', (
    tester,
  ) async {
    var loadCalls = 0;
    final initialItem = item(result: '上一次检测结果');
    final latestItem = item(result: '最新检测结果');

    await pumpDialog(
      tester,
      initialItems: [initialItem],
      onInitialLoad: () async {
        loadCalls += 1;
        return [latestItem];
      },
    );
    await tester.pumpAndSettle();

    expect(loadCalls, 1);
    expect(find.text('最新检测结果'), findsOneWidget);
    expect(find.text('上一次检测结果'), findsNothing);
    expect(
      find.byKey(const ValueKey('admin_auto_detection_reload_all')),
      findsNothing,
    );
  });

  testWidgets('status filters sit beside title without obsolete hints', (
    tester,
  ) async {
    await pumpDialog(tester, initialItems: [item()]);
    await tester.pumpAndSettle();

    final title = find.text('自动检测');
    final allFilter = find.byKey(
      const ValueKey('admin_auto_detection_filter_all'),
    );
    expect(allFilter, findsOneWidget);
    expect(
      tester.getTopLeft(allFilter).dx,
      greaterThan(tester.getTopRight(title).dx),
    );
    expect(
      find.byKey(const ValueKey('admin_auto_detection_filter_healthy')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin_auto_detection_filter_abnormal')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin_auto_detection_filter_pending')),
      findsOneWidget,
    );
    expect(find.textContaining('列表可滚动'), findsNothing);
    expect(find.text('重新检测全部'), findsNothing);
    expect(
      find.byKey(const ValueKey('admin_auto_detection_reload_all')),
      findsNothing,
    );
  });

  testWidgets('compact dialog keeps all status filters accessible', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      initialItems: [item()],
      physicalSize: const Size(820, 700),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin_auto_detection_filter_all')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin_auto_detection_filter_pending')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('status filters only change the left detection list', (
    tester,
  ) async {
    final items = [
      item(id: 'wifi', title: '连接 WiFi'),
      item(id: 'rj45', title: 'RJ45连接', state: AdminDetectionState.abnormal),
      item(id: 'scanner', title: '扫码器', state: AdminDetectionState.pending),
      item(id: 'camera', title: '检测中的摄像头', state: AdminDetectionState.checking),
    ];
    await pumpDialog(tester, initialItems: items);

    expect(
      find.byKey(const ValueKey('admin_auto_detection_item_wifi')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin_auto_detection_item_rj45')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin_auto_detection_item_scanner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin_auto_detection_item_camera')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('admin_auto_detection_filter_healthy')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('admin_auto_detection_item_wifi')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin_auto_detection_item_rj45')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('admin_auto_detection_item_scanner')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('admin_auto_detection_item_camera')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('admin_auto_detection_filter_abnormal')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('admin_auto_detection_item_wifi')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('admin_auto_detection_item_rj45')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('admin_auto_detection_filter_pending')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('admin_auto_detection_item_rj45')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('admin_auto_detection_item_scanner')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('admin_auto_detection_filter_all')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('admin_auto_detection_item_wifi')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin_auto_detection_item_rj45')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin_auto_detection_item_scanner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin_auto_detection_item_camera')),
      findsOneWidget,
    );
  });

  testWidgets('stream retry reports success only after stream health check', (
    tester,
  ) async {
    var reconnectCalls = 0;
    final initialItem = item(
      state: AdminDetectionState.abnormal,
      recoveryAction: AdminDetectionRecoveryAction.retryStream,
      streamHealthy: false,
      result: '设备连接成功\n视频推流：失败',
    );
    final recoveredItem = item(
      recoveryAction: AdminDetectionRecoveryAction.retryStream,
      streamHealthy: true,
      result: '设备连接成功\n视频推流：推流中',
    );

    await pumpDialog(
      tester,
      initialItems: [initialItem],
      onReconnect: (_) async {
        reconnectCalls += 1;
        return recoveredItem;
      },
    );
    await tester.tap(
      find.byKey(const ValueKey('admin_auto_detection_filter_abnormal')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('admin_auto_detection_reconnect_selected')),
    );
    await tester.pumpAndSettle();

    expect(reconnectCalls, 1);
    expect(find.text('柜外环境摄像头 推流已恢复'), findsOneWidget);
    expect(find.text('当前筛选条件下暂无检测项'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('admin_auto_detection_item_camera_outsideEnvironment'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'stream retry does not treat a healthy device as healthy stream',
    (tester) async {
      final initialItem = item(
        state: AdminDetectionState.abnormal,
        recoveryAction: AdminDetectionRecoveryAction.retryStream,
        streamHealthy: false,
        result: '设备连接成功\n视频推流：失败',
      );
      final stillStoppedItem = item(
        recoveryAction: AdminDetectionRecoveryAction.retryStream,
        streamHealthy: false,
        result: '设备连接成功\n视频推流：未启动',
      );

      await pumpDialog(
        tester,
        initialItems: [initialItem],
        onReconnect: (_) async => stillStoppedItem,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('admin_auto_detection_reconnect_selected')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('复检后视频流仍未进入推流中状态'), findsOneWidget);
      expect(find.textContaining('推流已恢复'), findsNothing);
    },
  );

  testWidgets('unsupported recovery is disabled and explains why', (
    tester,
  ) async {
    final unsupportedItem = item(
      state: AdminDetectionState.pending,
      recoveryAction: AdminDetectionRecoveryAction.unsupported,
      recoveryUnavailableReason: '系统尚未接入该设备接口',
      result: '待接入',
    );

    await pumpDialog(tester, initialItems: [unsupportedItem]);
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('admin_auto_detection_reconnect_selected')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('暂不支持自动恢复'), findsOneWidget);
    expect(find.text('系统尚未接入该设备接口'), findsOneWidget);
  });
}
