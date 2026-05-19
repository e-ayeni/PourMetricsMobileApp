import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class PourLoadingIndicator extends StatefulWidget {
  const PourLoadingIndicator({super.key, this.size = 64});

  final double size;

  @override
  State<PourLoadingIndicator> createState() => _PourLoadingIndicatorState();
}

class _PourLoadingIndicatorState extends State<PourLoadingIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _fillController;
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _fillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _fillController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_fillController, _waveController]),
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _PourPainter(
            fillLevel: Curves.easeInOut.transform(_fillController.value),
            wavePhase: _waveController.value * 2 * pi,
          ),
        );
      },
    );
  }
}

class _PourPainter extends CustomPainter {
  _PourPainter({required this.fillLevel, required this.wavePhase});

  final double fillLevel;
  final double wavePhase;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2;

    // Drop shape path (matching the SVG viewBox 0 0 120 120, scaled to size)
    final scale = s / 120;
    final dropPath = Path()
      ..moveTo(60 * scale, 18 * scale)
      ..cubicTo(
        60 * scale, 18 * scale,
        30 * scale, 52 * scale,
        30 * scale, 78 * scale,
      )
      ..arcToPoint(
        Offset(90 * scale, 78 * scale),
        radius: Radius.circular(30 * scale),
      )
      ..cubicTo(
        90 * scale, 52 * scale,
        60 * scale, 18 * scale,
        60 * scale, 18 * scale,
      )
      ..close();

    // Liquid fill: animate between 15% and 85% of the drop
    final minY = 90 * scale;
    final maxY = 38 * scale;
    final liquidY = minY + (maxY - minY) * fillLevel;

    // Wave surface
    final wavePath = Path();
    final waveAmp = 3.0 * scale;
    wavePath.moveTo(0, liquidY);
    for (double x = 0; x <= s; x += 1) {
      final y = liquidY + sin(wavePhase + x / s * 3 * pi) * waveAmp;
      wavePath.lineTo(x, y);
    }
    wavePath.lineTo(s, s);
    wavePath.lineTo(0, s);
    wavePath.close();

    // Clip to drop shape and draw liquid
    canvas.save();
    canvas.clipPath(dropPath);

    final liquidPaint = Paint()
      ..color = AppColors.primary.withAlpha(180)
      ..style = PaintingStyle.fill;
    canvas.drawPath(wavePath, liquidPaint);

    // Secondary wave for depth
    final wave2Path = Path();
    wave2Path.moveTo(0, liquidY + 2 * scale);
    for (double x = 0; x <= s; x += 1) {
      final y = liquidY +
          2 * scale +
          sin(wavePhase * 1.3 + x / s * 2.5 * pi + 1.2) * waveAmp * 0.6;
      wave2Path.lineTo(x, y);
    }
    wave2Path.lineTo(s, s);
    wave2Path.lineTo(0, s);
    wave2Path.close();

    final liquid2Paint = Paint()
      ..color = AppColors.primaryDark.withAlpha(120)
      ..style = PaintingStyle.fill;
    canvas.drawPath(wave2Path, liquid2Paint);

    canvas.restore();

    // Drop outline
    final outlinePaint = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * scale
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(dropPath, outlinePaint);

    // Gauge tick marks on the left
    final tickPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * scale
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(30 * scale, 64 * scale),
      Offset(36 * scale, 64 * scale),
      tickPaint,
    );
    canvas.drawLine(
      Offset(30 * scale, 74 * scale),
      Offset(34 * scale, 74 * scale),
      tickPaint,
    );
    canvas.drawLine(
      Offset(30 * scale, 84 * scale),
      Offset(36 * scale, 84 * scale),
      tickPaint,
    );
  }

  @override
  bool shouldRepaint(_PourPainter old) =>
      old.fillLevel != fillLevel || old.wavePhase != wavePhase;
}
