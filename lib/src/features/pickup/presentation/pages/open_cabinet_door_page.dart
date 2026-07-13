import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/app_router.dart';
import '../../../../components/Layout/TerminalShell/index.dart';
import '../../../../models/pickup_model.dart';
import '../../../../repositories/pickup_repository.dart';

/// 打开柜门/取件成功页面。
///
/// 页面参考原型图“打开柜门.png”，用于提示用户取件完成并关闭柜门。
class OpenCabinetDoorPage extends StatefulWidget {
  /// 创建取件成功页面。
  const OpenCabinetDoorPage({super.key});

  @override
  State<OpenCabinetDoorPage> createState() => _OpenCabinetDoorPageState();
}

class _OpenCabinetDoorPageState extends State<OpenCabinetDoorPage> {
  static const int _initialSeconds = 18;

  /// 取件展示数据。
  PickupModel _pickupData = PickupModel.fallback();

  Timer? _timer;
  int _seconds = _initialSeconds;

  @override
  void initState() {
    super.initState();
    _loadPickupData();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      if (_seconds <= 1) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
        return;
      }
      setState(() => _seconds -= 1);
    });
  }

  /// 加载取件展示数据。
  Future<void> _loadPickupData() async {
    final data = await pickupRepository.fetchPickupData();
    if (!mounted) {
      return;
    }
    setState(() => _pickupData = data);
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
                l10n.t('pickupSuccessTitle', '取件成功'),
                style: TextStyle(
                  color: Color(0xFF111936),
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _pickupData.pickupSuccessSummary,
                style: TextStyle(
                  color: Color(0xFF69769E),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 34),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFAEF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF3D8A8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFFC46A00),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.t('pickupCloseDoorHint', '请及时关闭柜门，系统将自动上锁'),
                      style: TextStyle(
                        color: Color(0xFFC46A00),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
                      label: Text(l10n.t('pickupReturnHome', '返回首页')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2F64F6),
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
                      onPressed: () {},
                      icon: const Icon(Icons.lock_outline_rounded, size: 18),
                      label: Text(l10n.t('pickupLockDoor', '锁定柜门')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6877A2),
                        side: const BorderSide(color: Color(0xFFD4DDF3)),
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
              const SizedBox(height: 16),
              Text(
                l10n
                    .t('pickupAutoReturnHome', '{seconds}s 后自动返回首页')
                    .replaceAll('{seconds}', '$_seconds'),
                style: const TextStyle(
                  color: Color(0xFFA7B0CC),
                  fontSize: 14,
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
