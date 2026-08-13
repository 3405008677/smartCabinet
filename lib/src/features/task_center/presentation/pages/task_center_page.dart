import 'dart:async';

import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/routing/app_routes.dart';
import 'package:smart_cabinet/src/app/shell/app_shell.dart';
import 'package:smart_cabinet/src/app/theme/app_theme.dart';
import 'package:smart_cabinet/src/core/device/cabinet_door_guard.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/repositories/operator_identity_repository_impl.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/task_center/data/repositories/task_center_repository_impl.dart';
import 'package:smart_cabinet/src/features/task_center/domain/entities/cabinet_task.dart';
import 'package:smart_cabinet/src/features/task_center/domain/repositories/task_center_repository.dart';
import 'package:smart_cabinet/src/features/task_center/presentation/pages/task_execution_page.dart';
import 'package:smart_cabinet/src/features/task_center/presentation/task_center_localization.dart';

/// 打开任务工作台所需的路由参数。
class TaskCenterArguments {
  /// 创建任务工作台参数。
  const TaskCenterArguments({
    required this.account,
    this.repository,
    this.doorGuard,
  });

  /// 已完成登录和二要素认证的操作员。
  final OperatorAccount account;

  /// 可选任务仓库，测试或后端接入时可替换默认实现。
  final TaskCenterRepository? repository;

  /// 可选柜门互锁器，默认使用应用全局实例。
  final CabinetDoorGuard? doorGuard;
}

/// 登录后的智能柜任务工作台。
class TaskCenterPage extends StatefulWidget {
  /// 创建任务工作台。
  const TaskCenterPage({super.key, required this.arguments});

  /// 当前任务会话参数。
  final TaskCenterArguments arguments;

  @override
  State<TaskCenterPage> createState() => _TaskCenterPageState();
}

/// 管理机构任务加载、单任务导航及登录会话无操作退出倒计时。
class _TaskCenterPageState extends State<TaskCenterPage> {
  static const int _inactivityTimeoutSeconds = 100;

  late final TaskCenterRepository _repository =
      widget.arguments.repository ?? taskCenterRepository;
  late final CabinetDoorGuard _doorGuard =
      widget.arguments.doorGuard ?? globalCabinetDoorGuard;

  List<CabinetTask> _tasks = const [];
  bool _loading = true;

  /// 任务跳转的页面级防重入锁，返回工作台并刷新后才解除。
  bool _navigationInProgress = false;
  Object? _error;
  Timer? _inactivityTicker;
  int _inactivitySeconds = _inactivityTimeoutSeconds;

