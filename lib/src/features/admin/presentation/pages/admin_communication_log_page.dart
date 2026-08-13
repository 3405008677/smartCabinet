import 'dart:async';

import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/shell/app_shell.dart';
import 'package:smart_cabinet/src/app/theme/app_theme.dart';
import 'package:smart_cabinet/src/core/logging/communication_log_store.dart';
import 'package:smart_cabinet/src/core/logging/native_communication_log_bridge.dart';

/// 管理员通讯日志页面。
///
/// 页面只读取日志存储提供的已脱敏快照，并实时展示服务器、硬件与升级指令的
/// 收发记录；协议解析、敏感信息处理和日志留存策略仍由基础设施层负责。
class AdminCommunicationLogPage extends StatefulWidget {
  /// 创建管理员通讯日志页面。
  const AdminCommunicationLogPage({
    this.initialEntries,
    this.changes,
    super.key,
  });

  /// 测试或嵌入场景提供的初始日志；为空时读取全局日志存储。
  final List<CommunicationLogEntry>? initialEntries;

  /// 测试或嵌入场景提供的实时日志流；为空时订阅全局日志存储。
  final Stream<List<CommunicationLogEntry>>? changes;

  @override
  State<AdminCommunicationLogPage> createState() =>
      _AdminCommunicationLogPageState();
}

/// 管理通讯日志表格的双向滚动控制器。
class _AdminCommunicationLogPageState extends State<AdminCommunicationLogPage> {
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    unawaited(NativeCommunicationLogBridge.instance.ensureStarted());
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final store = CommunicationLogStore.instance;

