import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/shell/app_shell.dart';
import 'package:smart_cabinet/src/features/flight_inspection/data/repositories/flight_inspection_repository_impl.dart';

/// 飞检柜门任务状态。
enum _InspectionTaskStatus { waiting, inspecting, completed }

/// 后台下发到智能柜内存的飞检柜门任务。
class _InspectionCabinetTask {
  /// 创建飞检柜门任务。
  const _InspectionCabinetTask({
    required this.doorNo,
    required this.fileCode,
    required this.secretLevel,
    required this.department,
    required this.status,
  });

  /// 柜门编号。
  final String doorNo;

  /// 文件编号。
  final String fileCode;

  /// 文件密级。
  final String secretLevel;

  /// 责任部门。
  final String department;

  /// 当前飞检状态。
  final _InspectionTaskStatus status;

  /// 返回更新状态后的新任务对象。
  _InspectionCabinetTask copyWith({_InspectionTaskStatus? status}) {
    return _InspectionCabinetTask(
      doorNo: doorNo,
      fileCode: fileCode,
      secretLevel: secretLevel,
      department: department,
      status: status ?? this.status,
    );
  }
}

/// 飞检柜门列表页。
class FlightInspectionTaskPage extends StatefulWidget {
  /// 创建飞检柜门列表页。
  const FlightInspectionTaskPage({super.key});

  @override
  State<FlightInspectionTaskPage> createState() =>
      _FlightInspectionTaskPageState();
}

class _FlightInspectionTaskPageState extends State<FlightInspectionTaskPage> {
  /// 飞检任务批次号。
  String _batchNo = 'FI-20260616-01';

