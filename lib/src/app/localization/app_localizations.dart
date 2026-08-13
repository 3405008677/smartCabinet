import 'dart:async';

import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/localization/values/admin_localizations.dart';
import 'package:smart_cabinet/src/app/localization/values/device_info_localizations.dart';
import 'package:smart_cabinet/src/app/localization/values/home_localizations.dart';
import 'package:smart_cabinet/src/app/localization/values/home_runtime_localizations.dart';
import 'package:smart_cabinet/src/app/localization/values/identity_localizations.dart';
import 'package:smart_cabinet/src/app/localization/values/operator_workflow_localizations.dart';
import 'package:smart_cabinet/src/app/localization/values/system_localizations.dart';
import 'package:smart_cabinet/src/app/localization/values/task_inventory_localizations.dart';
import 'package:smart_cabinet/src/app/localization/values/terminal_upgrade_localizations.dart';

/// 应用支持的界面语言。
enum AppLanguage {
  /// 简体中文。
  simplifiedChinese(locale: Locale('zh', 'CN'), label: '简体中文', icon: '🇨🇳'),

  /// 繁体中文。
  traditionalChinese(locale: Locale('zh', 'TW'), label: '繁體中文', icon: '🇹🇼'),

  /// 英语。
  english(locale: Locale('en', 'US'), label: 'English', icon: '🇺🇸'),

  /// 日语。
  japanese(locale: Locale('ja', 'JP'), label: '日本語', icon: '🇯🇵');

  /// 创建语言配置。
  const AppLanguage({
    required this.locale,
    required this.label,
    required this.icon,
  });

  /// Flutter 使用的语言地区。
  final Locale locale;

  /// 下拉列表中展示的语言名称。
  final String label;

  /// 代表语言国家或地区的图标。
  final String icon;

  /// 持久化到本地 Store 的标准语言标签。
  String get code => '${locale.languageCode}-${locale.countryCode}';

  /// 把本地存储或旧版本留下的语言代码解析为应用支持的语言。
  ///
  /// 同时兼容连字符、下划线、仅语言代码以及常见的繁体中文地区/脚本标签。
  static AppLanguage fromCode(String? code) {
    final normalized = (code ?? '').trim().replaceAll('_', '-').toLowerCase();
    for (final language in values) {
      if (language.code.toLowerCase() == normalized) {
        return language;
      }
    }

    if (normalized == 'zh' || normalized.startsWith('zh-')) {
      final traditional =
          normalized.contains('tw') ||
          normalized.contains('hk') ||
          normalized.contains('mo') ||
          normalized.contains('hant');
      return traditional ? traditionalChinese : simplifiedChinese;
    }
    if (normalized == 'en' || normalized.startsWith('en-')) {
      return english;
    }
    if (normalized == 'ja' || normalized.startsWith('ja-')) {
      return japanese;
    }
    return simplifiedChinese;
  }
}

/// 应用语言状态控制器。
final class AppLocaleController extends ChangeNotifier {
  /// 创建语言控制器，默认使用简体中文。
  AppLocaleController() : _language = AppLanguage.simplifiedChinese;

  AppLanguage _language;

  Future<void> Function(AppLanguage language)? _persistLanguage;
  void Function(Object error, StackTrace stackTrace)? _onPersistenceError;
  Future<void> _persistenceTail = Future<void>.value();
  int _persistenceGeneration = 0;

  /// 当前选择的语言。
  AppLanguage get language => _language;

  /// 当前选择语言对应的 Flutter Locale。
  Locale get locale => _language.locale;

  /// 切换应用语言。
  void setLanguage(AppLanguage language, {bool persist = true}) {
    if (_language == language) {
      return;
    }

    _language = language;
    notifyListeners();

    if (persist) {
      _schedulePersistence(language);
    }
  }

  /// 绑定语言偏好的持久化实现。
  ///
  /// 控制器会串行执行写入，确保用户快速连续切换语言时，最后一次选择不会被较慢的旧写入覆盖。
  void bindPersistence({
    required Future<void> Function(AppLanguage language) persistLanguage,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    _persistenceGeneration += 1;
    _persistLanguage = persistLanguage;
    _onPersistenceError = onError;
  }

  /// 解除当前持久化实现，供应用重新启动或测试清理状态时使用。
  void clearPersistence() {
    _persistenceGeneration += 1;
    _persistLanguage = null;
    _onPersistenceError = null;
  }

  void _schedulePersistence(AppLanguage language) {
    final persistLanguage = _persistLanguage;
    if (persistLanguage == null) {
      return;
    }

    final onError = _onPersistenceError;
    final generation = _persistenceGeneration;
    final previous = _persistenceTail;
    _persistenceTail = () async {
      await previous;
      if (generation != _persistenceGeneration) {
        return;
      }

      try {
        await persistLanguage(language);
      } catch (error, stackTrace) {
        onError?.call(error, stackTrace);
      }
    }();

    // 明确标记这个由控制器内部托管的异步任务，避免调用页面需要自行处理 Future。
    unawaited(_persistenceTail);
  }
}

/// 全局语言控制器，供应用根组件和设置弹窗共享。
final appLocaleController = AppLocaleController();

/// 应用文案本地化入口。
class AppLocalizations {
  /// 创建指定语言的文案集合。
  const AppLocalizations(this.language);

  /// 当前文案语言。
  final AppLanguage language;

  static final Map<String, Map<AppLanguage, String>> _values = {
    ...homeLocalizations,
    ...homeRuntimeLocalizations,
    ...deviceInfoLocalizations,
    ...identityLocalizations,
    ...operatorWorkflowLocalizations,
    ...systemLocalizations,
    ...taskInventoryLocalizations,
    ...adminLocalizations,
    ...terminalUpgradeRuntimeLocalizations,
  };

  /// 根据 key 读取当前语言文案，缺少注册项时回退到调用处的中文兜底文案。
  ///
  /// 简体中文也统一从资源表读取，确保所有语言只有一份可审计的正式文案；
  /// [fallback] 只负责保护尚未注册或动态生成的调用点。
  String t(String key, String fallback) {
    return _values[key]?[language] ?? fallback;
  }

  /// 从上下文读取当前文案集合。
  static AppLocalizations of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<AppLocalizationsScope>();
    return inherited?.localizations ??
        AppLocalizations(appLocaleController.language);
  }
}

/// 向子树暴露当前本地化文案。
class AppLocalizationsScope extends InheritedWidget {
  /// 创建本地化作用域。
  const AppLocalizationsScope({
    required this.localizations,
    required super.child,
    super.key,
  });

  /// 当前语言文案集合。
  final AppLocalizations localizations;

  @override
  bool updateShouldNotify(AppLocalizationsScope oldWidget) {
    return localizations.language != oldWidget.localizations.language;
  }
}

/// 快捷读取本地化文案的 BuildContext 扩展。
extension AppLocalizationsX on BuildContext {
  /// 当前语言文案集合。
  AppLocalizations get l10n => AppLocalizations.of(this);
}
