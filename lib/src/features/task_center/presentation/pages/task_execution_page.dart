import 'dart:async';

import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/routing/app_routes.dart';
import 'package:smart_cabinet/src/app/shell/app_shell.dart';
import 'package:smart_cabinet/src/app/theme/app_theme.dart';
import 'package:smart_cabinet/src/core/device/cabinet_door_guard.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/task_center/data/repositories/task_center_repository_impl.dart';
import 'package:smart_cabinet/src/features/task_center/domain/entities/cabinet_task.dart';
import 'package:smart_cabinet/src/features/task_center/domain/repositories/task_center_repository.dart';
import 'package:smart_cabinet/src/features/task_center/presentation/widgets/inventory_task_panel.dart';

/// 打开单个任务执行页所需的路由参数。
class TaskExecutionArguments {
  /// 创建任务执行参数。
  const TaskExecutionArguments({
    required this.account,
    required this.taskId,
    this.repository,
    this.doorGuard,
  });

  /// 当前已认证操作员。
  final OperatorAccount account;

  /// 要执行的任务 ID。
  final String taskId;

  /// 可选任务仓库。
  final TaskCenterRepository? repository;

  /// 可选柜门互锁器。
  final CabinetDoorGuard? doorGuard;
}

/// 存证、取证、借证、还证和盘点共用的任务执行页。
class TaskExecutionPage extends StatefulWidget {
  /// 创建任务执行页。
  const TaskExecutionPage({super.key, required this.arguments});

  /// 当前任务执行参数。
  final TaskExecutionArguments arguments;

  @override
  State<TaskExecutionPage> createState() => _TaskExecutionPageState();
}

/// 任务执行页状态，负责顺序推进步骤、柜门互锁与完成后的安全退出。
/// 管理单项任务的步骤推进、柜门互锁与完成后安全退出。
class _TaskExecutionPageState extends State<TaskExecutionPage> {
  static const int _doorTimeoutSeconds = 30;
  static const int _noTaskTimeoutSeconds = 10;

  late final TaskCenterRepository _repository =
      widget.arguments.repository ?? taskCenterRepository;
  late final CabinetDoorGuard _doorGuard =
      widget.arguments.doorGuard ?? globalCabinetDoorGuard;

