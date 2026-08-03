import 'dart:async';

import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/theme/app_theme.dart';
import 'package:smart_cabinet/src/core/device/cabinet_door_guard.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/task_center/domain/entities/cabinet_task.dart';
import 'package:smart_cabinet/src/features/task_center/domain/repositories/task_center_repository.dart';

/// 箱格级盘点主面板，负责飞检码、抽中箱格和箱内明细流程。
class InventoryTaskPanel extends StatefulWidget {
  /// 创建盘点主面板。
  const InventoryTaskPanel({
    super.key,
    required this.task,
    required this.account,
    required this.repository,
    required this.doorGuard,
    required this.onTaskChanged,
    required this.onDoorStateChanged,
    required this.onTaskReadyToComplete,
  });

  /// 当前盘点任务快照。
  final CabinetTask task;

  /// 已完成双因子认证的操作员。
  final OperatorAccount account;

  /// 盘点操作使用的任务仓库。
  final TaskCenterRepository repository;

  /// 应用级单柜门互锁器。
  final CabinetDoorGuard doorGuard;

  /// 盘点任务状态变化通知。
  final ValueChanged<CabinetTask> onTaskChanged;

  /// 柜门取得或释放互锁后的状态通知。
  final ValueChanged<bool> onDoorStateChanged;

  /// 全部抽中箱格完成后的整单提交回调。
  final Future<void> Function(CabinetTask task) onTaskReadyToComplete;

  @override
  State<InventoryTaskPanel> createState() => _InventoryTaskPanelState();
}

