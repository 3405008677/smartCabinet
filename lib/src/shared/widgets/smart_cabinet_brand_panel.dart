import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/theme/app_theme.dart';

/// 不包含栅格文字的智能柜品牌面板。
///
/// 启动页和首页共用这套代码化视觉，所有文字都会随当前语言即时切换。
class SmartCabinetBrandPanel extends StatelessWidget {
  /// 创建智能柜品牌面板。
  const SmartCabinetBrandPanel({
    this.compact = false,
    this.showLoading = false,
    super.key,
  });

  /// 是否使用适合首页卡片的紧凑布局。
  final bool compact;

  /// 是否显示系统启动进度。
  final bool showLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = l10n.t('startupBrandTitle', '智能柜');

    return Semantics(
      container: true,
      label: title,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7FAFF), Color(0xFFE8F1FF)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useCompactLayout =
                compact ||
                constraints.maxHeight < 420 ||
                constraints.maxWidth < 720;
            final iconBoxSize = useCompactLayout ? 64.0 : 96.0;

            return Stack(
              fit: StackFit.expand,
              children: [
                const _BrandBackdrop(),
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: useCompactLayout ? 20 : 48,
                      vertical: useCompactLayout ? 18 : 36,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: iconBoxSize,
                          height: iconBoxSize,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(
                              useCompactLayout ? 20 : 30,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: .22,
                                ),
                                blurRadius: useCompactLayout ? 18 : 28,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.inventory_2_rounded,
                            color: Colors.white,
                            size: useCompactLayout ? 34 : 52,
                          ),
                        ),
                        SizedBox(height: useCompactLayout ? 14 : 22),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontSize: useCompactLayout ? 25 : 40,
                            height: 1.08,
                            fontWeight: FontWeight.w900,
                            letterSpacing: useCompactLayout ? .4 : 1,
                          ),
                        ),
                        SizedBox(height: useCompactLayout ? 8 : 12),
                        Text(
                          l10n.t('startupBrandTagline', '智享生活，便捷未来'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: useCompactLayout ? 13 : 17,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: useCompactLayout ? 16 : 26),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: useCompactLayout ? 8 : 12,
                          runSpacing: useCompactLayout ? 8 : 12,
                          children: [
                            _BrandFeature(
                              compact: useCompactLayout,
                              icon: Icons.face_retouching_natural_rounded,
                              label: l10n.t(
                                'startupFeatureRecognition',
                                '智能识别',
                              ),
                            ),
                            _BrandFeature(
                              compact: useCompactLayout,
                              icon: Icons.verified_user_rounded,
                              label: l10n.t('startupFeatureSecurity', '安全可靠'),
                            ),
                            _BrandFeature(
                              compact: useCompactLayout,
                              icon: Icons.cloud_done_rounded,
                              label: l10n.t('startupFeatureCloud', '云端管理'),
                            ),
                            _BrandFeature(
                              compact: useCompactLayout,
                              icon: Icons.energy_savings_leaf_rounded,
                              label: l10n.t('startupFeatureEnergy', '绿色节能'),
                            ),
                          ],
                        ),
                        if (showLoading) ...[
                          SizedBox(height: useCompactLayout ? 22 : 34),
                          SizedBox(
                            width: useCompactLayout ? 22 : 26,
                            height: useCompactLayout ? 22 : 26,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.8,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          SizedBox(height: useCompactLayout ? 10 : 14),
                          Text(
                            l10n.t('startupSystemLoading', '系统启动中…'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: useCompactLayout ? 12 : 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BrandBackdrop extends StatelessWidget {
  const _BrandBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: -90,
            top: -110,
            child: _circle(270, const Color(0x1A3377FF)),
          ),
          Positioned(
            right: -70,
            bottom: -120,
            child: _circle(300, const Color(0x1430B59B)),
          ),
          Positioned(
            right: 54,
            top: 42,
            child: _circle(72, const Color(0x123377FF)),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _BrandFeature extends StatelessWidget {
  const _BrandFeature({
    required this.compact,
    required this.icon,
    required this.label,
  });

  final bool compact;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .84),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primaryBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 15 : 18, color: AppTheme.primaryColor),
          SizedBox(width: compact ? 5 : 7),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
