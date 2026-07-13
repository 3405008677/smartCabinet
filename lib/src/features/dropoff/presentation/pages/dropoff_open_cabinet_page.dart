import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';

import 'package:smart_cabinet/src/app/routing/app_routes.dart';
import 'package:smart_cabinet/src/app/shell/app_shell.dart';
import 'package:smart_cabinet/src/features/dropoff/domain/entities/dropoff.dart';
import 'package:smart_cabinet/src/features/dropoff/data/repositories/dropoff_repository_impl.dart';

/// 放件柜门打开页。
class DropoffOpenCabinetPage extends StatefulWidget {
  /// 创建柜门打开页。
  const DropoffOpenCabinetPage({super.key});

  @override
  State<DropoffOpenCabinetPage> createState() => _DropoffOpenCabinetPageState();
}

class _DropoffOpenCabinetPageState extends State<DropoffOpenCabinetPage> {
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
      topBarLeading: _DropoffHeader(
        title: l10n.t('dropoffOpenCabinetTitle', '放入文件'),
        onBack: () => Navigator.of(context).pop(),
      ),
      topRightBadge: FlowStatusBadge(
        text: l10n.t('dropoffOpenCabinetBadge', '柜门已打开 · 放件'),
      ),
      child: CustomPaint(
        painter: const _DropoffDotGridPainter(),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _DoorOpenIcon(),
              const SizedBox(height: 34),
              Text(
                _dropoffData.openDoorTitle,
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
                l10n.t('dropoffPlaceDocumentHint', '请将文件放入柜门并关闭'),
                style: TextStyle(
                  color: Color(0xFF69769E),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
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
                      l10n.t('dropoffAuditHint', '系统将记录本次放件审计日志'),
                      style: const TextStyle(
                        color: Color(0xFFC46A00),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 172,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pushReplacementNamed(AppRoutes.dropoffSuccess),
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                      ),
                      label: Text(l10n.t('dropoffCloseDoorButton', '确认已关闭柜门')),
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
                      onPressed: () {},
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(l10n.t('dropoffReopenDoorButton', '重新开柜')),
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
            ],
          ),
        ),
      ),
    );
  }
}

/// 柜门打开图标。
class _DoorOpenIcon extends StatelessWidget {
  const _DoorOpenIcon();

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
            color: const Color(0xFF4664E9).withValues(alpha: .08),
          ),
        ),
        Container(
          width: 138,
          height: 138,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF4664E9).withValues(alpha: .12),
          ),
        ),
        Container(
          width: 112,
          height: 112,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF4664E9),
          ),
          child: const Icon(
            Icons.meeting_room_outlined,
            color: Colors.white,
            size: 60,
          ),
        ),
      ],
    );
  }
}

/// 放件顶部左侧标题区。
class _DropoffHeader extends StatelessWidget {
  const _DropoffHeader({required this.title, required this.onBack});

  /// 页面标题。
  final String title;

  /// 返回按钮点击回调。
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: Text(context.l10n.t('dropoffBack', '返回')),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF4664E9),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF111936),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
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
