import 'package:flutter/foundation.dart';

import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/task_center/data/datasources/fake_task_center_data_source.dart';
import 'package:smart_cabinet/src/features/task_center/domain/entities/cabinet_task.dart';
import 'package:smart_cabinet/src/features/task_center/domain/repositories/task_center_repository.dart';

/// 任务中心仓库实现。
///
/// 仓库是任务状态机的唯一推进边界：页面只能提交业务动作，不能自行跳过步骤、
/// 推定柜门事实或放宽机构隔离规则。
final class TaskCenterRepositoryImpl implements TaskCenterRepository {
  /// 创建任务中心仓库。
  const TaskCenterRepositoryImpl(this._dataSource);

  final TaskCenterDataSource _dataSource;

  @override
  Future<List<CabinetTask>> fetchTasks(OperatorAccount account) async {
    _ensureAccountVerified(account);
    final tasks = await _dataSource.fetchTasksByOrganization(
      account.organizationId,
    );
    final authorizedTasks = <CabinetTask>[];
    for (final task in tasks) {
      // 即使真实 DataSource 过滤失误，也不能把其他机构任务标题返回给页面。
      if (task.organizationId != account.organizationId) {
        continue;
      }
      _ensureTaskDefinition(task);
      authorizedTasks.add(task);
    }
    return List<CabinetTask>.unmodifiable(authorizedTasks);
  }

  @override
  Future<CabinetTask> fetchTask({
    required OperatorAccount account,
    required String taskId,
  }) async {
    _ensureAccountVerified(account);
    return _loadAuthorizedTask(account: account, taskId: taskId);
  }

  /// 读取任务并执行机构隔离校验，供已经完成认证门禁的业务入口复用。
  Future<CabinetTask> _loadAuthorizedTask({
    required OperatorAccount account,
    required String taskId,
  }) async {
    final task = await _dataSource.fetchTaskById(taskId);
    if (task == null) {
      throw CabinetTaskNotFoundException(taskId);
    }
    _ensureTaskOrganization(account, task);
    _ensureTaskDefinition(task);
    return task;
  }

  @override
  Future<InstitutionSlotBinding> assignSlot({
    required OperatorAccount account,
    required String taskId,
    String? preferredDoorNo,
  }) async {
    _ensureAccountVerified(account);
    final task = await _loadAuthorizedTask(account: account, taskId: taskId);
    if (task.type == TaskType.inventory) {
      throw InventoryOperationException(
        taskId: taskId,
        failure: InventoryOperationFailure.dedicatedEntryRequired,
        currentStep: task.currentStep?.type,
      );
    }
    final currentStep = task.currentStep;
    if (currentStep?.type != TaskStepType.assignSlot) {
      throw CabinetTaskStepOrderException(
        expected: currentStep?.type ?? TaskStepType.assignSlot,
        actual: TaskStepType.assignSlot,
      );
    }
    final currentItem = task.currentItem;
    if (currentItem == null) {
      throw CabinetTaskDoorValidationException(
        taskId: taskId,
        requestedDoorNo: preferredDoorNo ?? '',
        failure: CabinetTaskDoorValidationFailure.currentItemMissing,
      );
    }
    final itemDoorNo = currentItem.doorNo;
    if (preferredDoorNo != null &&
        itemDoorNo != null &&
        preferredDoorNo != itemDoorNo) {
      throw CabinetTaskDoorValidationException(
        taskId: taskId,
        requestedDoorNo: preferredDoorNo,
        expectedDoorNo: itemDoorNo,
        failure: CabinetTaskDoorValidationFailure.itemDoorMismatch,
      );
    }
    final binding = await _dataSource.resolveSlot(
      organizationId: account.organizationId,
      preferredDoorNo: preferredDoorNo ?? itemDoorNo,
    );
    final updatedTask = task.copyWith(
      items: _bindCurrentItemToDoor(task.items, currentItem.id, binding.doorNo),
      slotBinding: binding,
      status: CabinetTaskStatus.inProgress,
    );
    await _dataSource.saveTask(updatedTask);
    return binding;
  }

  @override
  Future<CabinetTask> verifyPickupCode({
    required OperatorAccount account,
    required String taskId,
    required String pickupCode,
  }) async {
    _ensureAccountVerified(account);
    final task = await _loadAuthorizedTask(account: account, taskId: taskId);
    if (task.type != TaskType.retrieveEvidence &&
        task.type != TaskType.borrowEvidence) {
      throw PickupCodeVerificationException(
        taskId: taskId,
        reason: PickupCodeFailureReason.wrongTaskType,
        currentStep: task.currentStep?.type,
      );
    }
    final expectedCode = task.pickupCode;
    if (expectedCode == null || expectedCode.isEmpty) {
      throw PickupCodeVerificationException(
        taskId: taskId,
        reason: PickupCodeFailureReason.notConfigured,
        currentStep: task.currentStep?.type,
      );
    }
    final currentStep = task.currentStep;
    if (currentStep?.type != TaskStepType.verifyPickupCode) {
      throw PickupCodeVerificationException(
        taskId: taskId,
        reason: PickupCodeFailureReason.stepNotPending,
        currentStep: currentStep?.type,
      );
    }
    final normalizedCode = pickupCode.trim();
    if (normalizedCode.isEmpty) {
      throw PickupCodeVerificationException(
        taskId: taskId,
        reason: PickupCodeFailureReason.empty,
        currentStep: currentStep!.type,
      );
    }
    if (normalizedCode != expectedCode) {
      // 错误取件码不触发 saveTask，避免通过重试次数推进业务状态。
      throw PickupCodeVerificationException(
        taskId: taskId,
        reason: PickupCodeFailureReason.incorrect,
        currentStep: currentStep!.type,
      );
    }
    return _advanceCurrentStep(task, currentStep!);
  }