  /// 模拟后台通过网络下发并驻留在智能柜内存中的固定飞检任务。
  late final List<_InspectionCabinetTask> _tasks = [
    const _InspectionCabinetTask(
      doorNo: 'A-03',
      fileCode: 'FILE-2026-FI-003',
      secretLevel: '机密',
      department: '法务合规部',
      status: _InspectionTaskStatus.waiting,
    ),
    const _InspectionCabinetTask(
      doorNo: 'A-08',
      fileCode: 'FILE-2026-FI-008',
      secretLevel: '秘密',
      department: '财务管理部',
      status: _InspectionTaskStatus.waiting,
    ),
    const _InspectionCabinetTask(
      doorNo: 'B-02',
      fileCode: 'FILE-2026-FI-102',
      secretLevel: '内部',
      department: '行政档案室',
      status: _InspectionTaskStatus.waiting,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadInspectionTasks();
  }

  /// 加载飞检任务数据。
  Future<void> _loadInspectionTasks() async {
    final data = await flightInspectionRepository.fetchFlightInspectionData();
    if (!mounted) {
      return;
    }
    setState(() {
      _batchNo = data.batchNo;
      _tasks
        ..clear()
        ..addAll(
          data.tasks.map((task) {
            return _InspectionCabinetTask(
              doorNo: task.doorNo,
              fileCode: task.fileCode,
              secretLevel: task.secretLevel,
              department: task.department,
              status: _InspectionTaskStatus.waiting,
            );
          }),
        );
    });
  }

  /// 当前正在飞检的柜门编号。
  String? _activeDoorNo;

  /// 当前柜门物品是否已放回。
  bool _itemReturned = false;

  /// 当前柜门放回校验是否成功。
  bool _returnVerified = false;

  /// 是否存在正在飞检的柜门。
  bool get _hasActiveTask => _activeDoorNo != null;

  /// 当前正在飞检的任务。
  _InspectionCabinetTask? get _activeTask {
    final activeDoorNo = _activeDoorNo;
    if (activeDoorNo == null) {
      return null;
    }
    for (final task in _tasks) {
      if (task.doorNo == activeDoorNo) {
        return task;
      }
    }
    return null;
  }

  /// 是否所有柜门均已飞检。
  bool get _allCompleted {
    return _tasks.every(
      (task) => task.status == _InspectionTaskStatus.completed,
    );
  }

  /// 已完成飞检的柜门数量。
  int get _completedCount {
    return _tasks
        .where((task) => task.status == _InspectionTaskStatus.completed)
        .length;
  }

  /// 打开指定柜门并锁定其他柜门。
  void _openCabinet(String doorNo) {
    if (_hasActiveTask) {
      return;
    }
    final taskIndex = _tasks.indexWhere((task) => task.doorNo == doorNo);
    if (taskIndex < 0 ||
        _tasks[taskIndex].status != _InspectionTaskStatus.waiting) {
      return;
    }
    setState(() {
      _tasks[taskIndex] = _tasks[taskIndex].copyWith(
        status: _InspectionTaskStatus.inspecting,
      );
      _activeDoorNo = doorNo;
      _itemReturned = false;
      _returnVerified = false;
    });
  }

  /// 标记当前柜门物品已放回。
  void _markItemReturned() {
    if (!_hasActiveTask) {
      return;
    }
    setState(() {
      _itemReturned = true;
      _returnVerified = false;
    });
  }

  /// 执行当前柜门放回校验。
  void _verifyReturnedItem() {
    if (!_itemReturned || !_hasActiveTask) {
      return;
    }
    setState(() => _returnVerified = true);
  }

  /// 完成当前柜门飞检并恢复其他柜门可操作。
  void _completeActiveTask() {
    final activeDoorNo = _activeDoorNo;
    if (activeDoorNo == null || !_itemReturned || !_returnVerified) {
      return;
    }
    final taskIndex = _tasks.indexWhere((task) => task.doorNo == activeDoorNo);
    if (taskIndex < 0) {
      return;
    }
    setState(() {
      _tasks[taskIndex] = _tasks[taskIndex].copyWith(
        status: _InspectionTaskStatus.completed,
      );
      _activeDoorNo = null;
      _itemReturned = false;
      _returnVerified = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeTask = _activeTask;
    final l10n = context.l10n;

    return TerminalShell(
      topBarLeading: _InspectionHeader(
        title: l10n.t('inspectionTaskListTitle', '飞检柜门列表'),
        onBack: () => Navigator.of(context).pop(),
      ),
      topRightBadge: FlowStatusBadge(
        text: l10n.t('inspectionTaskBadge', '柜门任务 · 飞检'),
      ),
      child: CustomPaint(
        painter: const _InspectionDotGridPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(34, 28, 34, 28),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TaskSummaryCard(
                      batchNo: _batchNo,
                      completedCount: _completedCount,
                      totalCount: _tasks.length,
                      allCompleted: _allCompleted,
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _tasks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final task = _tasks[index];
                          return _InspectionTaskCard(
                            task: task,
                            lockedByOther:
                                _hasActiveTask &&
                                task.status != _InspectionTaskStatus.inspecting,
                            onOpen: () => _openCabinet(task.doorNo),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: _ActiveInspectionPanel(
                  activeTask: activeTask,
                  itemReturned: _itemReturned,
                  returnVerified: _returnVerified,
                  allCompleted: _allCompleted,
                  onMarkReturned: _markItemReturned,
                  onVerifyReturned: _verifyReturnedItem,
                  onComplete: _completeActiveTask,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 飞检页面顶部左侧标题区。
class _InspectionHeader extends StatelessWidget {
  const _InspectionHeader({required this.title, required this.onBack});

  /// 页面标题。
  final String title;

  /// 返回按钮点击回调。
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: Text(context.l10n.t('inspectionBack', '返回')),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF0891B2),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF111936),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

/// 飞检任务汇总卡片。
class _TaskSummaryCard extends StatelessWidget {
  const _TaskSummaryCard({
    required this.batchNo,
    required this.completedCount,
    required this.totalCount,
    required this.allCompleted,
  });

  /// 任务批次号。
  final String batchNo;

  /// 已完成数量。
  final int completedCount;

  /// 总任务数量。
  final int totalCount;

  /// 是否全部完成。
  final bool allCompleted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8F3F7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D1B2E5A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF0891B2).withValues(alpha: .1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: Color(0xFF0891B2),
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allCompleted
                      ? l10n.t('inspectionTaskCompleted', '本次飞检完成')
                      : l10n
                            .t('inspectionRandomTask', '后台随机任务 {batchNo}')
                            .replaceAll('{batchNo}', batchNo),
                  style: const TextStyle(
                    color: Color(0xFF111936),
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  l10n
                      .t(
                        'inspectionTaskMemoryStatus',
                        '已下发到本机内存 · 已飞检 {completedCount} / {totalCount} 个柜门',
                      )
                      .replaceAll('{completedCount}', '$completedCount')
                      .replaceAll('{totalCount}', '$totalCount'),
                  style: const TextStyle(
                    color: Color(0xFF6877A2),
                    fontSize: 14,
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

/// 单个飞检柜门任务卡片。
class _InspectionTaskCard extends StatelessWidget {
  const _InspectionTaskCard({
    required this.task,
    required this.lockedByOther,
    required this.onOpen,
  });

  /// 当前柜门任务。
  final _InspectionCabinetTask task;

  /// 是否被其他正在飞检的柜门锁定。
  final bool lockedByOther;

  /// 打开柜门回调。
  final VoidCallback onOpen;

  /// 状态强调色。
  Color get _statusColor {
    return switch (task.status) {
      _InspectionTaskStatus.waiting => const Color(0xFF0891B2),
      _InspectionTaskStatus.inspecting => const Color(0xFFE68A00),
      _InspectionTaskStatus.completed => const Color(0xFF22A857),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final canOpen =
        !lockedByOther && task.status == _InspectionTaskStatus.waiting;
    final statusText = switch (task.status) {
      _InspectionTaskStatus.waiting => l10n.t('inspectionStatusWaiting', '待飞检'),
      _InspectionTaskStatus.inspecting => l10n.t(
        'inspectionStatusInspecting',
        '飞检中',
      ),
      _InspectionTaskStatus.completed => l10n.t(
        'inspectionStatusCompleted',
        '已飞检',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _statusColor.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                task.doorNo,
                style: TextStyle(
                  color: _statusColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${task.doorNo} $statusText',
                  style: const TextStyle(
                    color: Color(0xFF111936),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${task.fileCode} · ${task.secretLevel} · ${task.department}',
                  style: const TextStyle(
                    color: Color(0xFF6877A2),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (lockedByOther) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.t('inspectionLockedHint', '其他柜门已锁定，请先完成当前柜门飞检'),
                    style: TextStyle(
                      color: Color(0xFFE68A00),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 118,
            height: 42,
            child: ElevatedButton(
              key: ValueKey('open_inspection_${task.doorNo}'),
              onPressed: canOpen ? onOpen : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0891B2),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFEAF0F2),
                disabledForegroundColor: const Color(0xFF8A96A8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: Text(
                task.status == _InspectionTaskStatus.completed
                    ? l10n.t('inspectionCompletedAction', '已完成')
                    : l10n.t('inspectionOpenDoorAction', '打开柜门'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 当前飞检柜门操作面板。
class _ActiveInspectionPanel extends StatelessWidget {
  const _ActiveInspectionPanel({
    required this.activeTask,
    required this.itemReturned,
    required this.returnVerified,
    required this.allCompleted,
    required this.onMarkReturned,
    required this.onVerifyReturned,
    required this.onComplete,
  });

  /// 当前正在飞检的任务。
  final _InspectionCabinetTask? activeTask;

  /// 物品是否已放回。
  final bool itemReturned;

  /// 放回校验是否成功。
  final bool returnVerified;

  /// 是否所有柜门均已完成。
  final bool allCompleted;

  /// 确认物品已放回回调。
  final VoidCallback onMarkReturned;

  /// 执行放回校验回调。
  final VoidCallback onVerifyReturned;

  /// 完成本柜飞检回调。
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final task = activeTask;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8F3F7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D1B2E5A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: task == null
          ? _IdleInspectionPanel(allCompleted: allCompleted)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n
                      .t('inspectionCurrentDoorTitle', '柜门 {doorNo} 飞检中')
                      .replaceAll('{doorNo}', task.doorNo),
                  style: const TextStyle(
                    color: Color(0xFF111936),
                    fontSize: 26,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.t('inspectionLockedHint', '其他柜门已锁定，请先完成当前柜门飞检'),
                  style: TextStyle(
                    color: Color(0xFFE68A00),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 28),
                _InfoLine(
                  label: l10n.t('inspectionDoorNoLabel', '柜门编号'),
                  value: task.doorNo,
                ),
                _InfoLine(
                  label: l10n.t('inspectionFileCodeLabel', '文件编号'),
                  value: task.fileCode,
                ),
                _InfoLine(
                  label: l10n.t('inspectionSecretLevelLabel', '文件密级'),
                  value: task.secretLevel,
                ),
                _InfoLine(
                  label: l10n.t('inspectionDepartmentLabel', '责任部门'),
                  value: task.department,
                ),
                const Spacer(),
                _StepIndicator(
                  label: itemReturned
                      ? l10n.t('inspectionItemReturned', '物品已放回')
                      : l10n.t('inspectionWaitingItemReturned', '等待物品放回'),
                  success: itemReturned,
                ),
                const SizedBox(height: 10),
                _StepIndicator(
                  label: returnVerified
                      ? l10n.t('inspectionReturnVerified', '放回校验成功')
                      : l10n.t('inspectionWaitingReturnCheck', '等待放回校验'),
                  success: returnVerified,
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: itemReturned ? null : onMarkReturned,
                  style: _buttonStyle(const Color(0xFF0891B2)),
                  child: Text(
                    itemReturned
                        ? l10n.t('inspectionItemReturned', '物品已放回')
                        : l10n.t('inspectionConfirmItemReturned', '确认物品已放回'),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: itemReturned && !returnVerified
                      ? onVerifyReturned
                      : null,
                  style: _buttonStyle(const Color(0xFF4664E9)),
                  child: Text(
                    returnVerified
                        ? l10n.t('inspectionReturnVerified', '放回校验成功')
                        : l10n.t('inspectionRunReturnCheck', '执行放回校验'),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: itemReturned && returnVerified ? onComplete : null,
                  style: _buttonStyle(const Color(0xFF22A857)),
                  child: Text(l10n.t('inspectionFinishCurrentDoor', '完成本柜飞检')),
                ),
              ],
            ),
    );
  }

  /// 构建统一的操作按钮样式。
  ButtonStyle _buttonStyle(Color color) {
    return ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(46),
      backgroundColor: color,
      foregroundColor: Colors.white,
      disabledBackgroundColor: const Color(0xFFEAF0F2),
      disabledForegroundColor: const Color(0xFF8A96A8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
    );
  }
}

/// 无活动柜门时的操作面板。
class _IdleInspectionPanel extends StatelessWidget {
  const _IdleInspectionPanel({required this.allCompleted});

  /// 是否所有飞检任务已完成。
  final bool allCompleted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          allCompleted ? Icons.verified_rounded : Icons.door_sliding_outlined,
          color: allCompleted
              ? const Color(0xFF22A857)
              : const Color(0xFF0891B2),
          size: 78,
        ),
        const SizedBox(height: 22),
        Text(
          allCompleted
              ? l10n.t('inspectionTaskCompleted', '本次飞检完成')
              : l10n.t('inspectionSelectDoorTitle', '请选择需要飞检的柜门'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF111936),
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          allCompleted
              ? l10n.t('inspectionAllDoneHint', '所有后台下发柜门均已标记已飞检')
              : l10n.t('inspectionSelectDoorHint', '打开一个柜门后，其他柜门将自动锁定'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF6877A2),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// 信息行。
class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  /// 信息标签。
  final String label;

  /// 信息内容。
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8D99B8),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF111936),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 飞检步骤状态提示。
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.label, required this.success});

  /// 步骤提示文案。
  final String label;

  /// 步骤是否成功。
  final bool success;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: success
            ? const Color(0xFF22A857).withValues(alpha: .08)
            : const Color(0xFFF5F7FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            success ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: success ? const Color(0xFF22A857) : const Color(0xFF8D99B8),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: success
                  ? const Color(0xFF22A857)
                  : const Color(0xFF6877A2),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// 飞检页面背景点阵。
class _InspectionDotGridPainter extends CustomPainter {
  /// 创建点阵绘制器。
  const _InspectionDotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0891B2).withValues(alpha: .06)
      ..style = PaintingStyle.fill;
    for (double x = 18; x < size.width; x += 28) {
      for (double y = 18; y < size.height; y += 28) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
