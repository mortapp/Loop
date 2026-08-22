import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// LOOP's brand mark: the "double loop seal" — two precisely interlocked
/// rings, each drawn with an engraved double line (outer Platinum, inner
/// Tyrian) and (at full size) a tiny Champagne key point where they
/// cross. Reads at once as a banking seal, an archive stamp, and a
/// monogram — deliberately not a crown, shield, or sparkle. Drawn, not
/// imported: a handful of stroked arcs, nothing that costs anything to
/// ship or render.
///
/// Shared by the auth screen (full mark + key point), the AI nav
/// destination (small, identifying generated content rather than a
/// robot/sparkle icon per docs/DESIGN_SYSTEM.md), and the Sell gallery's
/// placeholder image tile (large, faint watermark) — see
/// `keyPoint`/`opacity` for those variants.
class LoopSeal extends StatelessWidget {
  const LoopSeal({
    super.key,
    this.size = 40,
    this.keyPoint = true,
    this.opacity = 1,
  });

  final double size;
  final bool keyPoint;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: size,
        height: size * 0.7,
        child: CustomPaint(painter: LoopSealPainter(keyPoint: keyPoint)),
      ),
    );
  }
}

class LoopSealPainter extends CustomPainter {
  const LoopSealPainter({this.keyPoint = true});

  final bool keyPoint;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = AppColors.platinum.withValues(alpha: 0.85);
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.tyrianAccent;

    final radius = size.height / 2 - 1;
    final leftCenter = Offset(size.width / 2 - radius * 0.55, size.height / 2);
    final rightCenter = Offset(size.width / 2 + radius * 0.55, size.height / 2);

    canvas.drawCircle(leftCenter, radius, outer);
    canvas.drawCircle(rightCenter, radius, outer);
    canvas.drawCircle(leftCenter, radius - 3, inner);
    canvas.drawCircle(rightCenter, radius - 3, inner);

    if (keyPoint) {
      final keyPointPaint = Paint()..color = AppColors.champagne;
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        1.1,
        keyPointPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant LoopSealPainter oldDelegate) =>
      oldDelegate.keyPoint != keyPoint;
}