  /// 任务列表加载代次，防止较早刷新覆盖最近一次返回结果。
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _restartInactivityTimer();
    unawaited(_loadTasks());
  }

  /// 从仓库刷新当前机构的未完成任务。
  Future<void> _loadTasks() async {
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final tasks = await _repository.fetchTasks(widget.arguments.account);
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _tasks = tasks;
        _loading = false;
        _navigationInProgress = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _loading = false;
        _navigationInProgress = false;
        _error = error;
      });
    }
  }

  /// 重新开始 100 秒无操作倒计时。
  void _restartInactivityTimer() {
    if (!mounted || _navigationInProgress) {
      return;
    }
    _inactivityTicker?.cancel();
    if (_inactivitySeconds == _inactivityTimeoutSeconds) {
      _inactivitySeconds = _inactivityTimeoutSeconds;
    } else {
      setState(() => _inactivitySeconds = _inactivityTimeoutSeconds);
    }
    _inactivityTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _navigationInProgress) {
        return;
      }
      if (!_canLogoutForInactivity) {
        if (_inactivitySeconds != _inactivityTimeoutSeconds) {
          setState(() => _inactivitySeconds = _inactivityTimeoutSeconds);
        }
        return;
      }
      if (_inactivitySeconds <= 1) {
        _returnHome();
        return;
      }
      setState(() => _inactivitySeconds -= 1);
    });
  }

  /// 当前是否满足无进行中柜门动作且所有柜门关闭的安全退出条件。
  bool get _canLogoutForInactivity {
    return !_navigationInProgress &&
        _doorGuard.allDoorsClosed &&
        !_doorGuard.hasActiveOperation;
  }

  /// 停止无操作倒计时。
  void _cancelInactivityTicker() {
    _inactivityTicker?.cancel();
    _inactivityTicker = null;
  }

  /// 打开指定任务并在返回后刷新工作台。
  Future<void> _openTask(CabinetTask task) async {
    if (_navigationInProgress) {
      return;
    }
    if (_doorGuard.hasActiveOperation) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.t(
              'taskCenterDoorOpenCannotStartTask',
              '仍有柜门操作尚未完成，请确认关门后再开始其他任务',
            ),
          ),
        ),
      );
      return;
    }
    _cancelInactivityTicker();
    setState(() => _navigationInProgress = true);
    await Navigator.of(context).pushNamed(
      AppRoutes.taskExecution,
      arguments: TaskExecutionArguments(
        account: widget.arguments.account,
        taskId: task.id,
        repository: _repository,
        doorGuard: _doorGuard,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _navigationInProgress = false);
    _restartInactivityTimer();
    await _loadTasks();
  }

  /// 清理当前会话并返回登录首页。
  void _returnHome() {
    if (!mounted || _navigationInProgress) {
      return;
    }
    if (!_doorGuard.allDoorsClosed) {
      final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.t('taskCenterDoorOpenCannotLogout', '仍有柜门未关闭，暂不能退出登录'),
          ),
        ),
      );
      return;
    }
    _navigationInProgress = true;
    _cancelInactivityTicker();
    operatorIdentityRepository.clearSession();
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    _cancelInactivityTicker();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final verifiedCount = widget.arguments.account.verifiedFactors.length;

    final shell = TerminalShell(
      topBarLeading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.assignment_turned_in_outlined,
            color: AppTheme.primaryColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            l10n.t('taskCenterTitle', '任务工作台'),
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      topRightBadge: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FlowStatusBadge(
            text: l10n
                .t('taskCenterAuthenticatedBadge', '身份认证已通过 · {count} 项因子')
                .replaceAll('{count}', '$verifiedCount'),
          ),
          const SizedBox(width: 10),
          InactivityCountdownBadge(
            key: const ValueKey('task_center_inactivity_countdown'),
            seconds: _inactivitySeconds,
          ),
        ],
      ),
      child: Container(
        color: AppTheme.scaffoldBackgroundColor,
        padding: const EdgeInsets.fromLTRB(32, 26, 32, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 300,
              child: _OperatorPanel(
                account: widget.arguments.account,
                onLogout: _returnHome,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(child: _buildTaskArea(context)),
          ],
        ),
      ),
    );
    return Focus(
      onKeyEvent: (_, _) {
        _restartInactivityTimer();
        return KeyEventResult.ignored;
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _restartInactivityTimer(),
        onPointerSignal: (_) => _restartInactivityTimer(),
        child: shell,
      ),
    );
  }

  /// 构建任务加载、错误、空任务或五类任务卡片区域。
  Widget _buildTaskArea(BuildContext context) {
    final l10n = context.l10n;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _error;
    if (error != null) {
      return _TaskCenterError(error: error, onRetry: _loadTasks);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t('taskCenterAvailableTasks', '当前可执行任务'),
                    style: const TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n
                        .t('taskCenterTaskSummary', '本机构共有 {count} 项待办任务')
                        .replaceAll('{count}', '${_tasks.length}'),
                    style: const TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.t('taskCenterRefresh', '刷新任务'),
              onPressed: _loadTasks,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_tasks.isEmpty)
          _NoTaskPanel(
            countdownVisible: _canLogoutForInactivity,
            seconds: _inactivitySeconds,
            doorSafe: _doorGuard.allDoorsClosed,
          )
        else
          const SizedBox.shrink(),
        if (_tasks.isEmpty) const SizedBox(height: 18),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 14.0;
              final cardWidth = (constraints.maxWidth - spacing * 2) / 3;
              return SingleChildScrollView(
                child: Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final type in TaskType.values)
                      _TaskTypeCard(
                        width: cardWidth,
                        type: type,
                        tasks: _tasks
                            .where((task) => task.type == type)
                            .toList(growable: false),
                        onOpen: _openTask,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 操作员身份与机构信息面板。
class _OperatorPanel extends StatelessWidget {
  const _OperatorPanel({required this.account, required this.onLogout});

  final OperatorAccount account;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CircleAvatar(
            radius: 42,
            backgroundColor: AppTheme.primarySoftColor,
            child: Icon(
              Icons.person_outline_rounded,
              color: AppTheme.primaryColor,
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            account.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            account.username,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          _OperatorInfoLine(
            label: l10n.t('taskCenterCompany', '公司'),
            value: account.organizationName,
          ),
          _OperatorInfoLine(
            label: l10n.t('taskCenterPosition', '职位'),
            value: localizedOperatorPosition(context, account.position),
          ),
          _OperatorInfoLine(
            label: l10n.t('taskCenterPhoneNumber', '手机号'),
            value: account.phoneNumber,
          ),
          _OperatorInfoLine(
            label: l10n.t('taskCenterGender', '性别'),
            value: localizedOperatorGender(context, account.gender),
          ),
          _OperatorInfoLine(
            label: l10n.t('taskCenterAge', '年龄'),
            value: account.age?.toString() ?? '—',
          ),
          const Spacer(),
          OutlinedButton.icon(
            key: const ValueKey('task_center_logout'),
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text(l10n.t('taskCenterLogout', '退出登录')),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppTheme.touchTargetSize),
              foregroundColor: const Color(0xFFC43B3B),
            ),
          ),
        ],
      ),
    );
  }
}

