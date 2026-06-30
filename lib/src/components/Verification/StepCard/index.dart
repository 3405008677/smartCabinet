import 'package:flutter/material.dart';

/// 认证步骤统一外壳卡片。
///
/// 用于给人脸、指纹、NFC、取件码等步骤提供统一的外层边框和头部样式。
class VerificationStepCard extends StatelessWidget {
  /// 创建认证步骤统一外壳卡片。
  const VerificationStepCard({
    required this.index,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.verified,
    required this.child,
    this.width,
    this.height,
    super.key,
  });

  /// 步骤编号。
  final int index;

  /// 步骤标题。
  final String title;

  /// 步骤图标。
  final IconData icon;

  /// 强调色。
  final Color accentColor;

  /// 当前步骤是否已完成。
  final bool verified;

  /// 卡片内容区。
  final Widget child;

  /// 可选固定宽度。
  final double? width;

  /// 可选固定高度。
  final double? height;

  @override
  Widget build(BuildContext context) {
    final borderColor = verified ? const Color(0xFF59BE5A) : accentColor;

    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: verified ? .98 : .94),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D1B2E5A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              height: 74,
              padding: const EdgeInsets.fromLTRB(20, 0, 18, 0),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE9EEF8))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: .1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: accentColor, size: 23),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111936),
                        fontSize: 16,
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
                            '$index',
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
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