  @override
  Future<CabinetTask> selectTaskItem({
    required OperatorAccount account,
    required String taskId,
    required String itemId,
  }) async {
    _ensureAccountVerified(account);
    final task = await _loadAuthorizedTask(account: account, taskId: taskId);
    if (task.type != TaskType.retrieveEvidence &&
        task.type != TaskType.borrowEvidence) {
      throw TaskItemSelectionException(
        taskId: taskId,
        itemId: itemId,
        failure: TaskItemSelectionFailure.wrongTaskType,
        currentStep: task.currentStep?.type,
      );
    }
    final currentStep = task.currentStep?.type;
    if (currentStep != TaskStepType.reviewPendingItems &&
        currentStep != TaskStepType.assignSlot) {
      throw TaskItemSelectionException(
        taskId: taskId,
        itemId: itemId,
        failure: TaskItemSelectionFailure.stepNotReady,
        currentStep: currentStep,
      );
    }
    final selectedIndex = task.items.indexWhere((item) => item.id == itemId);
    if (selectedIndex < 0) {
      throw TaskItemSelectionException(
        taskId: taskId,
        itemId: itemId,
        failure: TaskItemSelectionFailure.itemNotFound,
        currentStep: currentStep,
      );
    }
    final selectedItem = task.items[selectedIndex];
    if (selectedItem.status == TaskItemStatus.completed) {
      throw TaskItemSelectionException(
        taskId: taskId,
        itemId: itemId,
        failure: TaskItemSelectionFailure.itemCompleted,
        currentStep: currentStep,
      );
    }
    if (selectedItem.status == TaskItemStatus.processing) {
      return task;
    }

    final updatedTask = task.copyWith(
      items: [
        for (var index = 0; index < task.items.length; index++)
          if (index == selectedIndex)
            task.items[index].copyWith(status: TaskItemStatus.processing)
          else if (task.items[index].status == TaskItemStatus.processing)
            task.items[index].copyWith(status: TaskItemStatus.pending)
          else
            task.items[index],
      ],
      clearSlotBinding: currentStep == TaskStepType.assignSlot,
      status: CabinetTaskStatus.inProgress,
    );
    await _dataSource.saveTask(updatedTask);
    return updatedTask;
  }

  @override
  Future<CabinetTask> verifyInventoryCode({
    required OperatorAccount account,
    required String taskId,
    required String inspectionCode,
  }) async {
    _ensureAccountVerified(account);
    final task = await _loadAuthorizedTask(account: account, taskId: taskId);
    final plan = _requireInventoryPlan(task);
    final expectedCode = plan.inspectionCode;
    if (expectedCode.isEmpty) {
      throw InventoryCodeVerificationException(
        taskId: taskId,
        reason: InventoryCodeFailureReason.notConfigured,
        currentStep: task.currentStep?.type,
      );
    }
    final currentStep = task.currentStep;
    if (currentStep?.type != TaskStepType.verifyInventoryCode) {
      throw InventoryCodeVerificationException(
        taskId: taskId,
        reason: InventoryCodeFailureReason.stepNotPending,
        currentStep: currentStep?.type,
      );
    }
    final normalizedCode = inspectionCode.trim();
    if (normalizedCode.isEmpty) {
      throw InventoryCodeVerificationException(
        taskId: taskId,
        reason: InventoryCodeFailureReason.empty,
        currentStep: currentStep!.type,
      );
    }
    if (normalizedCode != expectedCode) {
      // 错误飞检码不能触发 saveTask，防止重试绕过平台授权。
      throw InventoryCodeVerificationException(
        taskId: taskId,
        reason: InventoryCodeFailureReason.incorrect,
        currentStep: currentStep!.type,
      );
    }

    final updatedTask = task.copyWith(
      steps: _completeInventoryStep(task, TaskStepType.verifyInventoryCode),
      inventoryPlan: plan.copyWith(codeVerified: true),
      status: CabinetTaskStatus.inProgress,
    );
    await _dataSource.saveTask(updatedTask);
    return updatedTask;
  }

  @override
  Future<InstitutionSlotBinding> validateDoorOpen({
    required OperatorAccount account,
    required String taskId,
    required String doorNo,
  }) async {
    _ensureAccountVerified(account);
    final task = await _loadAuthorizedTask(account: account, taskId: taskId);
    if (task.currentStep?.type != TaskStepType.openDoor) {
      throw CabinetTaskDoorValidationException(
        taskId: taskId,
        requestedDoorNo: doorNo,
        currentStep: task.currentStep?.type,
        failure: CabinetTaskDoorValidationFailure.stepNotReady,
      );
    }
    final binding = task.slotBinding;
    if (binding == null) {
      throw CabinetTaskDoorValidationException(
        taskId: taskId,
        requestedDoorNo: doorNo,
        failure: CabinetTaskDoorValidationFailure.slotBindingMissing,
      );
    }
    if (binding.organizationId != account.organizationId ||
        binding.organizationId != task.organizationId) {
      throw CabinetTaskDoorValidationException(
        taskId: taskId,
        requestedDoorNo: doorNo,
        expectedDoorNo: binding.doorNo,
        operatorOrganizationId: account.organizationId,
        bindingOrganizationId: binding.organizationId,
        failure: CabinetTaskDoorValidationFailure.slotOrganizationMismatch,
      );
    }
    final currentItem = task.currentItem;
    if (currentItem == null) {
      throw CabinetTaskDoorValidationException(
        taskId: taskId,
        requestedDoorNo: doorNo,
        expectedDoorNo: binding.doorNo,
        failure: CabinetTaskDoorValidationFailure.currentItemMissing,
      );
    }
    final itemDoorNo = currentItem.doorNo;
    if (itemDoorNo == null || itemDoorNo.isEmpty) {
      throw CabinetTaskDoorValidationException(
        taskId: taskId,
        requestedDoorNo: doorNo,
        expectedDoorNo: binding.doorNo,
        failure: CabinetTaskDoorValidationFailure.itemDoorMissing,
      );
    }
    if (itemDoorNo != doorNo) {
      throw CabinetTaskDoorValidationException(
        taskId: taskId,
        requestedDoorNo: doorNo,
        expectedDoorNo: itemDoorNo,
        failure: CabinetTaskDoorValidationFailure.itemDoorMismatch,
      );
    }
    if (binding.doorNo != doorNo) {
      throw CabinetTaskDoorValidationException(
        taskId: taskId,
        requestedDoorNo: doorNo,
        expectedDoorNo: binding.doorNo,
        failure: CabinetTaskDoorValidationFailure.bindingDoorMismatch,
      );
    }
    await _ensureOrdinarySlotBindingCurrent(
      account: account,
      task: task,
      doorNo: doorNo,
    );
    return binding;
  }

  @override
  Future<CabinetTask> confirmDoorOpened({
    required OperatorAccount account,
    required String taskId,
    required String doorNo,
  }) async {
    _ensureAccountVerified(account);
    await validateDoorOpen(account: account, taskId: taskId, doorNo: doorNo);
    final task = await _loadAuthorizedTask(account: account, taskId: taskId);
    final currentStep = task.currentStep;
    if (currentStep?.type != TaskStepType.openDoor) {
      throw CabinetTaskDoorValidationException(
        taskId: taskId,
        requestedDoorNo: doorNo,
        currentStep: currentStep?.type,
        failure: CabinetTaskDoorValidationFailure.stepNotReady,
      );
    }
    await _ensureOrdinarySlotBindingCurrent(
      account: account,
      task: task,
      doorNo: doorNo,
    );
    return _advanceCurrentStep(task, currentStep!);
  }