  CabinetTask? _task;
  bool _loading = true;
  bool _actionInProgress = false;
  bool _taskCompleted = false;
  int _remainingTaskCount = 0;
  Object? _loadError;
  String? _actionError;
  String? _openedDoorNo;
  String? _openedDoorOperationId;
  bool _doorClosedConfirmed = false;
  Timer? _doorTimer;
  int _doorSeconds = _doorTimeoutSeconds;
  bool _doorTimeoutAlarm = false;
  bool _doorRecoveryRequired = false;
  bool _doorReportPending = false;
  Timer? _noTaskTimer;
  int _noTaskSeconds = _noTaskTimeoutSeconds;
  bool _navigationCommitted = false;
  bool _inventoryDoorOpen = false;
  int _loadGeneration = 0;
  final TextEditingController _pickupCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_loadTask());
  }

  /// 加载当前机构有权执行的任务。
  Future<void> _loadTask() async {
    final generation = ++_loadGeneration;
    try {
      final task = await _repository.fetchTask(
        account: widget.arguments.account,
        taskId: widget.arguments.taskId,
      );
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _task = task;
        _loading = false;
        _loadError = null;
        _doorReportPending = task.pendingClosedDoorNo != null;
        if (_doorReportPending) {
          _openedDoorNo = task.pendingClosedDoorNo;
          _openedDoorOperationId = null;
          _doorClosedConfirmed = true;
        }
      });
      if (task.currentStep == null && task.allRequiredItemsCompleted) {
        await _finishTask(task);
      }
    } catch (error) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _loading = false;
        _loadError = error;
      });
    }
  }

  /// 执行当前步骤并将结果写回任务仓库。
  Future<void> _performCurrentStep() async {
    final task = _task;
    final step = task?.currentStep;
    if (task == null || step == null || _actionInProgress) {
      return;
    }
    setState(() {
      _actionInProgress = true;
      _actionError = null;
    });

    try {
      CabinetTask? directlyUpdatedTask;
      switch (step.type) {
        case TaskStepType.assignSlot:
          await _repository.assignSlot(
            account: widget.arguments.account,
            taskId: task.id,
            preferredDoorNo: _preferredDoorNo(task),
          );
          break;
        case TaskStepType.openDoor:
          final doorNo = task.slotBinding?.doorNo ?? _preferredDoorNo(task);
          if (doorNo == null || doorNo.isEmpty) {
            _showStepError(
              context.l10n.t('taskExecutionSlotMissing', '平台尚未返回可用箱格'),
            );
            return;
          }
          final validatedBinding = await _repository.validateDoorOpen(
            account: widget.arguments.account,
            taskId: task.id,
            doorNo: doorNo,
          );
          if (!mounted) {
            return;
          }
          final validatedDoorNo = validatedBinding.doorNo;
          final operationId =
              _openedDoorOperationId ?? _doorGuard.createOperationId(task.id);
          final result = _doorGuard.requestOpen(
            validatedDoorNo,
            operationId: operationId,
          );
          if (result is CabinetDoorOpenConflict) {
            _showStepError(
              context.l10n
                  .t(
                    'taskExecutionAnotherDoorOpen',
                    '柜门 {activeDoorNo} 尚未关闭，不能打开 {requestedDoorNo}',
                  )
                  .replaceAll('{activeDoorNo}', result.activeDoorNo)
                  .replaceAll('{requestedDoorNo}', validatedDoorNo),
            );
            return;
          }
          _openedDoorNo = validatedDoorNo;
          _openedDoorOperationId = operationId;
          _doorClosedConfirmed = false;
          _doorRecoveryRequired = false;
          _startDoorCountdown();
          try {
            directlyUpdatedTask = await _repository.confirmDoorOpened(
              account: widget.arguments.account,
              taskId: task.id,
              doorNo: validatedDoorNo,
            );
          } catch (error, stackTrace) {
            final reconciledTask = await _readCommittedDoorOpen(
              originalTask: task,
              doorNo: validatedDoorNo,
            );
            if (reconciledTask != null) {
              // 平台已提交但响应丢失时继续当前开门周期，避免误回退或重复开门。
              directlyUpdatedTask = reconciledTask;
            } else {
              // 无法确认平台状态时保留互锁，必须人工关门并执行仓库补偿。
              if (mounted) {
                setState(() => _doorRecoveryRequired = true);
              }
              Error.throwWithStackTrace(error, stackTrace);
            }
          }
          break;
        case TaskStepType.closeDoorAndReport:
          final doorNo = _openedDoorNo ?? task.slotBinding?.doorNo;
          final doorStateMismatchMessage = context.l10n.t(
            'taskExecutionDoorStateMismatch',
            '柜门状态与当前任务不一致，柜门互锁未释放',
          );
          if (doorNo == null) {
            _showStepError(
              context.l10n.t('taskExecutionCloseTargetMissing', '没有可确认关闭的柜门'),
            );
            return;
          }
          if (!_doorClosedConfirmed) {
            final operationId = _openedDoorOperationId;
            if (operationId == null) {
              _showStepError(doorStateMismatchMessage);
              return;
            }
            final recordedTask = await _recordDoorClosedForReport(
              task: task,
              doorNo: doorNo,
            );
            final released = _doorGuard.markClosed(
              doorNo,
              operationId: operationId,
            );
            if (!released) {
              _showStepError(doorStateMismatchMessage);
              return;
            }
            _doorClosedConfirmed = true;
            _doorReportPending = true;
            _cancelDoorCountdown();
            if (mounted) {
              setState(() => _task = recordedTask);
            }
          }
          try {
            directlyUpdatedTask = await _repository.confirmDoorClosedAndReport(
              account: widget.arguments.account,
              taskId: task.id,
              doorNo: doorNo,
            );
          } catch (error, stackTrace) {
            final reconciledTask = await _readCommittedDoorClose(
              originalTask: task,
              doorNo: doorNo,
            );
            if (reconciledTask != null) {
              directlyUpdatedTask = reconciledTask;
            } else {
              Error.throwWithStackTrace(error, stackTrace);
            }
          }
          break;
        case TaskStepType.verifyPickupCode:
          directlyUpdatedTask = await _repository.verifyPickupCode(
            account: widget.arguments.account,
            taskId: task.id,
            pickupCode: _pickupCodeController.text,
          );
          break;
        case TaskStepType.attachRfid ||
            TaskStepType.scanRfid ||
            TaskStepType.captureFront ||
            TaskStepType.captureBack ||
            TaskStepType.runOcr ||
            TaskStepType.reviewPendingItems ||
            TaskStepType.transferWithinDeadline:
          await Future<void>.delayed(const Duration(milliseconds: 180));
          break;
        case TaskStepType.verifyInventoryCode || TaskStepType.inventoryBySlot:
          throw StateError('盘点任务必须使用箱格级专用流程');
      }

      final updatedTask =
          directlyUpdatedTask ??
          await _repository.completeStep(
            account: widget.arguments.account,
            taskId: task.id,
            stepType: step.type,
          );
      if (!mounted) {
        return;
      }
      final previousItemId = _activeItem(task)?.id;
      final currentItemId = _activeItem(updatedTask)?.id;
      if (previousItemId != currentItemId) {
        _pickupCodeController.clear();
      }
      if (step.type == TaskStepType.closeDoorAndReport) {
        _openedDoorNo = null;
        _openedDoorOperationId = null;
        _doorClosedConfirmed = false;
        _doorReportPending = false;
      }
      setState(() {
        _task = updatedTask;
        _actionInProgress = false;
      });
      if (updatedTask.currentStep == null) {
        await _finishTask(updatedTask);
      }
    } on PickupCodeVerificationException catch (error) {
      _showPickupCodeError(error.reason);
    } on CabinetTaskDoorValidationException {
      if (mounted) {
        _showStepError(
          context.l10n.t(
            'taskExecutionDoorValidationFailed',
            '任务箱格信息已变更，请返回任务工作台刷新',
          ),
        );
      }
    } on InstitutionSlotConflictException catch (error) {
      if (mounted) {
        _showStepError(
          context.l10n
              .t(
                'taskExecutionInstitutionSlotConflict',
                '箱格 {doorNo} 已绑定其他机构，当前机构无权使用',
              )
              .replaceAll('{doorNo}', error.doorNo),
        );
      }
    } catch (error) {
      _showStepError('$error');
    }
  }

  /// 从取证或借证列表选择任一待办证件作为下一次开箱目标。
  Future<void> _selectTaskItem(String itemId) async {
    final task = _task;
    if (task == null || _actionInProgress) {
      return;
    }
    setState(() {
      _actionInProgress = true;
      _actionError = null;
    });
    try {
      final updatedTask = await _repository.selectTaskItem(
        account: widget.arguments.account,
        taskId: task.id,
        itemId: itemId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _task = updatedTask;
        _actionInProgress = false;
      });
    } catch (error) {
      _showStepError('$error');
    }
  }

  /// 提交任务完成并决定返回任务中心或启动无任务退出倒计时。
  Future<void> _finishTask(CabinetTask task) async {
    if (!mounted || _actionInProgress) {
      return;
    }
    setState(() {
      _actionInProgress = true;
      _actionError = null;
    });
    try {
      CabinetTask completedTask;
      try {
        completedTask = await _repository.completeTask(
          account: widget.arguments.account,
          taskId: task.id,
        );
      } catch (error, stackTrace) {
        final latestTask = await _repository.fetchTask(
          account: widget.arguments.account,
          taskId: task.id,
        );
        if (!latestTask.isCompleted) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        completedTask = latestTask;
      }
      final remainingTasks = await _repository.fetchTasks(
        widget.arguments.account,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _task = completedTask;
        _taskCompleted = true;
        _remainingTaskCount = remainingTasks.length;
        _actionInProgress = false;
      });
      if (remainingTasks.isEmpty) {
        _startNoTaskCountdown();
      }
    } catch (error) {
      _showStepError('$error');
    }
  }

  /// 关门事实写入失败时回读平台，只有已持久化相同门号才允许释放互锁。
  Future<CabinetTask> _recordDoorClosedForReport({
    required CabinetTask task,
    required String doorNo,
  }) async {
    try {
      return await _repository.recordDoorClosedPendingReport(
        account: widget.arguments.account,
        taskId: task.id,
        doorNo: doorNo,
      );
    } catch (error, stackTrace) {
      final latestTask = await _repository.fetchTask(
        account: widget.arguments.account,
        taskId: task.id,
      );
      if (latestTask.pendingClosedDoorNo == doorNo) {
        return latestTask;
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// 关门上报响应异常时确认平台是否已经推进到下一证件或整单待提交状态。
  Future<CabinetTask?> _readCommittedDoorClose({
    required CabinetTask originalTask,
    required String doorNo,
  }) async {
    try {
      final latestTask = await _repository.fetchTask(
        account: widget.arguments.account,
        taskId: originalTask.id,
      );
      final stillWaitingForReport =
          latestTask.pendingClosedDoorNo == doorNo &&
          latestTask.currentStep?.type == TaskStepType.closeDoorAndReport;
      final movedPastOriginalItem =
          latestTask.currentItem?.id != originalTask.currentItem?.id;
      if (!stillWaitingForReport &&
          latestTask.pendingClosedDoorNo == null &&
          (movedPastOriginalItem ||
              latestTask.currentStep?.type !=
                  TaskStepType.closeDoorAndReport)) {
        return latestTask;
      }
    } catch (_) {
      // 对账失败时保留待上报状态，禁止离开页面并允许再次提交。
    }
    return null;
  }

  /// 将取件码校验失败映射为不泄露内部状态的操作提示。
  void _showPickupCodeError(PickupCodeFailureReason reason) {
    if (!mounted) {
      return;
    }
    final l10n = context.l10n;
    final message = switch (reason) {
      PickupCodeFailureReason.empty => l10n.t(
        'taskExecutionPickupCodeEmpty',
        '请输入取件码',
      ),
      PickupCodeFailureReason.incorrect => l10n.t(
        'taskExecutionPickupCodeIncorrect',
        '取件码错误，请重新输入',
      ),
      PickupCodeFailureReason.notConfigured => l10n.t(
        'taskExecutionPickupCodeNotConfigured',
        '当前任务未配置取件码，请联系平台处理',
      ),
      PickupCodeFailureReason.wrongTaskType ||
      PickupCodeFailureReason.stepNotPending ||
      PickupCodeFailureReason.dedicatedEntryRequired => l10n.t(
        'taskExecutionPickupCodeUnavailable',
        '当前步骤无法校验取件码，请刷新任务',
      ),
    };
    _showStepError(message);
  }

  /// 显示步骤执行失败原因并解除按钮忙碌状态。
  void _showStepError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _actionInProgress = false;
      _actionError = message;
    });
  }

  /// 读取当前证件声明的目标或来源柜门。
  String? _preferredDoorNo(CabinetTask task) => _activeItem(task)?.doorNo;

  /// 返回当前正在处理或下一条待处理证件。
  TaskItem? _activeItem(CabinetTask task) {
    for (final item in task.items) {
      if (item.status == TaskItemStatus.processing) {
        return item;
      }
    }
    for (final item in task.items) {
      if (item.status == TaskItemStatus.pending) {
        return item;
      }
    }
    return null;
  }

  /// 在柜门获得互锁资格后启动 30 秒关门倒计时。
  void _startDoorCountdown() {
    _doorTimer?.cancel();
    _doorSeconds = _doorTimeoutSeconds;
    _doorTimeoutAlarm = false;
    _doorTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isCurrentDoorOpen) {
        return;
      }
      if (_doorSeconds <= 1) {
        _doorTimer?.cancel();
        _doorTimer = null;
        setState(() {
          _doorSeconds = 0;
          _doorTimeoutAlarm = true;
        });
        return;
      }
      setState(() => _doorSeconds -= 1);
    });
  }

  /// 取消柜门倒计时但不自行改变互锁状态。
  void _cancelDoorCountdown() {
    _doorTimer?.cancel();
    _doorTimer = null;
    _doorSeconds = _doorTimeoutSeconds;
    _doorTimeoutAlarm = false;
  }

  /// 普通任务开门状态写入失败时，仅在人工确认匹配柜门已关闭后释放互锁。
  Future<void> _recoverOrdinaryDoor() async {
    final doorNo = _openedDoorNo;
    final operationId = _openedDoorOperationId;
    final task = _task;
    if (doorNo == null ||
        operationId == null ||
        task == null ||
        !_doorRecoveryRequired ||
        _actionInProgress) {
      return;
    }
    final doorStateMismatchMessage = context.l10n.t(
      'taskExecutionDoorStateMismatch',
      '柜门状态与当前任务不一致，柜门互锁未释放',
    );
    setState(() {
      _actionInProgress = true;
      _actionError = null;
    });
    try {
      final recoveredTask = await _repository.recoverDoorAfterOpenFailure(
        account: widget.arguments.account,
        taskId: task.id,
        doorNo: doorNo,
      );
      final released = _doorGuard.markClosed(doorNo, operationId: operationId);
      if (!released) {
        throw StateError(doorStateMismatchMessage);
      }
      _cancelDoorCountdown();
      if (!mounted) {
        return;
      }
      setState(() {
        _task = recoveredTask;
        _openedDoorNo = null;
        _openedDoorOperationId = null;
        _doorClosedConfirmed = false;
        _doorRecoveryRequired = false;
        _doorReportPending = false;
        _actionError = null;
        _actionInProgress = false;
      });
    } catch (error) {
      _showStepError('$error');
    }
  }

  /// 响应异常后读取最新任务，识别“平台已提交、仅响应丢失”的开门结果。
  Future<CabinetTask?> _readCommittedDoorOpen({
    required CabinetTask originalTask,
    required String doorNo,
  }) async {
    try {
      final latestTask = await _repository.fetchTask(
        account: widget.arguments.account,
        taskId: originalTask.id,
      );
      final canonicalSteps = requiredTaskStepTypes(originalTask.type);
      final openIndex = canonicalSteps.indexOf(TaskStepType.openDoor);
      if (openIndex < 0 || openIndex + 1 >= canonicalSteps.length) {
        return null;
      }
      final openCommitted =
          latestTask.steps[openIndex].status == TaskStepStatus.completed;
      final expectedNextStep = canonicalSteps[openIndex + 1];
      final sameDoor =
          latestTask.slotBinding?.doorNo == doorNo &&
          latestTask.currentItem?.doorNo == doorNo;
      if (openCommitted &&
          sameDoor &&
          latestTask.currentStep?.type == expectedNextStep) {
        return latestTask;
      }
    } catch (_) {
      // 对账读取失败不能推定平台未提交，仍进入人工关门与补偿流程。
    }
    return null;
  }

  /// 没有剩余任务时启动 10 秒安全退出倒计时。
  void _startNoTaskCountdown() {
    _noTaskTimer?.cancel();
    _noTaskSeconds = _noTaskTimeoutSeconds;
    _noTaskTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _remainingTaskCount != 0) {
        return;
      }
      if (!_doorGuard.allDoorsClosed || _doorGuard.hasActiveOperation) {
        if (_noTaskSeconds != _noTaskTimeoutSeconds) {
          setState(() => _noTaskSeconds = _noTaskTimeoutSeconds);
        }
        return;
      }
      if (_noTaskSeconds <= 1) {
        _returnHome();
        return;
      }
      setState(() => _noTaskSeconds -= 1);
    });
  }

  /// 返回任务中心并通知上页刷新任务。
  void _returnTaskCenter() {
    if (!mounted ||
        _navigationCommitted ||
        _doorGuard.hasActiveOperation ||
        _inventoryDoorOpen) {
      return;
    }
    _navigationCommitted = true;
    _noTaskTimer?.cancel();
    Navigator.of(context).pop(true);
  }

  /// 清空路由栈并返回登录首页。
  void _returnHome() {
    if (!mounted ||
        _navigationCommitted ||
        !_doorGuard.allDoorsClosed ||
        _doorGuard.hasActiveOperation) {
      return;
    }
    _navigationCommitted = true;
    _noTaskTimer?.cancel();
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
  }

  /// 当前任务打开的柜门是否仍占用全局互锁。
  bool get _isCurrentDoorOpen {
    final doorNo = _openedDoorNo;
    final operationId = _openedDoorOperationId;
    return _inventoryDoorOpen ||
        (doorNo != null &&
            operationId != null &&
            _doorGuard.isOpen(doorNo, operationId: operationId));
  }

  /// 同步盘点子流程返回的最新任务快照。
  void _onInventoryTaskChanged(CabinetTask task) {
    if (!mounted) {
      return;
    }
    setState(() => _task = task);
  }

  /// 同步盘点弹窗是否仍占用柜门互锁，阻止返回和退出。
  void _onInventoryDoorStateChanged(bool isOpen) {
    if (!mounted || _inventoryDoorOpen == isOpen) {
      return;
    }
    setState(() => _inventoryDoorOpen = isOpen);
  }

  /// 全部抽中箱格完成后提交盘点整单。
  Future<void> _onInventoryReadyToComplete(CabinetTask task) async {
    if (!mounted || _taskCompleted) {
      return;
    }
    setState(() => _task = task);
    await _finishTask(task);
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    _doorTimer?.cancel();
    _noTaskTimer?.cancel();
    _pickupCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final task = _task;
    final l10n = context.l10n;
    return PopScope(
      canPop: !_doorGuard.hasActiveOperation && !_inventoryDoorOpen,
      child: TerminalShell(
        topBarLeading: TextButton.icon(
          onPressed: _doorGuard.hasActiveOperation || _inventoryDoorOpen
              ? null
              : _returnTaskCenter,
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: Text(l10n.t('taskExecutionBack', '返回任务工作台')),
        ),
        topRightBadge: FlowStatusBadge(
          text: task == null
              ? l10n.t('taskExecutionLoadingBadge', '任务加载中')
              : l10n
                    .t('taskExecutionBadge', '{type}任务执行中')
                    .replaceAll('{type}', _taskTypeTitle(context, task.type)),
        ),
        child: Container(
          color: AppTheme.scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
          child: _buildBody(context),
        ),
      ),
    );
  }

  /// 构建加载、失败、执行中或任务完成状态。
  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final loadError = _loadError;
    if (loadError != null) {
      return _ExecutionLoadError(error: loadError, onRetry: _loadTask);
    }
    final task = _task;
    if (task == null) {
      return const SizedBox.shrink();
    }
    if (_taskCompleted) {
      return _TaskCompletedPanel(
        task: task,
        remainingTaskCount: _remainingTaskCount,
        noTaskSeconds: _noTaskSeconds,
        onReturnTaskCenter: _returnTaskCenter,
      );
    }

    if (task.currentStep == null && task.allRequiredItemsCompleted) {
      return _TaskFinalizationPanel(
        busy: _actionInProgress,
        error: _actionError,
        onRetry: () => _finishTask(task),
      );
    }

    if (task.type == TaskType.inventory) {
      return InventoryTaskPanel(
        task: task,
        account: widget.arguments.account,
        repository: _repository,
        doorGuard: _doorGuard,
        onTaskChanged: _onInventoryTaskChanged,
        onDoorStateChanged: _onInventoryDoorStateChanged,
        onTaskReadyToComplete: _onInventoryReadyToComplete,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 360,
          child: _ExecutionSummaryPanel(
            task: task,
            actionInProgress: _actionInProgress,
            onSelectItem: _selectTaskItem,
          ),
        ),
        const SizedBox(width: 22),
        Expanded(
          child: _StepWorkflowPanel(
            task: task,
            actionInProgress: _actionInProgress,
            actionError: _actionError,
            doorNo: _openedDoorNo,
            doorOpen: _isCurrentDoorOpen,
            doorSeconds: _doorSeconds,
            doorTimeoutAlarm: _doorTimeoutAlarm,
            pickupCodeController: _pickupCodeController,
            doorRecoveryRequired: _doorRecoveryRequired,
            onRecoverDoor: _recoverOrdinaryDoor,
            onPerformStep: _performCurrentStep,
          ),
        ),
      ],
    );
  }
}

