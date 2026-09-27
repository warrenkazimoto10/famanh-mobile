import 'package:flutter/material.dart';

import '../theme/adiake_colors.dart';

/// Logo officiel de la marque **Famanh** (Identique au Back-office).
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 96,
    this.radius,
    this.showText = false,
    this.showTagline = false,
  });

  final double size;
  final double? radius;
  final bool showText;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? size * 0.22;

    Widget iconWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r),
        boxShadow: [
          BoxShadow(
            color: FamanhColors.primaryContainer.withValues(alpha: 0.15),
            blurRadius: size * 0.15,
            offset: Offset(0, size * 0.05),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.08),
        child: CustomPaint(
          size: Size(size, size),
          painter: FamanhLogoPainter(),
        ),
      ),
    );

    if (!showText) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Image.asset(
          'assets/logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => iconWidget,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        iconWidget,
        SizedBox(width: size * 0.2),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF004BFF), Color(0xFF0094FF)],
              ).createShader(bounds),
              child: Text(
                'Famanh',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: size * 0.45,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  height: 1.0,
                ),
              ),
            ),
            if (showTagline) ...[
              SizedBox(height: size * 0.05),
              Text(
                'Un clic, vos services, chez vous.',
                style: TextStyle(
                  fontSize: size * 0.18,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF0052FF),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// CustomPainter reproduisant fidèlement le logo SVG Famanh du Back-Office
class FamanhLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100.0;

    // Dégradé Bleu Famanh
    final blueGradient = const LinearGradient(
      colors: [Color(0xFF0052FF), Color(0xFF00D2FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final bluePaint = Paint()
      ..shader = blueGradient
      ..style = PaintingStyle.fill;

    // Dark Navy Paint
    final darkNavyPaint = Paint()
      ..color = const Color(0xFF0A2540)
      ..style = PaintingStyle.fill;

    // 1. Lines speed left
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(4 * scale, 24 * scale, 16 * scale, 4 * scale), Radius.circular(2 * scale)),
      bluePaint..color = const Color(0xFF0052FF).withValues(alpha: 0.95),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(10 * scale, 32 * scale, 18 * scale, 4 * scale), Radius.circular(2 * scale)),
      bluePaint..color = const Color(0xFF0052FF).withValues(alpha: 0.95),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(2 * scale, 40 * scale, 14 * scale, 4 * scale), Radius.circular(2 * scale)),
      bluePaint..color = const Color(0xFF0052FF).withValues(alpha: 0.75),
    );

    // Re-apply gradient
    bluePaint.shader = blueGradient;

    // 2. Dynamic "F" Arc
    final fPath = Path();
    fPath.moveTo(32 * scale, 18 * scale);
    fPath.cubicTo(55 * scale, 5 * scale, 88 * scale, 12 * scale, 82 * scale, 38 * scale);
    fPath.cubicTo(76 * scale, 64 * scale, 48 * scale, 85 * scale, 26 * scale, 82 * scale);
    fPath.cubicTo(40 * scale, 76 * scale, 52 * scale, 64 * scale, 56 * scale, 48 * scale);
    fPath.cubicTo(60 * scale, 32 * scale, 45 * scale, 28 * scale, 32 * scale, 18 * scale);
    fPath.close();
    canvas.drawPath(fPath, bluePaint);

    // 3. Sub Base Swoosh
    final swooshPath = Path();
    swooshPath.moveTo(22 * scale, 84 * scale);
    swooshPath.cubicTo(45 * scale, 78 * scale, 75 * scale, 75 * scale, 88 * scale, 64 * scale);
    swooshPath.cubicTo(70 * scale, 76 * scale, 42 * scale, 84 * scale, 22 * scale, 84 * scale);
    swooshPath.close();
    canvas.drawPath(swooshPath, bluePaint);

    // 4. Location Pin top right
    canvas.save();
    canvas.translate(62 * scale, 8 * scale);
    canvas.scale(0.65 * scale);

    final pinPath = Path();
    pinPath.moveTo(24, 0);
    pinPath.cubicTo(10.7, 0, 0, 10.7, 0, 24);
    pinPath.cubicTo(0, 38, 24, 56, 24, 56);
    pinPath.cubicTo(24, 56, 48, 38, 48, 24);
    pinPath.cubicTo(48, 10.7, 37.3, 0, 24, 0);
    pinPath.close();
    canvas.drawPath(pinPath, bluePaint);

    canvas.drawCircle(const Offset(24, 22), 13, Paint()..color = Colors.white);

    // Box inside pin
    final boxPath = Path();
    boxPath.moveTo(24, 13);
    boxPath.lineTo(31, 17);
    boxPath.lineTo(31, 25);
    boxPath.lineTo(24, 29);
    boxPath.lineTo(17, 25);
    boxPath.lineTo(17, 17);
    boxPath.close();
    canvas.drawPath(boxPath, darkNavyPaint);

    final boxTop = Path();
    boxTop.moveTo(24, 13);
    boxTop.lineTo(31, 17);
    boxTop.lineTo(24, 21);
    boxTop.lineTo(17, 17);
    boxTop.close();
    canvas.drawPath(boxTop, bluePaint);

    canvas.restore();

    // 5. Scooter Delivery Driver Silhouette inside "F"
    canvas.save();
    canvas.translate(32 * scale, 32 * scale);
    canvas.scale(0.55 * scale);

    // Box on back
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(10, 8, 16, 16), const Radius.circular(3)),
      bluePaint,
    );

    // Helmet & Head
    canvas.drawCircle(const Offset(28, 10), 6, darkNavyPaint);

    // Body
    final bodyPath = Path();
    bodyPath.moveTo(22, 18);
    bodyPath.cubicTo(22, 18, 30, 16, 36, 22);
    bodyPath.lineTo(30, 32);
    bodyPath.lineTo(20, 30);
    bodyPath.close();
    canvas.drawPath(bodyPath, darkNavyPaint);

    // Wheels
    final wheelStroke = Paint()
      ..color = const Color(0xFF0A2540)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawCircle(const Offset(16, 42), 8, wheelStroke);
    canvas.drawCircle(const Offset(44, 42), 8, wheelStroke);

    // Frame
    final framePaint = Paint()
      ..color = const Color(0xFF0A2540)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final framePath = Path();
    framePath.moveTo(16, 42);
    framePath.lineTo(28, 32);
    framePath.lineTo(40, 32);
    framePath.lineTo(44, 42);
    canvas.drawPath(framePath, framePaint);

    final handlebarPath = Path();
    handlebarPath.moveTo(36, 20);
    handlebarPath.lineTo(42, 24);
    handlebarPath.lineTo(46, 32);
    canvas.drawPath(handlebarPath, framePaint..strokeWidth = 3);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

