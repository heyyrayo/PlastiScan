import 'package:flutter/material.dart';
import '../models/risk_level.dart';
import '../theme/plastiscan_colors.dart';

// ─── Risk chip (pill style) ────────────────────────────────────────────────────
class RiskChip extends StatelessWidget {
  const RiskChip({super.key, required this.level});

  final RiskLevel level;

  Color _bgColor(PlastiScanColors c) {
    switch (level) {
      case RiskLevel.low:     return c.riskLow.withValues(alpha: 0.1);
      case RiskLevel.medium:  return c.riskMedium.withValues(alpha: 0.1);
      case RiskLevel.high:    return c.riskHigh.withValues(alpha: 0.1);
      case RiskLevel.unknown: return c.riskUnknown.withValues(alpha: 0.1);
    }
  }

  Color _fgColor(PlastiScanColors c) {
    switch (level) {
      case RiskLevel.low:     return c.riskLow;
      case RiskLevel.medium:  return c.riskMedium;
      case RiskLevel.high:    return c.riskHigh;
      case RiskLevel.unknown: return c.riskUnknown;
    }
  }

  IconData _icon() {
    switch (level) {
      case RiskLevel.low:     return Icons.check_circle_outline_rounded;
      case RiskLevel.medium:  return Icons.warning_amber_rounded;
      case RiskLevel.high:    return Icons.dangerous_rounded;
      case RiskLevel.unknown: return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PlastiScanColors>()!;
    final fg = _fgColor(colors);
    final bg = _bgColor(colors);

    return Semantics(
      label: level.label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: fg),
            ),
            const SizedBox(width: 6),
            Icon(_icon(), color: fg, size: 14),
            const SizedBox(width: 4),
            Text(
              level.shortLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Risk circular indicator (Results screen) ─────────────────────────────────
class RiskCircularIndicator extends StatelessWidget {
  const RiskCircularIndicator({
    super.key,
    required this.level,
    required this.score,
    this.size = 200,
  });

  final RiskLevel level;
  final double score; // 0.0 – 10.0
  final double size;

  Color _color(PlastiScanColors c) {
    switch (level) {
      case RiskLevel.low:     return c.riskLow;
      case RiskLevel.medium:  return c.riskMedium;
      case RiskLevel.high:    return c.riskHigh;
      case RiskLevel.unknown: return c.riskUnknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PlastiScanColors>()!;
    final color = _color(colors);

    return Semantics(
      label: '${level.label}, score ${score.toStringAsFixed(1)}',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _RiskArcPainter(
                score: score,
                color: color,
                trackColor: color.withValues(alpha: 0.12),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  score.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                RiskChip(level: level),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskArcPainter extends CustomPainter {
  const _RiskArcPainter({
    required this.score,
    required this.color,
    required this.trackColor,
  });

  final double score;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 10.0;
    final rect = Rect.fromLTWH(
      strokeWidth / 2, strokeWidth / 2,
      size.width - strokeWidth, size.height - strokeWidth,
    );
    const startAngle = -2.4; // ~-135°
    const totalSweep = 4.8;  // ~275° total arc

    // Track
    canvas.drawArc(
      rect, startAngle, totalSweep, false,
      Paint()
        ..color = trackColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Filled arc
    final sweep = totalSweep * (score / 10.0);
    final paint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + totalSweep,
        colors: [color.withValues(alpha: 0.6), color],
      ).createShader(rect)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweep, false, paint);
  }

  @override
  bool shouldRepaint(_RiskArcPainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.color != color;
}
