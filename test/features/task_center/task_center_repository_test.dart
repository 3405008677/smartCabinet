import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/task_center/data/datasources/fake_task_center_data_source.dart';
import 'package:smart_cabinet/src/features/task_center/data/repositories/task_center_repository_impl.dart';
import 'package:smart_cabinet/src/features/task_center/domain/entities/cabinet_task.dart';
import 'package:smart_cabinet/src/features/task_center/domain/repositories/task_center_repository.dart';

void main() {
  const orgOneAccount = OperatorAccount(
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
  const orgTwoAccount = OperatorAccount(
    id: 'operator-002',
    username: '100002',
    name: '公安操作员',
    organizationId: 'org-002',
    organizationName: '市公安局',
    verifiedFactors: {
      IdentityFactor.face,
      IdentityFactor.fingerprint,
      IdentityFactor.nfc,
    },
  );
  const unverifiedAccount = OperatorAccount(
    id: 'operator-unverified',
    username: '100099',
    name: '未完成认证操作员',
    organizationId: 'org-001',
    organizationName: '市市场监督管理局',
    verifiedFactors: {IdentityFactor.face, IdentityFactor.fingerprint},
  );

  late TaskCenterRepository repository;

  setUp(() {
    repository = TaskCenterRepositoryImpl(FakeTaskCenterDataSource.seeded());
  });

  test('任务列表严格按操作员机构过滤', () async {
    final orgOneTasks = await repository.fetchTasks(orgOneAccount);
    final orgTwoTasks = await repository.fetchTasks(orgTwoAccount);

    expect(orgOneTasks, hasLength(5));
    expect(
      orgOneTasks.map((task) => task.type).toSet(),
      TaskType.values.toSet(),
    );
    expect(
      orgOneTasks.every((task) => task.organizationId == 'org-001'),
      isTrue,
    );
    expect(orgTwoTasks, hasLength(1));
    expect(orgTwoTasks.single.organizationId, 'org-002');
  });

  test('存证取证借证还证和盘点保持各自步骤顺序', () async {
    final tasks = await repository.fetchTasks(orgOneAccount);
    final stepsByType = {
      for (final task in tasks)
        task.type: task.steps.map((step) => step.type).toList(),
    };

    expect(stepsByType[TaskType.storeEvidence], const [
      TaskStepType.attachRfid,
      TaskStepType.captureFront,
      TaskStepType.captureBack,
      TaskStepType.runOcr,
      TaskStepType.assignSlot,
      TaskStepType.openDoor,
      TaskStepType.transferWithinDeadline,
      TaskStepType.closeDoorAndReport,
    ]);
    expect(stepsByType[TaskType.retrieveEvidence], const [
      TaskStepType.verifyPickupCode,
      TaskStepType.reviewPendingItems,
      TaskStepType.assignSlot,
      TaskStepType.openDoor,
      TaskStepType.scanRfid,
      TaskStepType.transferWithinDeadline,
      TaskStepType.closeDoorAndReport,
    ]);
    expect(
      stepsByType[TaskType.borrowEvidence],
      stepsByType[TaskType.retrieveEvidence],
    );
    expect(stepsByType[TaskType.returnEvidence], const [
      TaskStepType.reviewPendingItems,
      TaskStepType.scanRfid,
      TaskStepType.captureFront,
      TaskStepType.captureBack,
      TaskStepType.runOcr,
      TaskStepType.assignSlot,
      TaskStepType.openDoor,
      TaskStepType.transferWithinDeadline,
      TaskStepType.closeDoorAndReport,
    ]);
    expect(stepsByType[TaskType.inventory], const [
      TaskStepType.verifyInventoryCode,
      TaskStepType.inventoryBySlot,
    ]);
  });

  test('平台返回缺步或乱序任务时仓库拒绝加载', () async {
    final malformedRepository = TaskCenterRepositoryImpl(
      FakeTaskCenterDataSource(
        tasks: const [
          CabinetTask(
            id: 'TASK-MALFORMED-001',
            type: TaskType.storeEvidence,
            title: '缺少固定步骤的异常任务',
            organizationId: 'org-001',
            organizationName: '市市场监督管理局',
            items: [],
            steps: [TaskStep(type: TaskStepType.assignSlot)],
          ),
        ],
        slotBindings: const [],
      ),
    );

    await expectLater(
      malformedRepository.fetchTasks(orgOneAccount),
      throwsA(isA<CabinetTaskWorkflowException>()),
    );
  });

  test('所有仓库业务入口都拒绝缺少任一身份因子的账号', () async {
    final attempts = <Future<Object?> Function()>[
      () => repository.fetchTasks(unverifiedAccount),
      () => repository.fetchTask(
        account: unverifiedAccount,
        taskId: 'TASK-STORE-001',
      ),
      () => repository.assignSlot(
        account: unverifiedAccount,
        taskId: 'TASK-STORE-001',
      ),
      () => repository.verifyPickupCode(
        account: unverifiedAccount,
        taskId: 'TASK-RETRIEVE-001',
        pickupCode: '82640135',
      ),
      () => repository.selectTaskItem(
        account: unverifiedAccount,
        taskId: 'TASK-RETRIEVE-001',
        itemId: 'TASK-RETRIEVE-001-ITEM-01',
      ),
      () => repository.verifyInventoryCode(
        account: unverifiedAccount,
        taskId: 'TASK-INVENTORY-001',
        inspectionCode: '593826',
      ),
      () => repository.validateDoorOpen(
        account: unverifiedAccount,
        taskId: 'TASK-STORE-001',
        doorNo: 'A-01',
      ),
      () => repository.confirmDoorOpened(
        account: unverifiedAccount,
        taskId: 'TASK-STORE-001',
        doorNo: 'A-01',
      ),
      () => repository.recoverDoorAfterOpenFailure(
        account: unverifiedAccount,
        taskId: 'TASK-STORE-001',
        doorNo: 'A-01',
      ),
      () => repository.recordDoorClosedPendingReport(
        account: unverifiedAccount,
        taskId: 'TASK-STORE-001',
        doorNo: 'A-01',
      ),
      () => repository.confirmDoorClosedAndReport(
        account: unverifiedAccount,
        taskId: 'TASK-STORE-001',
        doorNo: 'A-01',
      ),
      () => repository.validateInventoryDoorOpen(
        account: unverifiedAccount,
        taskId: 'TASK-INVENTORY-001',
        doorNo: 'A-05',
      ),
      () => repository.startInventoryDoor(
        account: unverifiedAccount,
        taskId: 'TASK-INVENTORY-001',
        doorNo: 'A-05',
      ),
      () => repository.scanInventoryRfid(
        account: unverifiedAccount,
        taskId: 'TASK-INVENTORY-001',
        doorNo: 'A-05',
        rfid: 'RFID-A05-0001',
      ),
      () => repository.completeInventoryDoor(
        account: unverifiedAccount,
        taskId: 'TASK-INVENTORY-001',
        doorNo: 'A-05',
      ),
      () => repository.completeStep(
        account: unverifiedAccount,
        taskId: 'TASK-STORE-001',
        stepType: TaskStepType.attachRfid,
      ),
      () => repository.completeTask(
        account: unverifiedAccount,
        taskId: 'TASK-STORE-001',
      ),
    ];

    for (final attempt in attempts) {
      await expectLater(
        attempt(),
        throwsA(
          isA<OperatorFactorVerificationException>()
              .having((error) => error.requiredFactorCount, '要求因子数', 3)
              .having((error) => error.verifiedFactors, '已认证因子', {
                IdentityFactor.face,
                IdentityFactor.fingerprint,
              }),
        ),
      );
    }
  });

  test('操作员不能读取其他机构任务', () async {
    await expectLater(
      repository.fetchTask(account: orgOneAccount, taskId: 'TASK-ORG2-001'),
      throwsA(isA<CabinetTaskOrganizationException>()),
    );
  });

  test('平台分箱只能在当前步骤执行且拒绝其他机构绑定的柜门', () async {
    await expectLater(
      repository.assignSlot(
        account: orgOneAccount,
        taskId: 'TASK-STORE-001',
        preferredDoorNo: 'A-01',
      ),
      throwsA(
        isA<CabinetTaskStepOrderException>()
            .having(
              (error) => error.expected,
              'expected',
              TaskStepType.attachRfid,
            )
            .having((error) => error.actual, 'actual', TaskStepType.assignSlot),
      ),
    );
    final slotConflictRepository = _buildSlotConflictRepository();
    await expectLater(
      slotConflictRepository.assignSlot(
        account: orgOneAccount,
        taskId: 'TASK-SLOT-CONFLICT',
        preferredDoorNo: 'B-01',
      ),
      throwsA(
        isA<InstitutionSlotConflictException>()
            .having((error) => error.doorNo, 'doorNo', 'B-01')
            .having(
              (error) => error.requestedOrganizationId,
              'requestedOrganizationId',
              'org-001',
            )
            .having(
              (error) => error.boundOrganizationId,
              'boundOrganizationId',
              'org-002',
            ),
      ),
    );
  });

  test('任务步骤只能按定义顺序推进', () async {
    final updated = await repository.completeStep(
      account: orgOneAccount,
      taskId: 'TASK-STORE-001',
      stepType: TaskStepType.attachRfid,
    );

    expect(updated.completedStepCount, 1);
    expect(updated.currentStep?.type, TaskStepType.captureFront);
    await expectLater(
      repository.completeStep(
        account: orgOneAccount,
        taskId: 'TASK-STORE-001',
        stepType: TaskStepType.openDoor,
      ),
      throwsA(isA<CabinetTaskStepOrderException>()),
    );
  });

  test('错误取件码不推进步骤，正确取件码原子完成校验步骤', () async {
    await expectLater(
      repository.verifyPickupCode(
        account: orgOneAccount,
        taskId: 'TASK-RETRIEVE-001',
        pickupCode: '   ',
      ),
      throwsA(
        isA<PickupCodeVerificationException>().having(
          (error) => error.reason,
          'reason',
          PickupCodeFailureReason.empty,
        ),
      ),
    );
    await expectLater(
      repository.verifyPickupCode(
        account: orgOneAccount,
        taskId: 'TASK-RETRIEVE-001',
        pickupCode: '00000000',
      ),
      throwsA(
        isA<PickupCodeVerificationException>().having(
          (error) => error.reason,
          'reason',
          PickupCodeFailureReason.incorrect,
        ),
      ),
    );

    var task = await repository.fetchTask(
      account: orgOneAccount,
      taskId: 'TASK-RETRIEVE-001',
    );
    expect(task.completedStepCount, 0);
    expect(task.currentStep?.type, TaskStepType.verifyPickupCode);

    await expectLater(
      repository.completeStep(
        account: orgOneAccount,
        taskId: 'TASK-RETRIEVE-001',
        stepType: TaskStepType.verifyPickupCode,
      ),
      throwsA(
        isA<PickupCodeVerificationException>().having(
          (error) => error.reason,
          'reason',
          PickupCodeFailureReason.dedicatedEntryRequired,
        ),
      ),
    );

    task = await repository.verifyPickupCode(
      account: orgOneAccount,
      taskId: 'TASK-RETRIEVE-001',
      pickupCode: '82640135',
    );
    expect(task.completedStepCount, 1);
    expect(task.currentStep?.type, TaskStepType.reviewPendingItems);
    expect(task.currentItem?.status, TaskItemStatus.processing);
  });

  test('开门前同时复核任务绑定和当前证件门号', () async {
    await expectLater(
      repository.validateDoorOpen(
        account: orgOneAccount,
        taskId: 'TASK-STORE-001',
        doorNo: 'A-01',
      ),
      throwsA(
        isA<CabinetTaskDoorValidationException>()
            .having(
              (error) => error.failure,
              'failure',
              CabinetTaskDoorValidationFailure.stepNotReady,
            )
            .having(
              (error) => error.currentStep,
              'currentStep',
              TaskStepType.attachRfid,
            ),
      ),
    );
    await _advanceStoreToAssignSlot(
      repository: repository,
      account: orgOneAccount,
      taskId: 'TASK-STORE-001',
    );
    await expectLater(
      repository.completeStep(
        account: orgOneAccount,
        taskId: 'TASK-STORE-001',
        stepType: TaskStepType.assignSlot,
      ),
      throwsA(
        isA<CabinetTaskDoorValidationException>().having(
          (error) => error.failure,
          'failure',
          CabinetTaskDoorValidationFailure.slotBindingMissing,
        ),
      ),
    );
    await repository.assignSlot(
      account: orgOneAccount,
      taskId: 'TASK-STORE-001',
      preferredDoorNo: 'A-01',
    );
    await repository.completeStep(
      account: orgOneAccount,
      taskId: 'TASK-STORE-001',
      stepType: TaskStepType.assignSlot,
    );

    await expectLater(
      repository.validateDoorOpen(
        account: orgOneAccount,
        taskId: 'TASK-STORE-001',
        doorNo: 'A-02',
      ),
      throwsA(
        isA<CabinetTaskDoorValidationException>()
            .having(
              (error) => error.failure,
              'failure',
              CabinetTaskDoorValidationFailure.itemDoorMismatch,
            )
            .having((error) => error.expectedDoorNo, 'expectedDoorNo', 'A-01'),
      ),
    );

    final binding = await repository.validateDoorOpen(
      account: orgOneAccount,
      taskId: 'TASK-STORE-001',
      doorNo: 'A-01',
    );
    expect(binding.organizationId, orgOneAccount.organizationId);
    expect(binding.doorNo, 'A-01');

    final opened = await repository.confirmDoorOpened(
      account: orgOneAccount,
      taskId: 'TASK-STORE-001',
      doorNo: 'A-01',
    );
    expect(opened.currentStep?.type, TaskStepType.transferWithinDeadline);
  });

  test('普通任务分箱后权威柜体绑定变化时拒绝开门和推进', () async {
    final dataSource = _MutableInventorySlotDataSource(
      FakeTaskCenterDataSource.seeded(),
    );
    final bindingRepository = TaskCenterRepositoryImpl(dataSource);
    await _advanceStoreToAssignSlot(
      repository: bindingRepository,
      account: orgOneAccount,
      taskId: 'TASK-STORE-001',
    );
    await bindingRepository.assignSlot(
      account: orgOneAccount,
      taskId: 'TASK-STORE-001',
      preferredDoorNo: 'A-01',
    );
    await bindingRepository.completeStep(
      account: orgOneAccount,
      taskId: 'TASK-STORE-001',
      stepType: TaskStepType.assignSlot,
    );
    dataSource.a01BindingChanged = true;

    for (final attempt in <Future<Object?> Function()>[
      () => bindingRepository.validateDoorOpen(
        account: orgOneAccount,
        taskId: 'TASK-STORE-001',
        doorNo: 'A-01',
      ),
      () => bindingRepository.confirmDoorOpened(
        account: orgOneAccount,
        taskId: 'TASK-STORE-001',
        doorNo: 'A-01',
      ),
    ]) {
      await expectLater(
        attempt(),
        throwsA(
          isA<CabinetTaskDoorValidationException>().having(
            (error) => error.failure,
            'failure',
            CabinetTaskDoorValidationFailure.slotBindingChanged,
          ),
        ),
      );
    }
    final task = await bindingRepository.fetchTask(
      account: orgOneAccount,
      taskId: 'TASK-STORE-001',
    );
    expect(task.currentStep?.type, TaskStepType.openDoor);
  });

  test('开门结果已提交但需要人工关门时可安全回退并重新开门', () async {
    await _advanceStoreToAssignSlot(
      repository: repository,
      account: orgOneAccount,
      taskId: 'TASK-STORE-001',
    );
    await repository.assignSlot(
      account: orgOneAccount,
      taskId: 'TASK-STORE-001',
      preferredDoorNo: 'A-01',
    );
    await repository.completeStep(
      account: orgOneAccount,
      taskId: 'TASK-STORE-001',
      stepType: TaskStepType.assignSlot,
    );
    await repository.confirmDoorOpened(
      account: orgOneAccount,
      taskId: 'TASK-STORE-001',
      doorNo: 'A-01',
    );

    var task = await repository.recoverDoorAfterOpenFailure(
      account: orgOneAccount,
      taskId: 'TASK-STORE-001',
      doorNo: 'A-01',
    );
    expect(task.currentStep?.type, TaskStepType.openDoor);
    expect(task.slotBinding?.doorNo, 'A-01');

    task = await repository.confirmDoorOpened(
      account: orgOneAccount,
      taskId: 'TASK-STORE-001',
      doorNo: 'A-01',
    );
    expect(task.currentStep?.type, TaskStepType.transferWithinDeadline);
  });

  test('不同箱格的多证件会重置步骤和门号，全部完成后才能完成整单', () async {
    final multiItemRepository = _buildMultiItemRepository();

    await multiItemRepository.verifyPickupCode(
      account: orgOneAccount,
      taskId: 'TASK-MULTI-001',
      pickupCode: '12345678',
    );
    await multiItemRepository.completeStep(
      account: orgOneAccount,
      taskId: 'TASK-MULTI-001',
      stepType: TaskStepType.reviewPendingItems,
    );
    await multiItemRepository.assignSlot(
      account: orgOneAccount,
      taskId: 'TASK-MULTI-001',
    );
    await multiItemRepository.completeStep(
      account: orgOneAccount,
      taskId: 'TASK-MULTI-001',
      stepType: TaskStepType.assignSlot,
    );
    await multiItemRepository.confirmDoorOpened(
      account: orgOneAccount,
      taskId: 'TASK-MULTI-001',
      doorNo: 'A-01',
    );
    await multiItemRepository.completeStep(
      account: orgOneAccount,
      taskId: 'TASK-MULTI-001',
      stepType: TaskStepType.scanRfid,
    );
    await multiItemRepository.completeStep(
      account: orgOneAccount,
      taskId: 'TASK-MULTI-001',
      stepType: TaskStepType.transferWithinDeadline,
    );
    await multiItemRepository.recordDoorClosedPendingReport(
      account: orgOneAccount,
      taskId: 'TASK-MULTI-001',
      doorNo: 'A-01',
    );
    var task = await multiItemRepository.confirmDoorClosedAndReport(
      account: orgOneAccount,
      taskId: 'TASK-MULTI-001',
      doorNo: 'A-01',
    );

    expect(task.items[0].status, TaskItemStatus.completed);
    expect(task.items[1].status, TaskItemStatus.processing);
    expect(task.currentItem?.id, 'ITEM-002');
    expect(task.currentItem?.doorNo, 'A-02');
    expect(task.currentStep?.type, TaskStepType.assignSlot);
    expect(task.completedStepCount, 2);
    expect(task.steps[0].status, TaskStepStatus.completed);
    expect(task.steps[1].status, TaskStepStatus.completed);
    expect(task.slotBinding, isNull);

    await expectLater(
      multiItemRepository.completeTask(
        account: orgOneAccount,
        taskId: 'TASK-MULTI-001',
      ),
      throwsA(isA<CabinetTaskIncompleteException>()),
    );

    final secondBinding = await multiItemRepository.assignSlot(
      account: orgOneAccount,
      taskId: 'TASK-MULTI-001',
    );
    expect(secondBinding.doorNo, 'A-02');
    await multiItemRepository.completeStep(
      account: orgOneAccount,
      taskId: 'TASK-MULTI-001',
      stepType: TaskStepType.assignSlot,
    );
    await multiItemRepository.validateDoorOpen(
      account: orgOneAccount,
      taskId: 'TASK-MULTI-001',
      doorNo: 'A-02',
    );
    await multiItemRepository.confirmDoorOpened(
      account: orgOneAccount,
      taskId: 'TASK-MULTI-001',
      doorNo: 'A-02',
    );
    await multiItemRepository.completeStep(
      account: orgOneAccount,
      taskId: 'TASK-MULTI-001',
      stepType: TaskStepType.scanRfid,
    );
    await multiItemRepository.completeStep(
      account: orgOneAccount,
      taskId: 'TASK-MULTI-001',
      stepType: TaskStepType.transferWithinDeadline,
    );
    await multiItemRepository.recordDoorClosedPendingReport(
      account: orgOneAccount,
      taskId: 'TASK-MULTI-001',
      doorNo: 'A-02',
    );
    task = await multiItemRepository.confirmDoorClosedAndReport(
      account: orgOneAccount,
      taskId: 'TASK-MULTI-001',
      doorNo: 'A-02',
    );

    expect(task.currentItem, isNull);
    expect(task.currentStep, isNull);
    expect(task.allItemsCompleted, isTrue);
    expect(
      task.items.every((item) => item.status == TaskItemStatus.completed),
      isTrue,
    );

    final completed = await multiItemRepository.completeTask(
      account: orgOneAccount,
      taskId: 'TASK-MULTI-001',
    );
    expect(completed.status, CabinetTaskStatus.completed);
  });

  test('取证或借证同箱多份只开一次门并逐份扫描后再关门', () async {
    final batchRepository = _buildSameDoorBatchRepository();

    await batchRepository.verifyPickupCode(
      account: orgOneAccount,
      taskId: 'TASK-SAME-DOOR-001',
      pickupCode: '44556677',
    );
    await batchRepository.completeStep(
      account: orgOneAccount,
      taskId: 'TASK-SAME-DOOR-001',
      stepType: TaskStepType.reviewPendingItems,
    );
    await batchRepository.assignSlot(
      account: orgOneAccount,
      taskId: 'TASK-SAME-DOOR-001',
    );
    await batchRepository.completeStep(
      account: orgOneAccount,
      taskId: 'TASK-SAME-DOOR-001',
      stepType: TaskStepType.assignSlot,
    );
    await batchRepository.confirmDoorOpened(
      account: orgOneAccount,
      taskId: 'TASK-SAME-DOOR-001',
      doorNo: 'A-01',
    );

    await batchRepository.completeStep(
      account: orgOneAccount,
      taskId: 'TASK-SAME-DOOR-001',
      stepType: TaskStepType.scanRfid,
    );
    var task = await batchRepository.completeStep(
      account: orgOneAccount,
      taskId: 'TASK-SAME-DOOR-001',
      stepType: TaskStepType.transferWithinDeadline,
    );

    expect(task.items[0].status, TaskItemStatus.completed);
    expect(task.items[1].status, TaskItemStatus.processing);
    expect(task.currentItem?.id, 'ITEM-SAME-002');
    expect(task.currentStep?.type, TaskStepType.scanRfid);
    expect(task.slotBinding?.doorNo, 'A-01');

    await batchRepository.completeStep(
      account: orgOneAccount,
      taskId: 'TASK-SAME-DOOR-001',
      stepType: TaskStepType.scanRfid,
    );
    task = await batchRepository.completeStep(
      account: orgOneAccount,
      taskId: 'TASK-SAME-DOOR-001',
      stepType: TaskStepType.transferWithinDeadline,
    );
    expect(task.currentItem?.id, 'ITEM-SAME-002');
    expect(task.currentStep?.type, TaskStepType.closeDoorAndReport);

    await batchRepository.recordDoorClosedPendingReport(
      account: orgOneAccount,
      taskId: 'TASK-SAME-DOOR-001',
      doorNo: 'A-01',
    );
    task = await batchRepository.confirmDoorClosedAndReport(
      account: orgOneAccount,
      taskId: 'TASK-SAME-DOOR-001',
      doorNo: 'A-01',
    );
    expect(task.items[1].status, TaskItemStatus.completed);
    expect(task.currentItem?.id, 'ITEM-SAME-003');
    expect(task.currentItem?.doorNo, 'A-02');
    expect(task.currentStep?.type, TaskStepType.assignSlot);
    expect(task.slotBinding, isNull);
  });

  test('取证或借证可从待办列表选择任一未完成证件', () async {
    final selectionRepository = _buildSameDoorBatchRepository();

    await selectionRepository.verifyPickupCode(
      account: orgOneAccount,
      taskId: 'TASK-SAME-DOOR-001',
      pickupCode: '44556677',
    );
    var task = await selectionRepository.selectTaskItem(
      account: orgOneAccount,
      taskId: 'TASK-SAME-DOOR-001',
      itemId: 'ITEM-SAME-003',
    );
    expect(task.currentItem?.id, 'ITEM-SAME-003');
    expect(task.currentItem?.doorNo, 'A-02');
    expect(task.items.first.status, TaskItemStatus.pending);

    await selectionRepository.completeStep(
      account: orgOneAccount,
      taskId: 'TASK-SAME-DOOR-001',
      stepType: TaskStepType.reviewPendingItems,
    );
    final binding = await selectionRepository.assignSlot(
      account: orgOneAccount,
      taskId: 'TASK-SAME-DOOR-001',
    );
    expect(binding.doorNo, 'A-02');
  });

  test('飞检码必须通过专用入口校验且失败不会推进盘点计划', () async {
    for (final attempt in <({String code, InventoryCodeFailureReason reason})>[
      (code: '   ', reason: InventoryCodeFailureReason.empty),
      (code: '000000', reason: InventoryCodeFailureReason.incorrect),
    ]) {
      await expectLater(
        repository.verifyInventoryCode(
          account: orgOneAccount,
          taskId: 'TASK-INVENTORY-001',
          inspectionCode: attempt.code,
        ),
        throwsA(
          isA<InventoryCodeVerificationException>().having(
            (error) => error.reason,
            'reason',
            attempt.reason,
          ),
        ),
      );
    }

    var task = await repository.fetchTask(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
    );
    expect(task.currentStep?.type, TaskStepType.verifyInventoryCode);
    expect(task.completedStepCount, 0);
    expect(task.inventoryPlan?.codeVerified, isFalse);

    await expectLater(
      repository.completeStep(
        account: orgOneAccount,
        taskId: 'TASK-INVENTORY-001',
        stepType: TaskStepType.verifyInventoryCode,
      ),
      throwsA(
        isA<InventoryOperationException>().having(
          (error) => error.failure,
          'failure',
          InventoryOperationFailure.dedicatedEntryRequired,
        ),
      ),
    );

    task = await repository.verifyInventoryCode(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      inspectionCode: ' 593826 ',
    );
    expect(task.currentStep?.type, TaskStepType.inventoryBySlot);
    expect(task.completedStepCount, 1);
    expect(task.inventoryPlan?.codeVerified, isTrue);

    await expectLater(
      repository.verifyInventoryCode(
        account: orgOneAccount,
        taskId: 'TASK-INVENTORY-001',
        inspectionCode: '593826',
      ),
      throwsA(
        isA<InventoryCodeVerificationException>().having(
          (error) => error.reason,
          'reason',
          InventoryCodeFailureReason.stepNotPending,
        ),
      ),
    );
  });

  test('平台按箱抽盘且指定证件会扩展为所在箱格全部证件', () async {
    final ratioTask = await repository.fetchTask(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
    );
    expect(
      ratioTask.inventoryPlan?.samplingMode,
      InventorySamplingMode.byBoxRatio,
    );
    expect(ratioTask.inventoryPlan?.boxSampleRatio, 0.5);
    expect(ratioTask.inventoryPlan?.allDoorNos, [
      'A-05',
      'A-06',
      'A-07',
      'A-08',
    ]);
    expect(ratioTask.inventoryPlan?.requiredDoorNos, ['A-05', 'A-06']);
    expect(ratioTask.inventoryItemsForDoor('A-05'), hasLength(2));
    expect(ratioTask.inventoryPendingCount('A-05'), 2);
    expect(ratioTask.inventorySlotStatus('A-05'), InventorySlotStatus.pending);
    expect(
      ratioTask.inventorySlotStatus('A-07'),
      InventorySlotStatus.notRequired,
    );

    final specifiedTask = await repository.fetchTask(
      account: orgTwoAccount,
      taskId: 'TASK-ORG2-001',
    );
    expect(
      specifiedTask.inventoryPlan?.samplingMode,
      InventorySamplingMode.specifiedDocuments,
    );
    expect(specifiedTask.inventoryPlan?.specifiedDocumentCodes, [
      'CERT-B01-001',
    ]);
    expect(specifiedTask.inventoryPlan?.requiredDoorNos, ['B-01']);
    expect(specifiedTask.inventoryItemsForDoor('B-01'), hasLength(2));
    expect(
      specifiedTask
          .inventoryItemsForDoor('B-01')
          .map((item) => item.documentCode),
      containsAll(['CERT-B01-001', 'CERT-B01-002']),
    );
    expect(
      specifiedTask.inventorySlotStatus('B-02'),
      InventorySlotStatus.notRequired,
    );
  });

  test('全量盘点计划漏列证件所在箱格时拒绝加载', () async {
    final malformedRepository = TaskCenterRepositoryImpl(
      FakeTaskCenterDataSource(
        tasks: [
          _buildInventoryDefinitionTask(
            id: 'TASK-INVENTORY-MISSING-DOOR',
            plan: const InventoryPlan(
              inspectionCode: '123456',
              samplingMode: InventorySamplingMode.full,
              allDoorNos: ['A-05'],
              requiredDoorNos: ['A-05'],
            ),
            items: const [
              TaskItem(
                id: 'ITEM-A05',
                documentCode: 'DOC-A05',
                documentName: 'A-05 证件',
                rfid: 'RFID-A05',
                doorNo: 'A-05',
              ),
              TaskItem(
                id: 'ITEM-A06',
                documentCode: 'DOC-A06',
                documentName: '被计划漏列的 A-06 证件',
                rfid: 'RFID-A06',
                doorNo: 'A-06',
              ),
            ],
          ),
        ],
        slotBindings: const [],
      ),
    );

    await expectLater(
      malformedRepository.fetchTask(
        account: orgOneAccount,
        taskId: 'TASK-INVENTORY-MISSING-DOOR',
      ),
      throwsA(
        isA<InventoryOperationException>().having(
          (error) => error.failure,
          'failure',
          InventoryOperationFailure.planInvalid,
        ),
      ),
    );
  });

  test('指定证件盘点包含不存在的证件编号时拒绝加载', () async {
    final malformedRepository = TaskCenterRepositoryImpl(
      FakeTaskCenterDataSource(
        tasks: [
          _buildInventoryDefinitionTask(
            id: 'TASK-INVENTORY-PHANTOM-DOCUMENT',
            plan: const InventoryPlan(
              inspectionCode: '123456',
              samplingMode: InventorySamplingMode.specifiedDocuments,
              allDoorNos: ['A-05'],
              requiredDoorNos: ['A-05'],
              specifiedDocumentCodes: ['DOC-A05', 'DOC-NOT-FOUND'],
            ),
            items: const [
              TaskItem(
                id: 'ITEM-A05',
                documentCode: 'DOC-A05',
                documentName: 'A-05 证件',
                rfid: 'RFID-A05',
                doorNo: 'A-05',
              ),
            ],
          ),
        ],
        slotBindings: const [],
      ),
    );

    await expectLater(
      malformedRepository.fetchTasks(orgOneAccount),
      throwsA(
        isA<InventoryOperationException>().having(
          (error) => error.failure,
          'failure',
          InventoryOperationFailure.planInvalid,
        ),
      ),
    );
  });

  test('同一箱格支持多 RFID、重复扫描幂等并记录溢余', () async {
    await repository.verifyInventoryCode(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      inspectionCode: '593826',
    );

    await expectLater(
      repository.validateInventoryDoorOpen(
        account: orgOneAccount,
        taskId: 'TASK-INVENTORY-001',
        doorNo: 'A-07',
      ),
      throwsA(
        isA<InventoryOperationException>().having(
          (error) => error.failure,
          'failure',
          InventoryOperationFailure.doorNotRequired,
        ),
      ),
    );

    final binding = await repository.validateInventoryDoorOpen(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      doorNo: 'A-05',
    );
    expect(binding.doorNo, 'A-05');
    expect(binding.organizationId, orgOneAccount.organizationId);

    var task = await repository.startInventoryDoor(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      doorNo: 'A-05',
    );
    expect(task.inventoryPlan?.activeDoorNo, 'A-05');
    expect(task.inventorySlotStatus('A-05'), InventorySlotStatus.inProgress);

    await expectLater(
      repository.startInventoryDoor(
        account: orgOneAccount,
        taskId: 'TASK-INVENTORY-001',
        doorNo: 'A-06',
      ),
      throwsA(
        isA<InventoryOperationException>()
            .having(
              (error) => error.failure,
              'failure',
              InventoryOperationFailure.anotherDoorActive,
            )
            .having((error) => error.activeDoorNo, 'activeDoorNo', 'A-05'),
      ),
    );

    task = await repository.scanInventoryRfid(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      doorNo: 'A-05',
      rfid: ' RFID-A05-0001 ',
    );
    final firstExpected = task.items.singleWhere(
      (item) => item.rfid == 'RFID-A05-0001',
    );
    expect(firstExpected.inventoryResult, InventoryItemResult.normal);
    expect(firstExpected.inventoryReturnStatus, InventoryReturnStatus.waiting);
    expect(task.inventoryPendingCount('A-05'), 1);
    expect(
      task.inventorySlotStatus('A-05'),
      InventorySlotStatus.partiallyChecked,
    );

    final itemCountAfterFirstScan = task.items.length;
    task = await repository.scanInventoryRfid(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      doorNo: 'A-05',
      rfid: 'RFID-A05-0001',
    );
    expect(task.items, hasLength(itemCountAfterFirstScan));

    task = await repository.scanInventoryRfid(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      doorNo: 'A-05',
      rfid: 'RFID-A05-0002',
    );
    expect(task.inventoryPendingCount('A-05'), 0);
    expect(
      task
          .inventoryItemsForDoor('A-05')
          .where((item) => !item.isInventorySurplus)
          .every((item) => item.inventoryResult == InventoryItemResult.normal),
      isTrue,
    );

    task = await repository.scanInventoryRfid(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      doorNo: 'A-05',
      rfid: 'RFID-A05-SURPLUS',
    );
    var surplusItems = task
        .inventoryItemsForDoor('A-05')
        .where((item) => item.isInventorySurplus);
    expect(surplusItems, hasLength(1));
    expect(surplusItems.single.inventoryResult, InventoryItemResult.surplus);
    expect(
      surplusItems.single.inventoryReturnStatus,
      InventoryReturnStatus.waiting,
    );

    task = await repository.scanInventoryRfid(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      doorNo: 'A-05',
      rfid: 'RFID-A05-SURPLUS',
    );
    surplusItems = task
        .inventoryItemsForDoor('A-05')
        .where((item) => item.isInventorySurplus);
    expect(surplusItems, hasLength(1));

    await repository.recordDoorClosedPendingReport(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      doorNo: 'A-05',
    );
    task = await repository.completeInventoryDoor(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      doorNo: 'A-05',
    );
    expect(task.inventoryPlan?.activeDoorNo, isNull);
    expect(task.inventoryPlan?.completedDoorNos, ['A-05']);
    expect(
      task
          .inventoryItemsForDoor('A-05')
          .every(
            (item) =>
                item.inventoryReturnStatus == InventoryReturnStatus.returned,
          ),
      isTrue,
    );
    expect(task.inventorySlotStatus('A-05'), InventorySlotStatus.abnormal);
    expect(task.currentStep?.type, TaskStepType.inventoryBySlot);
  });

  test('盘点开箱后机构箱格绑定发生变化时拒绝扫码和结算', () async {
    final dataSource = _MutableInventorySlotDataSource(
      FakeTaskCenterDataSource.seeded(),
    );
    final bindingRepository = TaskCenterRepositoryImpl(dataSource);

    await bindingRepository.verifyInventoryCode(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      inspectionCode: '593826',
    );
    await bindingRepository.startInventoryDoor(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      doorNo: 'A-05',
    );
    dataSource.bindingChanged = true;
    await bindingRepository.recordDoorClosedPendingReport(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      doorNo: 'A-05',
    );

    for (final attempt in <Future<Object?> Function()>[
      () => bindingRepository.scanInventoryRfid(
        account: orgOneAccount,
        taskId: 'TASK-INVENTORY-001',
        doorNo: 'A-05',
        rfid: 'RFID-A05-0001',
      ),
      () => bindingRepository.completeInventoryDoor(
        account: orgOneAccount,
        taskId: 'TASK-INVENTORY-001',
        doorNo: 'A-05',
      ),
    ]) {
      await expectLater(
        attempt(),
        throwsA(
          isA<InventoryOperationException>().having(
            (error) => error.failure,
            'failure',
            InventoryOperationFailure.slotBindingChanged,
          ),
        ),
      );
    }
  });

  test('盘点开始前两次解析到不同箱格绑定时拒绝进入开箱状态', () async {
    final dataSource = _MutableInventorySlotDataSource(
      FakeTaskCenterDataSource.seeded(),
    )..changeAtA05ResolveCall = 2;
    final bindingRepository = TaskCenterRepositoryImpl(dataSource);

    await bindingRepository.verifyInventoryCode(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      inspectionCode: '593826',
    );
    await expectLater(
      bindingRepository.startInventoryDoor(
        account: orgOneAccount,
        taskId: 'TASK-INVENTORY-001',
        doorNo: 'A-05',
      ),
      throwsA(
        isA<InventoryOperationException>().having(
          (error) => error.failure,
          'failure',
          InventoryOperationFailure.slotBindingChanged,
        ),
      ),
    );
    final task = await bindingRepository.fetchTask(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
    );
    expect(task.inventoryPlan?.activeDoorNo, isNull);
    expect(task.slotBinding, isNull);
  });

  test('关箱自动判定缺失且全部抽中箱格完成后才能结束任务', () async {
    await repository.verifyInventoryCode(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      inspectionCode: '593826',
    );
    await repository.startInventoryDoor(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      doorNo: 'A-05',
    );
    await repository.scanInventoryRfid(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      doorNo: 'A-05',
      rfid: 'RFID-A05-0001',
    );
    await repository.recordDoorClosedPendingReport(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      doorNo: 'A-05',
    );
    var task = await repository.completeInventoryDoor(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      doorNo: 'A-05',
    );

    final normalItem = task.items.singleWhere(
      (item) => item.rfid == 'RFID-A05-0001',
    );
    final missingItem = task.items.singleWhere(
      (item) => item.rfid == 'RFID-A05-0002',
    );
    expect(normalItem.inventoryResult, InventoryItemResult.normal);
    expect(normalItem.inventoryReturnStatus, InventoryReturnStatus.returned);
    expect(normalItem.status, TaskItemStatus.completed);
    expect(missingItem.inventoryResult, InventoryItemResult.missing);
    expect(
      missingItem.inventoryReturnStatus,
      InventoryReturnStatus.notRequired,
    );
    expect(missingItem.status, TaskItemStatus.completed);
    expect(task.inventorySlotStatus('A-05'), InventorySlotStatus.abnormal);

    await expectLater(
      repository.completeTask(
        account: orgOneAccount,
        taskId: 'TASK-INVENTORY-001',
      ),
      throwsA(
        isA<CabinetTaskIncompleteException>()
            .having((error) => error.hasPendingStep, 'hasPendingStep', isTrue)
            .having(
              (error) => error.incompleteItemIds,
              'incompleteItemIds',
              contains('TASK-INVENTORY-001-A06-01'),
            ),
      ),
    );

    await repository.startInventoryDoor(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      doorNo: 'A-06',
    );
    await repository.scanInventoryRfid(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      doorNo: 'A-06',
      rfid: 'RFID-A06-0001',
    );
    await repository.recordDoorClosedPendingReport(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      doorNo: 'A-06',
    );
    task = await repository.completeInventoryDoor(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      doorNo: 'A-06',
    );

    expect(task.inventoryPlan?.allRequiredDoorsCompleted, isTrue);
    expect(task.currentStep, isNull);
    expect(task.inventorySlotStatus('A-06'), InventorySlotStatus.completed);
    final notRequiredItem = task.items.singleWhere(
      (item) => item.doorNo == 'A-07',
    );
    expect(notRequiredItem.status, TaskItemStatus.pending);
    expect(notRequiredItem.inventoryResult, InventoryItemResult.pending);
    expect(task.allRequiredItemsCompleted, isTrue);

    final completed = await repository.completeTask(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
    );
    expect(completed.status, CabinetTaskStatus.completed);
  });

  test('盘点专用入口全部拒绝跨机构账号', () async {
    final attempts = <Future<Object?> Function()>[
      () => repository.verifyInventoryCode(
        account: orgTwoAccount,
        taskId: 'TASK-INVENTORY-001',
        inspectionCode: '593826',
      ),
      () => repository.validateInventoryDoorOpen(
        account: orgTwoAccount,
        taskId: 'TASK-INVENTORY-001',
        doorNo: 'A-05',
      ),
      () => repository.startInventoryDoor(
        account: orgTwoAccount,
        taskId: 'TASK-INVENTORY-001',
        doorNo: 'A-05',
      ),
      () => repository.scanInventoryRfid(
        account: orgTwoAccount,
        taskId: 'TASK-INVENTORY-001',
        doorNo: 'A-05',
        rfid: 'RFID-A05-0001',
      ),
      () => repository.recordDoorClosedPendingReport(
        account: orgTwoAccount,
        taskId: 'TASK-INVENTORY-001',
        doorNo: 'A-05',
      ),
      () => repository.completeInventoryDoor(
        account: orgTwoAccount,
        taskId: 'TASK-INVENTORY-001',
        doorNo: 'A-05',
      ),
    ];

    for (final attempt in attempts) {
      await expectLater(
        attempt(),
        throwsA(isA<CabinetTaskOrganizationException>()),
      );
    }
  });

  test('通用步骤入口不能绕过箱格盘点或专用开关门校验', () async {
    await repository.verifyInventoryCode(
      account: orgOneAccount,
      taskId: 'TASK-INVENTORY-001',
      inspectionCode: '593826',
    );
    await expectLater(
      repository.completeStep(
        account: orgOneAccount,
        taskId: 'TASK-INVENTORY-001',
        stepType: TaskStepType.inventoryBySlot,
      ),
      throwsA(
        isA<InventoryOperationException>().having(
          (error) => error.failure,
          'failure',
          InventoryOperationFailure.dedicatedEntryRequired,
        ),
      ),
    );

    await _advanceStoreToAssignSlot(
      repository: repository,
      account: orgOneAccount,
      taskId: 'TASK-STORE-001',
    );
    await repository.assignSlot(
      account: orgOneAccount,
      taskId: 'TASK-STORE-001',
      preferredDoorNo: 'A-01',
    );
    await repository.completeStep(
      account: orgOneAccount,
      taskId: 'TASK-STORE-001',
      stepType: TaskStepType.assignSlot,
    );

    await expectLater(
      repository.completeStep(
        account: orgOneAccount,
        taskId: 'TASK-STORE-001',
        stepType: TaskStepType.openDoor,
      ),
      throwsA(
        isA<CabinetTaskDoorValidationException>().having(
          (error) => error.failure,
          'failure',
          CabinetTaskDoorValidationFailure.dedicatedEntryRequired,
        ),
      ),
    );
    await repository.confirmDoorOpened(
      account: orgOneAccount,
      taskId: 'TASK-STORE-001',
      doorNo: 'A-01',
    );
    await repository.completeStep(
      account: orgOneAccount,
      taskId: 'TASK-STORE-001',
      stepType: TaskStepType.transferWithinDeadline,
    );
    await expectLater(
      repository.completeStep(
        account: orgOneAccount,
        taskId: 'TASK-STORE-001',
        stepType: TaskStepType.closeDoorAndReport,
      ),
      throwsA(
        isA<CabinetTaskDoorValidationException>().having(
          (error) => error.failure,
          'failure',
          CabinetTaskDoorValidationFailure.dedicatedEntryRequired,
        ),
      ),
    );

    final task = await repository.fetchTask(
      account: orgOneAccount,
      taskId: 'TASK-STORE-001',
    );
    expect(task.currentStep?.type, TaskStepType.closeDoorAndReport);
  });
}

/// 创建证件目标门号已被其他机构独占绑定的测试仓库。
TaskCenterRepository _buildSlotConflictRepository() {
  return TaskCenterRepositoryImpl(
    FakeTaskCenterDataSource(
      tasks: const [
        CabinetTask(
          id: 'TASK-SLOT-CONFLICT',
          type: TaskType.storeEvidence,
          title: '跨机构分箱测试任务',
          organizationId: 'org-001',
          organizationName: '市市场监督管理局',
          items: [
            TaskItem(
              id: 'ITEM-SLOT-CONFLICT',
              documentCode: 'DOC-SLOT-CONFLICT',
              documentName: '跨机构分箱测试证件',
              doorNo: 'B-01',
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
          doorNo: 'B-01',
          organizationId: 'org-002',
          organizationName: '市公安局',
        ),
      ],
    ),
  );
}

/// 将存证任务推进到平台分箱步骤。
Future<void> _advanceStoreToAssignSlot({
  required TaskCenterRepository repository,
  required OperatorAccount account,
  required String taskId,
}) async {
  for (final stepType in const [
    TaskStepType.attachRfid,
    TaskStepType.captureFront,
    TaskStepType.captureBack,
    TaskStepType.runOcr,
  ]) {
    await repository.completeStep(
      account: account,
      taskId: taskId,
      stepType: stepType,
    );
  }
}

/// 创建包含两份证件且使用不同专属柜门的测试仓库。
TaskCenterRepository _buildMultiItemRepository() {
  return TaskCenterRepositoryImpl(
    FakeTaskCenterDataSource(
      tasks: const [
        CabinetTask(
          id: 'TASK-MULTI-001',
          type: TaskType.retrieveEvidence,
          title: '两证件取证任务',
          organizationId: 'org-001',
          organizationName: '市市场监督管理局',
          pickupCode: '12345678',
          items: [
            TaskItem(
              id: 'ITEM-001',
              documentCode: 'DOC-001',
              documentName: '第一份证件',
              doorNo: 'A-01',
            ),
            TaskItem(
              id: 'ITEM-002',
              documentCode: 'DOC-002',
              documentName: '第二份证件',
              doorNo: 'A-02',
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
}

/// 创建包含同箱两份和另一箱一份借证证件的测试仓库。
TaskCenterRepository _buildSameDoorBatchRepository() {
  return TaskCenterRepositoryImpl(
    FakeTaskCenterDataSource(
      tasks: const [
        CabinetTask(
          id: 'TASK-SAME-DOOR-001',
          type: TaskType.borrowEvidence,
          title: '同箱多证件借证任务',
          organizationId: 'org-001',
          organizationName: '市市场监督管理局',
          pickupCode: '44556677',
          items: [
            TaskItem(
              id: 'ITEM-SAME-001',
              documentCode: 'DOC-SAME-001',
              documentName: '同箱第一份证件',
              rfid: 'RFID-SAME-001',
              doorNo: 'A-01',
            ),
            TaskItem(
              id: 'ITEM-SAME-002',
              documentCode: 'DOC-SAME-002',
              documentName: '同箱第二份证件',
              rfid: 'RFID-SAME-002',
              doorNo: 'A-01',
            ),
            TaskItem(
              id: 'ITEM-SAME-003',
              documentCode: 'DOC-SAME-003',
              documentName: '另一箱证件',
              rfid: 'RFID-SAME-003',
              doorNo: 'A-02',
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
}

/// 构造用于验证盘点计划定义的最小规范任务。
CabinetTask _buildInventoryDefinitionTask({
  required String id,
  required InventoryPlan plan,
  required List<TaskItem> items,
}) {
  return CabinetTask(
    id: id,
    type: TaskType.inventory,
    title: '盘点计划校验任务',
    organizationId: 'org-001',
    organizationName: '市市场监督管理局',
    items: items,
    steps: const [
      TaskStep(type: TaskStepType.verifyInventoryCode),
      TaskStep(type: TaskStepType.inventoryBySlot),
    ],
    inventoryPlan: plan,
  );
}

/// 可在开箱后模拟平台更换箱格绑定的数据源。
final class _MutableInventorySlotDataSource implements TaskCenterDataSource {
  /// 包装真实的内存数据源，仅在测试指定时返回变化后的绑定。
  _MutableInventorySlotDataSource(this._delegate);

  final FakeTaskCenterDataSource _delegate;

  /// 是否将 A-05 的柜体编号改为另一台柜体。
  bool bindingChanged = false;

  /// 是否将普通任务 A-01 的权威柜体编号改为另一台柜体。
  bool a01BindingChanged = false;

  /// 从第几次解析 A-05 开始返回变化后的绑定。
  int? changeAtA05ResolveCall;

  int _a05ResolveCallCount = 0;

  @override
  Future<List<CabinetTask>> fetchTasksByOrganization(String organizationId) =>
      _delegate.fetchTasksByOrganization(organizationId);

  @override
  Future<CabinetTask?> fetchTaskById(String taskId) =>
      _delegate.fetchTaskById(taskId);

  @override
  Future<void> saveTask(CabinetTask task) => _delegate.saveTask(task);

  @override
  Future<InstitutionSlotBinding> resolveSlot({
    required String organizationId,
    String? preferredDoorNo,
  }) async {
    final binding = await _delegate.resolveSlot(
      organizationId: organizationId,
      preferredDoorNo: preferredDoorNo,
    );
    if (a01BindingChanged && preferredDoorNo == 'A-01') {
      return InstitutionSlotBinding(
        cabinetId: 'CAB-A01-CHANGED',
        doorNo: binding.doorNo,
        organizationId: binding.organizationId,
        organizationName: binding.organizationName,
      );
    }
    if (preferredDoorNo == 'A-05') {
      _a05ResolveCallCount += 1;
    }
    final changedByCount =
        preferredDoorNo == 'A-05' &&
        changeAtA05ResolveCall != null &&
        _a05ResolveCallCount >= changeAtA05ResolveCall!;
    if ((!bindingChanged && !changedByCount) || preferredDoorNo != 'A-05') {
      return binding;
    }
    return InstitutionSlotBinding(
      cabinetId: 'CAB-CHANGED',
      doorNo: binding.doorNo,
      organizationId: binding.organizationId,
      organizationName: binding.organizationName,
    );
  }
}
