import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/app_router.dart';
import '../../../../components/Layout/TerminalShell/index.dart';

/// 存取件。
///
/// 这是智能柜终端启动后看到的主界面，提供“取件”和“放件”两个入口。
class FoundationHomePage extends StatelessWidget {
  /// 创建组件。
  const FoundationHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return TerminalShell(
      topBarLeading: _BackToHomeButton(
        onTap: () => Navigator.of(context).maybePop(),
      ),
      topRightBadge: FlowStatusBadge(
        text: l10n.t('foundationSystemOnline', 'SYSTEM ONLINE · 安全运行中'),
      ),
      child: CustomPaint(
        painter: const _DotGridPainter(),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF2F6FF), Color(0xFFF8FAFF)],
            ),
          ),
          child: const _HomeBody(),
        ),
      ),
    );
  }
}

class _BackToHomeButton extends StatelessWidget {
  const _BackToHomeButton({required this.onTap});

  /// 点击“返回首页”时的回调。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    /// 这里使用 `TextButton.icon`，让返回操作视觉上更轻量，不抢主入口焦点。
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
      label: Text(context.l10n.t('foundationBackHome', '返回首页')),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF4664E9),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// 首页主体内容。
///
/// 包含在线状态、操作标题以及取件/放件卡片。
class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      children: [
        const SizedBox(height: 59),
        Text(
          l10n.t('foundationSelectActionTitle', '请选择操作类型'),
          style: TextStyle(
            color: Color(0xFF111936),
            fontSize: 46,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.t('foundationSecuritySubtitle', '四重安全认证 · 全程加密保护 · 实名追溯存档'),
          style: TextStyle(
            color: Color(0xFF69769E),
            fontSize: 16,
            height: 1,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 62),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ActionCard(
              title: l10n.t('foundationPickupTitle', '取件'),
              subtitle: 'PICK UP',
              description: l10n.t(
                'foundationPickupDescription',
                '人脸 · 指纹 · NFC · 取件码四重验证后安全取出文件',
              ),
              startText: l10n.t('foundationTapStart', '点击开始 →'),
              icon: const _DocumentActionIcon(
                color: Color(0xFF4B67EA),
                isUpload: false,
              ),
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.pickupVerification),
            ),
            const SizedBox(width: 34),
            _ActionCard(
              title: l10n.t('foundationDropoffTitle', '放件'),
              subtitle: 'DROP OFF',
              description: l10n.t(
                'foundationDropoffDescription',
                '人脸 · 指纹 · NFC 认证后进入文件认证并安全存入文件',
              ),
              startText: l10n.t('foundationTapStart', '点击开始 →'),
              icon: const _DocumentActionIcon(
                color: Color(0xFF5791B6),
                isUpload: true,
              ),
              onTap: () => Navigator.of(
                context,
              ).pushNamed(AppRoutes.dropoffPersonVerification),
            ),
          ],
        ),
      ],
    );
  }
}

/// 首页操作卡片。
///
/// 用于展示一个可点击的业务入口，例如“取件”或“放件”。
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.startText,
    required this.icon,
    this.onTap,
  });

  /// 卡片主标题，例如“取件”“放件”。
  final String title;

  /// 卡片英文副标题，用于增强终端大屏视觉层次。
  final String subtitle;

  /// 入口说明文案，向用户解释进入后会进行什么业务。
  final String description;

  /// 卡片底部的开始提示文案。
  final String startText;

  /// 卡片顶部图标区域。
  final Widget icon;

  /// 点击卡片时触发的业务动作。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          width: 362,
          height: 376,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5EBF8)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D1B2E5A),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 48),
              icon,
              const SizedBox(height: 29),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF020817),
                  fontSize: 36,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF4664E9),
                  fontSize: 13,
                  height: 1,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 250,
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF4C5E8B),
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Text(
                startText,
                style: TextStyle(
                  color: Color(0xFFA9B2CC),
                  fontSize: 14,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 文件操作图标容器。
class _DocumentActionIcon extends StatelessWidget {
  const _DocumentActionIcon({required this.color, required this.isUpload});

  /// 图标主色。
  final Color color;

  /// 是否绘制为“上载/放件”方向的文档动作图标。
  final bool isUpload;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: CustomPaint(
          size: const Size(46, 54),
          painter: _DocumentIconPainter(color: color, isUpload: isUpload),
        ),
      ),
    );
  }
}

/// 文件图标绘制器。
class _DocumentIconPainter extends CustomPainter {
  const _DocumentIconPainter({required this.color, required this.isUpload});

  final Color color;
  final bool isUpload;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final document = Path()
      ..moveTo(10, 2)
      ..lineTo(28, 2)
      ..lineTo(42, 16)
      ..lineTo(42, 50)
      ..lineTo(10, 50)
      ..close();
    canvas.drawPath(document, stroke);

    final fold = Path()
      ..moveTo(28, 2)
      ..lineTo(28, 16)
      ..lineTo(42, 16);
    canvas.drawPath(fold, stroke);

    if (isUpload) {
      canvas.drawLine(const Offset(26, 39), const Offset(26, 25), stroke);
      canvas.drawLine(const Offset(26, 25), const Offset(17, 34), stroke);
      canvas.drawLine(const Offset(26, 25), const Offset(35, 34), stroke);
    } else {
      canvas.drawLine(const Offset(26, 25), const Offset(26, 39), stroke);
      canvas.drawLine(const Offset(26, 39), const Offset(17, 30), stroke);
      canvas.drawLine(const Offset(26, 39), const Offset(35, 30), stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _DocumentIconPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isUpload != isUpload;
  }
}

/// 背景点阵绘制器。
class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD8E1F4)
      ..style = PaintingStyle.fill;

    const spacing = 32.0;
    for (double y = 17; y < size.height; y += spacing) {
      for (double x = 16; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.05, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
