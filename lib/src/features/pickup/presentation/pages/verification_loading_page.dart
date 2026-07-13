import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/app_router.dart';
import '../../../../components/Layout/TerminalShell/index.dart';

/// 四项验证成功后的证据信息加载页。
///
/// 页面参考原型图“校验安全认证.png”，文案按需求改为：
/// “验证成功，正在获取证据信息···”。
class VerificationLoadingPage extends StatefulWidget {
  /// 创建证据信息加载页。
  const VerificationLoadingPage({super.key});

  @override
  State<VerificationLoadingPage> createState() =>
      _VerificationLoadingPageState();
}

class _VerificationLoadingPageState extends State<VerificationLoadingPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    /// 模拟后端获取证据信息。
    ///
    /// 后端接口接入后，可以把这里替换成真实请求成功后再跳转。
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.cabinetDoorInfo);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return TerminalShell(
      child: CustomPaint(
        painter: const _DotGridPainter(),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SuccessPulseIcon(),
              const SizedBox(height: 34),
              Text(
                l10n.t('pickupLoadingTitle', '验证成功，正在获取证据信息···'),
                style: const TextStyle(
                  color: Color(0xFF111936),
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.t('pickupLoadingSubtitle', '系统正在读取本次取件凭证、人员信息与柜门授权数据'),
                style: const TextStyle(
                  color: Color(0xFF69769E),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              FlowStatusBadge(
                text: l10n.t('pickupVerificationPassedBadge', '四重认证通过 · 取件'),
              ),
              const SizedBox(height: 42),
              const SizedBox(
                width: 240,
                child: LinearProgressIndicator(
                  minHeight: 6,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                  backgroundColor: Color(0xFFE7ECF8),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2F64F6)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 成功状态的圆形图标。
class _SuccessPulseIcon extends StatelessWidget {
  const _SuccessPulseIcon();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 178,
          height: 178,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1DB954).withValues(alpha: .08),
          ),
        ),
        Container(
          width: 138,
          height: 138,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1DB954).withValues(alpha: .12),
          ),
        ),
        Container(
          width: 112,
          height: 112,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF1DB954),
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 60),
        ),
      ],
    );
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
