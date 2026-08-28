import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/scan_result.dart';
import '../../theme/plastiscan_colors.dart';

// ─── AI Analysis loading screen ───────────────────────────────────────────────
class AiAnalysisScreen extends StatefulWidget {
  const AiAnalysisScreen({super.key, this.pendingResult});

  final ScanResult? pendingResult;

  @override
  State<AiAnalysisScreen> createState() => _AiAnalysisScreenState();
}

class _AiAnalysisScreenState extends State<AiAnalysisScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ringCtrl;
  late final AnimationController _orbitCtrl;

  // Staged status messages — one shown every ~1.2s
  static const _stages = [
    'Identifying polymer structure…',
    'Analysing chemical composition…',
    'Cross-referencing safety database…',
    'Calculating risk profile…',
    'Finalising report…',
  ];
  int _stageIndex = 0;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _advanceStages();
    _navigateOnComplete();
  }

  void _advanceStages() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return false;
      if (_stageIndex < _stages.length - 1) {
        setState(() => _stageIndex++);
        return true;
      }
      return false;
    });
  }

  void _navigateOnComplete() {
    // Total analysis time ~6s, then navigate to results
    Future.delayed(const Duration(milliseconds: 6500), () {
      if (mounted && widget.pendingResult != null) {
        context.push('/results', extra: widget.pendingResult);
      } else if (mounted) {
        context.go('/');
      }
    });
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _orbitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PlastiScanColors>()!;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Circular progress ring with orbit dots ─────────────────
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _ringCtrl,
                        builder: (_, __) => CustomPaint(
                          size: const Size(200, 200),
                          painter: _ProgressRingPainter(
                            progress: _ringCtrl.value,
                            gradientStart: colors.gradientStart,
                            gradientEnd: colors.gradientEnd,
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _orbitCtrl,
                        builder: (_, __) => CustomPaint(
                          size: const Size(200, 200),
                          painter: _OrbitDotsPainter(
                            angle: _orbitCtrl.value * 3.14159 * 2,
                            color: colors.mintAccent,
                          ),
                        ),
                      ),
                      // Centre icon
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.gradientStart.withValues(alpha: 0.1),
                        ),
                        child: Icon(
                          Icons.biotech_rounded,
                          color: colors.gradientStart,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // ── Status text crossfade ──────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: child,
                  ),
                  child: Text(
                    _stages[_stageIndex],
                    key: ValueKey(_stageIndex),
                    style: textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 12),
                Text(
                  'AI Molecular Analysis',
                  style: textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 1.0,
                  ),
                ),

                const SizedBox(height: 48),

                // ── Step indicators ───────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_stages.length, (i) {
                    final done = i < _stageIndex;
                    final active = i == _stageIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: done || active
                            ? colors.gradientStart
                            : Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Painters ─────────────────────────────────────────────────────────────────
class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({
    required this.progress,
    required this.gradientStart,
    required this.gradientEnd,
  });

  final double progress;
  final Color gradientStart;
  final Color gradientEnd;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);

    // Track
    canvas.drawArc(
      rect,
      -1.5708,
      6.2832,
      false,
      Paint()
        ..color = gradientStart.withValues(alpha: 0.12)
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Animated arc
    final sweep = 6.2832 * progress;
    canvas.drawArc(
      rect,
      -1.5708,
      sweep,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: -1.5708,
          endAngle: -1.5708 + 6.2832,
          colors: [gradientStart, gradientEnd, gradientStart],
        ).createShader(rect)
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) => old.progress != progress;
}

class _OrbitDotsPainter extends CustomPainter {
  const _OrbitDotsPainter({required this.angle, required this.color});

  final double angle;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const orbitR = 88.0;
    const dotR = 5.0;

    for (int i = 0; i < 3; i++) {
      final a = angle + (i * 3.14159 * 2 / 3);
      final dx = cx + orbitR * (a.abs() > 0 ? _cos(a) : 1);
      final dy = cy + orbitR * _sin(a);
      final alpha = 0.3 + (0.7 * ((i == 0) ? 1.0 : (i == 1 ? 0.6 : 0.3)));
      canvas.drawCircle(
        Offset(dx, dy),
        dotR,
        Paint()..color = color.withValues(alpha: alpha),
      );
    }
  }

  static double _cos(double a) {
    // Use dart:math indirectly
    return _sin(a + 1.5708);
  }

  static double _sin(double a) {
    // Taylor series sin for small loop (good enough for animation)
    // Using the identity to avoid dart:math import collision
    double x = a % (3.14159 * 2);
    if (x < 0) x += 3.14159 * 2;
    // Bhaskara I approximation
    double xr = x > 3.14159 ? x - 3.14159 : x;
    double s = 4 * xr * (3.14159 - xr) / (3.14159 * 3.14159 * 0.9);
    return x > 3.14159 ? -s : s;
  }

  @override
  bool shouldRepaint(_OrbitDotsPainter old) => old.angle != angle;
}
