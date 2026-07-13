import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';

/// 底部验证进度条。
///
/// 用于显示当前认证流程已完成的步骤数量。
class VerificationProgressFooter extends StatelessWidget {
  /// 创建底部验证进度条。
  const VerificationProgressFooter({
    required this.completedCount,
    required this.totalCount,
    this.accentColor,
    super.key,
  });

  /// 已完成的步骤数量。
  final int completedCount;

  /// 总步骤数量。
  final int totalCount;

  /// 进度条主题色。
  ///
  /// 为空时使用当前应用主题主色。
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    /// 当前流程进度，范围在 0 到 1 之间。
    final double progress = totalCount == 0 ? 0 : completedCount / totalCount;

    /// 当前界面语言的文案读取入口。
    final l10n = context.l10n;

    /// 当前组件实际使用的强调色。
    final effectiveAccentColor =
        accentColor ?? Theme.of(context).colorScheme.primary;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFF),
        border: Border(top: BorderSide(color: Color(0xFFE4EAF6))),
      ),
      child: Row(
        children: [
          Text(
            l10n.t('sharedVerificationProgress', '验证进度'),
            style: TextStyle(
              color: Color(0xFF9AA7C4),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: progress),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE9EEF8),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      effectiveAccentColor,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '$completedCount / $totalCount',
            style: TextStyle(
              color: effectiveAccentColor,
              fontSize: 13,
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
