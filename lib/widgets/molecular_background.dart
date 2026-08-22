import 'dart:math';
import 'package:flutter/material.dart';

/// Reusable ambient molecular background texture implemented as a
/// lightweight CustomPainter. No raster assets needed — can be recolored
/// by passing a [nodeColor].
class MolecularBackground extends StatelessWidget {
  const MolecularBackground({
    super.key,
    this.nodeColor,
    this.opacity = 0.06,
    this.nodeCount = 28,
  });

  final Color? nodeColor;
  final double opacity;
  final int nodeCount;

  @override
  Widget build(BuildContext context) {
    final color = (nodeColor ?? Theme.of(context).colorScheme.primary)
        .withValues(alpha: opacity);
    return CustomPaint(
      painter: _MolecularPainter(color: color, nodeCount: nodeCount),
      child: const SizedBox.expand(),
    );
  }
}

class _MolecularPainter extends CustomPainter {
  _MolecularPainter({required this.color, required this.nodeCount});

  final Color color;
  final int nodeCount;

  static List<Offset>? _cachedNodes;
  static int? _cachedCount;

  @override
  void paint(Canvas canvas, Size size) {
    // Deterministic node placement based on nodeCount
    if (_cachedNodes == null || _cachedCount != nodeCount) {
      final rng = Random(42);
      _cachedNodes = List.generate(nodeCount,
          (_) => Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height));
      _cachedCount = nodeCount;
    }

    final nodes = _cachedNodes!;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw edges between close nodes
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final dist = (nodes[i] - nodes[j]).distance;
        if (dist < size.width * 0.22) {
          canvas.drawLine(nodes[i], nodes[j], linePaint);
        }
      }
      // Dot at each node
      canvas.drawCircle(nodes[i], 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_MolecularPainter old) => old.color != color;
}
