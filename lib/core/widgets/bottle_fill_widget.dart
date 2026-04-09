import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Draws a bottle silhouette filled to [fillPercent] (0.0–1.0).
class BottleFillWidget extends StatelessWidget {
  const BottleFillWidget({
    super.key,
    required this.fillPercent,
    this.width = 28,
    this.height = 60,
    this.isRetired = false,
  });

  final double fillPercent;
  final double width;
  final double height;
  final bool isRetired;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _BottlePainter(
          fillPercent: fillPercent.clamp(0.0, 1.0),
          isRetired: isRetired,
        ),
      ),
    );
  }
}

class _BottlePainter extends CustomPainter {
  _BottlePainter({required this.fillPercent, required this.isRetired});

  final double fillPercent;
  final bool isRetired;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Proportions
    final capH = h * 0.08;
    final neckW = w * 0.38;
    final neckH = h * 0.20;
    final shoulderH = h * 0.14;
    final bodyH = h - capH - neckH - shoulderH;
    final bodyY = capH + neckH + shoulderH;

    final neckLeft = (w - neckW) / 2;
    final neckRight = neckLeft + neckW;

    // Build bottle outline path
    final bottle = Path();
    // Cap top-left → top-right
    bottle.moveTo(neckLeft, capH);
    bottle.lineTo(neckRight, capH);
    // Neck right side down
    bottle.lineTo(neckRight, capH + neckH);
    // Right shoulder curve into body
    bottle.quadraticBezierTo(neckRight, bodyY, w, bodyY);
    // Body right side down to bottom
    bottle.lineTo(w, h);
    // Bottom
    bottle.lineTo(0, h);
    // Body left side up
    bottle.lineTo(0, bodyY);
    // Left shoulder curve into neck
    bottle.quadraticBezierTo(neckLeft, bodyY, neckLeft, capH + neckH);
    // Neck left up to cap
    bottle.lineTo(neckLeft, capH);
    bottle.close();

    // Cap (separate small rounded rect at very top)
    final capPath = Path();
    final capLeft = neckLeft + w * 0.04;
    final capRight = neckRight - w * 0.04;
    capPath.addRRect(RRect.fromLTRBR(
        capLeft, 0, capRight, capH + 1, const Radius.circular(2)));

    // ── Fill ──────────────────────────────────────────────────────────────
    // The fillable area spans from the bottom to the top of the body + shoulder.
    // We extend fill into the neck when >~75% full.
    final fillColor = isRetired
        ? Colors.grey.shade400
        : _fillColor(fillPercent);

    if (fillPercent > 0) {
      final fillableTop = capH + neckH; // top of shoulder
      final fillableBottom = h;
      final fillableHeight = fillableBottom - fillableTop;

      // Fill y-coordinate from bottom
      double fillTop;
      if (fillPercent <= 0.85) {
        fillTop = fillableBottom - fillableHeight * fillPercent;
      } else {
        // Spills into neck for high fill
        final extra = (fillPercent - 0.85) / 0.15;
        fillTop = fillableTop - (neckH * extra * 0.6);
      }
      fillTop = fillTop.clamp(capH, fillableBottom);

      final fillRect = Rect.fromLTRB(0, fillTop, w, h);
      final fillPath = Path.combine(
        PathOperation.intersect,
        bottle,
        Path()..addRect(fillRect),
      );
      canvas.drawPath(fillPath, Paint()..color = fillColor);

      // Liquid surface highlight line
      if (fillPercent > 0.02) {
        canvas.drawLine(
          Offset(0, fillTop),
          Offset(w, fillTop),
          Paint()
            ..color = Colors.white.withAlpha(60)
            ..strokeWidth = 1.2,
        );
      }
    }

    // ── Outline ───────────────────────────────────────────────────────────
    final outlineColor =
        isRetired ? Colors.grey.shade400 : AppColors.primaryDark.withAlpha(180);
    final outlinePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawPath(bottle, outlinePaint);
    canvas.drawPath(capPath, Paint()..color = outlineColor..style = PaintingStyle.fill);

    // ── % label inside body ───────────────────────────────────────────────
    if (!isRetired && fillPercent > 0.15) {
      final pct = '${(fillPercent * 100).round()}%';
      final tp = TextPainter(
        text: TextSpan(
          text: pct,
          style: TextStyle(
            fontSize: h * 0.13,
            fontWeight: FontWeight.w700,
            color: fillPercent > 0.4
                ? Colors.white.withAlpha(220)
                : outlineColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelY = bodyY + bodyH / 2 + shoulderH / 2 - tp.height / 2;
      tp.paint(canvas, Offset((w - tp.width) / 2, labelY));
    }
  }

  Color _fillColor(double pct) {
    if (pct > 0.5) return const Color(0xFFD97706).withAlpha(200); // amber
    if (pct > 0.25) return const Color(0xFFF59E0B).withAlpha(180); // lighter
    return const Color(0xFFEF4444).withAlpha(180); // red when low
  }

  @override
  bool shouldRepaint(_BottlePainter old) =>
      old.fillPercent != fillPercent || old.isRetired != isRetired;
}
