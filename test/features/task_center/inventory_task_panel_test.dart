import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/app/theme/app_theme.dart';
import 'package:smart_cabinet/src/core/device/cabinet_door_guard.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/task_center/data/datasources/fake_task_center_data_source.dart';
import 'package:smart_cabinet/src/features/task_center/data/repositories/task_center_repository_impl.dart';
import 'package:smart_cabinet/src/features/task_center/domain/entities/cabinet_task.dart';
import 'package:smart_cabinet/src/features/task_center/presentation/pages/task_execution_page.dart';

void main() {
  const account = OperatorAccount(
    id: 'operator-001',
    username: '100001',
    name: '市场监管操作员',
    organizationId: 'org-001',
    organizationName: '市市场监督管理局',
    verifiedFactors: {
      IdentityFactor.face,
      IdentityFactor.fingerprint,
      IdentityFactor.nfc,
    },
  );

  testWidgets('盘点按箱执行并在明确关箱后结算缺失与溢余', (tester) async {
    await _setTerminalSurface(tester);
    final guard = CabinetDoorGuard();
    final repository = TaskCenterRepositoryImpl(
      FakeTaskCenterDataSource.seeded(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: TaskExecutionPage(
          arguments: TaskExecutionArguments(
            account: account,
            taskId: 'TASK-INVENTORY-001',
            repository: repository,
            doorGuard: guard,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final codeInput = find.byKey(const ValueKey('inventory_code_input'));
    expect(codeInput, findsOneWidget);
    expect(tester.widget<TextField>(codeInput).obscureText, isTrue);

    await tester.enterText(codeInput, '000000');
    await tester.tap(find.byKey(const ValueKey('inventory_verify_code')));
    await _pumpAsyncWork(tester);
    var task = await repository.fetchTask(
      account: account,
      taskId: 'TASK-INVENTORY-001',
    );
    expect(task.currentStep?.type, TaskStepType.verifyInventoryCode);

    await tester.enterText(codeInput, '593826');
    await tester.tap(find.byKey(const ValueKey('inventory_verify_code')));
    await _pumpAsyncWork(tester);
    expect(find.byKey(const ValueKey('inventory_slot_grid')), findsOneWidget);

    final excludedSlot = tester.widget<InkWell>(
      find.byKey(const ValueKey('inventory_slot_A-07')),
    );
    expect(excludedSlot.onTap, isNull);

    expect(
      guard.requestOpen('A-01', operationId: 'EXTERNAL-TASK'),
      isA<CabinetDoorOpenGranted>(),
    );
    await tester.tap(find.byKey(const ValueKey('inventory_slot_A-05')));
    await _pumpAsyncWork(tester);
    expect(find.byKey(const ValueKey('inventory_slot_dialog')), findsNothing);
    expect(guard.activeDoorNo, 'A-01');
    expect(guard.markClosed('A-01', operationId: 'EXTERNAL-TASK'), isTrue);

    await tester.tap(find.byKey(const ValueKey('inventory_slot_A-05')));
    await _pumpDialogOpen(tester);
    expect(find.byKey(const ValueKey('inventory_slot_dialog')), findsOneWidget);
    expect(guard.activeDoorNo, 'A-05');

    await tester.pump(const Duration(seconds: 31));
    expect(guard.activeDoorNo, 'A-05');
    task = await repository.fetchTask(
      account: account,
      taskId: 'TASK-INVENTORY-001',
    );
    expect(
      task
          .inventoryItemsForDoor('A-05')
          .every((item) => item.inventoryResult == InventoryItemResult.pending),
      isTrue,
    );

    await tester.tap(
      find.byKey(const ValueKey('inventory_scan_expected_RFID-A05-0001')),
    );
    await _pumpAsyncWork(tester);
    task = await repository.fetchTask(
      account: account,
      taskId: 'TASK-INVENTORY-001',
    );
    expect(
      task.inventorySlotStatus('A-05'),
      InventorySlotStatus.partiallyChecked,
    );

    await tester.tap(find.byKey(const ValueKey('inventory_scan_surplus_demo')));
    await _pumpAsyncWork(tester);
    await tester.tap(find.byKey(const ValueKey('inventory_close_door')));
    await _pumpDialogClose(tester);

    expect(guard.allDoorsClosed, isTrue);
    task = await repository.fetchTask(
      account: account,
      taskId: 'TASK-INVENTORY-001',
    );
    expect(task.inventorySlotStatus('A-05'), InventorySlotStatus.abnormal);
    expect(
      task
          .inventoryItemsForDoor('A-05')
          .where((item) => item.inventoryResult == InventoryItemResult.missing),
      hasLength(1),
    );
    expect(
      task
          .inventoryItemsForDoor('A-05')
          .where((item) => item.inventoryResult == InventoryItemResult.surplus)
          .single
          .inventoryReturnStatus,
      InventoryReturnStatus.returned,
    );

    await tester.tap(find.byKey(const ValueKey('inventory_slot_A-05')));
    await _pumpDialogOpen(tester);
    expect(
      find.byKey(const ValueKey('inventory_completed_slot_dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('inventory_close_completed_detail')),
    );
    await _pumpDialogClose(tester);

    await tester.tap(find.byKey(const ValueKey('inventory_slot_A-06')));
    await _pumpDialogOpen(tester);
    await tester.tap(
      find.byKey(const ValueKey('inventory_scan_expected_RFID-A06-0001')),
    );
    await _pumpAsyncWork(tester);
    await tester.tap(find.byKey(const ValueKey('inventory_close_door')));
    await _pumpDialogClose(tester);

    expect(guard.allDoorsClosed, isTrue);
    task = await repository.fetchTask(
      account: account,
      taskId: 'TASK-INVENTORY-001',
    );
    expect(task.inventorySlotStatus('A-06'), InventorySlotStatus.completed);
    expect(task.status, CabinetTaskStatus.completed);
    expect(
      find.byKey(const ValueKey('task_execution_completed')),
      findsOneWidget,
    );
  });

  testWidgets('盘点结算保存前失败可安全返回并从待上报状态恢复', (tester) async {
    await _setTerminalSurface(tester);
    final guard = CabinetDoorGuard();
    final repository = TaskCenterRepositoryImpl(
      _FailInventorySettlementDataSource(
        FakeTaskCenterDataSource.seeded(),
        commitBeforeThrow: false,
      ),
    );
    await _pumpInventoryPage(
      tester,
      account: account,
      repository: repository,
      guard: guard,
    );
    await _verifyCodeAndOpenA05(tester);

    await tester.tap(find.byKey(const ValueKey('inventory_close_door')));
    await _pumpAsyncWork(tester);

    expect(guard.allDoorsClosed, isTrue);
    expect(
      find.byKey(const ValueKey('inventory_return_with_pending_report')),
      findsOneWidget,
    );
    var task = await repository.fetchTask(
      account: account,
      taskId: 'TASK-INVENTORY-001',
    );
    expect(task.pendingClosedDoorNo, 'A-05');
    expect(task.inventoryPlan?.activeDoorNo, 'A-05');

    await tester.tap(
      find.byKey(const ValueKey('inventory_return_with_pending_report')),
    );
    await _pumpDialogClose(tester);
    expect(find.byKey(const ValueKey('inventory_slot_dialog')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('inventory_slot_A-05')));
    await _pumpDialogOpen(tester);
    expect(guard.allDoorsClosed, isTrue);
    expect(find.text('重试盘点结算'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('inventory_close_door')));
    await _pumpDialogClose(tester);

    task = await repository.fetchTask(
      account: account,
      taskId: 'TASK-INVENTORY-001',
    );
    expect(task.pendingClosedDoorNo, isNull);
    expect(task.inventoryPlan?.completedDoorNos, contains('A-05'));
    expect(find.byKey(const ValueKey('inventory_slot_dialog')), findsNothing);
  });

  testWidgets('盘点结算已保存但响应丢失时对账后直接关闭弹窗', (tester) async {
    await _setTerminalSurface(tester);
    final guard = CabinetDoorGuard();
    final repository = TaskCenterRepositoryImpl(
      _FailInventorySettlementDataSource(
        FakeTaskCenterDataSource.seeded(),
        commitBeforeThrow: true,
      ),
    );
    await _pumpInventoryPage(
      tester,
      account: account,
      repository: repository,
      guard: guard,
    );
    await _verifyCodeAndOpenA05(tester);

    await tester.tap(find.byKey(const ValueKey('inventory_close_door')));
    await _pumpDialogClose(tester);

    expect(guard.allDoorsClosed, isTrue);
    expect(find.byKey(const ValueKey('inventory_slot_dialog')), findsNothing);
    final task = await repository.fetchTask(
      account: account,
      taskId: 'TASK-INVENTORY-001',
    );
    expect(task.pendingClosedDoorNo, isNull);
    expect(task.inventoryPlan?.completedDoorNos, contains('A-05'));
  });
}

/// 渲染盘点任务执行页。
Future<void> _pumpInventoryPage(
  WidgetTester tester, {
  required OperatorAccount account,
  required TaskCenterRepositoryImpl repository,
  required CabinetDoorGuard guard,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: TaskExecutionPage(
        arguments: TaskExecutionArguments(
          account: account,
          taskId: 'TASK-INVENTORY-001',
          repository: repository,
          doorGuard: guard,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 校验演示飞检码并打开 A-05 箱格。
Future<void> _verifyCodeAndOpenA05(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('inventory_code_input')),
    '593826',
  );
  await tester.tap(find.byKey(const ValueKey('inventory_verify_code')));
  await _pumpAsyncWork(tester);
  await tester.tap(find.byKey(const ValueKey('inventory_slot_A-05')));
  await _pumpDialogOpen(tester);
  expect(find.byKey(const ValueKey('inventory_slot_dialog')), findsOneWidget);
}

/// 将 Widget 测试窗口设为智能柜横屏尺寸。
Future<void> _setTerminalSurface(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 800);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

/// 推进同步完成的仓库操作与页面重建。
Future<void> _pumpAsyncWork(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pump();
}

/// 推进盘点明细弹窗的打开动画。
Future<void> _pumpDialogOpen(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

/// 推进盘点明细弹窗的关闭动画和任务完成回调。
Future<void> _pumpDialogClose(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

/// 首次结算 A-05 时模拟平台保存前失败或保存后响应丢失。
final class _FailInventorySettlementDataSource implements TaskCenterDataSource {
  /// 包装内存数据源并配置失败发生在提交前还是提交后。
  _FailInventorySettlementDataSource(
    this._delegate, {
    required this.commitBeforeThrow,
  });

  final FakeTaskCenterDataSource _delegate;
  final bool commitBeforeThrow;
  bool _failed = false;

  @override
  Future<List<CabinetTask>> fetchTasksByOrganization(String organizationId) =>
      _delegate.fetchTasksByOrganization(organizationId);

  @override
  Future<CabinetTask?> fetchTaskById(String taskId) =>
      _delegate.fetchTaskById(taskId);

  @override
  Future<InstitutionSlotBinding> resolveSlot({
    required String organizationId,
    String? preferredDoorNo,
  }) => _delegate.resolveSlot(
    organizationId: organizationId,
    preferredDoorNo: preferredDoorNo,
  );

  @override
  Future<void> saveTask(CabinetTask task) async {
    final settlesA05 =
        task.type == TaskType.inventory &&
        task.pendingClosedDoorNo == null &&
        (task.inventoryPlan?.completedDoorNos.contains('A-05') ?? false);
    if (!_failed && settlesA05) {
      _failed = true;
      if (commitBeforeThrow) {
        await _delegate.saveTask(task);
      }
      throw StateError('模拟盘点结算响应异常');
    }
    await _delegate.saveTask(task);
  }
}