/// 管理飞检码校验、箱格开门和异常恢复。
class _InventoryTaskPanelState extends State<InventoryTaskPanel> {
  final TextEditingController _inspectionCodeController =
      TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _inspectionCodeController.dispose();
    super.dispose();
  }

  /// 校验平台飞检码，错误码不会推进盘点状态。
  Future<void> _verifyInspectionCode() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updatedTask = await widget.repository.verifyInventoryCode(
        account: widget.account,
        taskId: widget.task.id,
        inspectionCode: _inspectionCodeController.text,
      );
      if (!mounted) {
        return;
      }
      _inspectionCodeController.clear();
      widget.onTaskChanged(updatedTask);
      setState(() => _busy = false);
    } on InventoryCodeVerificationException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = _inventoryCodeError(context, error.reason);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = '$error';
      });
    }
  }

  /// 打开抽中箱格或查看已经完成的只读盘点明细。
  Future<void> _openSlot(String doorNo) async {
    if (_busy) {
      return;
    }
    final status = widget.task.inventorySlotStatus(doorNo);
    if (status == InventorySlotStatus.notRequired) {
      return;
    }
    if (status == InventorySlotStatus.completed ||
        status == InventorySlotStatus.abnormal) {
      await showDialog<void>(
        context: context,
        builder: (context) =>
            _InventoryCompletedSlotDialog(task: widget.task, doorNo: doorNo),
      );
      return;
    }
    if (widget.task.pendingClosedDoorNo == doorNo) {
      await _resumePendingSettlement(doorNo);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    var guardAcquired = false;
    String? operationId;
    try {
      final binding = await widget.repository.validateInventoryDoorOpen(
        account: widget.account,
        taskId: widget.task.id,
        doorNo: doorNo,
      );
      if (!mounted) {
        return;
      }
      operationId = widget.doorGuard.createOperationId(widget.task.id);
      final guardResult = widget.doorGuard.requestOpen(
        binding.doorNo,
        operationId: operationId,
      );
      if (guardResult is CabinetDoorOpenConflict) {
        setState(() {
          _busy = false;
          _error = context.l10n
              .t(
                'taskExecutionAnotherDoorOpen',
                '柜门 {activeDoorNo} 尚未关闭，不能打开 {requestedDoorNo}',
              )
              .replaceAll('{activeDoorNo}', guardResult.activeDoorNo)
              .replaceAll('{requestedDoorNo}', doorNo);
        });
        return;
      }
      guardAcquired = true;
      widget.onDoorStateChanged(true);
      final startedTask = await widget.repository.startInventoryDoor(
        account: widget.account,
        taskId: widget.task.id,
        doorNo: doorNo,
      );
      if (!mounted) {
        return;
      }
      widget.onTaskChanged(startedTask);
      setState(() => _busy = false);

      final updatedTask = await showDialog<CabinetTask>(
        context: context,
        barrierDismissible: false,
        builder: (context) => InventorySlotDetailDialog(
          initialTask: startedTask,
          doorNo: doorNo,
          account: widget.account,
          repository: widget.repository,
          doorGuard: widget.doorGuard,
          doorOperationId: operationId!,
          initialDoorClosedConfirmed: false,
          onTaskChanged: widget.onTaskChanged,
          onDoorStateChanged: widget.onDoorStateChanged,
        ),
      );
      if (!mounted || updatedTask == null) {
        return;
      }
      guardAcquired = false;
      widget.onDoorStateChanged(false);
      widget.onTaskChanged(updatedTask);
      if (updatedTask.currentStep == null) {
        await widget.onTaskReadyToComplete(updatedTask);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = '$error';
      });
      if (guardAcquired && operationId != null) {
        await _confirmRecoveryDoorClosed(doorNo, operationId);
      }
    }
  }

  /// 门已安全关闭但平台尚未结算时，不重新开门，直接恢复幂等结算弹窗。
  Future<void> _resumePendingSettlement(String doorNo) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updatedTask = await showDialog<CabinetTask>(
        context: context,
        barrierDismissible: false,
        builder: (context) => InventorySlotDetailDialog(
          initialTask: widget.task,
          doorNo: doorNo,
          account: widget.account,
          repository: widget.repository,
          doorGuard: widget.doorGuard,
          doorOperationId: null,
          initialDoorClosedConfirmed: true,
          onTaskChanged: widget.onTaskChanged,
          onDoorStateChanged: widget.onDoorStateChanged,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      if (updatedTask == null) {
        return;
      }
      widget.onTaskChanged(updatedTask);
      if (updatedTask.currentStep == null) {
        await widget.onTaskReadyToComplete(updatedTask);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = '$error';
      });
    }
  }

  /// 开门后仓库异常时等待人工确认关门，不自动释放互锁。
  Future<void> _confirmRecoveryDoorClosed(
    String doorNo,
    String operationId,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(
            context.l10n.t('taskInventoryDoorRecoveryTitle', '请先确认柜门已关闭'),
          ),
          content: Text(
            context.l10n
                .t(
                  'taskInventoryDoorRecoveryHint',
                  '箱格 {doorNo} 已取得开门资格，但盘点状态更新失败。确认柜门已经关闭后才能退出。',
                )
                .replaceAll('{doorNo}', doorNo),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                if (!widget.doorGuard.markClosed(
                  doorNo,
                  operationId: operationId,
                )) {
                  return;
                }
                widget.onDoorStateChanged(false);
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                context.l10n.t('taskInventoryConfirmDoorClosed', '确认柜门已关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final plan = task.inventoryPlan;
    if (plan == null) {
      return _InventoryMissingPlanPanel(error: _error);
    }
    if (!plan.codeVerified) {
      return _InventoryCodePanel(
        controller: _inspectionCodeController,
        busy: _busy,
        error: _error,
        onSubmit: _verifyInspectionCode,
      );
    }
    return _InventorySlotGridPanel(
      task: task,
      busy: _busy,
      error: _error,
      onOpenSlot: _openSlot,
    );
  }
}

/// 飞检码输入面板。
class _InventoryCodePanel extends StatelessWidget {
  const _InventoryCodePanel({
    required this.controller,
    required this.busy,
    required this.error,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool busy;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Container(
        key: const ValueKey('inventory_code_panel'),
        width: 650,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.outlineColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.fact_check_outlined,
              color: AppTheme.primaryColor,
              size: 62,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.t('taskInventoryCodeTitle', '输入飞检码'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.t(
                'taskInventoryCodeDescription',
                '飞检码仅用于确认本次盘点计划，验证通过后按平台抽中的箱格整箱盘点。',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              key: const ValueKey('inventory_code_input'),
              controller: controller,
              keyboardType: TextInputType.number,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                labelText: l10n.t('taskInventoryCodeInput', '飞检码'),
                hintText: l10n.t('taskInventoryCodeHint', '请输入平台下发的飞检码'),
                prefixIcon: const Icon(Icons.password_rounded),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              _InventoryErrorBanner(message: error!),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: AppTheme.touchTargetSize,
              child: ElevatedButton.icon(
                key: const ValueKey('inventory_verify_code'),
                onPressed: busy ? null : onSubmit,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.verified_outlined),
                label: Text(
                  busy
                      ? l10n.t('taskExecutionProcessing', '处理中...')
                      : l10n.t('taskInventoryVerifyCode', '验证并查看盘点明细'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 盘点计划说明、颜色图例和箱格按钮网格。
class _InventorySlotGridPanel extends StatelessWidget {
  const _InventorySlotGridPanel({
    required this.task,
    required this.busy,
    required this.error,
    required this.onOpenSlot,
  });

  final CabinetTask task;
  final bool busy;
  final String? error;
  final ValueChanged<String> onOpenSlot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final plan = task.inventoryPlan!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 320,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.outlineColor),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.t('taskInventoryPlanTitle', '盘点计划'),
                    style: const TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _samplingModeText(context, plan),
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n
                        .t(
                          'taskInventorySamplingSummary',
                          '已完成 {completed} / {required} 箱，共展示 {total} 箱',
                        )
                        .replaceAll('{completed}', '${plan.completedDoorCount}')
                        .replaceAll('{required}', '${plan.requiredDoorCount}')
                        .replaceAll('{total}', '${plan.allDoorNos.length}'),
                    style: const TextStyle(
                      color: AppTheme.textSecondaryColor,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoftColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.t(
                        'taskInventorySamplingRuleHint',
                        '比例按箱格计算；抽中箱格后，箱内全部证件必须全盘。指定证件时，其所在箱格全部纳入。',
                      ),
                      style: const TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.t('taskInventoryLegendTitle', '状态说明'),
                    style: const TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final status in InventorySlotStatus.values)
                    _InventoryLegendItem(status: status),
                  const SizedBox(height: 10),
                  Text(
                    l10n.t(
                      'taskInventoryPhotoPolicy',
                      '正常证件不逐件拍照；建议开关箱保留箱内全景，缺失或溢余时补拍异常照片。当前为流程模拟。',
                    ),
                    style: const TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Container(
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
                        l10n.t('taskInventoryDetailsTitle', '盘点明细'),
                        style: const TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      l10n.t('taskInventorySelectSlotHint', '点击蓝色箱格开始盘点'),
                      style: const TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  _InventoryErrorBanner(message: error!),
                ],
                const SizedBox(height: 18),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 760
                          ? 4
                          : constraints.maxWidth >= 520
                          ? 3
                          : 2;
                      return GridView.builder(
                        key: const ValueKey('inventory_slot_grid'),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 1.45,
                        ),
                        itemCount: plan.allDoorNos.length,
                        itemBuilder: (context, index) {
                          final doorNo = plan.allDoorNos[index];
                          final status = task.inventorySlotStatus(doorNo);
                          return _InventorySlotButton(
                            task: task,
                            doorNo: doorNo,
                            status: status,
                            enabled:
                                !busy &&
                                status != InventorySlotStatus.notRequired,
                            onPressed: () => onOpenSlot(doorNo),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 单个箱格按钮，颜色与文字共同表达盘点状态。
class _InventorySlotButton extends StatelessWidget {
  const _InventorySlotButton({
    required this.task,
    required this.doorNo,
    required this.status,
    required this.enabled,
    required this.onPressed,
  });

  final CabinetTask task;
  final String doorNo;
  final InventorySlotStatus status;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = _InventorySlotPalette.forStatus(status);
    final expectedItems = task
        .inventoryItemsForDoor(doorNo)
        .where((item) => !item.isInventorySurplus)
        .length;
    final pendingItems = task.inventoryPendingCount(doorNo);
    final differenceCount = task
        .inventoryItemsForDoor(doorNo)
        .where(
          (item) =>
              item.inventoryResult == InventoryItemResult.missing ||
              item.inventoryResult == InventoryItemResult.surplus,
        )
        .length;
    final metricText = switch (status) {
      InventorySlotStatus.notRequired => null,
      InventorySlotStatus.completed =>
        context.l10n
            .t('taskInventorySlotCheckedCount', '已盘：{count}')
            .replaceAll('{count}', '$expectedItems'),
      InventorySlotStatus.abnormal =>
        context.l10n
            .t('taskInventorySlotDifferenceCount', '差异：{count}')
            .replaceAll('{count}', '$differenceCount'),
      InventorySlotStatus.pending ||
      InventorySlotStatus.inProgress ||
      InventorySlotStatus.partiallyChecked =>
        context.l10n
            .t('taskInventorySlotPendingCount', '待盘：{count}')
            .replaceAll('{count}', '$pendingItems'),
    };
    return Material(
      color: palette.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey('inventory_slot_$doorNo'),
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#$doorNo',
                      style: TextStyle(
                        color: palette.foreground,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Icon(
                    _inventorySlotIcon(status),
                    color: palette.foreground,
                    size: 22,
                  ),
                ],
              ),
              const Spacer(),
              if (metricText != null)
                Text(
                  metricText,
                  style: TextStyle(
                    color: palette.foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              if (metricText != null) const SizedBox(height: 4),
              Text(
                _inventorySlotStatusText(context, status),
                style: TextStyle(
                  color: palette.foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 打开箱格后的 RFID 明细弹窗。
class InventorySlotDetailDialog extends StatefulWidget {
  /// 创建箱内证件盘点弹窗。
  const InventorySlotDetailDialog({
    super.key,
    required this.initialTask,
    required this.doorNo,
    required this.account,
    required this.repository,
    required this.doorGuard,
    required this.doorOperationId,
    required this.initialDoorClosedConfirmed,
    required this.onTaskChanged,
    required this.onDoorStateChanged,
  });

  /// 开箱后的任务快照。
  final CabinetTask initialTask;

  /// 当前已打开的箱格编号。
  final String doorNo;

  /// 当前认证操作员。
  final OperatorAccount account;

  /// 盘点仓库。
  final TaskCenterRepository repository;

  /// 应用级柜门互锁器。
  final CabinetDoorGuard doorGuard;

  /// 当前箱格这一次开门周期的唯一互锁操作 ID。
  final String? doorOperationId;

  /// 是否从“实物已关、等待平台结算”的持久化状态恢复弹窗。
  final bool initialDoorClosedConfirmed;

  /// 扫码后向外同步任务状态。
  final ValueChanged<CabinetTask> onTaskChanged;

  /// 明确关门后向外同步柜门状态。
  final ValueChanged<bool> onDoorStateChanged;

  @override
  State<InventorySlotDetailDialog> createState() =>
      _InventorySlotDetailDialogState();
}

/// 管理箱内 RFID 扫描、30 秒报警和关门结算。
class _InventorySlotDetailDialogState extends State<InventorySlotDetailDialog> {
  static const int _doorTimeoutSeconds = 30;

  late CabinetTask _task = widget.initialTask;
  final TextEditingController _rfidController = TextEditingController();
  Timer? _doorTimer;
  int _seconds = _doorTimeoutSeconds;
  bool _alarm = false;
  bool _busy = false;
  late bool _doorClosedConfirmed = widget.initialDoorClosedConfirmed;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_doorClosedConfirmed) {
      _seconds = 0;
      return;
    }
    _doorTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _doorClosedConfirmed) {
        return;
      }
      if (_seconds <= 1) {
        _doorTimer?.cancel();
        _doorTimer = null;
        setState(() {
          _seconds = 0;
          _alarm = true;
        });
        return;
      }
      setState(() => _seconds -= 1);
    });
  }

  @override
  void dispose() {
    _doorTimer?.cancel();
    _rfidController.dispose();
    super.dispose();
  }

  /// 记录 RFID；匹配项标正常，未知项幂等新增为溢余。
  Future<void> _scanRfid([String? simulatedRfid]) async {
    if (_busy || _doorClosedConfirmed) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updatedTask = await widget.repository.scanInventoryRfid(
        account: widget.account,
        taskId: _task.id,
        doorNo: widget.doorNo,
        rfid: simulatedRfid ?? _rfidController.text,
      );
      if (!mounted) {
        return;
      }
      _rfidController.clear();
      widget.onTaskChanged(updatedTask);
      setState(() {
        _task = updatedTask;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = '$error';
      });
    }
  }

  /// 人工确认实物放回并关门后，结算正常、缺失和溢余结果。
  Future<void> _closeDoorAndComplete() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    if (!_doorClosedConfirmed) {
      final operationId = widget.doorOperationId;
      if (operationId == null) {
        setState(() {
          _busy = false;
          _error = context.l10n.t(
            'taskExecutionDoorStateMismatch',
            '柜门状态与当前任务不一致，柜门互锁未释放',
          );
        });
        return;
      }
      final recordedTask = await _recordDoorClosedForSettlement();
      if (recordedTask == null || !mounted) {
        return;
      }
      final released = widget.doorGuard.markClosed(
        widget.doorNo,
        operationId: operationId,
      );
      if (!released) {
        setState(() {
          _busy = false;
          _error = context.l10n.t(
            'taskExecutionDoorStateMismatch',
            '柜门状态与当前任务不一致，柜门互锁未释放',
          );
        });
        return;
      }
      _doorClosedConfirmed = true;
      _task = recordedTask;
      _doorTimer?.cancel();
      _doorTimer = null;
      widget.onTaskChanged(recordedTask);
      widget.onDoorStateChanged(false);
    }

    try {
      CabinetTask updatedTask;
      try {
        updatedTask = await widget.repository.completeInventoryDoor(
          account: widget.account,
          taskId: _task.id,
          doorNo: widget.doorNo,
        );
      } catch (error, stackTrace) {
        final latestTask = await widget.repository.fetchTask(
          account: widget.account,
          taskId: _task.id,
        );
        final committed =
            latestTask.pendingClosedDoorNo == null &&
            (latestTask.inventoryPlan?.completedDoorNos.contains(
                  widget.doorNo,
                ) ??
                false);
        if (!committed) {
          if (mounted) {
            setState(() => _task = latestTask);
          }
          Error.throwWithStackTrace(error, stackTrace);
        }
        updatedTask = latestTask;
      }
      if (!mounted) {
        return;
      }
      widget.onTaskChanged(updatedTask);
      Navigator.of(context).pop(updatedTask);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = '$error';
      });
    }
  }

  /// 在释放互锁前持久化门已关闭事实，响应丢失时通过回读确认写入结果。
  Future<CabinetTask?> _recordDoorClosedForSettlement() async {
    try {
      return await widget.repository.recordDoorClosedPendingReport(
        account: widget.account,
        taskId: _task.id,
        doorNo: widget.doorNo,
      );
    } catch (error) {
      try {
        final latestTask = await widget.repository.fetchTask(
          account: widget.account,
          taskId: _task.id,
        );
        if (latestTask.pendingClosedDoorNo == widget.doorNo) {
          return latestTask;
        }
      } catch (_) {
        // 回读仍失败时保留互锁，不能推定关门状态已经持久化。
      }
      if (!mounted) {
        return null;
      }
      setState(() {
        _busy = false;
        _error = '$error';
      });
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = _task.inventoryItemsForDoor(widget.doorNo);
    final pendingExpectedItems = items
        .where(
          (item) =>
              !item.isInventorySurplus &&
              item.inventoryResult == InventoryItemResult.pending &&
              item.rfid != null,
        )
        .toList(growable: false);
    final slotStatus = _task.inventorySlotStatus(widget.doorNo);
    final slotPalette = _InventorySlotPalette.forStatus(slotStatus);
    return PopScope(
      canPop: _doorClosedConfirmed,
      child: Dialog(
        key: const ValueKey('inventory_slot_dialog'),
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 1120,
          height: 680,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n
                                .t(
                                  'taskInventorySlotDetailTitle',
                                  '箱格 #{doorNo} 证件明细',
                                )
                                .replaceAll('{doorNo}', widget.doorNo),
                            style: const TextStyle(
                              color: AppTheme.textPrimaryColor,
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            l10n.t(
                              'taskInventorySlotDetailHint',
                              '逐一扫描箱内全部 RFID；未扫到的预期证件将在关箱时标记为缺失。',
                            ),
                            style: const TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      key: const ValueKey('inventory_active_slot_status'),
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: slotPalette.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: slotPalette.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _inventorySlotIcon(slotStatus),
                            color: slotPalette.foreground,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _inventorySlotStatusText(context, slotStatus),
                            style: TextStyle(
                              color: slotPalette.foreground,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _InventoryDoorTimer(
                      doorNo: widget.doorNo,
                      seconds: _doorClosedConfirmed ? 0 : _seconds,
                      alarm: _alarm,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('inventory_rfid_input'),
                        controller: _rfidController,
                        enabled: !_doorClosedConfirmed,
                        onSubmitted: (_) => _scanRfid(),
                        decoration: InputDecoration(
                          labelText: l10n.t(
                            'taskInventoryScanRfidInput',
                            '扫描 RFID',
                          ),
                          hintText: l10n.t(
                            'taskInventoryScanRfidHint',
                            '请使用 RFID 设备扫描，或输入演示值',
                          ),
                          prefixIcon: const Icon(Icons.nfc_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: AppTheme.touchTargetSize,
                      child: ElevatedButton.icon(
                        key: const ValueKey('inventory_scan_rfid'),
                        onPressed: _busy || _doorClosedConfirmed
                            ? null
                            : _scanRfid,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: Text(
                          l10n.t('taskInventoryScanRfidAction', '确认扫描'),
                        ),
                      ),
                    ),
                  ],
                ),
                if (pendingExpectedItems.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text(
                          l10n.t('taskInventoryDemoScan', '演示快速扫描：'),
                          style: const TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        for (final item in pendingExpectedItems) ...[
                          ActionChip(
                            key: ValueKey(
                              'inventory_scan_expected_${item.rfid}',
                            ),
                            onPressed: _busy || _doorClosedConfirmed
                                ? null
                                : () => _scanRfid(item.rfid),
                            avatar: const Icon(Icons.nfc_rounded, size: 16),
                            label: Text(item.rfid!),
                          ),
                          const SizedBox(width: 8),
                        ],
                        ActionChip(
                          key: const ValueKey('inventory_scan_surplus_demo'),
                          onPressed: _busy || _doorClosedConfirmed
                              ? null
                              : () => _scanRfid('RFID-EXTRA-${widget.doorNo}'),
                          avatar: const Icon(
                            Icons.add_circle_outline_rounded,
                            size: 16,
                          ),
                          label: Text(
                            l10n.t('taskInventoryDemoSurplus', '模拟溢余'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  _InventoryErrorBanner(message: _error!),
                ],
                const SizedBox(height: 14),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.outlineColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            AppTheme.surfaceColor,
                          ),
                          columns: [
                            DataColumn(
                              label: Text(
                                l10n.t('taskInventorySequenceColumn', '序号'),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                l10n.t(
                                  'taskInventoryDocumentCodeColumn',
                                  '合格证编号',
                                ),
                              ),
                            ),
                            const DataColumn(label: Text('RFID')),
                            DataColumn(
                              label: Text(
                                l10n.t('taskInventoryResultColumn', '盘点结果'),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                l10n.t(
                                  'taskInventoryReturnStatusColumn',
                                  '放回状态',
                                ),
                              ),
                            ),
                          ],
                          rows: [
                            for (var index = 0; index < items.length; index++)
                              _inventoryDataRow(
                                context,
                                index: index,
                                item: items[index],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.t(
                          'taskInventoryCloseRuleHint',
                          '确认关箱将把未扫描证件标记为缺失，并把正常及溢余实物标记为已放回。',
                        ),
                        style: const TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_doorClosedConfirmed && _error != null) ...[
                      const SizedBox(width: 10),
                      SizedBox(
                        height: AppTheme.touchTargetSize,
                        child: OutlinedButton.icon(
                          key: const ValueKey(
                            'inventory_return_with_pending_report',
                          ),
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).pop(_task),
                          icon: const Icon(Icons.save_outlined),
                          label: Text(
                            l10n.t(
                              'taskInventoryReturnWithPendingReport',
                              '保存待上报状态并返回',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    SizedBox(
                      height: AppTheme.touchTargetSize,
                      child: ElevatedButton.icon(
                        key: const ValueKey('inventory_close_door'),
                        onPressed: _busy ? null : _closeDoorAndComplete,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.lock_rounded),
                        label: Text(
                          _doorClosedConfirmed
                              ? l10n.t('taskInventoryRetrySettlement', '重试盘点结算')
                              : l10n.t(
                                  'taskInventoryCloseDoorAction',
                                  '确认全部放回并关箱',
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 已完成箱格的只读盘点结果弹窗。
class _InventoryCompletedSlotDialog extends StatelessWidget {
  const _InventoryCompletedSlotDialog({
    required this.task,
    required this.doorNo,
  });

  final CabinetTask task;
  final String doorNo;

  @override
  Widget build(BuildContext context) {
    final items = task.inventoryItemsForDoor(doorNo);
    return AlertDialog(
      key: const ValueKey('inventory_completed_slot_dialog'),
      title: Text(
        context.l10n
            .t('taskInventoryCompletedDetailTitle', '箱格 #{doorNo} 盘点结果')
            .replaceAll('{doorNo}', doorNo),
      ),
      content: SizedBox(
        width: 900,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(
                label: Text(
                  context.l10n.t('taskInventorySequenceColumn', '序号'),
                ),
              ),
              DataColumn(
                label: Text(
                  context.l10n.t('taskInventoryDocumentCodeColumn', '合格证编号'),
                ),
              ),
              const DataColumn(label: Text('RFID')),
              DataColumn(
                label: Text(
                  context.l10n.t('taskInventoryResultColumn', '盘点结果'),
                ),
              ),
              DataColumn(
                label: Text(
                  context.l10n.t('taskInventoryReturnStatusColumn', '放回状态'),
                ),
              ),
            ],
            rows: [
              for (var index = 0; index < items.length; index++)
                _inventoryDataRow(context, index: index, item: items[index]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('inventory_close_completed_detail'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.t('taskInventoryCloseDetail', '关闭')),
        ),
      ],
    );
  }
}

/// 柜门倒计时，超时只报警，不释放互锁也不标记缺失。
class _InventoryDoorTimer extends StatelessWidget {
  const _InventoryDoorTimer({
    required this.doorNo,
    required this.seconds,
    required this.alarm,
  });

  final String doorNo;
  final int seconds;
  final bool alarm;

  @override
  Widget build(BuildContext context) {
    final color = alarm ? const Color(0xFFB42318) : const Color(0xFFC46A00);
    return Container(
      key: const ValueKey('inventory_door_countdown'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: alarm ? const Color(0xFFFFE9E7) : const Color(0xFFFFF6E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            alarm ? Icons.notifications_active_rounded : Icons.timer_outlined,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            alarm
                ? context.l10n
                      .t(
                        'taskExecutionDoorTimeoutAlarm',
                        '柜门 {doorNo} 超时未关闭，请立即处理',
                      )
                      .replaceAll('{doorNo}', doorNo)
                : context.l10n
                      .t(
                        'taskInventoryDoorCountdown',
                        '箱格 {doorNo}：{seconds} 秒',
                      )
                      .replaceAll('{doorNo}', doorNo)
                      .replaceAll('{seconds}', '$seconds'),
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

/// 盘点计划缺失提示。
class _InventoryMissingPlanPanel extends StatelessWidget {
  const _InventoryMissingPlanPanel({required this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        error ?? context.l10n.t('taskInventoryPlanMissing', '平台未下发盘点计划'),
        style: const TextStyle(
          color: Color(0xFFB42318),
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// 盘点操作错误横幅。
class _InventoryErrorBanner extends StatelessWidget {
  const _InventoryErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEEE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFB42318),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// 箱格状态图例行。
class _InventoryLegendItem extends StatelessWidget {
  const _InventoryLegendItem({required this.status});

  final InventorySlotStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = _InventorySlotPalette.forStatus(status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: palette.border),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _inventorySlotStatusText(context, status),
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 箱格状态使用的背景、边框和前景色。
final class _InventorySlotPalette {
  const _InventorySlotPalette({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;

  /// 按业务状态返回固定色板。
  factory _InventorySlotPalette.forStatus(InventorySlotStatus status) {
    return switch (status) {
      InventorySlotStatus.notRequired => const _InventorySlotPalette(
        background: Color(0xFFF0F2F5),
        border: Color(0xFFC8CDD6),
        foreground: Color(0xFF7B8494),
      ),
      InventorySlotStatus.pending => const _InventorySlotPalette(
        background: Color(0xFFEAF2FF),
        border: Color(0xFF5B8DEF),
        foreground: Color(0xFF2458B8),
      ),
      InventorySlotStatus.inProgress => const _InventorySlotPalette(
        background: Color(0xFFFFF0DD),
        border: Color(0xFFF09A32),
        foreground: Color(0xFF9A5400),
      ),
      InventorySlotStatus.partiallyChecked => const _InventorySlotPalette(
        background: Color(0xFFE5F6E9),
        border: Color(0xFF78C88B),
        foreground: Color(0xFF347A46),
      ),
      InventorySlotStatus.completed => const _InventorySlotPalette(
        background: Color(0xFFDDF4E5),
        border: Color(0xFF2FA65A),
        foreground: Color(0xFF18753A),
      ),
      InventorySlotStatus.abnormal => const _InventorySlotPalette(
        background: Color(0xFFFFE5E2),
        border: Color(0xFFE05252),
        foreground: Color(0xFFB42318),
      ),
    };
  }
}

/// 生成盘点明细表中的一行。
DataRow _inventoryDataRow(
  BuildContext context, {
  required int index,
  required TaskItem item,
}) {
  final resultColor = switch (item.inventoryResult) {
    InventoryItemResult.pending => AppTheme.textSecondaryColor,
    InventoryItemResult.normal => const Color(0xFF18753A),
    InventoryItemResult.missing ||
    InventoryItemResult.surplus => const Color(0xFFB42318),
  };
  return DataRow(
    key: ValueKey('inventory_item_${item.id}'),
    cells: [
      DataCell(Text('${index + 1}')),
      DataCell(
        Text(
          item.isInventorySurplus
              ? context.l10n.t('taskInventorySurplusDocument', '未登记证件')
              : item.documentCode,
        ),
      ),
      DataCell(Text(item.rfid ?? '-')),
      DataCell(
        Text(
          _inventoryResultText(context, item.inventoryResult),
          style: TextStyle(color: resultColor, fontWeight: FontWeight.w900),
        ),
      ),
      DataCell(
        Text(
          _inventoryReturnStatusText(context, item.inventoryReturnStatus),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

/// 返回飞检码错误的安全提示。
String _inventoryCodeError(
  BuildContext context,
  InventoryCodeFailureReason reason,
) {
  return switch (reason) {
    InventoryCodeFailureReason.empty => context.l10n.t(
      'taskInventoryCodeEmpty',
      '请输入飞检码',
    ),
    InventoryCodeFailureReason.incorrect => context.l10n.t(
      'taskInventoryCodeIncorrect',
      '飞检码错误，请重新输入',
    ),
    InventoryCodeFailureReason.notConfigured => context.l10n.t(
      'taskInventoryCodeNotConfigured',
      '当前盘点任务未配置飞检码，请联系平台处理',
    ),
    InventoryCodeFailureReason.stepNotPending ||
    InventoryCodeFailureReason.dedicatedEntryRequired => context.l10n.t(
      'taskInventoryCodeUnavailable',
      '当前步骤无法校验飞检码，请刷新任务',
    ),
  };
}

/// 返回盘点抽样方式说明。
String _samplingModeText(BuildContext context, InventoryPlan plan) {
  return switch (plan.samplingMode) {
    InventorySamplingMode.full => context.l10n.t(
      'taskInventorySamplingFull',
      '全部箱格盘点',
    ),
    InventorySamplingMode.byBoxRatio =>
      context.l10n
          .t('taskInventorySamplingByBoxRatio', '按箱格比例抽盘 {percent}%')
          .replaceAll(
            '{percent}',
            '${((plan.boxSampleRatio ?? 0) * 100).round()}',
          ),
    InventorySamplingMode.specifiedDocuments => context.l10n.t(
      'taskInventorySamplingSpecifiedDocuments',
      '指定证件所在箱格整箱盘点',
    ),
  };
}

/// 返回箱格状态文案。
String _inventorySlotStatusText(
  BuildContext context,
  InventorySlotStatus status,
) {
  return switch (status) {
    InventorySlotStatus.notRequired => context.l10n.t(
      'taskInventorySlotNotRequired',
      '无需盘点',
    ),
    InventorySlotStatus.pending => context.l10n.t(
      'taskInventorySlotPending',
      '待盘点',
    ),
    InventorySlotStatus.inProgress => context.l10n.t(
      'taskInventorySlotInProgress',
      '正在盘点',
    ),
    InventorySlotStatus.partiallyChecked => context.l10n.t(
      'taskInventorySlotPartiallyChecked',
      '部分已盘',
    ),
    InventorySlotStatus.completed => context.l10n.t(
      'taskInventorySlotCompleted',
      '盘点正确',
    ),
    InventorySlotStatus.abnormal => context.l10n.t(
      'taskInventorySlotAbnormal',
      '已盘 · 有差异',
    ),
  };
}

/// 返回盘点结果文案。
String _inventoryResultText(BuildContext context, InventoryItemResult result) {
  return switch (result) {
    InventoryItemResult.pending => context.l10n.t(
      'taskInventoryResultPending',
      '待扫描',
    ),
    InventoryItemResult.normal => context.l10n.t(
      'taskInventoryResultNormal',
      '正常',
    ),
    InventoryItemResult.missing => context.l10n.t(
      'taskInventoryResultMissing',
      '缺失',
    ),
    InventoryItemResult.surplus => context.l10n.t(
      'taskInventoryResultSurplus',
      '溢余',
    ),
  };
}

/// 返回证件放回状态文案。
String _inventoryReturnStatusText(
  BuildContext context,
  InventoryReturnStatus status,
) {
  return switch (status) {
    InventoryReturnStatus.notRequired => context.l10n.t(
      'taskInventoryReturnNotRequired',
      '未发现 / 无需放回',
    ),
    InventoryReturnStatus.waiting => context.l10n.t(
      'taskInventoryReturnWaiting',
      '等待放回',
    ),
    InventoryReturnStatus.returned => context.l10n.t(
      'taskInventoryReturnReturned',
      '已放回',
    ),
  };
}

/// 返回箱格状态图标。
IconData _inventorySlotIcon(InventorySlotStatus status) {
  return switch (status) {
    InventorySlotStatus.notRequired => Icons.remove_circle_outline_rounded,
    InventorySlotStatus.pending => Icons.inventory_2_outlined,
    InventorySlotStatus.inProgress => Icons.lock_open_rounded,
    InventorySlotStatus.partiallyChecked => Icons.pending_actions_rounded,
    InventorySlotStatus.completed => Icons.check_circle_rounded,
    InventorySlotStatus.abnormal => Icons.error_rounded,
  };
}