  @override
  Future<CabinetTask> recoverDoorAfterOpenFailure({
    required OperatorAccount account,
    required String taskId,
    required String doorNo,
  }) async {
    _ensureAccountVerified(account);
    final task = await _loadAuthorizedTask(account: account, taskId: taskId);
    if (task.type == TaskType.inventory) {
      throw CabinetTaskDoorValidationException(
        taskId: taskId,
        requestedDoorNo: doorNo,
        currentStep: task.currentStep?.type,
        failure: CabinetTaskDoorValidationFailure.recoveryStateInvalid,
      );
    }
    _ensureDoorMatchesTask(task: task, account: account, doorNo: doorNo);
    final currentStep = task.currentStep?.type;
    if (currentStep == TaskStepType.openDoor) {
      return task;
    }
    final expectedAfterOpen = _stepImmediatelyAfterOpen(task.type);
    if (currentStep != expectedAfterOpen) {
      throw CabinetTaskDoorValidationException(
        taskId: taskId,
        requestedDoorNo: doorNo,
        currentStep: currentStep,
        failure: CabinetTaskDoorValidationFailure.recoveryStateInvalid,
      );
    }

    final openStepIndex = task.steps.indexWhere(
      (step) => step.type == TaskStepType.openDoor,
    );
    final updatedTask = task.copyWith(
      steps: [
        for (var index = 0; index < task.steps.length; index++)
          if (index < openStepIndex)
            task.steps[index]
          else
            TaskStep(type: task.steps[index].type),
      ],
      status: CabinetTaskStatus.inProgress,
    );
    await _dataSource.saveTask(updatedTask);
    return updatedTask;
  }

  @override
  Future<CabinetTask> recordDoorClosedPendingReport({
    required OperatorAccount account,
    required String taskId,
    required String doorNo,
  }) async {
    _ensureAccountVerified(account);
    final task = await _loadAuthorizedTask(account: account, taskId: taskId);
    // 这是释放物理互锁前的安全检查点；同门号重试必须幂等，不同门号不能覆盖。
    final pendingDoorNo = task.pendingClosedDoorNo;
    if (pendingDoorNo == doorNo) {
      return task;
    }
    if (pendingDoorNo != null) {
      throw CabinetTaskDoorValidationException(
        taskId: taskId,
        requestedDoorNo: doorNo,
        expectedDoorNo: pendingDoorNo,
        currentStep: task.currentStep?.type,
        failure: CabinetTaskDoorValidationFailure.recoveryStateInvalid,
      );
    }

    if (task.type == TaskType.inventory) {
      final plan = _requireInventoryPlan(task);
      _ensureInventoryDoorActive(task: task, plan: plan, doorNo: doorNo);
    } else {
      if (task.currentStep?.type != TaskStepType.closeDoorAndReport) {
        throw CabinetTaskDoorValidationException(
          taskId: taskId,
          requestedDoorNo: doorNo,
          currentStep: task.currentStep?.type,
          failure: CabinetTaskDoorValidationFailure.stepNotReady,
        );
      }
      _ensureDoorMatchesTask(task: task, account: account, doorNo: doorNo);
    }

    final updatedTask = task.copyWith(
      pendingClosedDoorNo: doorNo,
      status: CabinetTaskStatus.inProgress,
    );
    await _dataSource.saveTask(updatedTask);
    return updatedTask;
  }

  @override
  Future<CabinetTask> confirmDoorClosedAndReport({
    required OperatorAccount account,
    required String taskId,
    required String doorNo,
  }) async {
    _ensureAccountVerified(account);
    final task = await _loadAuthorizedTask(account: account, taskId: taskId);
    final currentStep = task.currentStep;
    if (currentStep?.type != TaskStepType.closeDoorAndReport) {
      throw CabinetTaskDoorValidationException(
        taskId: taskId,
        requestedDoorNo: doorNo,
        currentStep: currentStep?.type,
        failure: CabinetTaskDoorValidationFailure.stepNotReady,
      );
    }
    if (task.pendingClosedDoorNo != doorNo) {
      throw CabinetTaskDoorValidationException(
        taskId: taskId,
        requestedDoorNo: doorNo,
        expectedDoorNo: task.pendingClosedDoorNo,
        currentStep: currentStep?.type,
        failure: CabinetTaskDoorValidationFailure.recoveryStateInvalid,
      );
    }
    final binding = task.slotBinding;
    final itemDoorNo = task.currentItem?.doorNo;
    if (binding == null) {
      throw CabinetTaskDoorValidationException(
        taskId: taskId,
        requestedDoorNo: doorNo,
        failure: CabinetTaskDoorValidationFailure.slotBindingMissing,
      );
    }
    if (binding.organizationId != account.organizationId ||
        binding.organizationId != task.organizationId) {
      throw CabinetTaskDoorValidationException(
        taskId: taskId,
        requestedDoorNo: doorNo,
        expectedDoorNo: binding.doorNo,
        operatorOrganizationId: account.organizationId,
        bindingOrganizationId: binding.organizationId,
        failure: CabinetTaskDoorValidationFailure.slotOrganizationMismatch,
      );
    }
    if (itemDoorNo == null || itemDoorNo.isEmpty) {
      throw CabinetTaskDoorValidationException(
        taskId: taskId,
        requestedDoorNo: doorNo,
        expectedDoorNo: binding.doorNo,
        failure: CabinetTaskDoorValidationFailure.itemDoorMissing,
      );
    }
    if (itemDoorNo != doorNo) {
      throw CabinetTaskDoorValidationException(
        taskId: taskId,
        requestedDoorNo: doorNo,
        expectedDoorNo: itemDoorNo,
        failure: CabinetTaskDoorValidationFailure.itemDoorMismatch,
      );
    }
    if (binding.doorNo != doorNo) {
      throw CabinetTaskDoorValidationException(
        taskId: taskId,
        requestedDoorNo: doorNo,
        expectedDoorNo: binding.doorNo,
        failure: CabinetTaskDoorValidationFailure.bindingDoorMismatch,
      );
    }
    return _advanceCurrentStep(task, currentStep!);
  }

  @override
  Future<InstitutionSlotBinding> validateInventoryDoorOpen({
    required OperatorAccount account,
    required String taskId,
    required String doorNo,
  }) async {
    _ensureAccountVerified(account);
    final task = await _loadAuthorizedTask(account: account, taskId: taskId);
    final plan = _requireInventoryPlan(task);
    _ensureInventoryDoorReady(task: task, plan: plan, doorNo: doorNo);
    final binding = await _dataSource.resolveSlot(
      organizationId: account.organizationId,
      preferredDoorNo: doorNo,
    );
    if (binding.organizationId != task.organizationId) {
      throw InstitutionSlotConflictException(
        doorNo: doorNo,
        requestedOrganizationId: task.organizationId,
        boundOrganizationId: binding.organizationId,
      );
    }
    return binding;
  }

