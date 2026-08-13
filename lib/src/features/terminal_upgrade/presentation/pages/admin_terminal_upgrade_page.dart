import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/shell/app_shell.dart';
import 'package:smart_cabinet/src/app/theme/app_theme.dart';
import 'package:smart_cabinet/src/core/config/app_config.dart';
import 'package:smart_cabinet/src/core/device/device_info_service.dart';
import 'package:smart_cabinet/src/core/storage/app_local_store_provider.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/domain/entities/terminal_upgrade.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/domain/repositories/terminal_upgrade_repository.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/presentation/terminal_upgrade_offer_notifier.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/terminal_upgrade_providers.dart';
import 'package:smart_cabinet/src/shared/widgets/app_message.dart';

/// 管理员终端升级页面。
class AdminTerminalUpgradePage extends ConsumerStatefulWidget {
  /// 创建终端升级页面。
  const AdminTerminalUpgradePage({super.key});

  @override
  ConsumerState<AdminTerminalUpgradePage> createState() =>
      _AdminTerminalUpgradePageState();
}

/// 管理现场连接配置，并观察后台 STUM 长连接和安装状态。
class _AdminTerminalUpgradePageState
    extends ConsumerState<AdminTerminalUpgradePage> {
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _terminalIdController = TextEditingController();
  final TextEditingController _packageTagController = TextEditingController();

  late final TerminalUpgradeRepository _repository;
  StreamSubscription<TerminalUpgradeSnapshot>? _stateSubscription;
  TerminalUpgradeSnapshot _snapshot = const TerminalUpgradeSnapshot();
  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  bool _isDisposing = false;
  String _uniqueDeviceId = '';

  @override
  void initState() {
    super.initState();
    _repository = ref.read(terminalUpgradeRepositoryProvider);
    _snapshot = _repository.current;
    _stateSubscription = _repository.states.listen((snapshot) {
      if (mounted && !_isDisposing) {
        if (snapshot.offer != null) {
          // 当前页面已经完整展示版本和安装操作，避免全局卡片覆盖管理员按钮。
          globalTerminalUpgradeOfferNotifier.dismiss();
        }
        setState(() => _snapshot = snapshot);
      }
    });
    unawaited(_loadSettings());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposing) {
        return;
      }
      // 页面完成首帧后状态面板已经承担 offer 展示；延迟通知可避免在
      // MaterialApp.builder 正在构建全局覆盖层时触发嵌套重建。
      globalTerminalUpgradeOfferNotifier.dismiss();
    });
  }

  /// 从统一本地 Store 恢复现场参数，并刷新原生安装结果。
  Future<void> _loadSettings() async {
    try {
      final store = await ref.read(appLocalStoreProvider.future);
      final state = await store.state();
      final settings = TerminalUpgradeSettings.fromJson(
        state.upgrade,
        defaultHost: AppConfig.terminalUpgradeHost,
        defaultPort: AppConfig.terminalUpgradePort,
      );
      var uniqueDeviceId = DeviceInfoService.uniqueDeviceIdFrom(
        state.deviceInfo,
      );
      if (uniqueDeviceId == null) {
        try {
          // 页面可能早于首帧后的缓存任务打开；此处使用与“关于设备”相同的
          // 原生数据源补读，但不把协议 CD 另存进升级配置。
          uniqueDeviceId = await const DeviceInfoService()
              .fetchUniqueDeviceId()
              .timeout(const Duration(seconds: 5));
        } on Object {
          // 保持为空并交给启用时的强校验给出稳定提示，避免显示平台占位值。
        }
      }
      if (!mounted) {
        return;
      }
      _hostController.text = settings.host;
      _portController.text = settings.port == 0 ? '' : '${settings.port}';
      _terminalIdController.text = settings.terminalId;
      _packageTagController.text = settings.packageTag;
      setState(() {
        _enabled = settings.enabled;
        _uniqueDeviceId = uniqueDeviceId ?? '';
        _loading = false;
      });
      await _repository.refreshInstallStatus();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      Message.error(
        context,
        _upgradeActionErrorText(
          context,
          key: 'adminUpgradeLoadSettingsFailed',
          fallback: '读取升级配置失败：{detail}',
          error: error,
        ),
      );
    }
  }

  /// 从表单构建强类型设置，协议校验统一由 Entity 执行。
  TerminalUpgradeSettings _settingsFromForm() {
    return TerminalUpgradeSettings(
      enabled: _enabled,
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 0,
      terminalId: _terminalIdController.text.trim(),
      packageTag: _packageTagController.text.trim(),
    );
  }

  /// 保存配置并按开关启动或停止监控。
  ///
  /// [showSuccessMessage] 只控制独立保存动作的完成提示；检查升级会复用保存逻辑，
  /// 但必须继续展示检查请求的真实语义，不能让“配置已保存”冒充检查结果。
  Future<bool> _saveSettings({bool showSuccessMessage = true}) async {
    if (_saving) {
      return false;
    }
    final settings = _settingsFromForm();
    final settingsValidationError = settings.validate();
    if (settings.enabled && settingsValidationError != null) {
      Message.error(
        context,
        _upgradeMessageText(
          context,
          TerminalUpgradeMessage(settingsValidationError),
        ),
      );
      return false;
    }
    // 从补读 CD 开始就锁住保存操作，避免快速双击并发执行 Store 的读改写。
    setState(() => _saving = true);
    try {
      if (settings.enabled && _uniqueDeviceId.isEmpty) {
        try {
          final uniqueDeviceId = await const DeviceInfoService()
              .fetchUniqueDeviceId()
              .timeout(const Duration(seconds: 5));
          if (!mounted) {
            return false;
          }
          setState(() => _uniqueDeviceId = uniqueDeviceId);
        } on Object {
          if (mounted) {
            Message.error(
              context,
              _upgradeMessageText(
                context,
                const TerminalUpgradeMessage(
                  TerminalUpgradeMessageCode.settingsChipIdInvalid,
                ),
              ),
            );
          }
          return false;
        }
      }
      final loginIdentity = TerminalUpgradeLoginIdentity(
        moduleId: AppConfig.current.afrrDeviceImei,
        dataProtocolIp: AppConfig.current.terminalUpgradeDataProtocolIp,
        chipId: _uniqueDeviceId,
      );
      final validationError = loginIdentity.validate();
      if (settings.enabled && validationError != null) {
        Message.error(
          context,
          _upgradeMessageText(context, TerminalUpgradeMessage(validationError)),
        );
        return false;
      }
      final store = await ref.read(appLocalStoreProvider.future);
      await store.update((state) => state.copyWith(upgrade: settings.toJson()));
      if (settings.enabled) {
        await _repository.start(settings);
      } else {
        await _repository.stop();
      }
      if (!mounted) {
        return true;
      }
      if (showSuccessMessage) {
        Message.success(
          context,
          context.l10n.t('adminUpgradeSettingsSaved', '升级配置已保存'),
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        Message.error(
          context,
          _upgradeActionErrorText(
            context,
            key: 'adminUpgradeSaveSettingsFailed',
            fallback: '保存升级配置失败：{detail}',
            error: error,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// 保存最新表单后发起一次手工 T03 检查。
  Future<void> _checkNow() async {
    if (!_enabled) {
      Message.warning(
        context,
        context.l10n.t('adminUpgradeEnableFirst', '请先启用升级监控'),
      );
      return;
    }
    if (!await _saveSettings(showSuccessMessage: false) || !mounted) {
      return;
    }
    try {
      await _repository.requestCheck();
      if (mounted) {
        Message.info(
          context,
          context.l10n.t('adminUpgradeCheckStarted', '正在检查新版本，等待服务端结果'),
        );
      }
    } catch (error) {
      if (mounted) {
        Message.error(
          context,
          _upgradeActionErrorText(
            context,
            key: 'adminUpgradeCheckFailed',
            fallback: '检查升级失败：{detail}',
            error: error,
          ),
        );
      }
    }
  }

  /// 要求管理员再次确认后才下载并提交 APK，避免远程 S03 打断现场任务。
  Future<void> _installUpdate() async {
    final offer = _snapshot.offer;
    if (offer == null || _snapshot.busy) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.t('adminUpgradeConfirmTitle', '确认安装升级')),
        content: Text(
          context.l10n
              .t(
                'adminUpgradeConfirmMessage',
                '即将安装版本 {version}。安装期间应用可能重启，请先确认没有进行中的任务且所有柜门已经关闭。',
              )
              .replaceAll('{version}', offer.targetVersion),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.t('adminUpgradeCancel', '取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.t('adminUpgradeInstall', '下载并安装')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await _repository.installAvailableUpdate(
        confirmedOffer: offer,
        administratorConfirmed: true,
      );
    } catch (error) {
      if (mounted) {
        Message.error(
          context,
          _upgradeActionErrorText(
            context,
            key: 'adminUpgradeInstallFailed',
            fallback: '升级安装失败：{detail}',
            error: error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _isDisposing = true;
    final subscription = _stateSubscription;
    _stateSubscription = null;
    unawaited(subscription?.cancel());
    final latestSnapshot = _repository.current;
    final pendingOffer = latestSnapshot.offer;
    if (pendingOffer != null && !latestSnapshot.busy) {
      final pendingOfferIdentity = pendingOffer.identityKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final currentSnapshot = _repository.current;
        final currentOffer = currentSnapshot.offer;
        if (currentOffer == null ||
            currentOffer.identityKey != pendingOfferIdentity ||
            currentSnapshot.busy) {
          return;
        }
        // 路由完成卸载且 Repository 仍持有同一份空闲 offer 时才恢复入口；
        // dispose 阶段 Widget 树被锁定，不能同步通知全局覆盖层重建。
        globalTerminalUpgradeOfferNotifier.show(currentOffer);
      });
    }
    _hostController.dispose();
    _portController.dispose();
    _terminalIdController.dispose();
    _packageTagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final installationInProgress = switch (_snapshot.phase) {
      TerminalUpgradePhase.downloading ||
      TerminalUpgradePhase.verifying ||
      TerminalUpgradePhase.installing => true,
      _ => false,
    };
    return TerminalShell(
      topBarLeading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: installationInProgress
                ? null
                : () => Navigator.of(context).pop(),
            tooltip: l10n.t('adminBackTooltip', '返回'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Text(
            l10n.t('adminUpgradeTitle', '终端升级'),
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      topRightBadge: FlowStatusBadge(
        text: l10n.t('adminUpgradeBadge', '设备维护 · STUM'),
      ),
      child: Container(
        key: const ValueKey('admin_terminal_upgrade_page'),
        color: AppTheme.scaffoldBackgroundColor,
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: _UpgradeCard(
                      title: l10n.t('adminUpgradeConnectionTitle', '升级服务配置'),
                      icon: Icons.settings_ethernet_rounded,
                      child: _buildSettingsForm(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: _UpgradeCard(
                      title: l10n.t('adminUpgradeStatusTitle', '升级状态'),
                      icon: Icons.system_update_alt_rounded,
                      child: _buildStatusPanel(context),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// 构建现场连接配置表单。
  Widget _buildSettingsForm(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.t('adminUpgradeEnabled', '开机连接升级监控服务')),
          subtitle: Text(
            l10n.t('adminUpgradeEnabledHint', '默认关闭；启用后按 T01 登录并在重连后发送 T03'),
          ),
          value: _enabled,
          onChanged: _snapshot.busy
              ? null
              : (value) => setState(() => _enabled = value),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _UpgradeField(
                        controller: _hostController,
                        label: l10n.t('adminUpgradeHost', '服务地址'),
                        hint: AppConfig.terminalUpgradeHost,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _UpgradeField(
                        controller: _portController,
                        label: l10n.t('adminUpgradePort', 'TCP 端口'),
                        hint: '${AppConfig.terminalUpgradePort}',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _UpgradeField(
                        controller: _terminalIdController,
                        label: l10n.t(
                          'adminUpgradeTerminalId',
                          '设备号 ID（11/15 位数字）',
                        ),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _UpgradeReadOnlyField(
                        label: l10n.t('adminUpgradeModuleId', '设备 IMEI（IM）'),
                        // 管理员页完整展示与 AFRR 共用的 DEVICE_IMEI；该值只来自
                        // AppConfig，不创建控制器或第二份持久化来源。
                        value: AppConfig.current.afrrDeviceImei.trim(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _UpgradeField(
                        controller: _packageTagController,
                        label: l10n.t('adminUpgradePackageTag', '包标记 PT（可选）'),
                        hint: 'APP',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _UpgradeReadOnlyField(
                        label: l10n.t('adminUpgradeDataIp', '数据通讯 IP DP'),
                        value: AppConfig.current.terminalUpgradeDataProtocolIp
                            .trim(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _UpgradeReadOnlyField(
                  label: l10n.t('adminUpgradeChipId', '设备唯一 ID CD'),
                  value: _uniqueDeviceId,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF7D88A)),
                  ),
                  child: Text(
                    l10n.t(
                      'adminUpgradeProtocolBoundary',
                      '当前仅支持 URL 模式（DT=1），并只在当前 T03 请求窗口处理 S03。分包模式 AD=2 缺少帧定义，将按 NG3AD 拒绝。',
                    ),
                    style: const TextStyle(
                      color: Color(0xFF7C2D12),
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving || _snapshot.busy ? null : _saveSettings,
                icon: const Icon(Icons.save_outlined),
                label: Text(l10n.t('adminUpgradeSave', '保存配置')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _saving || _snapshot.busy ? null : _checkNow,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.t('adminUpgradeCheck', '检查升级')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建连接、升级包和安装进度面板。
  Widget _buildStatusPanel(BuildContext context) {
    final l10n = context.l10n;
    final offer = _snapshot.offer;
    final installStatus = _snapshot.installStatus;
    final progress = _snapshot.downloadProgress;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusBanner(snapshot: _snapshot),
          const SizedBox(height: 16),
          _StatusRow(
            label: l10n.t('adminUpgradeCurrentVersion', '当前版本'),
            value: _snapshot.currentVersion.isEmpty
                ? '—'
                : _snapshot.currentVersion,
          ),
          _StatusRow(
            label: l10n.t('adminUpgradeTargetVersion', '目标版本'),
            value: offer?.targetVersion ?? installStatus?.targetVersion ?? '—',
          ),
          if (installStatus != null && installStatus.state != 'idle') ...[
            _StatusRow(
              label: l10n.t('adminUpgradeInstallStatus', '安装状态'),
              value: _installStateText(context, installStatus),
            ),
            if (installStatus.sessionId != null)
              _StatusRow(
                label: l10n.t('adminUpgradeInstallSession', '安装会话'),
                value: '${installStatus.sessionId}',
              ),
            if (installStatus.message.isNotEmpty ||
                installStatus.diagnosticCode.isNotEmpty ||
                installStatus.requiresUserAction ||
                installStatus.confirmationLaunchFailed)
              _StatusRow(
                label: l10n.t('adminUpgradeInstallMessage', '系统说明'),
                value: _installStatusMessageText(context, installStatus),
                selectable: true,
              ),
          ],
          _StatusRow(
            label: 'PT',
            value: offer == null || offer.packageTag.isEmpty
                ? '—'
                : offer.packageTag,
          ),
          _StatusRow(
            label: 'MD5',
            value: offer?.md5.toUpperCase() ?? '—',
            selectable: true,
          ),
          _StatusRow(
            label: l10n.t('adminUpgradeDownloadAddress', '下载地址'),
            value: offer?.safeDownloadAddress ?? '—',
            selectable: true,
          ),
          if (_snapshot.phase == TerminalUpgradePhase.downloading ||
              _snapshot.phase == TerminalUpgradePhase.verifying) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text(
              _downloadText(_snapshot.downloadedBytes, _snapshot.totalBytes),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondaryColor),
            ),
          ],
          if (_snapshot.errorMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFC4C9)),
              ),
              child: Text(
                _upgradeMessageText(context, _snapshot.errorMessage!),
                style: const TextStyle(
                  color: Color(0xFF7F1D1D),
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: offer == null || _snapshot.busy ? null : _installUpdate,
            icon: const Icon(Icons.install_mobile_rounded),
            label: Text(l10n.t('adminUpgradeInstall', '下载并安装')),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _snapshot.busy ? null : _repository.refreshInstallStatus,
            icon: const Icon(Icons.sync_rounded),
            label: Text(l10n.t('adminUpgradeRefreshInstall', '刷新安装结果')),
          ),
        ],
      ),
    );
  }

  /// 把字节进度格式化为稳定的 MB 展示，不改变下载器提供的原始计数。
  String _downloadText(int downloaded, int? total) {
    String mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
    return total == null
        ? '${mb(downloaded)} MB'
        : '${mb(downloaded)} / ${mb(total)} MB';
  }
}

/// 升级页统一卡片。
class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.outlineColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// 升级配置文本框。
class _UpgradeField extends StatelessWidget {
  const _UpgradeField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enableSuggestions: !obscureText,
      autocorrect: !obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// 只读展示由系统配置或设备信息派生的 STUM 身份字段。
class _UpgradeReadOnlyField extends StatelessWidget {
  const _UpgradeReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: SelectableText(value.isEmpty ? '—' : value),
    );
  }
}

/// 当前阶段的主状态提示。
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.snapshot});

  final TerminalUpgradeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final failed = snapshot.phase == TerminalUpgradePhase.failed;
    final color = failed ? const Color(0xFFE11D48) : AppTheme.primaryColor;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          Icon(
            failed ? Icons.error_outline_rounded : Icons.update_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _phaseText(context, snapshot.phase),
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
                if (snapshot.message != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _upgradeMessageText(context, snapshot.message!),
                    style: const TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (snapshot.busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

/// 状态详情键值行。
class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final valueWidget = selectable
        ? SelectableText(value, textAlign: TextAlign.right)
        : Text(value, textAlign: TextAlign.right);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: valueWidget),
        ],
      ),
    );
  }
}

/// 把领域阶段映射为当前语言的简短状态。
String _phaseText(BuildContext context, TerminalUpgradePhase phase) {
  return switch (phase) {
    TerminalUpgradePhase.disabled => context.l10n.t(
      'adminUpgradePhaseDisabled',
      '未启用',
    ),
    TerminalUpgradePhase.disconnected => context.l10n.t(
      'adminUpgradePhaseDisconnected',
      '等待连接',
    ),
    TerminalUpgradePhase.connecting => context.l10n.t(
      'adminUpgradePhaseConnecting',
      '连接中',
    ),
    TerminalUpgradePhase.authenticating => context.l10n.t(
      'adminUpgradePhaseAuthenticating',
      '登录验证中',
    ),
    TerminalUpgradePhase.checking => context.l10n.t(
      'adminUpgradePhaseChecking',
      '检查中',
    ),
    TerminalUpgradePhase.upToDate => context.l10n.t(
      'adminUpgradePhaseLatest',
      '无可用升级包',
    ),
    TerminalUpgradePhase.updateAvailable => context.l10n.t(
      'adminUpgradePhaseAvailable',
      '发现新版本',
    ),
    TerminalUpgradePhase.downloading => context.l10n.t(
      'adminUpgradePhaseDownloading',
      '下载中',
    ),
    TerminalUpgradePhase.verifying => context.l10n.t(
      'adminUpgradePhaseVerifying',
      '校验中',
    ),
    TerminalUpgradePhase.installing => context.l10n.t(
      'adminUpgradePhaseInstalling',
      '提交安装中',
    ),
    TerminalUpgradePhase.awaitingRestart => context.l10n.t(
      'adminUpgradePhaseRestart',
      '等待安装与重启',
    ),
    TerminalUpgradePhase.failed => context.l10n.t(
      'adminUpgradePhaseFailed',
      '升级失败',
    ),
  };
}

/// 把原生 PackageInstaller 状态映射为管理员可理解的文案。
String _installStateText(
  BuildContext context,
  TerminalInstallStatus installStatus,
) {
  final state = installStatus.state;
  return switch (state) {
    'validating' => context.l10n.t(
      'adminUpgradeInstallStateValidating',
      '正在校验升级包',
    ),
    'submitting' => context.l10n.t(
      'adminUpgradeInstallStateSubmitting',
      '正在提交安装',
    ),
    'submitted' => context.l10n.t(
      'adminUpgradeInstallStateSubmitted',
      '已提交系统安装器',
    ),
    'pending_user_action' => context.l10n.t(
      'adminUpgradeInstallStatePending',
      '等待管理员确认',
    ),
    'success' => context.l10n.t('adminUpgradeInstallStateSuccess', '安装成功'),
    'failure' ||
    'failed' => context.l10n.t('adminUpgradeInstallStateFailed', '安装失败'),
    _ => _replaceUpgradePlaceholders(
      context.l10n.t('adminUpgradeInstallStateUnknown', '未知安装状态（{state}）'),
      <String, String>{'state': state},
    ),
  };
}

/// 按原生稳定诊断码展示说明，避免把持久化的固定中文 message 直接上屏。
String _installStatusMessageText(
  BuildContext context,
  TerminalInstallStatus status,
) {
  final code = _installDiagnosticMessageCode(status);
  if (code != null) {
    return _upgradeMessageText(context, TerminalUpgradeMessage(code));
  }
  if (status.requiresUserAction || status.state == 'pending_user_action') {
    return _upgradeMessageText(
      context,
      const TerminalUpgradeMessage(
        TerminalUpgradeMessageCode.awaitingUserConfirmation,
      ),
    );
  }
  return _installStateText(context, status);
}

/// 将 Android 安装器诊断码映射为语言无关的业务语义。
TerminalUpgradeMessageCode? _installDiagnosticMessageCode(
  TerminalInstallStatus status,
) {
  if (status.confirmationLaunchFailed) {
    return TerminalUpgradeMessageCode.confirmationLaunchFailed;
  }
  return switch (status.diagnosticCode) {
    'validation_failed' => TerminalUpgradeMessageCode.installValidationFailed,
    'session_submission_failed' =>
      TerminalUpgradeMessageCode.installSubmissionFailed,
    'session_missing' => TerminalUpgradeMessageCode.installSessionMissing,
    'stale_uncommitted_session' || 'stale_committed_session' =>
      TerminalUpgradeMessageCode.installSessionExpired,
    'confirmation_required' =>
      TerminalUpgradeMessageCode.awaitingUserConfirmation,
    'confirmation_launch_failed' =>
      TerminalUpgradeMessageCode.confirmationLaunchFailed,
    'confirmation_recovery_schedule_failed' =>
      TerminalUpgradeMessageCode.confirmationRecoveryFailed,
    'confirmation_timeout' => TerminalUpgradeMessageCode.confirmationTimedOut,
    'package_installer_failure' =>
      TerminalUpgradeMessageCode.packageInstallerFailed,
    _ => null,
  };
}

/// 把结构化升级消息映射为当前语言，并替换非敏感参数与外部动态详情。
String _upgradeMessageText(
  BuildContext context,
  TerminalUpgradeMessage message,
) {
  final l10n = context.l10n;
  final template = switch (message.code) {
    TerminalUpgradeMessageCode.settingsHostRequired => l10n.t(
      'adminUpgradeValidationHostRequired',
      '升级服务地址不能为空',
    ),
    TerminalUpgradeMessageCode.settingsPortInvalid => l10n.t(
      'adminUpgradeValidationPortInvalid',
      '升级服务端口必须在 1 到 65535 之间',
    ),
    TerminalUpgradeMessageCode.settingsTerminalIdInvalid => l10n.t(
      'adminUpgradeValidationTerminalIdInvalid',
      '终端 ID 必须是非零开头的 11 位或 15 位数字',
    ),
    TerminalUpgradeMessageCode.settingsModuleIdInvalid => l10n.t(
      'adminUpgradeValidationModuleIdInvalid',
      'DEVICE_IMEI 系统配置无效，必须配置为 15 位数字',
    ),
    TerminalUpgradeMessageCode.settingsDataProtocolIpInvalid => l10n.t(
      'adminUpgradeValidationDataIpInvalid',
      'STUM_DP 必须是一个或多个以英文逗号分隔的 IPv4 地址',
    ),
    TerminalUpgradeMessageCode.settingsChipIdInvalid => l10n.t(
      'adminUpgradeValidationChipIdInvalid',
      '“关于设备”中没有可用于 CD 的有效唯一设备 ID',
    ),
    TerminalUpgradeMessageCode.settingsProtocolValueInvalid => l10n.t(
      'adminUpgradeValidationProtocolValueInvalid',
      'PT 只能使用 ASCII 字符，且不能包含竖线或换行',
    ),
    TerminalUpgradeMessageCode.monitoringDisabled => l10n.t(
      'adminUpgradeMessageMonitoringDisabled',
      '升级监控未启用',
    ),
    TerminalUpgradeMessageCode.monitoringReady => l10n.t(
      'adminUpgradeMessageMonitoringReady',
      '升级监控已启用，准备连接服务端',
    ),
    TerminalUpgradeMessageCode.connectingServer => l10n.t(
      'adminUpgradeMessageConnectingServer',
      '正在连接升级服务端',
    ),
    TerminalUpgradeMessageCode.authenticatingTerminal => l10n.t(
      'adminUpgradeMessageAuthenticatingTerminal',
      '已连接，正在验证终端身份',
    ),
    TerminalUpgradeMessageCode.checkingVersion => l10n.t(
      'adminUpgradeMessageCheckingVersion',
      '正在检查新版本',
    ),
    TerminalUpgradeMessageCode.checkRequestAccepted => l10n.t(
      'adminUpgradeMessageCheckRequestAccepted',
      '服务端已接收升级检查请求',
    ),
    TerminalUpgradeMessageCode.alreadyLatest => l10n.t(
      'adminUpgradeMessageAlreadyLatest',
      '服务端当前没有可下发升级包（VE=0）',
    ),
    TerminalUpgradeMessageCode.updateAvailable => l10n.t(
      'adminUpgradeMessageUpdateAvailable',
      '发现新版本 {version}，请管理员确认安装',
    ),
    TerminalUpgradeMessageCode.downloadingVersion => l10n.t(
      'adminUpgradeMessageDownloadingVersion',
      '正在下载版本 {version}',
    ),
    TerminalUpgradeMessageCode.checksumVerified => l10n.t(
      'adminUpgradeMessageChecksumVerified',
      '升级包 MD5 校验通过',
    ),
    TerminalUpgradeMessageCode.submittingInstaller => l10n.t(
      'adminUpgradeMessageSubmittingInstaller',
      '正在提交 Android 安装会话',
    ),
    TerminalUpgradeMessageCode.installSessionSubmitted => l10n.t(
      'adminUpgradeMessageInstallSessionSubmitted',
      '安装会话 {sessionId} 已提交，等待系统完成升级',
    ),
    TerminalUpgradeMessageCode.awaitingUserConfirmation => l10n.t(
      'adminUpgradeMessageAwaitingUserConfirmation',
      '等待管理员确认系统安装',
    ),
    TerminalUpgradeMessageCode.awaitingSystemInstall => l10n.t(
      'adminUpgradeMessageAwaitingSystemInstall',
      '等待系统完成安装',
    ),
    TerminalUpgradeMessageCode.installSucceeded => l10n.t(
      'adminUpgradeMessageInstallSucceeded',
      '终端已经升级到 {version}',
    ),
    TerminalUpgradeMessageCode.connectionInterruptedRetrying => l10n.t(
      'adminUpgradeMessageConnectionInterruptedRetrying',
      '升级服务连接已中断，将自动重连',
    ),
    TerminalUpgradeMessageCode.readAppVersionFailed => l10n.t(
      'adminUpgradeErrorReadAppVersionFailed',
      '无法读取当前应用版本',
    ),
    TerminalUpgradeMessageCode.monitoringNotEnabled => l10n.t(
      'adminUpgradeErrorMonitoringNotEnabled',
      '请先保存并启用升级监控配置',
    ),
    TerminalUpgradeMessageCode.checkBlockedByDownload => l10n.t(
      'adminUpgradeErrorCheckBlockedByDownload',
      '升级包正在下载或校验，不能重复检查',
    ),
    TerminalUpgradeMessageCode.installAlreadyActive => l10n.t(
      'adminUpgradeErrorInstallAlreadyActive',
      '系统仍在处理上一笔升级安装',
    ),
    TerminalUpgradeMessageCode.noInstallableOffer => l10n.t(
      'adminUpgradeErrorNoInstallableOffer',
      '当前没有可安装的升级包',
    ),
    TerminalUpgradeMessageCode.administratorConfirmationRequired => l10n.t(
      'adminUpgradeErrorAdministratorConfirmationRequired',
      '请由管理员明确确认本次升级后再安装',
    ),
    TerminalUpgradeMessageCode.confirmedOfferChanged => l10n.t(
      'adminUpgradeErrorConfirmedOfferChanged',
      '待安装升级包已变化，请重新确认',
    ),
    TerminalUpgradeMessageCode.pendingOfferRequiresDecision => l10n.t(
      'adminUpgradeErrorPendingOfferRequiresDecision',
      '已有待确认升级包，请先处理后再检查',
    ),
    TerminalUpgradeMessageCode.doorsNotClosed => l10n.t(
      'adminUpgradeErrorDoorsNotClosed',
      '存在尚未确认关闭的柜门，禁止安装升级',
    ),
    TerminalUpgradeMessageCode.maintenanceUnavailable => l10n.t(
      'adminUpgradeErrorMaintenanceUnavailable',
      '柜门或其他维护操作正在占用设备，禁止安装升级',
    ),
    TerminalUpgradeMessageCode.doorsChangedDuringDownload => l10n.t(
      'adminUpgradeErrorDoorsChangedDuringDownload',
      '下载期间柜门状态发生变化，已取消安装',
    ),
    TerminalUpgradeMessageCode.installFailed => l10n.t(
      'adminUpgradeErrorInstallFailed',
      '升级安装失败',
    ),
    TerminalUpgradeMessageCode.readInstallStatusFailed => l10n.t(
      'adminUpgradeErrorReadInstallStatusFailed',
      '读取系统安装状态失败',
    ),
    TerminalUpgradeMessageCode.serverLoginRejected => l10n.t(
      'adminUpgradeErrorServerLoginRejected',
      '终端登录被服务端拒绝',
    ),
    TerminalUpgradeMessageCode.connectFailed => l10n.t(
      'adminUpgradeErrorConnectFailed',
      '无法连接升级服务端',
    ),
    TerminalUpgradeMessageCode.serverCheckRejected => l10n.t(
      'adminUpgradeErrorServerCheckRejected',
      '升级检查被服务端拒绝',
    ),
    TerminalUpgradeMessageCode.offerRejected => l10n.t(
      'adminUpgradeErrorOfferRejected',
      '升级包未通过协议校验（{responseCode}）',
    ),
    TerminalUpgradeMessageCode.checkTimedOut => l10n.t(
      'adminUpgradeErrorCheckTimedOut',
      '等待升级检查结果超时，请手动重试',
    ),
    TerminalUpgradeMessageCode.maintenanceRestoreFailed => l10n.t(
      'adminUpgradeErrorMaintenanceRestoreFailed',
      '安装仍在进行，但无法恢复升级维护锁；请立即停止柜门业务并联系运维人员',
    ),
    TerminalUpgradeMessageCode.confirmationLaunchFailed => l10n.t(
      'adminUpgradeErrorConfirmationLaunchFailed',
      '系统安装确认页未能打开，请退出锁定任务模式后重试或联系运维人员',
    ),
    TerminalUpgradeMessageCode.installerReasonUnavailable => l10n.t(
      'adminUpgradeErrorInstallerReasonUnavailable',
      '系统安装器未提供失败原因',
    ),
    TerminalUpgradeMessageCode.operationCancelled => l10n.t(
      'adminUpgradeErrorOperationCancelled',
      '升级操作已取消',
    ),
    TerminalUpgradeMessageCode.repositoryDisposed => l10n.t(
      'adminUpgradeErrorRepositoryDisposed',
      '终端升级服务已经释放',
    ),
    TerminalUpgradeMessageCode.installValidationFailed => l10n.t(
      'adminUpgradeErrorInstallValidationFailed',
      '升级包未通过 Android 安装前校验',
    ),
    TerminalUpgradeMessageCode.installSubmissionFailed => l10n.t(
      'adminUpgradeErrorInstallSubmissionFailed',
      '无法创建或提交系统安装会话',
    ),
    TerminalUpgradeMessageCode.installSessionMissing => l10n.t(
      'adminUpgradeErrorInstallSessionMissing',
      '系统安装会话已不存在，请重新发起升级',
    ),
    TerminalUpgradeMessageCode.installSessionExpired => l10n.t(
      'adminUpgradeErrorInstallSessionExpired',
      '系统安装会话已过期并被终止，请重新发起升级',
    ),
    TerminalUpgradeMessageCode.confirmationRecoveryFailed => l10n.t(
      'adminUpgradeErrorConfirmationRecoveryFailed',
      '安装确认恢复任务无法调度，请联系运维人员',
    ),
    TerminalUpgradeMessageCode.confirmationTimedOut => l10n.t(
      'adminUpgradeErrorConfirmationTimedOut',
      '等待安装确认超时，系统会话已取消，请重新发起升级',
    ),
    TerminalUpgradeMessageCode.packageInstallerFailed => l10n.t(
      'adminUpgradeErrorPackageInstallerFailed',
      'Android 系统安装器报告安装失败',
    ),
  };
  final text = _replaceUpgradePlaceholders(template, message.arguments);
  final detail = message.detail.trim();
  final containsCjk = RegExp(r'[\u3400-\u9fff\u3040-\u30ff]').hasMatch(detail);
  if (detail.isEmpty ||
      containsCjk && l10n.language != AppLanguage.simplifiedChinese) {
    return text;
  }
  return _replaceUpgradePlaceholders(
    l10n.t('adminUpgradeMessageWithDetail', '{message}：{detail}'),
    <String, String>{'message': text, 'detail': detail},
  );
}

/// 为读取、保存、检查和安装操作生成当前语言的错误提示。
String _upgradeActionErrorText(
  BuildContext context, {
  required String key,
  required String fallback,
  required Object error,
}) {
  final rawDetail = error is TerminalUpgradeOperationException
      ? _upgradeMessageText(context, error.reason)
      : error
            .toString()
            .replaceFirst(RegExp(r'^(Bad state|Exception):\s*'), '')
            .trim();
  final containsCjk = RegExp(
    r'[\u3400-\u9fff\u3040-\u30ff]',
  ).hasMatch(rawDetail);
  final detail =
      error is TerminalUpgradeOperationException ||
          rawDetail.isNotEmpty &&
              (!containsCjk ||
                  context.l10n.language == AppLanguage.simplifiedChinese)
      ? rawDetail
      : context.l10n.t('adminUpgradeErrorUnexpectedOperation', '操作未完成，请重试');
  return _replaceUpgradePlaceholders(
    context.l10n.t(key, fallback),
    <String, String>{'detail': detail},
  );
}

/// 替换升级文案模板中的命名占位符。
String _replaceUpgradePlaceholders(
  String template,
  Map<String, String> arguments,
) {
  var result = template;
  for (final entry in arguments.entries) {
    result = result.replaceAll('{${entry.key}}', entry.value);
  }
  return result;
}
