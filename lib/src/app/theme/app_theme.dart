import 'package:flutter/material.dart';

/// 应用主题配置。
///
/// 主题用于统一控制全局颜色、按钮样式、字体密度等视觉规范。
class AppTheme {
  const AppTheme._();

  /// 应用主色。
  static const Color primaryColor = Color(0xFF0F766E);

  /// 页面外层背景色。
  static const Color scaffoldBackgroundColor = Color(0xFFD6DEEF);

  /// 卡片和弹窗常用背景色。
  static const Color surfaceColor = Color(0xFFF9FAFF);

  /// 常用触控目标尺寸。
  ///
  /// 较大的触控区域更适合智能柜这类触屏终端设备。
  static const double touchTargetSize = 56;

  /// 浅色主题。
  ///
  /// 当前项目使用 Material 3，并基于 [primaryColor] 生成一套颜色方案。
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(seedColor: primaryColor);

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),

      /// 全局 ElevatedButton 默认样式。
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(touchTargetSize, touchTargetSize),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline),
          minimumSize: const Size(touchTargetSize, touchTargetSize),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
      ),
    );
  }
}
