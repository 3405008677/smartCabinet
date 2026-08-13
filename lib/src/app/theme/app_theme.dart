import 'package:flutter/material.dart';

/// 应用主题配置。
///
/// 主题用于统一控制全局颜色、按钮样式、字体密度等视觉规范。
class AppTheme {
  const AppTheme._();

  /// 应用主色。
  static const Color primaryColor = Color(0xFF0F766E);

  /// 品牌深色，用于按下态和高强调文本。
  static const Color primaryStrongColor = Color(0xFF0B5F59);

  /// 品牌亮色，用于渐变和装饰元素。
  static const Color primaryLightColor = Color(0xFF2A9D8F);

  /// 品牌浅色背景，用于选中态和信息容器。
  static const Color primarySoftColor = Color(0xFFE7F3F1);

  /// 品牌浅色边框，用于选中控件的轮廓。
  static const Color primaryBorderColor = Color(0xFFB8D8D3);

  /// 页面外层背景色。
  static const Color scaffoldBackgroundColor = Color(0xFFF1F6F5);

  /// 卡片和弹窗常用背景色。
  static const Color surfaceColor = Color(0xFFFBFDFC);

  /// 正文和高强调文本使用的中性色。
  static const Color textPrimaryColor = Color(0xFF172321);

  /// 辅助说明文本使用的中性色。
  static const Color textSecondaryColor = Color(0xFF64736F);

  /// 分隔线和普通控件轮廓使用的中性色。
  static const Color outlineColor = Color(0xFFD9E4E1);

  /// 常用触控目标尺寸。
  ///
  /// 较大的触控区域更适合智能柜这类触屏终端设备。
  static const double touchTargetSize = 56;

  /// 浅色主题。
  ///
  /// 当前项目使用 Material 3，并基于 [primaryColor] 生成一套颜色方案。
  static ThemeData get lightTheme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
          surface: surfaceColor,
        ).copyWith(
          primary: primaryColor,
          onPrimary: Colors.white,
          primaryContainer: primarySoftColor,
          onPrimaryContainer: primaryStrongColor,
          surface: surfaceColor,
          onSurface: textPrimaryColor,
          outline: outlineColor,
        );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      visualDensity: VisualDensity.standard,
      dividerColor: outlineColor,
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: primarySoftColor,
        circularTrackColor: primarySoftColor,
      ),
      cardTheme: const CardThemeData(
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outlineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
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
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.onPrimary
              : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : null,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : null,
        ),
      ),
    );
  }
}