    return TerminalShell(
      topBarLeading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const ValueKey('admin_communication_log_back'),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: l10n.t('adminBackTooltip', '返回'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Text(
            l10n.t('adminCommunicationLogTitle', '通讯日志'),
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      topRightBadge: FlowStatusBadge(
        text: l10n.t('adminCommunicationLogBadge', '设备通讯 · 管理员'),
      ),
      child: Container(
        key: const ValueKey('admin_communication_log_page'),
        color: AppTheme.scaffoldBackgroundColor,
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<CommunicationLogEntry>>(
          initialData: List<CommunicationLogEntry>.unmodifiable(
            widget.initialEntries ?? store.entries,
          ),
          stream: widget.changes ?? store.changes,
          builder: (context, snapshot) {
            final entries = snapshot.data ?? const <CommunicationLogEntry>[];
            return _buildLogCard(context, entries);
          },
        ),
      ),
    );
  }

  /// 构建包含标题、记录数、空态与日志表格的主卡片。
  Widget _buildLogCard(
    BuildContext context,
    List<CommunicationLogEntry> entries,
  ) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.outlineColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14111B3D),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('adminCommunicationLogTableTitle', '通讯记录'),
                      style: const TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n
                          .t(
                            'adminCommunicationLogRecordCount',
                            '当前共 {count} 条记录',
                          )
                          .replaceAll('{count}', '${entries.length}'),
                      style: const TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: entries.isEmpty
                ? _CommunicationLogEmptyState(
                    message: l10n.t('adminCommunicationLogEmpty', '暂无通讯日志'),
                  )
                : _buildLogTable(context, entries),
          ),
        ],
      ),
    );
  }

  /// 构建支持横向和纵向滚动的通讯日志表格。
  Widget _buildLogTable(
    BuildContext context,
    List<CommunicationLogEntry> entries,
  ) {
    final l10n = context.l10n;
    return Container(
      key: const ValueKey('admin_communication_log_table'),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.outlineColor),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Scrollbar(
            controller: _verticalScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _verticalScrollController,
              child: Scrollbar(
                controller: _horizontalScrollController,
                thumbVisibility: true,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        AppTheme.primarySoftColor,
                      ),
                      headingTextStyle: const TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontWeight: FontWeight.w900,
                      ),
                      dataTextStyle: const TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                      columnSpacing: 28,
                      dataRowMinHeight: 64,
                      dataRowMaxHeight: 72,
                      columns: [
                        DataColumn(
                          label: Text(
                            l10n.t('adminCommunicationLogTypeColumn', '类型'),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            l10n.t(
                              'adminCommunicationLogDirectionColumn',
                              '发送类型',
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            l10n.t(
                              'adminCommunicationLogMessageBodyColumn',
                              '消息体',
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            l10n.t(
                              'adminCommunicationLogRequestTimeColumn',
                              '请求时间',
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            l10n.t('adminCommunicationLogResultColumn', '请求结果'),
                          ),
                        ),
                      ],
                      rows: [
                        for (var index = 0; index < entries.length; index += 1)
                          _buildLogRow(context, entries[index]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 将一条通讯日志映射为表格行。
  DataRow _buildLogRow(BuildContext context, CommunicationLogEntry entry) {
    final l10n = context.l10n;
    final messagePreview = _singleLine(entry.messageBody);
    return DataRow(
      key: ValueKey('admin_communication_log_row_${entry.id}'),
      cells: [
        DataCell(Text(_targetTypeText(l10n, entry.targetType))),
        DataCell(Text(_directionText(l10n, entry.direction))),
        DataCell(
          SizedBox(
            width: 360,
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: ValueKey('admin_communication_log_message_${entry.id}'),
                onPressed: () => _showLogDetail(context, entry),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.centerLeft,
                ),
                child: Text(
                  messagePreview.isEmpty
                      ? l10n.t(
                          'adminCommunicationLogEmptyMessageBody',
                          '（空消息体）',
                        )
                      : messagePreview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
        DataCell(
          SizedBox(width: 172, child: Text(_formatTime(entry.requestTime))),
        ),
        DataCell(
          SizedBox(
            width: 210,
            child: Tooltip(
              message: entry.result,
              child: Text(
                entry.result,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 打开当前日志的完整信息弹窗。
  Future<void> _showLogDetail(
    BuildContext context,
    CommunicationLogEntry entry,
  ) {
    final l10n = context.l10n;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          key: const ValueKey('admin_communication_log_detail_dialog'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: SizedBox(
            width: 900,
            height: 610,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.t('adminCommunicationLogDetailTitle', '通讯日志详情'),
                          style: const TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey(
                          'admin_communication_log_detail_close',
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        tooltip: l10n.t(
                          'adminCommunicationLogCloseDetail',
                          '关闭',
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _CommunicationLogDetailField(
                        label: l10n.t('adminCommunicationLogTypeColumn', '类型'),
                        value: _targetTypeText(l10n, entry.targetType),
                      ),
                      _CommunicationLogDetailField(
                        label: l10n.t(
                          'adminCommunicationLogDirectionColumn',
                          '发送类型',
                        ),
                        value: _directionText(l10n, entry.direction),
                      ),
                      _CommunicationLogDetailField(
                        label: l10n.t(
                          'adminCommunicationLogRequestTimeColumn',
                          '请求时间',
                        ),
                        value: _formatTime(entry.requestTime),
                      ),
                      _CommunicationLogDetailField(
                        label: l10n.t(
                          'adminCommunicationLogResultColumn',
                          '请求结果',
                        ),
                        value: entry.result,
                        wide: true,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    l10n.t(
                      'adminCommunicationLogCompleteInformation',
                      '完整信息（已脱敏）',
                    ),
                    style: const TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    key: const ValueKey(
                      'admin_communication_log_complete_information',
                    ),
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.scaffoldBackgroundColor,
                      border: Border.all(color: AppTheme.outlineColor),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        entry.completeInformation,
                        style: const TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: 13,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 通讯日志为空时的页面提示。
class _CommunicationLogEmptyState extends StatelessWidget {
  /// 创建通讯日志空态。
  const _CommunicationLogEmptyState({required this.message});

  /// 空态提示文案。
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('admin_communication_log_empty'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.swap_horiz_rounded,
            size: 54,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 详情弹窗中的一组标签和值。
class _CommunicationLogDetailField extends StatelessWidget {
  /// 创建详情字段。
  const _CommunicationLogDetailField({
    required this.label,
    required this.value,
    this.wide = false,
  });

  /// 字段名称。
  final String label;

  /// 字段值。
  final String value;

  /// 是否占用更宽的横向空间。
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: wide ? 420 : 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: wide ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// 将日志目标类型转换为当前语言的界面文案。
String _targetTypeText(
  AppLocalizations l10n,
  CommunicationTargetType targetType,
) {
  return switch (targetType) {
    CommunicationTargetType.server => l10n.t(
      'adminCommunicationLogServerType',
      '服务器',
    ),
    CommunicationTargetType.hardware => l10n.t(
      'adminCommunicationLogHardwareType',
      '硬件',
    ),
    CommunicationTargetType.upgradeCommand => l10n.t(
      'adminCommunicationLogUpgradeCommandType',
      '升级指令',
    ),
  };
}

/// 将软件视角的通讯方向转换为用户约定的上报或下发文案。
String _directionText(AppLocalizations l10n, CommunicationDirection direction) {
  return switch (direction) {
    CommunicationDirection.outbound => l10n.t(
      'adminCommunicationLogOutboundDirection',
      '上报',
    ),
    CommunicationDirection.inbound => l10n.t(
      'adminCommunicationLogInboundDirection',
      '下发',
    ),
  };
}

/// 将请求时间格式化为固定宽度的本地时间，便于表格纵向比较。
String _formatTime(DateTime requestTime) {
  final local = requestTime.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  String three(int value) => value.toString().padLeft(3, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}.'
      '${three(local.millisecond)}';
}

/// 压平消息体换行，仅用于表格预览；详情仍展示完整信息。
String _singleLine(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}