  @override
  Future<CabinetTask> startInventoryDoor({
    required OperatorAccount account,
    required String taskId,
    required String doorNo,
  }) async {
    _ensureAccountVerified(account);
    final binding = await validateInventoryDoorOpen(
      account: account,
      taskId: taskId,
      doorNo: doorNo,
    );
    final task = await _loadAuthorizedTask(account: account, taskId: taskId);
    final plan = _requireInventoryPlan(task);
    // 开门结果响应丢失后允许同一绑定幂等重试，但绑定变化必须中止本次盘点。
    if (plan.activeDoorNo == doorNo && task.slotBinding?.doorNo == doorNo) {
      if (_sameSlotBinding(task.slotBinding!, binding)) {
        return task;
      }
      throw InventoryOperationException(
        taskId: taskId,
        doorNo: doorNo,
        activeDoorNo: plan.activeDoorNo,
        currentStep: task.currentStep?.type,
        failure: InventoryOperationFailure.slotBindingChanged,
      );
    }
    _ensureInventoryDoorReady(task: task, plan: plan, doorNo: doorNo);
    final latestBinding = await _dataSource.resolveSlot(
      organizationId: account.organizationId,
      preferredDoorNo: doorNo,
    );
    if (!_sameSlotBinding(binding, latestBinding)) {
      throw InventoryOperationException(
        taskId: taskId,
        doorNo: doorNo,
        activeDoorNo: plan.activeDoorNo,
        currentStep: task.currentStep?.type,
        failure: InventoryOperationFailure.slotBindingChanged,
      );
    }
    final updatedTask = task.copyWith(
      inventoryPlan: plan.copyWith(activeDoorNo: doorNo),
      slotBinding: binding,
      status: CabinetTaskStatus.inProgress,
    );
    await _dataSource.saveTask(updatedTask);
    return updatedTask;
  }

  @override
  Future<CabinetTask> scanInventoryRfid({
    required OperatorAccount account,
    required String taskId,
    required String doorNo,
    required String rfid,
  }) async {
    _ensureAccountVerified(account);
    final task = await _loadAuthorizedTask(account: account, taskId: taskId);
    final plan = _requireInventoryPlan(task);
    _ensureInventoryDoorActive(task: task, plan: plan, doorNo: doorNo);
    await _ensureInventorySlotBindingCurrent(
      account: account,
      task: task,
      doorNo: doorNo,
    );
    final normalizedRfid = rfid.trim();
    if (normalizedRfid.isEmpty) {
      throw InventoryOperationException(
        taskId: taskId,
        doorNo: doorNo,
        activeDoorNo: plan.activeDoorNo,
        currentStep: task.currentStep?.type,
        failure: InventoryOperationFailure.rfidEmpty,
      );
    }

    // 先匹配平台清单；同一已确认 RFID 重扫只返回当前快照，不重复改变状态。
    final expectedIndex = task.items.indexWhere(
      (item) =>
          item.doorNo == doorNo &&
          !item.isInventorySurplus &&
          item.rfid == normalizedRfid,
    );
    if (expectedIndex >= 0) {
      final expectedItem = task.items[expectedIndex];
      if (expectedItem.inventoryResult == InventoryItemResult.normal) {
        return task;
      }
      final updatedItems = [...task.items];
      updatedItems[expectedIndex] = expectedItem.copyWith(
        status: TaskItemStatus.processing,
        inventoryResult: InventoryItemResult.normal,
        inventoryReturnStatus: InventoryReturnStatus.waiting,
      );
      final updatedTask = task.copyWith(items: updatedItems);
      await _dataSource.saveTask(updatedTask);
      return updatedTask;
    }

    // 未知 RFID 以溢余项持久化，同一箱格重复扫描仍保持单条记录。
    final existingSurplus = task.items.any(
      (item) =>
          item.doorNo == doorNo &&
          item.isInventorySurplus &&
          item.rfid == normalizedRfid,
    );
    if (existingSurplus) {
      return task;
    }
    final sequence =
        task.items.where((item) => item.isInventorySurplus).length + 1;
    final surplusItem = TaskItem(
      id: '$taskId-SURPLUS-$sequence',
      documentCode: 'SURPLUS-$sequence',
      documentName: '盘点溢余证件',
      rfid: normalizedRfid,
      doorNo: doorNo,
      status: TaskItemStatus.processing,
      inventoryResult: InventoryItemResult.surplus,
      inventoryReturnStatus: InventoryReturnStatus.waiting,
      isInventorySurplus: true,
    );
    final updatedTask = task.copyWith(items: [...task.items, surplusItem]);
    await _dataSource.saveTask(updatedTask);
    return updatedTask;
  }

  @override
  Future<CabinetTask> completeInventoryDoor({
    required OperatorAccount account,
    required String taskId,
    required String doorNo,
  }) async {
    _ensureAccountVerified(account);
    final task = await _loadAuthorizedTask(account: account, taskId: taskId);
    final plan = _requireInventoryPlan(task);
    _ensureInventoryDoorActive(task: task, plan: plan, doorNo: doorNo);
    if (task.pendingClosedDoorNo != doorNo) {
      throw InventoryOperationException(
        taskId: taskId,
        doorNo: doorNo,
        activeDoorNo: plan.activeDoorNo,
        currentStep: task.currentStep?.type,
        failure: InventoryOperationFailure.doorNotActive,
      );
    }
    await _ensureInventorySlotBindingCurrent(
      account: account,
      task: task,
      doorNo: doorNo,
    );

    // 只有人工确认关门后的结算才把未扫描清单项标记为缺失；倒计时报警不会走到这里。
    final updatedItems = [
      for (final item in task.items)
        if (item.doorNo != doorNo)
          item
        else if (item.isInventorySurplus)
          item.copyWith(
            status: TaskItemStatus.completed,
            inventoryResult: InventoryItemResult.surplus,
            inventoryReturnStatus: InventoryReturnStatus.returned,
          )
        else if (item.inventoryResult == InventoryItemResult.pending)
          item.copyWith(
            status: TaskItemStatus.completed,
            inventoryResult: InventoryItemResult.missing,
            inventoryReturnStatus: InventoryReturnStatus.notRequired,
          )
        else
          item.copyWith(
            status: TaskItemStatus.completed,
            inventoryReturnStatus: InventoryReturnStatus.returned,
          ),
    ];
    final completedDoorNos = <String>[
      ...plan.completedDoorNos,
      if (!plan.completedDoorNos.contains(doorNo)) doorNo,
    ];
    final updatedPlan = plan.copyWith(
      completedDoorNos: completedDoorNos,
      clearActiveDoorNo: true,
    );
    final allDoorsCompleted = updatedPlan.allRequiredDoorsCompleted;
    final updatedTask = task.copyWith(
      items: updatedItems,
      steps: allDoorsCompleted
          ? _completeInventoryStep(task, TaskStepType.inventoryBySlot)
          : task.steps,
      inventoryPlan: updatedPlan,
      clearSlotBinding: true,
      clearPendingClosedDoorNo: true,
      status: CabinetTaskStatus.inProgress,
    );
    await _dataSource.saveTask(updatedTask);
    return updatedTask;
  }

