import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../core/device/hardware_recovery_advice.dart';

/// 指纹和 NFC 等简单传感器认证卡片。
class SensorVerificationCard extends StatelessWidget {
  /// 创建简单传感器认证卡片。
  const SensorVerificationCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.stepNumber,
    required this.verified,
    required this.actionText,
    required this.verifiedText,
    required this.onConfirm,
    this.accentColor = const Color(0xFF4664E9),
    this.compact = false,
    this.showHeader = true,
    this.recoveryAdvice,
    this.onRetry,
  });

  /// 卡片标题。
  final String title;

  /// 卡片英文副标题。
  ///
  /// 当前统一头部样式不再展示该字段，保留仅为兼容现有调用。
  final String subtitle;

  /// 卡片图标。
  final IconData icon;

  /// 右上角显示的步骤编号。
  final int? stepNumber;

  /// 是否已经认证通过。
  final bool verified;

  /// 未认证时的按钮文案。
  final String actionText;

  /// 认证通过后的状态文案。
  final String verifiedText;

  /// 点击认证按钮时触发。
  final VoidCallback onConfirm;

  /// 主题强调色。
  final Color accentColor;

  /// 是否使用紧凑模式。
  final bool compact;

  /// 是否显示卡片内部标题和副标题。
  final bool showHeader;

  /// 硬件异常恢复建议。
  final HardwareRecoveryAdvice? recoveryAdvice;

  /// 点击重新检测时触发。
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    /// 当前语言文案集合。
    final l10n = context.l10n;

    /// 当前视觉状态下使用的主色，认证完成后统一切为成功绿。
    final activeColor = verified ? const Color(0xFF22A857) : accentColor;

    /// 中部状态图标尺寸。
    final iconSize = compact ? 42.0 : 48.0;

    /// 中部图标容器尺寸。
    final iconBoxSize = compact ? 82.0 : 92.0;

    /// 底部主操作按钮宽度。
    final buttonWidth = compact ? 160.0 : 168.0;

    /// 头部左侧圆形图标容器尺寸。
    final headerIconBoxSize = compact ? 40.0 : 44.0;

    /// 头部左侧图标尺寸。
    final headerIconSize = compact ? 22.0 : 24.0;

    /// 头部标题字号。
    final headerTitleSize = compact ? 16.0 : 18.0;

    /// 当前硬件异常恢复建议，没有异常时为 null。
    final advice = recoveryAdvice;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showHeader ? (compact ? 20 : 24) : 0,
        vertical: showHeader ? (compact ? 20 : 24) : 4,
      ),
      decoration: showHeader
          ? BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: activeColor.withValues(alpha: .22)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D1B2E5A),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            )
          : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showHeader) ...[
            Container(
              height: compact ? 54 : 58,
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE9EEF8))),
              ),
              child: Row(
                children: [
                  Container(
                    width: headerIconBoxSize,
                    height: headerIconBoxSize,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: .1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: accentColor, size: headerIconSize),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF111936),
                        fontSize: headerTitleSize,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: verified ? const Color(0xFF59BE5A) : accentColor,
                      shape: BoxShape.circle,
                    ),
                    child: verified
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 18,
                          )
                        : Text(
                            '${stepNumber ?? 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            SizedBox(height: compact ? 20 : 24),
          ],
          Container(
            width: iconBoxSize,
            height: iconBoxSize,
            decoration: BoxDecoration(
              color: activeColor.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(compact ? 24 : 28),
            ),
            child: Icon(
              verified ? Icons.check_circle_rounded : icon,
              color: activeColor,
              size: iconSize,
            ),
          ),
          if (advice != null) ...[
            SizedBox(height: compact ? 12 : 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6E8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFD49A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    advice.title,
                    style: const TextStyle(
                      color: Color(0xFF9A5A00),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    advice.recoverySteps,
                    style: const TextStyle(
                      color: Color(0xFF7A4A0A),
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: onRetry ?? onConfirm,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF9A5A00),
                      side: const BorderSide(color: Color(0xFFFFC46F)),
                    ),
                    child: const Text('重新检测'),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: compact ? 18 : 24),
          if (!showHeader) SizedBox(height: compact ? 14 : 18),
          Text(
            verified
                ? verifiedText
                : l10n.t('sharedWaitingVerification', '等待认证'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: activeColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: compact ? 14 : 18),
          SizedBox(
            height: 44,
            width: buttonWidth,
            child: ElevatedButton(
              onPressed: verified ? null : onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFEAF0FF),
                disabledForegroundColor: const Color(0xFF22A857),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: Text(
                verified ? l10n.t('sharedVerified', '已通过') : actionText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
