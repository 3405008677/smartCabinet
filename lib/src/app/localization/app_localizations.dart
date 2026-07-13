import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/localization/values/admin_localizations.dart';
import 'package:smart_cabinet/src/app/localization/values/dropoff_localizations.dart';
import 'package:smart_cabinet/src/app/localization/values/foundation_localizations.dart';
import 'package:smart_cabinet/src/app/localization/values/home_localizations.dart';
import 'package:smart_cabinet/src/app/localization/values/inspection_localizations.dart';
import 'package:smart_cabinet/src/app/localization/values/pickup_localizations.dart';

/// 应用支持的界面语言。
enum AppLanguage {
  /// 简体中文。
  simplifiedChinese(locale: Locale('zh', 'CN'), label: '简体中文', icon: '🇨🇳'),

  /// 繁体中文。
  traditionalChinese(locale: Locale('zh', 'TW'), label: '繁體中文', icon: '🇭🇰'),

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
}

/// 应用语言状态控制器。
final class AppLocaleController extends ChangeNotifier {
  /// 创建语言控制器，默认使用简体中文。
  AppLocaleController() : _language = AppLanguage.simplifiedChinese;

  AppLanguage _language;

  /// 当前选择的语言。
  AppLanguage get language => _language;

  /// 当前选择语言对应的 Flutter Locale。
  Locale get locale => _language.locale;

  /// 切换应用语言。
  void setLanguage(AppLanguage language) {
    if (_language == language) {
      return;
    }

    _language = language;
    notifyListeners();
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
    ...foundationLocalizations,
    ...pickupLocalizations,
    ...dropoffLocalizations,
    ...inspectionLocalizations,
    ...adminLocalizations,
  };

  /// 根据 key 读取当前语言文案，缺少翻译时回退到调用处的中文兜底文案。
  String t(String key, String fallback) {
    if (language == AppLanguage.simplifiedChinese) {
      return fallback;
    }

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