  @override
  Future<CabinetTask> completeStep({
    required OperatorAccount account,
    required String taskId,
    required TaskStepType stepType,
  }) async {
    _ensureAccountVerified(account);
    final task = await _loadAuthorizedTask(account: account, taskId: taskId);
    final currentStep = task.currentStep;
    if (currentStep == null) {
      return task;
    }
    if (currentStep.type != stepType) {
      throw CabinetTaskStepOrderException(
        expected: currentStep.type,
        actual: stepType,
      );
    }
    if (stepType == TaskStepType.verifyPickupCode) {
      throw PickupCodeVerificationException(
        taskId: taskId,
        reason: PickupCodeFailureReason.dedicatedEntryRequired,
        currentStep: currentStep.type,
      );
    }
    if (stepType == TaskStepType.verifyInventoryCode ||
        stepType == TaskStepType.inventoryBySlot) {
      throw InventoryOperationException(
        taskId: taskId,
        activeDoorNo: task.inventoryPlan?.activeDoorNo,
        currentStep: currentStep.type,
        failure: InventoryOperationFailure.dedicatedEntryRequired,
      );
    }
    if (stepType == TaskStepType.openDoor ||
        stepType == TaskStepType.closeDoorAndReport) {
      throw CabinetTaskDoorValidationException(
        taskId: taskId,
        requestedDoorNo:
            task.slotBinding?.doorNo ?? task.currentItem?.doorNo ?? '',
        currentStep: currentStep.type,
        failure: CabinetTaskDoorValidationFailure.dedicatedEntryRequired,
      );
    }
    if (stepType == TaskStepType.assignSlot) {
      final binding = task.slotBinding;
      final itemDoorNo = task.currentItem?.doorNo;
      if (binding == null) {
        throw CabinetTaskDoorValidationException(
          taskId: taskId,
          requestedDoorNo: itemDoorNo ?? '',
          currentStep: currentStep.type,
          failure: CabinetTaskDoorValidationFailure.slotBindingMissing,
        );
      }
      if (itemDoorNo == null || itemDoorNo.isEmpty) {
        throw CabinetTaskDoorValidationException(
          taskId: taskId,
          requestedDoorNo: binding.doorNo,
          expectedDoorNo: binding.doorNo,
          currentStep: currentStep.type,
          failure: CabinetTaskDoorValidationFailure.itemDoorMissing,
        );
      }
      if (binding.doorNo != itemDoorNo) {
        throw CabinetTaskDoorValidationException(
          taskId: taskId,
          requestedDoorNo: binding.doorNo,
          expectedDoorNo: itemDoorNo,
          currentStep: currentStep.type,
          failure: CabinetTaskDoorValidationFailure.bindingDoorMismatch,
        );
      }
    }
    return _advanceCurrentStep(task, currentStep);
  }

  @override
  Future<CabinetTask> completeTask({
    required OperatorAccount account,
    required String taskId,
  }) async {
    _ensureAccountVerified(account);
    final task = await _loadAuthorizedTask(account: account, taskId: taskId);
    if (task.currentStep != null || !task.allRequiredItemsCompleted) {
      throw CabinetTaskIncompleteException(
        taskId: taskId,
        hasPendingStep: task.currentStep != null,
        incompleteItemIds: [
          for (final item in task.items)
            if (_itemBlocksTaskCompletion(task, item)) item.id,
        ],
      );
    }
    final updatedTask = task.copyWith(status: CabinetTaskStatus.completed);
    await _dataSource.saveTask(updatedTask);
    return updatedTask;
  }

  /// 完成当前步骤，并在证件末步骤处原子切换到下一证件。
  Future<CabinetTask> _advanceCurrentStep(
    CabinetTask task,
    TaskStep currentStep,
  ) async {
    final currentStepIndex = task.steps.indexWhere(
      (step) => step.status == TaskStepStatus.pending,
    );
    final steps = [
      for (var index = 0; index < task.steps.length; index++)
        if (index == currentStepIndex)
          task.steps[index].copyWith(status: TaskStepStatus.completed)
        else
          task.steps[index],
    ];
    var items = _markCurrentItemProcessing(task.items, task.currentItem?.id);
    var resetStepsForNextItem = false;

    final continuedBatch = _continueSameDoorTakeOutBatch(
      task: task,
      currentStep: currentStep,
      completedSteps: steps,
      items: items,
    );
    if (continuedBatch != null) {
      await _dataSource.saveTask(continuedBatch);
      return continuedBatch;
    }

    if (steps.every((step) => step.status == TaskStepStatus.completed)) {
      final currentItemId = task.currentItem?.id;
      items = [
        for (final item in items)
          if (item.id == currentItemId)
            item.copyWith(status: TaskItemStatus.completed)
          else
            item,
      ];
      final nextItemIndex = items.indexWhere(
        (item) => item.status == TaskItemStatus.pending,
      );
      if (nextItemIndex >= 0) {
        items = [
          for (var index = 0; index < items.length; index++)
            if (index == nextItemIndex)
              items[index].copyWith(status: TaskItemStatus.processing)
            else
              items[index],
        ];
        resetStepsForNextItem = true;
      }
    }

    final updatedTask = task.copyWith(
      items: items,
      steps: resetStepsForNextItem
          ? [
              for (final step in task.steps)
                if (_isTaskLevelStep(step.type) &&
                    step.status == TaskStepStatus.completed)
                  step
                else
                  TaskStep(type: step.type),
            ]
          : steps,
      clearSlotBinding: resetStepsForNextItem,
      clearPendingClosedDoorNo:
          currentStep.type == TaskStepType.closeDoorAndReport,
      status: CabinetTaskStatus.inProgress,
    );
    await _dataSource.saveTask(updatedTask);
    return updatedTask;
  }

