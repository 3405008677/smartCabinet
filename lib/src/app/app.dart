import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'localization/app_localizations.dart';
import 'router/app_router.dart';
import 'startup/startup_media.dart';
import 'theme/app_theme.dart';

/// 应用的根组件。
///
/// [SmartCabinetApp] 是整个 Flutter UI 树的入口，负责配置：
/// - 应用标题；
/// - 主题样式；
/// - 初始页面；
/// - 路由生成规则；
/// - 中文和英文的本地化支持。
class SmartCabinetApp extends StatelessWidget {
  /// 创建智能柜应用根组件。
  const SmartCabinetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appLocaleController,
      builder: (context, _) {
        final localizations = AppLocalizations(appLocaleController.language);

        return AppLocalizationsScope(
          localizations: localizations,
          child: MaterialApp(
            /// 系统任务列表、无障碍服务等地方可能会使用这个标题。
            title: localizations.t('appTitle', '智能文件保管柜'),

            /// 关闭右上角 Debug 横幅，让界面更接近真实设备效果。
            debugShowCheckedModeBanner: false,

            /// 使用项目统一定义的浅色主题。
            theme: AppTheme.lightTheme,

            /// 应用启动后默认进入首页。
            initialRoute: AppRoutes.home,

            /// 根据路由名称创建对应页面。
            onGenerateRoute: AppRouter.onGenerateRoute,

            /// 在首页初始化完成前显示启动媒体层，避免启动白屏。
            builder: (context, child) {
              return StartupMedia(child: child ?? const SizedBox.shrink());
            },

            /// 当前界面语言。
            locale: appLocaleController.locale,

            /// 声明应用支持的语言环境。
            supportedLocales: AppLanguage.values
                .map((language) => language.locale)
                .toList(growable: false),

            /// Flutter 官方组件的本地化代理。
            ///
            /// 例如日期选择器、Material 组件默认文案等，会根据当前语言显示。
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
          ),
        );
      },
    );
  }
}
