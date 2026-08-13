import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/app/routing/app_router.dart';
import 'package:smart_cabinet/src/app/shell/app_shell.dart';
import 'package:smart_cabinet/src/app/theme/app_theme.dart';
import 'package:smart_cabinet/src/core/device/cabinet_door_guard.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/task_center/data/datasources/fake_task_center_data_source.dart';
import 'package:smart_cabinet/src/features/task_center/data/repositories/task_center_repository_impl.dart';
import 'package:smart_cabinet/src/features/task_center/domain/entities/cabinet_task.dart';
import 'package:smart_cabinet/src/features/task_center/presentation/pages/task_center_page.dart';
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

  testWidgets('两份证件分别使用各自箱格并在全部完成后结束任务', (tester) async {
    await _setTerminalSurface(tester);
    final guard = CabinetDoorGuard();
    final repository = TaskCenterRepositoryImpl(
      FakeTaskCenterDataSource(
        tasks: const [
          CabinetTask(
            id: 'TASK-TEST-001',
            type: TaskType.storeEvidence,
            title: '盘点演示任务',
            organizationId: 'org-001',
            organizationName: '市市场监督管理局',
            items: [
              TaskItem(
                id: 'ITEM-001',
                documentCode: 'DOC-001',
                documentName: '演示证件',
                rfid: 'RFID-001',
                doorNo: 'A-01',
              ),
              TaskItem(
                id: 'ITEM-002',
                documentCode: 'DOC-002',
                documentName: '第二份演示证件',
                rfid: 'RFID-002',
                doorNo: 'A-02',
              ),
            ],
            steps: [
              TaskStep(
                type: TaskStepType.attachRfid,
                status: TaskStepStatus.completed,
              ),
              TaskStep(
                type: TaskStepType.captureFront,
                status: TaskStepStatus.completed,
              ),
              TaskStep(
                type: TaskStepType.captureBack,
                status: TaskStepStatus.completed,
              ),
              TaskStep(
                type: TaskStepType.runOcr,
                status: TaskStepStatus.completed,
              ),
              TaskStep(type: TaskStepType.assignSlot),
              TaskStep(type: TaskStepType.openDoor),
              TaskStep(type: TaskStepType.transferWithinDeadline),
              TaskStep(type: TaskStepType.closeDoorAndReport),
            ],
          ),
          CabinetTask(
            id: 'TASK-TEST-002',
            type: TaskType.storeEvidence,
            title: '剩余任务',
            organizationId: 'org-001',
            organizationName: '市市场监督管理局',
            items: [],
            steps: [
              TaskStep(type: TaskStepType.attachRfid),
              TaskStep(type: TaskStepType.captureFront),
              TaskStep(type: TaskStepType.captureBack),
              TaskStep(type: TaskStepType.runOcr),
              TaskStep(type: TaskStepType.assignSlot),
              TaskStep(type: TaskStepType.openDoor),
              TaskStep(type: TaskStepType.transferWithinDeadline),
              TaskStep(type: TaskStepType.closeDoorAndReport),
            ],
          ),
        ],
        slotBindings: const [
          InstitutionSlotBinding(
            cabinetId: 'CAB-A01',
            doorNo: 'A-01',
            organizationId: 'org-001',
            organizationName: '市市场监督管理局',
          ),
          InstitutionSlotBinding(
            cabinetId: 'CAB-A01',
            doorNo: 'A-02',
            organizationId: 'org-001',
            organizationName: '市市场监督管理局',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: TaskExecutionPage(
          arguments: TaskExecutionArguments(
            account: account,
            taskId: 'TASK-TEST-001',
            repository: repository,
            doorGuard: guard,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapStep(tester, TaskStepType.assignSlot);
    await _tapStep(tester, TaskStepType.openDoor);
    expect(guard.activeDoorNo, 'A-01');
    expect(
      find.byKey(const ValueKey('task_execution_door_countdown')),
      findsOneWidget,
    );

    await _tapStep(tester, TaskStepType.transferWithinDeadline);
    await _tapStep(tester, TaskStepType.closeDoorAndReport);

    expect(guard.allDoorsClosed, isTrue);
    final afterFirstItem = await repository.fetchTask(
      account: account,
      taskId: 'TASK-TEST-001',
    );
    expect(afterFirstItem.items.first.status, TaskItemStatus.completed);
    expect(afterFirstItem.items.last.status, TaskItemStatus.processing);
    expect(afterFirstItem.currentStep?.type, TaskStepType.attachRfid);
    expect(
      find.byKey(const ValueKey('task_execution_completed')),
      findsNothing,
    );

    await _tapStep(tester, TaskStepType.attachRfid);
    await _tapStep(tester, TaskStepType.captureFront);
    await _tapStep(tester, TaskStepType.captureBack);
    await _tapStep(tester, TaskStepType.runOcr);
    await _tapStep(tester, TaskStepType.assignSlot);
    await _tapStep(tester, TaskStepType.openDoor);
    expect(guard.activeDoorNo, 'A-02');
    await _tapStep(tester, TaskStepType.transferWithinDeadline);
    await _tapStep(tester, TaskStepType.closeDoorAndReport);

    expect(guard.allDoorsClosed, isTrue);
    expect(
      find.byKey(const ValueKey('task_execution_completed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('task_execution_return_center')),
      findsOneWidget,
    );
  });

  testWidgets('取件码不明文展示且错误码不能推进任务', (tester) async {
    await _setTerminalSurface(tester);
    final repository = TaskCenterRepositoryImpl(
      FakeTaskCenterDataSource(
        tasks: const [
          CabinetTask(
            id: 'TASK-PICKUP-001',
            type: TaskType.retrieveEvidence,
            title: '取证演示任务',
            organizationId: 'org-001',
            organizationName: '市市场监督管理局',
            pickupCode: '246810',
            items: [
              TaskItem(
                id: 'ITEM-PICKUP-001',
                documentCode: 'DOC-PICKUP-001',
                documentName: '取证证件',
                doorNo: 'A-01',
              ),
            ],
            steps: [
              TaskStep(type: TaskStepType.verifyPickupCode),
              TaskStep(type: TaskStepType.reviewPendingItems),
              TaskStep(type: TaskStepType.assignSlot),
              TaskStep(type: TaskStepType.openDoor),
              TaskStep(type: TaskStepType.scanRfid),
              TaskStep(type: TaskStepType.transferWithinDeadline),
              TaskStep(type: TaskStepType.closeDoorAndReport),
            ],
          ),
        ],
        slotBindings: const [],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: TaskExecutionPage(
          arguments: TaskExecutionArguments(
            account: account,
            taskId: 'TASK-PICKUP-001',
            repository: repository,
            doorGuard: CabinetDoorGuard(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('246810'), findsNothing);
    final input = find.byKey(
      const ValueKey('task_execution_pickup_code_input'),
    );
    expect(input, findsOneWidget);
    expect(tester.widget<TextField>(input).obscureText, isTrue);

    await _tapStep(tester, TaskStepType.verifyPickupCode);
    expect(find.textContaining('请输入取件码'), findsOneWidget);

    await tester.enterText(input, '000000');
    await _tapStep(tester, TaskStepType.verifyPickupCode);
    final rejectedTask = await repository.fetchTask(
      account: account,
      taskId: 'TASK-PICKUP-001',
    );
    expect(rejectedTask.currentStep?.type, TaskStepType.verifyPickupCode);
    expect(input, findsOneWidget);
    expect(find.textContaining('取件码错误，请重新输入'), findsOneWidget);

    await tester.enterText(input, '246810');
    await _tapStep(tester, TaskStepType.verifyPickupCode);
    final acceptedTask = await repository.fetchTask(
      account: account,
      taskId: 'TASK-PICKUP-001',
    );
    expect(acceptedTask.currentStep?.type, TaskStepType.reviewPendingItems);
    expect(input, findsNothing);
  });

  testWidgets('工作台右上角显示100秒倒计时且操作后重置', (tester) async {
    await _setTerminalSurface(tester);
    final observer = _HomePushObserver();
    final repository = TaskCenterRepositoryImpl(
      FakeTaskCenterDataSource.seeded(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        navigatorObservers: [observer],
        home: TaskCenterPage(
          arguments: TaskCenterArguments(
            account: account,
            repository: repository,
            doorGuard: CabinetDoorGuard(),
          ),
        ),
      ),
    );
    await tester.pump();

    final authenticationBadge = find.byType(FlowStatusBadge);
    final countdownBadge = find.byKey(
      const ValueKey('task_center_inactivity_countdown'),
    );
    expect(authenticationBadge, findsOneWidget);
    expect(countdownBadge, findsOneWidget);
    expect(find.text('100 秒'), findsOneWidget);
    expect(
      tester.getTopLeft(countdownBadge).dx,
      greaterThan(tester.getTopRight(authenticationBadge).dx),
    );

    await _pumpSeconds(tester, 35);
    expect(find.text('65 秒'), findsOneWidget);

    await tester.tap(find.text('当前可执行任务'));
    await tester.pump();
    expect(find.text('100 秒'), findsOneWidget);

    await _pumpSeconds(tester, 99);
    expect(observer.homePushCount, 1);
    expect(find.text('1 秒'), findsOneWidget);

    await _pumpSeconds(tester, 1);
    expect(observer.homePushCount, greaterThanOrEqualTo(2));
  });

  testWidgets('进入任务执行页后启用100秒倒计时且操作后重置', (tester) async {
    await _setTerminalSurface(tester);
    final observer = _HomePushObserver();
    final repository = TaskCenterRepositoryImpl(
      FakeTaskCenterDataSource.seeded(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        navigatorObservers: [observer],
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: TaskCenterPage(
          arguments: TaskCenterArguments(
            account: account,
            repository: repository,
            doorGuard: CabinetDoorGuard(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('task_center_open_storeEvidence')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TaskExecutionPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('task_execution_inactivity_countdown')),
      findsOneWidget,
    );
    expect(find.text('100 秒'), findsOneWidget);

    await _pumpSeconds(tester, 35);
    expect(find.text('65 秒'), findsOneWidget);

    await tester.tap(find.byType(FlowStatusBadge));
    await tester.pump();
    expect(find.text('100 秒'), findsOneWidget);

    await _pumpSeconds(tester, 99);
    expect(find.byType(TaskExecutionPage), findsOneWidget);
    expect(observer.homePushCount, 1);
    expect(find.text('1 秒'), findsOneWidget);

    await _pumpSeconds(tester, 1);
    await tester.pumpAndSettle();
    expect(find.byType(TaskExecutionPage), findsNothing);
    expect(observer.homePushCount, greaterThanOrEqualTo(2));
  });

  testWidgets('任务执行中柜门未关闭时不会强制退出', (tester) async {
    await _setTerminalSurface(tester);
    final observer = _HomePushObserver();
    final guard = CabinetDoorGuard();
    final repository = TaskCenterRepositoryImpl(
      FakeTaskCenterDataSource.seeded(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        navigatorObservers: [observer],
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: TaskCenterPage(
          arguments: TaskCenterArguments(
            account: account,
            repository: repository,
            doorGuard: guard,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('task_center_open_storeEvidence')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TaskExecutionPage), findsOneWidget);

    guard.requestOpen('A-01', operationId: 'EXECUTION-DOOR');
    expect(guard.activeDoorNo, 'A-01');

    await _pumpSeconds(tester, 102);
    expect(find.byType(TaskExecutionPage), findsOneWidget);
    expect(observer.homePushCount, 1);
    expect(find.text('100 秒'), findsOneWidget);

    expect(guard.markClosed('A-01', operationId: 'EXECUTION-DOOR'), isTrue);
    await _pumpSeconds(tester, 99);
    expect(find.byType(TaskExecutionPage), findsOneWidget);
    expect(observer.homePushCount, 1);

    await _pumpSeconds(tester, 1);
    await tester.pumpAndSettle();
    expect(find.byType(TaskExecutionPage), findsNothing);
    expect(observer.homePushCount, greaterThanOrEqualTo(2));
  });

  testWidgets('无操作倒计时等待柜门关闭后才退出', (tester) async {
    await _setTerminalSurface(tester);
    final guard = CabinetDoorGuard()
      ..requestOpen('A-01', operationId: 'EXTERNAL-TASK');
    final observer = _HomePushObserver();
    final repository = TaskCenterRepositoryImpl(
      FakeTaskCenterDataSource(tasks: [], slotBindings: []),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        navigatorObservers: [observer],
        home: TaskCenterPage(
          arguments: TaskCenterArguments(
            account: account,
            repository: repository,
            doorGuard: guard,
          ),
        ),
      ),
    );
    await tester.pump();

    await _pumpSeconds(tester, 12);
    expect(observer.homePushCount, 1);
    expect(find.text('等待全部柜门关闭后再退出登录'), findsOneWidget);

    expect(guard.markClosed('A-01', operationId: 'EXTERNAL-TASK'), isTrue);
    await _pumpSeconds(tester, 102);
    expect(observer.homePushCount, greaterThanOrEqualTo(2));
  });

  testWidgets('任务工作台销毁后无操作计时器不会继续导航', (tester) async {
    await _setTerminalSurface(tester);
    final observer = _HomePushObserver();
    final repository = TaskCenterRepositoryImpl(
      FakeTaskCenterDataSource(tasks: [], slotBindings: []),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        navigatorObservers: [observer],
        home: TaskCenterPage(
          arguments: TaskCenterArguments(
            account: account,
            repository: repository,
            doorGuard: CabinetDoorGuard(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await _pumpSeconds(tester, 102);

    expect(tester.takeException(), isNull);
    expect(observer.homePushCount, 1);
  });

  testWidgets('取证同箱多份保持单门开启并提示继续扫描', (tester) async {
    await _setTerminalSurface(tester);
    final guard = CabinetDoorGuard();
    final repository = TaskCenterRepositoryImpl(
      FakeTaskCenterDataSource(
        tasks: const [
          CabinetTask(
            id: 'TASK-SAME-SLOT-WIDGET',
            type: TaskType.retrieveEvidence,
            title: '同箱多份取证任务',
            organizationId: 'org-001',
            organizationName: '市市场监督管理局',
            items: [
              TaskItem(
                id: 'ITEM-SAME-SLOT-001',
                documentCode: 'DOC-SAME-SLOT-001',
                documentName: '同箱第一份证件',
                rfid: 'RFID-SAME-SLOT-001',
                doorNo: 'A-01',
              ),
              TaskItem(
                id: 'ITEM-SAME-SLOT-002',
                documentCode: 'DOC-SAME-SLOT-002',
                documentName: '同箱第二份证件',
                rfid: 'RFID-SAME-SLOT-002',
                doorNo: 'A-01',
              ),
            ],
            steps: [
              TaskStep(
                type: TaskStepType.verifyPickupCode,
                status: TaskStepStatus.completed,
              ),
              TaskStep(
                type: TaskStepType.reviewPendingItems,
                status: TaskStepStatus.completed,
              ),
              TaskStep(type: TaskStepType.assignSlot),
              TaskStep(type: TaskStepType.openDoor),
              TaskStep(type: TaskStepType.scanRfid),
              TaskStep(type: TaskStepType.transferWithinDeadline),
              TaskStep(type: TaskStepType.closeDoorAndReport),
            ],
          ),
        ],
        slotBindings: const [
          InstitutionSlotBinding(
            cabinetId: 'CAB-A01',
            doorNo: 'A-01',
            organizationId: 'org-001',
            organizationName: '市市场监督管理局',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: TaskExecutionPage(
          arguments: TaskExecutionArguments(
            account: account,
            taskId: 'TASK-SAME-SLOT-WIDGET',
            repository: repository,
            doorGuard: guard,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('task_item_select_ITEM-SAME-SLOT-002')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final selectedTask = await repository.fetchTask(
      account: account,
      taskId: 'TASK-SAME-SLOT-WIDGET',
    );
    expect(selectedTask.currentItem?.id, 'ITEM-SAME-SLOT-002');

    await _tapStep(tester, TaskStepType.assignSlot);
    await _tapStep(tester, TaskStepType.openDoor);
    expect(guard.activeDoorNo, 'A-01');
    expect(
      find.byKey(const ValueKey('task_execution_same_slot_remaining')),
      findsOneWidget,
    );
    expect(find.textContaining('还有 2 份待取'), findsOneWidget);

    await _tapStep(tester, TaskStepType.scanRfid);
    await _tapStep(tester, TaskStepType.transferWithinDeadline);
    expect(guard.activeDoorNo, 'A-01');
    expect(
      find.byKey(const ValueKey('task_step_action_scanRfid')),
      findsOneWidget,
    );
    expect(find.textContaining('还有 1 份待取'), findsOneWidget);

    await _tapStep(tester, TaskStepType.scanRfid);
    await _tapStep(tester, TaskStepType.transferWithinDeadline);
    expect(guard.activeDoorNo, 'A-01');
    await _tapStep(tester, TaskStepType.closeDoorAndReport);

    expect(guard.allDoorsClosed, isTrue);
    expect(
      find.byKey(const ValueKey('task_execution_completed')),
      findsOneWidget,
    );
  });

  testWidgets('普通任务开门状态写入失败时必须确认关门后恢复', (tester) async {
    await _setTerminalSurface(tester);
    final guard = CabinetDoorGuard();
    final dataSource = _FailOnceAfterDoorOpenedDataSource(
      FakeTaskCenterDataSource(
        tasks: const [
          CabinetTask(
            id: 'TASK-DOOR-RECOVERY',
            type: TaskType.storeEvidence,
            title: '开门失败恢复任务',
            organizationId: 'org-001',
            organizationName: '市市场监督管理局',
            items: [
              TaskItem(
                id: 'ITEM-DOOR-RECOVERY',
                documentCode: 'DOC-DOOR-RECOVERY',
                documentName: '恢复测试证件',
                doorNo: 'A-01',
              ),
            ],
            steps: [
              TaskStep(
                type: TaskStepType.attachRfid,
                status: TaskStepStatus.completed,
              ),
              TaskStep(
                type: TaskStepType.captureFront,
                status: TaskStepStatus.completed,
              ),
              TaskStep(
                type: TaskStepType.captureBack,
                status: TaskStepStatus.completed,
              ),
              TaskStep(
                type: TaskStepType.runOcr,
                status: TaskStepStatus.completed,
              ),
              TaskStep(type: TaskStepType.assignSlot),
              TaskStep(type: TaskStepType.openDoor),
              TaskStep(type: TaskStepType.transferWithinDeadline),
              TaskStep(type: TaskStepType.closeDoorAndReport),
            ],
          ),
        ],
        slotBindings: const [
          InstitutionSlotBinding(
            cabinetId: 'CAB-A01',
            doorNo: 'A-01',
            organizationId: 'org-001',
            organizationName: '市市场监督管理局',
          ),
        ],
      ),
    );
    final repository = TaskCenterRepositoryImpl(dataSource);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: TaskExecutionPage(
          arguments: TaskExecutionArguments(
            account: account,
            taskId: 'TASK-DOOR-RECOVERY',
            repository: repository,
            doorGuard: guard,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapStep(tester, TaskStepType.assignSlot);
    await _tapStep(tester, TaskStepType.openDoor);
    expect(guard.activeDoorNo, 'A-01');
    expect(guard.activeOperationId, startsWith('TASK-DOOR-RECOVERY:'));
    expect(
      find.byKey(const ValueKey('task_execution_recover_door')),
      findsOneWidget,
    );
    final blockedOpenAction = find.byKey(
      const ValueKey('task_step_action_openDoor'),
    );
    expect(blockedOpenAction, findsOneWidget);
    expect(tester.widget<ElevatedButton>(blockedOpenAction).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('task_execution_recover_door')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(guard.allDoorsClosed, isTrue);
    expect(guard.hasActiveOperation, isFalse);
    expect(
      find.byKey(const ValueKey('task_execution_recover_door')),
      findsNothing,
    );
    final recoveredOpenAction = find.byKey(
      const ValueKey('task_step_action_openDoor'),
    );
    expect(recoveredOpenAction, findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(recoveredOpenAction).onPressed,
      isNotNull,
    );
    final reloaded = await repository.fetchTask(
      account: account,
      taskId: 'TASK-DOOR-RECOVERY',
    );
    expect(reloaded.currentStep?.type, TaskStepType.openDoor);
  });

  testWidgets('平台已提交开门但响应丢失时对账后保持本次开门流程', (tester) async {
    await _setTerminalSurface(tester);
    final guard = CabinetDoorGuard();
    final repository = TaskCenterRepositoryImpl(
      _buildDoorResponseFailureDataSource(commitBeforeThrow: true),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: TaskExecutionPage(
          arguments: TaskExecutionArguments(
            account: account,
            taskId: 'TASK-DOOR-RECOVERY',
            repository: repository,
            doorGuard: guard,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapStep(tester, TaskStepType.assignSlot);
    await _tapStep(tester, TaskStepType.openDoor);

    expect(guard.activeDoorNo, 'A-01');
    expect(guard.activeOperationId, startsWith('TASK-DOOR-RECOVERY:'));
    expect(
      find.byKey(const ValueKey('task_execution_recover_door')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('task_step_action_transferWithinDeadline')),
      findsOneWidget,
    );
    final reconciled = await repository.fetchTask(
      account: account,
      taskId: 'TASK-DOOR-RECOVERY',
    );
    expect(reconciled.currentStep?.type, TaskStepType.transferWithinDeadline);
  });

  testWidgets('关门上报保存前失败后重建页面可从待上报状态继续', (tester) async {
    await _setTerminalSurface(tester);
    final guard = CabinetDoorGuard();
    final repository = TaskCenterRepositoryImpl(
      _buildDoorCloseFailureDataSource(commitBeforeThrow: false),
    );

    Future<void> pumpExecutionPage() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TaskExecutionPage(
            arguments: TaskExecutionArguments(
              account: account,
              taskId: 'TASK-DOOR-CLOSE-FAILURE',
              repository: repository,
              doorGuard: guard,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpExecutionPage();
    await _tapStep(tester, TaskStepType.assignSlot);
    await _tapStep(tester, TaskStepType.openDoor);
    await _tapStep(tester, TaskStepType.transferWithinDeadline);
    await _tapStep(tester, TaskStepType.closeDoorAndReport);

    expect(guard.allDoorsClosed, isTrue);
    var task = await repository.fetchTask(
      account: account,
      taskId: 'TASK-DOOR-CLOSE-FAILURE',
    );
    expect(task.pendingClosedDoorNo, 'A-01');
    expect(task.currentStep?.type, TaskStepType.closeDoorAndReport);

    await pumpExecutionPage();
    final retryClose = find.byKey(
      const ValueKey('task_step_action_closeDoorAndReport'),
    );
    expect(retryClose, findsOneWidget);
    expect(tester.widget<ElevatedButton>(retryClose).onPressed, isNotNull);
    await _tapStep(tester, TaskStepType.closeDoorAndReport);

    task = await repository.fetchTask(
      account: account,
      taskId: 'TASK-DOOR-CLOSE-FAILURE',
    );
    expect(task.pendingClosedDoorNo, isNull);
    expect(task.status, CabinetTaskStatus.completed);
    expect(
      find.byKey(const ValueKey('task_execution_completed')),
      findsOneWidget,
    );
  });

  testWidgets('关门上报已保存但响应丢失时自动对账并完成任务', (tester) async {
    await _setTerminalSurface(tester);
    final guard = CabinetDoorGuard();
    final repository = TaskCenterRepositoryImpl(
      _buildDoorCloseFailureDataSource(commitBeforeThrow: true),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: TaskExecutionPage(
          arguments: TaskExecutionArguments(
            account: account,
            taskId: 'TASK-DOOR-CLOSE-FAILURE',
            repository: repository,
            doorGuard: guard,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tapStep(tester, TaskStepType.assignSlot);
    await _tapStep(tester, TaskStepType.openDoor);
    await _tapStep(tester, TaskStepType.transferWithinDeadline);
    await _tapStep(tester, TaskStepType.closeDoorAndReport);

    expect(guard.allDoorsClosed, isTrue);
    final task = await repository.fetchTask(
      account: account,
      taskId: 'TASK-DOOR-CLOSE-FAILURE',
    );
    expect(task.pendingClosedDoorNo, isNull);
    expect(task.status, CabinetTaskStatus.completed);
    expect(
      find.byKey(const ValueKey('task_execution_completed')),
      findsOneWidget,
    );
  });

  testWidgets('已有柜门操作时任务工作台拒绝进入另一任务', (tester) async {
    await _setTerminalSurface(tester);
    final guard = CabinetDoorGuard()
      ..requestOpen('A-01', operationId: 'EXTERNAL-TASK');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: TaskCenterPage(
          arguments: TaskCenterArguments(
            account: account,
            repository: TaskCenterRepositoryImpl(
              FakeTaskCenterDataSource.seeded(),
            ),
            doorGuard: guard,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('task_center_open_storeEvidence')),
    );
    await tester.pump();

    expect(find.byType(TaskCenterPage), findsOneWidget);
    expect(find.byType(TaskExecutionPage), findsNothing);
    expect(find.textContaining('尚未完成'), findsOneWidget);
  });
}

/// 将 Widget 测试视口设置为柜机横屏尺寸。
Future<void> _setTerminalSurface(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 800);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

/// 点击当前步骤按钮并推进模拟异步操作。
Future<void> _tapStep(WidgetTester tester, TaskStepType type) async {
  final finder = find.byKey(ValueKey('task_step_action_${type.name}'));
  expect(finder, findsOneWidget);
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 220));
  await tester.pump();
}

/// 逐秒推进测试时钟，确保周期 Timer 的每一拍都会执行。
Future<void> _pumpSeconds(WidgetTester tester, int seconds) async {
  for (var index = 0; index < seconds; index += 1) {
    await tester.pump(const Duration(seconds: 1));
  }
}

/// 记录首页命名路由被压入的次数。
final class _HomePushObserver extends NavigatorObserver {
  int homePushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name == Navigator.defaultRouteName) {
      homePushCount += 1;
    }
  }
}

/// 首次保存“柜门已打开”结果时模拟平台写入失败的数据源。
final class _FailOnceAfterDoorOpenedDataSource implements TaskCenterDataSource {
  /// 包装测试内存数据源。
  _FailOnceAfterDoorOpenedDataSource(
    this._delegate, {
    this.commitBeforeThrow = false,
  });

  final FakeTaskCenterDataSource _delegate;

  /// 抛出响应异常前是否已经把任务写入平台状态。
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
    if (!_failed &&
        task.id == 'TASK-DOOR-RECOVERY' &&
        task.currentStep?.type == TaskStepType.transferWithinDeadline) {
      _failed = true;
      if (commitBeforeThrow) {
        await _delegate.saveTask(task);
      }
      throw StateError('模拟平台写入失败');
    }
    await _delegate.saveTask(task);
  }
}

/// 创建可模拟开门响应在提交前或提交后失败的数据源。
TaskCenterDataSource _buildDoorResponseFailureDataSource({
  required bool commitBeforeThrow,
}) {
  return _FailOnceAfterDoorOpenedDataSource(
    FakeTaskCenterDataSource(
      tasks: const [
        CabinetTask(
          id: 'TASK-DOOR-RECOVERY',
          type: TaskType.storeEvidence,
          title: '开门响应异常任务',
          organizationId: 'org-001',
          organizationName: '市市场监督管理局',
          items: [
            TaskItem(
              id: 'ITEM-DOOR-RECOVERY',
              documentCode: 'DOC-DOOR-RECOVERY',
              documentName: '恢复测试证件',
              doorNo: 'A-01',
            ),
          ],
          steps: [
            TaskStep(
              type: TaskStepType.attachRfid,
              status: TaskStepStatus.completed,
            ),
            TaskStep(
              type: TaskStepType.captureFront,
              status: TaskStepStatus.completed,
            ),
            TaskStep(
              type: TaskStepType.captureBack,
              status: TaskStepStatus.completed,
            ),
            TaskStep(
              type: TaskStepType.runOcr,
              status: TaskStepStatus.completed,
            ),
            TaskStep(type: TaskStepType.assignSlot),
            TaskStep(type: TaskStepType.openDoor),
            TaskStep(type: TaskStepType.transferWithinDeadline),
            TaskStep(type: TaskStepType.closeDoorAndReport),
          ],
        ),
      ],
      slotBindings: const [
        InstitutionSlotBinding(
          cabinetId: 'CAB-A01',
          doorNo: 'A-01',
          organizationId: 'org-001',
          organizationName: '市市场监督管理局',
        ),
      ],
    ),
    commitBeforeThrow: commitBeforeThrow,
  );
}

/// 创建首次关门上报在提交前或提交后抛出响应异常的数据源。
TaskCenterDataSource _buildDoorCloseFailureDataSource({
  required bool commitBeforeThrow,
}) {
  return _FailOnceAfterDoorClosedDataSource(
    FakeTaskCenterDataSource(
      tasks: const [
        CabinetTask(
          id: 'TASK-DOOR-CLOSE-FAILURE',
          type: TaskType.storeEvidence,
          title: '关门上报异常任务',
          organizationId: 'org-001',
          organizationName: '市市场监督管理局',
          items: [
            TaskItem(
              id: 'ITEM-DOOR-CLOSE-FAILURE',
              documentCode: 'DOC-DOOR-CLOSE-FAILURE',
              documentName: '关门恢复测试证件',
              doorNo: 'A-01',
            ),
          ],
          steps: [
            TaskStep(
              type: TaskStepType.attachRfid,
              status: TaskStepStatus.completed,
            ),
            TaskStep(
              type: TaskStepType.captureFront,
              status: TaskStepStatus.completed,
            ),
            TaskStep(
              type: TaskStepType.captureBack,
              status: TaskStepStatus.completed,
            ),
            TaskStep(
              type: TaskStepType.runOcr,
              status: TaskStepStatus.completed,
            ),
            TaskStep(type: TaskStepType.assignSlot),
            TaskStep(type: TaskStepType.openDoor),
            TaskStep(type: TaskStepType.transferWithinDeadline),
            TaskStep(type: TaskStepType.closeDoorAndReport),
          ],
        ),
      ],
      slotBindings: const [
        InstitutionSlotBinding(
          cabinetId: 'CAB-A01',
          doorNo: 'A-01',
          organizationId: 'org-001',
          organizationName: '市市场监督管理局',
        ),
      ],
    ),
    commitBeforeThrow: commitBeforeThrow,
  );
}

/// 首次普通任务关门结算时模拟保存前失败或保存后响应丢失。
final class _FailOnceAfterDoorClosedDataSource implements TaskCenterDataSource {
  /// 包装内存数据源并配置异常发生在提交前还是提交后。
  _FailOnceAfterDoorClosedDataSource(
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
    final settlesDoor =
        task.id == 'TASK-DOOR-CLOSE-FAILURE' &&
        task.status == CabinetTaskStatus.inProgress &&
        task.pendingClosedDoorNo == null &&
        task.currentStep == null;
    if (!_failed && settlesDoor) {
      _failed = true;
      if (commitBeforeThrow) {
        await _delegate.saveTask(task);
      }
      throw StateError('模拟关门上报响应异常');
    }
    await _delegate.saveTask(task);
  }
}