  /// 取证或借证同箱还有证件时保持柜门开启，并回到下一份 RFID 扫描。
  CabinetTask? _continueSameDoorTakeOutBatch({
    required CabinetTask task,
    required TaskStep currentStep,
    required List<TaskStep> completedSteps,
    required List<TaskItem> items,
  }) {
    final isTakeOutTask =
        task.type == TaskType.retrieveEvidence ||
        task.type == TaskType.borrowEvidence;
    if (!isTakeOutTask ||
        currentStep.type != TaskStepType.transferWithinDeadline) {
      return null;
    }
    final currentItem = task.currentItem;
    final doorNo = currentItem?.doorNo;
    if (currentItem == null || doorNo == null || doorNo.isEmpty) {
      return null;
    }
    final nextItemIndex = items.indexWhere(
      (item) =>
          item.id != currentItem.id &&
          item.doorNo == doorNo &&
          item.status == TaskItemStatus.pending,
    );
    if (nextItemIndex < 0) {
      return null;
    }

    final updatedItems = [
      for (var index = 0; index < items.length; index++)
        if (items[index].id == currentItem.id)
          items[index].copyWith(status: TaskItemStatus.completed)
        else if (index == nextItemIndex)
          items[index].copyWith(status: TaskItemStatus.processing)
        else
          items[index],
    ];
    final updatedSteps = [
      for (final step in completedSteps)
        if (step.type == TaskStepType.scanRfid ||
            step.type == TaskStepType.transferWithinDeadline)
          TaskStep(type: step.type)
        else
          step,
    ];
    return task.copyWith(
      items: updatedItems,
      steps: updatedSteps,
      status: CabinetTaskStatus.inProgress,
    );
  }

  /// 判断步骤是否只需在整单任务开始时执行一次。
  bool _isTaskLevelStep(TaskStepType stepType) {
    return stepType == TaskStepType.verifyPickupCode ||
        stepType == TaskStepType.reviewPendingItems ||
        stepType == TaskStepType.verifyInventoryCode;
  }

  /// 读取盘点计划，并拒绝把普通任务送入箱格级盘点入口。
  InventoryPlan _requireInventoryPlan(CabinetTask task) {
    if (task.type != TaskType.inventory) {
      throw InventoryOperationException(
        taskId: task.id,
        currentStep: task.currentStep?.type,
        failure: InventoryOperationFailure.wrongTaskType,
      );
    }
    final plan = task.inventoryPlan;
    if (plan == null) {
      throw InventoryOperationException(
        taskId: task.id,
        currentStep: task.currentStep?.type,
        failure: InventoryOperationFailure.planMissing,
      );
    }
    _ensureValidInventoryPlan(task, plan);
    return plan;
  }

  /// 校验平台任务没有删减、重排步骤或构造“待办后又完成”的非法状态。
  void _ensureCanonicalWorkflow(CabinetTask task) {
    final expectedTypes = requiredTaskStepTypes(task.type);
    final hasExpectedTypes =
        task.steps.length == expectedTypes.length &&
        List<bool>.generate(
          expectedTypes.length,
          (index) => task.steps[index].type == expectedTypes[index],
        ).every((matches) => matches);
    if (!hasExpectedTypes) {
      throw CabinetTaskWorkflowException(
        taskId: task.id,
        taskType: task.type,
        message: '步骤被删减、增加或重排',
      );
    }

    var pendingSeen = false;
    for (final step in task.steps) {
      if (step.status == TaskStepStatus.pending) {
        pendingSeen = true;
      } else if (pendingSeen) {
        throw CabinetTaskWorkflowException(
          taskId: task.id,
          taskType: task.type,
          message: '已完成步骤出现在待办步骤之后',
        );
      }
    }
  }

  /// 校验平台任务的固定步骤和盘点计划，不让异常定义进入页面层。
  void _ensureTaskDefinition(CabinetTask task) {
    _ensureCanonicalWorkflow(task);
    if (task.type == TaskType.inventory) {
      final plan = task.inventoryPlan;
      if (plan == null) {
        throw InventoryOperationException(
          taskId: task.id,
          currentStep: task.currentStep?.type,
          failure: InventoryOperationFailure.planMissing,
        );
      }
      _ensureValidInventoryPlan(task, plan);
    } else if (task.inventoryPlan != null) {
      throw CabinetTaskWorkflowException(
        taskId: task.id,
        taskType: task.type,
        message: '普通任务不应携带盘点计划',
      );
    }
    _ensurePendingDoorState(task);
  }

  /// 校验“实物已关、等待业务上报”状态只出现在匹配的关门结算步骤。
  void _ensurePendingDoorState(CabinetTask task) {
    final pendingDoorNo = task.pendingClosedDoorNo;
    if (pendingDoorNo == null) {
      return;
    }
    final bindingMatches =
        task.slotBinding?.doorNo == pendingDoorNo &&
        task.slotBinding?.organizationId == task.organizationId;
    if (task.type == TaskType.inventory) {
      final plan = task.inventoryPlan;
      if (!bindingMatches ||
          plan?.activeDoorNo != pendingDoorNo ||
          task.currentStep?.type != TaskStepType.inventoryBySlot) {
        throw InventoryOperationException(
          taskId: task.id,
          doorNo: pendingDoorNo,
          activeDoorNo: plan?.activeDoorNo,
          currentStep: task.currentStep?.type,
          failure: InventoryOperationFailure.planInvalid,
        );
      }
      return;
    }
    if (!bindingMatches ||
        task.currentItem?.doorNo != pendingDoorNo ||
        task.currentStep?.type != TaskStepType.closeDoorAndReport) {
      throw CabinetTaskWorkflowException(
        taskId: task.id,
        taskType: task.type,
        message: '待上报关门状态与当前任务步骤或箱格不一致',
      );
    }
  }

