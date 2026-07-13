import 'package:flutter/material.dart';

// Home 页面内部共享视觉组件。
//
// 这些组件目前只服务 Home 页面：基础卡片、柜体预览和背景点阵等。
// 如果后续其它页面也复用，再移动到 `components` 公共组件目录。

/// 首页卡片基础容器。
///
/// 统一首页各业务卡片的白底、圆角、边框、阴影和顶部强调条样式。
class HomeDashboardCard extends StatelessWidget {
  const HomeDashboardCard({
    required this.width,
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderColor,
  });

  /// 卡片宽度。
  final double width;

  /// 卡片内部内容。
  final Widget child;

  /// 卡片内容内边距。
  final EdgeInsetsGeometry padding;

  /// 顶部强调色条颜色；为空时不显示强调色条。
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: radius,
        border: Border.all(color: const Color(0xFFE5EBF8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D1B2E5A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (borderColor != null)
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              child: Container(height: 3, color: borderColor),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// 当前柜体卡片中的原生柜体预览。
class HomeCabinetModelViewer extends StatelessWidget {
  const HomeCabinetModelViewer({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: const DecoratedBox(
        key: ValueKey('cabinet_native_preview'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEAF2FF), Color(0xFFF8FBFF)],
          ),
        ),
        child: CustomPaint(
          painter: _CabinetPreviewPainter(),
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}

/// 首页小卡片使用的轻量柜体绘制器。
class _CabinetPreviewPainter extends CustomPainter {
  const _CabinetPreviewPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bodyRect = Rect.fromLTWH(
      size.width * .18,
      size.height * .08,
      size.width * .58,
      size.height * .84,
    );
    final sidePath = Path()
      ..moveTo(bodyRect.right, bodyRect.top)
      ..lineTo(size.width * .88, size.height * .19)
      ..lineTo(size.width * .88, size.height * .82)
      ..lineTo(bodyRect.right, bodyRect.bottom)
      ..close();
    final topPath = Path()
      ..moveTo(bodyRect.left, bodyRect.top)
      ..lineTo(size.width * .31, size.height * .01)
      ..lineTo(size.width * .88, size.height * .19)
      ..lineTo(bodyRect.right, bodyRect.top)
      ..close();

    final shadowPaint = Paint()
      ..color = const Color(0x24334666)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .2,
          size.height * .86,
          size.width * .68,
          size.height * .08,
        ),
        const Radius.circular(12),
      ),
      shadowPaint,
    );

    canvas.drawPath(
      sidePath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFB9C8E7), Color(0xFF7E91BB)],
        ).createShader(sidePath.getBounds()),
    );
    canvas.drawPath(
      topPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFDDE7FA)],
        ).createShader(topPath.getBounds()),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(8)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8FBFF), Color(0xFFD8E4F8)],
        ).createShader(bodyRect),
    );

    final strokePaint = Paint()
      ..color = const Color(0xFF7D91BB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(8)),
      strokePaint,
    );
    canvas.drawPath(topPath, strokePaint);
    canvas.drawPath(sidePath, strokePaint);

    _drawDoors(canvas, bodyRect);
    _drawDisplay(canvas, bodyRect);
    _drawStatusLight(canvas, size);
  }

  /// 绘制柜体门格。
  ///
  /// 这里只画首页缩略模型，不绑定真实格口数量；真实柜门状态在业务页面中展示。
  void _drawDoors(Canvas canvas, Rect bodyRect) {
    final doorPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;
    final doorStrokePaint = Paint()
      ..color = const Color(0xFFC3D1EA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;

    const rowCount = 5;
    const columnCount = 2;
    final gap = bodyRect.width * .055;
    final doorWidth = (bodyRect.width - gap * 3) / columnCount;
    final doorHeight = (bodyRect.height * .67 - gap * 6) / rowCount;
    final startTop = bodyRect.top + bodyRect.height * .25;

    for (var row = 0; row < rowCount; row++) {
      for (var column = 0; column < columnCount; column++) {
        final left = bodyRect.left + gap + column * (doorWidth + gap);
        final top = startTop + row * (doorHeight + gap);
        final doorRect = Rect.fromLTWH(left, top, doorWidth, doorHeight);
        canvas.drawRRect(
          RRect.fromRectAndRadius(doorRect, const Radius.circular(2.5)),
          doorPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(doorRect, const Radius.circular(2.5)),
          doorStrokePaint,
        );
        canvas.drawCircle(
          Offset(doorRect.right - doorWidth * .18, doorRect.center.dy),
          1.1,
          Paint()..color = const Color(0xFF9AACCE),
        );
      }
    }
  }

  /// 绘制柜体顶部屏幕区域。
  void _drawDisplay(Canvas canvas, Rect bodyRect) {
    final screenRect = Rect.fromLTWH(
      bodyRect.left + bodyRect.width * .14,
      bodyRect.top + bodyRect.height * .08,
      bodyRect.width * .72,
      bodyRect.height * .12,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(screenRect, const Radius.circular(4)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF2563EB), Color(0xFF22C55E)],
        ).createShader(screenRect),
    );
    canvas.drawCircle(
      Offset(screenRect.left + screenRect.width * .17, screenRect.center.dy),
      2,
      Paint()..color = const Color(0xB3FFFFFF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          screenRect.left + screenRect.width * .34,
          screenRect.center.dy - 1.2,
          screenRect.width * .42,
          2.4,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0x8CFFFFFF),
    );
  }

  /// 绘制柜体右上角在线状态灯。
  void _drawStatusLight(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width * .83, size.height * .24),
      4.4,
      Paint()..color = const Color(0x3322C55E),
    );
    canvas.drawCircle(
      Offset(size.width * .83, size.height * .24),
      2.4,
      Paint()..color = const Color(0xFF22C55E),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 背景点阵绘制器。
class HomeDotGridPainter extends CustomPainter {
  const HomeDotGridPainter();

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
