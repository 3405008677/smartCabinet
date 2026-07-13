import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/core/device/device_info_service.dart';
import 'package:smart_cabinet/src/core/storage/app_local_store_provider.dart';
import 'package:smart_cabinet/src/features/admin/presentation/widgets/admin_login_dialog.dart';

// 首页隐藏设置模块。
//
// 入口由首页底部版本号连续点击触发。这里聚合语言切换、管理员模式入口和
// 设备信息弹窗，避免这些低频配置逻辑挤在 Home 页面主文件中。

/// 打开首页隐藏设置弹窗。
void showSettingsDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _SettingsDialog(),
  );
}

/// 首页设置弹窗。
class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog();

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

/// 设置弹窗状态。
///
/// 当前设置项都直接依赖全局控制器或本地服务，不需要额外持有表单状态。
class _SettingsDialogState extends State<_SettingsDialog> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE4EAF6)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24111B3D),
                blurRadius: 28,
                offset: Offset(0, 18),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 22, 18, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFF17213D), Color(0xFF2F64F6)],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.settings_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.t('settings', '设置'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              height: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.t('settingsSubtitle', '设备偏好与本地显示配置'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .76),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.t('close', '关闭'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LanguageSettingRow(
                      selectedLanguage: appLocaleController.language,
                      onChanged: (language) {
                        if (language == null) {
                          return;
                        }

                        appLocaleController.setLanguage(language);
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 14),
                    _AdminModeSettingRow(
                      onTap: () {
                        Navigator.of(context).pop();
                        showAdminLoginDialog(context);
                      },
                    ),
                    const SizedBox(height: 14),
                    _AboutDeviceSettingRow(
                      onTap: () => _showAboutDeviceDialog(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 设置列表中的管理员模式入口行。
class _AdminModeSettingRow extends StatelessWidget {
  const _AdminModeSettingRow({required this.onTap});

  /// 点击管理员模式入口时执行的动作。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE4EAF6)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF2F64F6).withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: Color(0xFF2F64F6),
                  size: 21,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  l10n.t('adminMode', '管理员模式'),
                  style: const TextStyle(
                    color: Color(0xFF17213D),
                    fontSize: 16,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF7A86A8),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 设置列表中的关于设备入口行。
class _AboutDeviceSettingRow extends StatelessWidget {
  const _AboutDeviceSettingRow({required this.onTap});

  /// 点击关于设备入口时执行的动作。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE4EAF6)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF2F64F6).withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.memory_rounded,
                  color: Color(0xFF2F64F6),
                  size: 21,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('aboutDevice', '关于设备'),
                      style: const TextStyle(
                        color: Color(0xFF17213D),
                        fontSize: 16,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.t('aboutDeviceHint', '查看当前主板与系统信息'),
                      style: const TextStyle(
                        color: Color(0xFF7A86A8),
                        fontSize: 12,
                        height: 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF7A86A8),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 弹出关于设备窗口。
void _showAboutDeviceDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => const _AboutDeviceDialog(),
  );
}

/// 关于设备弹窗。
class _AboutDeviceDialog extends StatefulWidget {
  const _AboutDeviceDialog();

  @override
  State<_AboutDeviceDialog> createState() => _AboutDeviceDialogState();
}

class _AboutDeviceDialogState extends State<_AboutDeviceDialog> {
  /// 设备信息加载任务。
  late final Future<List<DeviceInfoItem>> _deviceInfoFuture;

  @override
  void initState() {
    super.initState();
    _deviceInfoFuture = _loadCachedDeviceInfo();
  }

  /// 从本地 Store 读取启动阶段缓存的设备信息。
  Future<List<DeviceInfoItem>> _loadCachedDeviceInfo() async {
    final providerContainer = ProviderScope.containerOf(context, listen: false);
    final store = await providerContainer.read(appLocalStoreProvider.future);
    final deviceInfo = (await store.state()).deviceInfo;

    if (deviceInfo.isEmpty) {
      return const [DeviceInfoItem(label: '状态', value: '设备信息尚未完成启动缓存')];
    }

    return deviceInfo.entries
        .map(
          (entry) => DeviceInfoItem(
            label: entry.key,
            value: entry.value?.toString() ?? '未知',
          ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE4EAF6)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24111B3D),
                blurRadius: 28,
                offset: Offset(0, 18),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AboutDeviceHeader(title: l10n.t('aboutDevice', '关于设备')),
              Flexible(
                child: FutureBuilder<List<DeviceInfoItem>>(
                  future: _deviceInfoFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SizedBox(
                        height: 220,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError) {
                      return _AboutDeviceError(
                        message: l10n.t(
                          'aboutDeviceLoadFailed',
                          '设备信息读取失败，请确认当前运行在 Android 主板环境',
                        ),
                      );
                    }

                    final items = snapshot.data ?? const <DeviceInfoItem>[];
                    return _AboutDeviceInfoList(items: items);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 关于设备弹窗标题栏。
class _AboutDeviceHeader extends StatelessWidget {
  const _AboutDeviceHeader({required this.title});

  /// 标题文本。
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 18, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF17213D), Color(0xFF2F64F6)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.memory_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.t('close', '关闭'),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// 关于设备信息列表。
class _AboutDeviceInfoList extends StatelessWidget {
  const _AboutDeviceInfoList({required this.items});

  /// 设备信息条目。
  final List<DeviceInfoItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      itemBuilder: (context, index) => _AboutDeviceInfoRow(item: items[index]),
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemCount: items.length,
    );
  }
}

/// 单条关于设备信息行。
class _AboutDeviceInfoRow extends StatelessWidget {
  const _AboutDeviceInfoRow({required this.item});

  /// 设备信息条目。
  final DeviceInfoItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4EAF6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 154,
            child: Text(
              item.label,
              style: const TextStyle(
                color: Color(0xFF6E7CA7),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SelectableText(
              item.value,
              style: const TextStyle(
                color: Color(0xFF17213D),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 关于设备读取失败提示。
class _AboutDeviceError extends StatelessWidget {
  const _AboutDeviceError({required this.message});

  /// 错误提示。
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF9A3412),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// 设置列表中的语言选择行。
class _LanguageSettingRow extends StatelessWidget {
  const _LanguageSettingRow({
    required this.selectedLanguage,
    required this.onChanged,
  });

  /// 当前选中的语言。
  final AppLanguage selectedLanguage;

  /// 语言选择变化回调。
  final ValueChanged<AppLanguage?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EAF6)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF2F64F6).withValues(alpha: .08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.language_rounded,
              color: Color(0xFF2F64F6),
              size: 21,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('languageSetting', '语言设置'),
                  style: const TextStyle(
                    color: Color(0xFF17213D),
                    fontSize: 16,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.t('languageSettingHint', '选择终端界面显示语言'),
                  style: const TextStyle(
                    color: Color(0xFF7A86A8),
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _LanguageDropdown(
            selectedLanguage: selectedLanguage,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// 带国家或地区图标的语言下拉框。
class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({
    required this.selectedLanguage,
    required this.onChanged,
  });

  /// 当前选中的语言。
  final AppLanguage selectedLanguage;

  /// 语言选择变化回调。
  final ValueChanged<AppLanguage?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 172,
      height: 46,
      padding: const EdgeInsets.only(left: 12, right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9E2F5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppLanguage>(
          key: const ValueKey('settings_language_dropdown'),
          value: selectedLanguage,
          borderRadius: BorderRadius.circular(14),
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF6877A2),
          ),
          items: AppLanguage.values
              .map((language) {
                return DropdownMenuItem<AppLanguage>(
                  value: language,
                  child: _LanguageOption(language: language),
                );
              })
              .toList(growable: false),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// 下拉框中的单个语言选项。
class _LanguageOption extends StatelessWidget {
  const _LanguageOption({required this.language});

  /// 语言配置。
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(language.icon, style: const TextStyle(fontSize: 19)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            language.label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF17213D),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