  /// 校验盘点箱格集合、抽样模式和当前活动箱格等平台计划不变量。
  void _ensureValidInventoryPlan(CabinetTask task, InventoryPlan plan) {
    final allDoors = plan.allDoorNos.toSet();
    final requiredDoors = plan.requiredDoorNos.toSet();
    final completedDoors = plan.completedDoorNos.toSet();
    final expectedItems = task.items
        .where((item) => !item.isInventorySurplus)
        .toList(growable: false);
    final verificationStep = task.steps.firstWhere(
      (step) => step.type == TaskStepType.verifyInventoryCode,
    );
    final activeDoorNo = plan.activeDoorNo;
    final activeBinding = task.slotBinding;
    var valid =
        plan.allDoorNos.isNotEmpty &&
        allDoors.length == plan.allDoorNos.length &&
        plan.requiredDoorNos.isNotEmpty &&
        requiredDoors.length == plan.requiredDoorNos.length &&
        requiredDoors.every(allDoors.contains) &&
        completedDoors.length == plan.completedDoorNos.length &&
        completedDoors.every(requiredDoors.contains) &&
        (plan.activeDoorNo == null ||
            (requiredDoors.contains(plan.activeDoorNo) &&
                !completedDoors.contains(plan.activeDoorNo))) &&
        expectedItems.every(
          (item) =>
              item.doorNo != null &&
              item.doorNo!.isNotEmpty &&
              allDoors.contains(item.doorNo),
        ) &&
        requiredDoors.every(
          (doorNo) => task.items.any(
            (item) => item.doorNo == doorNo && !item.isInventorySurplus,
          ),
        ) &&
        plan.codeVerified ==
            (verificationStep.status == TaskStepStatus.completed) &&
        (activeDoorNo == null
            ? activeBinding == null
            : activeBinding != null &&
                  activeBinding.doorNo == activeDoorNo &&
                  activeBinding.organizationId == task.organizationId);

    switch (plan.samplingMode) {
      case InventorySamplingMode.full:
        valid = valid && requiredDoors.length == allDoors.length;
      case InventorySamplingMode.byBoxRatio:
        final ratio = plan.boxSampleRatio;
        valid =
            valid &&
            ratio != null &&
            ratio > 0 &&
            ratio <= 1 &&
            requiredDoors.length == (allDoors.length * ratio).ceil();
      case InventorySamplingMode.specifiedDocuments:
        final specifiedCodes = plan.specifiedDocumentCodes.toSet();
        final specifiedDoors = <String>{};
        var eachCodeMatchesExactlyOnce = true;
        for (final code in specifiedCodes) {
          final matches = expectedItems
              .where((item) => item.documentCode == code)
              .toList(growable: false);
          if (matches.length != 1 || matches.single.doorNo == null) {
            eachCodeMatchesExactlyOnce = false;
            continue;
          }
          specifiedDoors.add(matches.single.doorNo!);
        }
        valid =
            valid &&
            specifiedCodes.isNotEmpty &&
            specifiedCodes.length == plan.specifiedDocumentCodes.length &&
            eachCodeMatchesExactlyOnce &&
            specifiedDoors.length == requiredDoors.length &&
            specifiedDoors.every(requiredDoors.contains);
    }
    if (!valid) {
      throw InventoryOperationException(
        taskId: task.id,
        activeDoorNo: plan.activeDoorNo,
        currentStep: task.currentStep?.type,
        failure: InventoryOperationFailure.planInvalid,
      );
    }
  }

  /// 扫码和关箱前重新读取箱格绑定，拒绝使用开箱时已经过期的机构信息。
  Future<void> _ensureInventorySlotBindingCurrent({
    required OperatorAccount account,
    required CabinetTask task,
    required String doorNo,
  }) async {
    final cachedBinding = task.slotBinding;
    if (cachedBinding == null ||
        cachedBinding.doorNo != doorNo ||
        cachedBinding.organizationId != account.organizationId ||
        cachedBinding.organizationId != task.organizationId) {
      throw InventoryOperationException(
        taskId: task.id,
        doorNo: doorNo,
        activeDoorNo: task.inventoryPlan?.activeDoorNo,
        currentStep: task.currentStep?.type,
        failure: InventoryOperationFailure.slotBindingChanged,
      );
    }
    final currentBinding = await _dataSource.resolveSlot(
      organizationId: account.organizationId,
      preferredDoorNo: doorNo,
    );
    if (!_sameSlotBinding(currentBinding, cachedBinding)) {
      throw InventoryOperationException(
        taskId: task.id,
        doorNo: doorNo,
        activeDoorNo: task.inventoryPlan?.activeDoorNo,
        currentStep: task.currentStep?.type,
        failure: InventoryOperationFailure.slotBindingChanged,
      );
    }
  }

  /// 普通任务开门前重新解析权威绑定，拒绝使用分箱后已经变化的缓存。
  Future<void> _ensureOrdinarySlotBindingCurrent({
    required OperatorAccount account,
    required CabinetTask task,
    required String doorNo,
  }) async {
    final cachedBinding = task.slotBinding;
    if (cachedBinding == null ||
        cachedBinding.doorNo != doorNo ||
        cachedBinding.organizationId != account.organizationId ||
        cachedBinding.organizationId != task.organizationId) {
      throw CabinetTaskDoorValidationException(
        taskId: task.id,
        requestedDoorNo: doorNo,
        expectedDoorNo: cachedBinding?.doorNo,
        currentStep: task.currentStep?.type,
        operatorOrganizationId: account.organizationId,
        bindingOrganizationId: cachedBinding?.organizationId,
        failure: CabinetTaskDoorValidationFailure.slotBindingChanged,
      );
    }
    final currentBinding = await _dataSource.resolveSlot(
      organizationId: account.organizationId,
      preferredDoorNo: doorNo,
    );
    if (!_sameSlotBinding(cachedBinding, currentBinding)) {
      throw CabinetTaskDoorValidationException(
        taskId: task.id,
        requestedDoorNo: doorNo,
        expectedDoorNo: cachedBinding.doorNo,
        currentStep: task.currentStep?.type,
        operatorOrganizationId: account.organizationId,
        bindingOrganizationId: currentBinding.organizationId,
        failure: CabinetTaskDoorValidationFailure.slotBindingChanged,
      );
    }
  }

  /// 判断两次平台箱格解析结果是否仍指向同一柜体、柜门和机构。
  bool _sameSlotBinding(
    InstitutionSlotBinding left,
    InstitutionSlotBinding right,
  ) {
    return left.cabinetId == right.cabinetId &&
        left.doorNo == right.doorNo &&
        left.organizationId == right.organizationId;
  }

  /// 返回规范流程中开门步骤提交后的直接下一步。
  TaskStepType _stepImmediatelyAfterOpen(TaskType taskType) {
    final steps = requiredTaskStepTypes(taskType);
    final openIndex = steps.indexOf(TaskStepType.openDoor);
    if (openIndex < 0 || openIndex + 1 >= steps.length) {
      throw StateError('任务没有可恢复的开门后步骤：$taskType');
    }
    return steps[openIndex + 1];
  }

  /// 恢复前复核任务、当前证件与平台箱格仍指向同一柜门和机构。
  void _ensureDoorMatchesTask({
    required CabinetTask task,
    required OperatorAccount account,
    required String doorNo,
  }) {
    final binding = task.slotBinding;
    final itemDoorNo = task.currentItem?.doorNo;
    if (binding == null ||
        binding.doorNo != doorNo ||
        binding.organizationId != account.organizationId ||
        binding.organizationId != task.organizationId ||
        itemDoorNo != doorNo) {
      throw CabinetTaskDoorValidationException(
        taskId: task.id,
        requestedDoorNo: doorNo,
        expectedDoorNo: itemDoorNo ?? binding?.doorNo,
        currentStep: task.currentStep?.type,
        operatorOrganizationId: account.organizationId,
        bindingOrganizationId: binding?.organizationId,
        failure: CabinetTaskDoorValidationFailure.recoveryStateInvalid,
      );
    }
  }