/// 任务概要、证件列表和平台箱格面板。
class _ExecutionSummaryPanel extends StatelessWidget {
  const _ExecutionSummaryPanel({
    required this.task,
    required this.actionInProgress,
    required this.onSelectItem,
  });

  final CabinetTask task;
  final bool actionInProgress;
  final ValueChanged<String> onSelectItem;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _taskTypeTitle(context, task.type),
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            task.title,
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 23,
              height: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          _SummaryLine(
            label: l10n.t('taskExecutionTaskId', '任务编号'),
            value: task.id,
          ),
          _SummaryLine(
            label: l10n.t('taskExecutionOrganization', '监管机构'),
            value: task.organizationName,
          ),
          _SummaryLine(
            label: l10n.t('taskExecutionProgress', '步骤进度'),
            value: '${task.completedStepCount} / ${task.steps.length}',
          ),
          const Divider(height: 28),
          Text(
            l10n.t('taskExecutionPendingItems', '待办证件列表'),
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          if ((task.type == TaskType.retrieveEvidence ||
                  task.type == TaskType.borrowEvidence) &&
              (task.currentStep?.type == TaskStepType.reviewPendingItems ||
                  task.currentStep?.type == TaskStepType.assignSlot)) ...[
            const SizedBox(height: 6),
            Text(
              l10n.t('taskExecutionSelectItemHint', '点击任一待办证件，选择下一次开箱目标'),
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: task.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = task.items[index];
                final canSelect =
                    !actionInProgress &&
                    item.status != TaskItemStatus.completed &&
                    (task.type == TaskType.retrieveEvidence ||
                        task.type == TaskType.borrowEvidence) &&
                    (task.currentStep?.type ==
                            TaskStepType.reviewPendingItems ||
                        task.currentStep?.type == TaskStepType.assignSlot);
                final selected = task.currentItem?.id == item.id;
                return Material(
                  color: selected
                      ? AppTheme.primarySoftColor
                      : AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    key: ValueKey('task_item_select_${item.id}'),
                    onTap: canSelect ? () => onSelectItem(item.id) : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primaryColor
                              : AppTheme.outlineColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.documentName,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimaryColor,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${item.documentCode} · ${item.rfid ?? '-'}',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F7FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryBorderColor),
            ),
            child: Text(
              task.slotBinding == null
                  ? l10n.t('taskExecutionWaitingSlot', '等待平台分配或授权箱格')
                  : l10n
                        .t('taskExecutionAssignedSlot', '平台箱格：{doorNo}')
                        .replaceAll('{doorNo}', task.slotBinding!.doorNo),
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 任务步骤列表和当前步骤操作面板。
class _StepWorkflowPanel extends StatelessWidget {
  const _StepWorkflowPanel({
    required this.task,
    required this.actionInProgress,
    required this.actionError,
    required this.doorNo,
    required this.doorOpen,
    required this.doorSeconds,
    required this.doorTimeoutAlarm,
    required this.pickupCodeController,
    required this.doorRecoveryRequired,
    required this.onRecoverDoor,
    required this.onPerformStep,
  });

  final CabinetTask task;
  final bool actionInProgress;
  final String? actionError;
  final String? doorNo;
  final bool doorOpen;
  final int doorSeconds;
  final bool doorTimeoutAlarm;
  final TextEditingController pickupCodeController;
  final bool doorRecoveryRequired;
  final VoidCallback onRecoverDoor;
  final VoidCallback onPerformStep;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currentStep = task.currentStep;
    final activeDoorNo = doorNo ?? task.slotBinding?.doorNo;
    final isTakeOutTask =
        task.type == TaskType.retrieveEvidence ||
        task.type == TaskType.borrowEvidence;
    final sameDoorRemaining = activeDoorNo == null
        ? 0
        : task.unfinishedItemCountForDoor(activeDoorNo);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.t('taskExecutionWorkflow', '任务执行步骤'),
                  style: const TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${task.completedStepCount} / ${task.steps.length}',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: task.steps.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final step = task.steps[index];
                return _StepRow(
                  index: index + 1,
                  step: step,
                  active: identical(step, currentStep),
                  taskType: task.type,
                );
              },
            ),
          ),
          if (doorOpen) ...[
            const SizedBox(height: 14),
            _DoorCountdownPanel(
              doorNo: doorNo ?? '-',
              seconds: doorSeconds,
              alarm: doorTimeoutAlarm,
            ),
          ],
          if (doorOpen && isTakeOutTask && sameDoorRemaining > 0) ...[
            const SizedBox(height: 12),
            Container(
              key: const ValueKey('task_execution_same_slot_remaining'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primarySoftColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryBorderColor),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n
                          .t(
                            'taskExecutionSameSlotRemaining',
                            '箱格 {doorNo} 还有 {count} 份待取，请逐份扫描，全部取出后再关门',
                          )
                          .replaceAll('{doorNo}', activeDoorNo!)
                          .replaceAll('{count}', '$sameDoorRemaining'),
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (doorRecoveryRequired) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0DD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF09A32)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFF9A5400),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.t(
                        'taskExecutionDoorRecoveryHint',
                        '开门状态更新失败。请先确认当前柜门已经关闭，再恢复任务。',
                      ),
                      style: const TextStyle(
                        color: Color(0xFF9A5400),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('task_execution_recover_door'),
                    onPressed: onRecoverDoor,
                    icon: const Icon(Icons.lock_rounded),
                    label: Text(
                      l10n.t(
                        'taskExecutionConfirmClosedAndRecover',
                        '确认已关门并恢复',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (currentStep?.type == TaskStepType.verifyPickupCode) ...[
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('task_execution_pickup_code_input'),
              controller: pickupCodeController,
              keyboardType: TextInputType.number,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.t('taskExecutionPickupCodeInput', '输入取件码'),
                hintText: l10n.t('taskExecutionPickupCodeHint', '请输入平台下发的取件码'),
                prefixIcon: const Icon(Icons.pin_outlined),
              ),
            ),
          ],
          if (actionError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                l10n
                    .t('taskExecutionActionFailed', '步骤执行失败：{error}')
                    .replaceAll('{error}', actionError!),
                style: const TextStyle(
                  color: Color(0xFFB42318),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: AppTheme.touchTargetSize,
            child: ElevatedButton.icon(
              key: ValueKey(
                'task_step_action_${currentStep?.type.name ?? 'none'}',
              ),
              onPressed:
                  currentStep == null ||
                      actionInProgress ||
                      doorRecoveryRequired
                  ? null
                  : onPerformStep,
              icon: actionInProgress
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(_stepIcon(currentStep?.type)),
              label: Text(
                actionInProgress
                    ? l10n.t('taskExecutionProcessing', '处理中...')
                    : currentStep == null
                    ? l10n.t('taskExecutionAllStepsDone', '全部步骤已完成')
                    : _stepActionText(context, currentStep.type, task.type),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单条任务步骤状态。
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.step,
    required this.active,
    required this.taskType,
  });

  final int index;
  final TaskStep step;
  final bool active;
  final TaskType taskType;

  @override
  Widget build(BuildContext context) {
    final completed = step.status == TaskStepStatus.completed;
    final color = completed
        ? const Color(0xFF22A857)
        : active
        ? AppTheme.primaryColor
        : const Color(0xFF9AA7C4);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: active ? AppTheme.primarySoftColor : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? AppTheme.primaryBorderColor : AppTheme.outlineColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: completed
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : Text(
                    '$index',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Icon(_stepIcon(step.type), color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _stepTitle(context, step.type, taskType),
                  style: const TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  completed
                      ? context.l10n.t('taskExecutionStepCompleted', '已完成')
                      : active
                      ? context.l10n.t('taskExecutionStepCurrent', '当前步骤')
                      : context.l10n.t('taskExecutionStepPending', '等待执行'),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 柜门打开后的限时操作和报警提示。
class _DoorCountdownPanel extends StatelessWidget {
  const _DoorCountdownPanel({
    required this.doorNo,
    required this.seconds,
    required this.alarm,
  });

  final String doorNo;
  final int seconds;
  final bool alarm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      key: const ValueKey('task_execution_door_countdown'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: alarm ? const Color(0xFFFFE9E7) : const Color(0xFFFFF6E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alarm ? const Color(0xFFE05252) : const Color(0xFFFFC46F),
        ),
      ),
      child: Row(
        children: [
          Icon(
            alarm ? Icons.notifications_active_rounded : Icons.timer_outlined,
            color: alarm ? const Color(0xFFE05252) : const Color(0xFFC46A00),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              alarm
                  ? l10n
                        .t(
                          'taskExecutionDoorTimeoutAlarm',
                          '柜门 {doorNo} 超时未关闭，请立即处理',
                        )
                        .replaceAll('{doorNo}', doorNo)
                  : l10n
                        .t(
                          'taskExecutionDoorCountdown',
                          '柜门 {doorNo} 已打开，请在 {seconds} 秒内完成存取并关门',
                        )
                        .replaceAll('{doorNo}', doorNo)
                        .replaceAll('{seconds}', '$seconds'),
              style: TextStyle(
                color: alarm
                    ? const Color(0xFFB42318)
                    : const Color(0xFF8A4C00),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 所有业务步骤完成后等待整单提交或允许幂等重试的面板。
class _TaskFinalizationPanel extends StatelessWidget {
  const _TaskFinalizationPanel({
    required this.busy,
    required this.error,
    required this.onRetry,
  });

  final bool busy;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Container(
        key: const ValueKey('task_execution_finalization_pending'),
        width: 640,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryBorderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_upload_outlined,
              color: AppTheme.primaryColor,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.t('taskExecutionFinalizationTitle', '等待任务结果提交'),
              style: const TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.t(
                'taskExecutionFinalizationHint',
                '业务步骤已完成，正在向平台提交整单结果；失败时可安全重试，不会重复执行开关门。',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                height: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB42318),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: AppTheme.touchTargetSize,
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const ValueKey('task_execution_retry_finalization'),
                onPressed: busy ? null : onRetry,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(
                  busy
                      ? l10n.t('taskExecutionProcessing', '处理中...')
                      : l10n.t('taskExecutionRetryFinalization', '重试提交任务结果'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 任务完成后的后续动作面板。
class _TaskCompletedPanel extends StatelessWidget {
  const _TaskCompletedPanel({
    required this.task,
    required this.remainingTaskCount,
    required this.noTaskSeconds,
    required this.onReturnTaskCenter,
  });

  final CabinetTask task;
  final int remainingTaskCount;
  final int noTaskSeconds;
  final VoidCallback onReturnTaskCenter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Container(
        key: const ValueKey('task_execution_completed'),
        width: 650,
        padding: const EdgeInsets.all(34),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFBEE8CC)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.task_alt_rounded,
              color: Color(0xFF22A857),
              size: 76,
            ),
            const SizedBox(height: 20),
            Text(
              l10n
                  .t('taskExecutionCompletedTitle', '{type}任务已经完成')
                  .replaceAll('{type}', _taskTypeTitle(context, task.type)),
              style: const TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              remainingTaskCount > 0
                  ? l10n
                        .t('taskExecutionRemainingTasks', '还有 {count} 项任务待处理')
                        .replaceAll('{count}', '$remainingTaskCount')
                  : l10n
                        .t(
                          'taskExecutionNoTaskExit',
                          '当前无其他任务，{seconds} 秒后退出登录',
                        )
                        .replaceAll('{seconds}', '$noTaskSeconds'),
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (remainingTaskCount > 0) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                key: const ValueKey('task_execution_return_center'),
                onPressed: onReturnTaskCenter,
                icon: const Icon(Icons.dashboard_outlined),
                label: Text(l10n.t('taskExecutionReturnCenter', '返回任务工作台')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 任务加载失败提示。
class _ExecutionLoadError extends StatelessWidget {
  const _ExecutionLoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48),
          const SizedBox(height: 12),
          Text(
            l10n
                .t('taskExecutionLoadFailed', '任务加载失败：{error}')
                .replaceAll('{error}', '$error'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            child: Text(l10n.t('taskExecutionRetry', '重新加载')),
          ),
        ],
      ),
    );
  }
}

/// 任务概要信息行。
class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8D99B8),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 返回任务类型的本地化标题。
String _taskTypeTitle(BuildContext context, TaskType type) {
  final l10n = context.l10n;
  return switch (type) {
    TaskType.storeEvidence => l10n.t('taskTypeStoreEvidence', '存证'),
    TaskType.retrieveEvidence => l10n.t('taskTypeRetrieveEvidence', '取证'),
    TaskType.borrowEvidence => l10n.t('taskTypeBorrowEvidence', '借证'),
    TaskType.returnEvidence => l10n.t('taskTypeReturnEvidence', '还证'),
    TaskType.inventory => l10n.t('taskTypeInventory', '盘点'),
  };
}

/// 返回步骤标题。
String _stepTitle(BuildContext context, TaskStepType step, TaskType taskType) {
  final l10n = context.l10n;
  return switch (step) {
    TaskStepType.attachRfid => l10n.t('taskStepAttachRfid', '贴 RFID 并读取'),
    TaskStepType.scanRfid => l10n.t('taskStepScanRfid', '扫描 RFID 并匹配'),
    TaskStepType.captureFront => l10n.t('taskStepCaptureFront', '拍摄证件正面'),
    TaskStepType.captureBack => l10n.t('taskStepCaptureBack', '拍摄证件反面'),
    TaskStepType.runOcr => l10n.t('taskStepRunOcr', 'OCR 识别并确认信息'),
    TaskStepType.verifyPickupCode => l10n.t(
      'taskStepVerifyPickupCode',
      '验证取件码',
    ),
    TaskStepType.reviewPendingItems => l10n.t(
      'taskStepReviewPendingItems',
      '确认待办证件列表',
    ),
    TaskStepType.verifyInventoryCode => l10n.t(
      'taskStepVerifyInventoryCode',
      '验证飞检码',
    ),
    TaskStepType.inventoryBySlot => l10n.t(
      'taskStepInventoryBySlot',
      '按箱格执行整箱盘点',
    ),
    TaskStepType.assignSlot =>
      taskType == TaskType.storeEvidence || taskType == TaskType.returnEvidence
          ? l10n.t('taskStepAssignSlot', '向平台请求分箱')
          : l10n.t('taskStepAuthorizeSlot', '向平台确认授权箱格'),
    TaskStepType.openDoor => l10n.t('taskStepOpenDoor', '打开指定柜门'),
    TaskStepType.transferWithinDeadline => l10n.t(
      'taskStepTransferWithinDeadline',
      '限时完成存取或盘点',
    ),
    TaskStepType.closeDoorAndReport => l10n.t(
      'taskStepCloseDoorAndReport',
      '确认关门并上报平台',
    ),
  };
}

/// 返回当前步骤按钮文案。
String _stepActionText(
  BuildContext context,
  TaskStepType step,
  TaskType taskType,
) {
  final l10n = context.l10n;
  return switch (step) {
    TaskStepType.attachRfid => l10n.t('taskActionAttachRfid', '模拟读取 RFID'),
    TaskStepType.scanRfid => l10n.t('taskActionScanRfid', '模拟扫描 RFID'),
    TaskStepType.captureFront => l10n.t('taskActionCaptureFront', '拍摄正面'),
    TaskStepType.captureBack => l10n.t('taskActionCaptureBack', '拍摄反面'),
    TaskStepType.runOcr => l10n.t('taskActionRunOcr', '执行 OCR 并确认'),
    TaskStepType.verifyPickupCode => l10n.t(
      'taskActionVerifyPickupCode',
      '确认取件码',
    ),
    TaskStepType.reviewPendingItems => l10n.t(
      'taskActionReviewPendingItems',
      '确认待办列表',
    ),
    TaskStepType.verifyInventoryCode => l10n.t(
      'taskActionVerifyInventoryCode',
      '验证飞检码',
    ),
    TaskStepType.inventoryBySlot => l10n.t(
      'taskActionInventoryBySlot',
      '进入盘点明细',
    ),
    TaskStepType.assignSlot =>
      taskType == TaskType.storeEvidence || taskType == TaskType.returnEvidence
          ? l10n.t('taskActionAssignSlot', '请求平台分箱')
          : l10n.t('taskActionAuthorizeSlot', '确认平台授权箱格'),
    TaskStepType.openDoor => l10n.t('taskActionOpenDoor', '通知打开柜门'),
    TaskStepType.transferWithinDeadline => l10n.t(
      'taskActionTransferDone',
      '确认本次存取或盘点完成',
    ),
    TaskStepType.closeDoorAndReport => l10n.t(
      'taskActionCloseDoorAndReport',
      '确认已关门并上报',
    ),
  };
}

/// 返回步骤图标。
IconData _stepIcon(TaskStepType? step) {
  return switch (step) {
    TaskStepType.attachRfid || TaskStepType.scanRfid => Icons.nfc_rounded,
    TaskStepType.captureFront ||
    TaskStepType.captureBack => Icons.camera_alt_outlined,
    TaskStepType.runOcr => Icons.document_scanner_outlined,
    TaskStepType.verifyPickupCode => Icons.pin_outlined,
    TaskStepType.reviewPendingItems => Icons.list_alt_rounded,
    TaskStepType.verifyInventoryCode => Icons.password_rounded,
    TaskStepType.inventoryBySlot => Icons.grid_view_rounded,
    TaskStepType.assignSlot => Icons.grid_view_rounded,
    TaskStepType.openDoor => Icons.lock_open_rounded,
    TaskStepType.transferWithinDeadline => Icons.timer_outlined,
    TaskStepType.closeDoorAndReport => Icons.lock_rounded,
    null => Icons.check_rounded,
  };
}