/// 操作员信息行。
class _OperatorInfoLine extends StatelessWidget {
  const _OperatorInfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8D99B8),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// 某一任务类型的入口卡片。
class _TaskTypeCard extends StatelessWidget {
  const _TaskTypeCard({
    required this.width,
    required this.type,
    required this.tasks,
    required this.onOpen,
  });

  final double width;
  final TaskType type;
  final List<CabinetTask> tasks;
  final ValueChanged<CabinetTask> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final task = tasks.isEmpty ? null : tasks.first;
    final color = _taskTypeColor(type);
    return Container(
      width: width,
      height: 208,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: task == null
              ? AppTheme.outlineColor
              : color.withValues(alpha: .4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_taskTypeIcon(type), color: color, size: 24),
              ),
              const Spacer(),
              Text(
                l10n
                    .t('taskCenterTaskCount', '{count} 项')
                    .replaceAll('{count}', '${tasks.length}'),
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            localizedTaskTypeTitle(context, type),
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              task == null
                  ? l10n.t('taskCenterNoTaskOfType', '暂无此类任务')
                  : localizedTaskTitle(context, task),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            height: AppTheme.touchTargetSize,
            width: double.infinity,
            child: ElevatedButton(
              key: ValueKey('task_center_open_${type.name}'),
              onPressed: task == null ? null : () => onOpen(task),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
              ),
              child: Text(l10n.t('taskCenterStartTask', '开始任务')),
            ),
          ),
        ],
      ),
    );
  }
}

/// 无任务时的安全退出提示。
class _NoTaskPanel extends StatelessWidget {
  const _NoTaskPanel({
    required this.countdownVisible,
    required this.seconds,
    required this.doorSafe,
  });

  final bool countdownVisible;
  final int seconds;
  final bool doorSafe;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryBorderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.task_alt_rounded, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              countdownVisible
                  ? l10n
                        .t(
                          'taskCenterNoTaskCountdown',
                          '当前无任务，{seconds} 秒后退出登录',
                        )
                        .replaceAll('{seconds}', '$seconds')
                  : doorSafe
                  ? l10n.t('taskCenterNoTasks', '当前无待办任务')
                  : l10n.t('taskCenterWaitingDoorClose', '等待全部柜门关闭后再退出登录'),
              style: const TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 任务加载失败状态。
class _TaskCenterError extends StatelessWidget {
  const _TaskCenterError({required this.error, required this.onRetry});

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
                .t('taskCenterLoadFailed', '任务加载失败：{error}')
                .replaceAll('{error}', localizedTaskError(context, error)),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            child: Text(l10n.t('taskCenterRetry', '重新加载')),
          ),
        ],
      ),
    );
  }
}

/// 返回任务类型图标。
IconData _taskTypeIcon(TaskType type) {
  return switch (type) {
    TaskType.storeEvidence => Icons.archive_outlined,
    TaskType.retrieveEvidence => Icons.unarchive_outlined,
    TaskType.borrowEvidence => Icons.assignment_return_outlined,
    TaskType.returnEvidence => Icons.assignment_returned_outlined,
    TaskType.inventory => Icons.inventory_2_outlined,
  };
}

/// 返回任务类型强调色。
Color _taskTypeColor(TaskType type) {
  return switch (type) {
    TaskType.storeEvidence => const Color(0xFF315BE8),
    TaskType.retrieveEvidence => const Color(0xFF14855E),
    TaskType.borrowEvidence => const Color(0xFF7B4CC9),
    TaskType.returnEvidence => const Color(0xFFCC6B18),
    TaskType.inventory => const Color(0xFF356E98),
  };
}