  /// 校验箱格已被本次计划抽中且没有其他箱格处于盘点状态。
  void _ensureInventoryDoorReady({
    required CabinetTask task,
    required InventoryPlan plan,
    required String doorNo,
  }) {
    if (!plan.codeVerified) {
      throw InventoryOperationException(
        taskId: task.id,
        doorNo: doorNo,
        currentStep: task.currentStep?.type,
        failure: InventoryOperationFailure.codeNotVerified,
      );
    }
    if (task.currentStep?.type != TaskStepType.inventoryBySlot) {
      throw InventoryOperationException(
        taskId: task.id,
        doorNo: doorNo,
        currentStep: task.currentStep?.type,
        failure: InventoryOperationFailure.stepNotReady,
      );
    }
    if (!plan.allDoorNos.contains(doorNo)) {
      throw InventoryOperationException(
        taskId: task.id,
        doorNo: doorNo,
        currentStep: task.currentStep?.type,
        failure: InventoryOperationFailure.doorNotInPlan,
      );
    }
    if (!plan.requiresDoor(doorNo)) {
      throw InventoryOperationException(
        taskId: task.id,
        doorNo: doorNo,
        currentStep: task.currentStep?.type,
        failure: InventoryOperationFailure.doorNotRequired,
      );
    }
    if (plan.isDoorCompleted(doorNo)) {
      throw InventoryOperationException(
        taskId: task.id,
        doorNo: doorNo,
        currentStep: task.currentStep?.type,
        failure: InventoryOperationFailure.doorAlreadyCompleted,
      );
    }
    final activeDoorNo = plan.activeDoorNo;
    if (activeDoorNo != null && activeDoorNo != doorNo) {
      throw InventoryOperationException(
        taskId: task.id,
        doorNo: doorNo,
        activeDoorNo: activeDoorNo,
        currentStep: task.currentStep?.type,
        failure: InventoryOperationFailure.anotherDoorActive,
      );
    }
  }

  /// 校验 RFID 和关门动作只作用于当前已打开的盘点箱格。
  void _ensureInventoryDoorActive({
    required CabinetTask task,
    required InventoryPlan plan,
    required String doorNo,
  }) {
    if (task.currentStep?.type != TaskStepType.inventoryBySlot ||
        !plan.codeVerified) {
      throw InventoryOperationException(
        taskId: task.id,
        doorNo: doorNo,
        activeDoorNo: plan.activeDoorNo,
        currentStep: task.currentStep?.type,
        failure: InventoryOperationFailure.stepNotReady,
      );
    }
    if (plan.activeDoorNo != doorNo || task.slotBinding?.doorNo != doorNo) {
      throw InventoryOperationException(
        taskId: task.id,
        doorNo: doorNo,
        activeDoorNo: plan.activeDoorNo,
        currentStep: task.currentStep?.type,
        failure: InventoryOperationFailure.doorNotActive,
      );
    }
  }

  /// 完成一个只能由盘点专用入口推进的任务级步骤。
  List<TaskStep> _completeInventoryStep(
    CabinetTask task,
    TaskStepType expectedType,
  ) {
    final currentStepIndex = task.steps.indexWhere(
      (step) => step.status == TaskStepStatus.pending,
    );
    if (currentStepIndex < 0 ||
        task.steps[currentStepIndex].type != expectedType) {
      throw InventoryOperationException(
        taskId: task.id,
        activeDoorNo: task.inventoryPlan?.activeDoorNo,
        currentStep: task.currentStep?.type,
        failure: InventoryOperationFailure.stepNotReady,
      );
    }
    return [
      for (var index = 0; index < task.steps.length; index++)
        if (index == currentStepIndex)
          task.steps[index].copyWith(status: TaskStepStatus.completed)
        else
          task.steps[index],
    ];
  }

  /// 平台分箱后将当前证件绑定到精确门号并标记为处理中。
  List<TaskItem> _bindCurrentItemToDoor(
    List<TaskItem> items,
    String currentItemId,
    String doorNo,
  ) {
    return [
      for (final item in items)
        if (item.id == currentItemId)
          item.copyWith(doorNo: doorNo, status: TaskItemStatus.processing)
        else
          item,
    ];
  }

  /// 判断一份证件是否会阻止当前任务提交完成。
  bool _itemBlocksTaskCompletion(CabinetTask task, TaskItem item) {
    final plan = task.inventoryPlan;
    if (task.type == TaskType.inventory && plan != null) {
      return plan.requiresDoor(item.doorNo ?? '') &&
          item.status != TaskItemStatus.completed;
    }
    return item.status != TaskItemStatus.completed;
  }

  /// 将选中的待处理证件标记为处理中，其余证件状态保持不变。
  List<TaskItem> _markCurrentItemProcessing(
    List<TaskItem> items,
    String? currentItemId,
  ) {
    if (currentItemId == null) {
      return items;
    }
    return [
      for (final item in items)
        if (item.id == currentItemId && item.status == TaskItemStatus.pending)
          item.copyWith(status: TaskItemStatus.processing)
        else
          item,
    ];
  }

  /// 校验当前账号已经通过人脸、指纹与 NFC 三项身份因子。
  void _ensureAccountVerified(OperatorAccount account) {
    if (account.verifiedFactors.containsAll(requiredOperatorIdentityFactors)) {
      return;
    }
    throw OperatorFactorVerificationException(
      operatorId: account.id,
      verifiedFactors: account.verifiedFactors,
    );
  }

  /// 校验任务与当前操作员属于同一监管机构。
  void _ensureTaskOrganization(OperatorAccount account, CabinetTask task) {
    if (task.organizationId == account.organizationId) {
      return;
    }
    throw CabinetTaskOrganizationException(
      taskId: task.id,
      operatorOrganizationId: account.organizationId,
      taskOrganizationId: task.organizationId,
    );
  }
}

TaskCenterRepository _taskCenterRepository = TaskCenterRepositoryImpl(
  FakeTaskCenterDataSource.seeded(),
);

/// 应用默认共享的内存任务仓库。
TaskCenterRepository get taskCenterRepository => _taskCenterRepository;

/// 重建默认任务仓库，避免会修改任务状态的 Widget 测试互相污染。
@visibleForTesting
void resetTaskCenterRepositoryForTesting() {
  _taskCenterRepository = TaskCenterRepositoryImpl(
    FakeTaskCenterDataSource.seeded(),
  );
}
