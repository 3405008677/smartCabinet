import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';

import 'package:smart_cabinet/src/app/routing/app_routes.dart';
import 'package:smart_cabinet/src/app/shell/app_shell.dart';
import 'package:smart_cabinet/src/features/dropoff/domain/entities/dropoff.dart';
import 'package:smart_cabinet/src/features/dropoff/data/repositories/dropoff_repository_impl.dart';

/// 放件成功页。
class DropoffSuccessPage extends StatefulWidget {
  /// 创建放件成功页。
  const DropoffSuccessPage({super.key});

  @override
  State<DropoffSuccessPage> createState() => _DropoffSuccessPageState();
}

class _DropoffSuccessPageState extends State<DropoffSuccessPage> {
  /// 放件展示数据。
  DropoffData _dropoffData = DropoffData.fallback();

  @override
  void initState() {
    super.initState();
    _loadDropoffData();
  }

  /// 加载放件展示数据。
  Future<void> _loadDropoffData() async {
    final data = await dropoffRepository.fetchDropoffData();
    if (!mounted) {
      return;
    }
    setState(() => _dropoffData = data);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return TerminalShell(
      topRightBadge: FlowStatusBadge(
        text: l10n.t('dropoffCompletedBadge', '放件完成'),
      ),
      child: CustomPaint(
        painter: const _DropoffDotGridPainter(),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SuccessPulseIcon(),
              const SizedBox(height: 34),
              Text(
                l10n.t('dropoffSuccessTitle', '放件成功'),
                style: TextStyle(
                  color: Color(0xFF111936),
                  fontSize: 36,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _dropoffData.successSummary,
                style: TextStyle(
                  color: Color(0xFF69769E),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 36),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 144,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            AppRoutes.home,
                            (route) => false,
                          ),
                      icon: const Icon(Icons.home_outlined, size: 18),
                      label: Text(l10n.t('dropoffReturnHome', '返回首页')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4664E9),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 144,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pushReplacementNamed(
                            AppRoutes.dropoffPersonVerification,
                          ),
                      icon: const Icon(Icons.add_box_outlined, size: 18),
                      label: Text(l10n.t('dropoffContinue', '继续放件')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4664E9),
                        side: const BorderSide(color: Color(0xFFC8D5FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 成功图标。
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

/// 放件背景点阵。
class _DropoffDotGridPainter extends CustomPainter {
  const _DropoffDotGridPainter();

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
