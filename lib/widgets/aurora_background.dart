import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Sand background with soft, overlapping radial glows near the top
/// that fade out into flat color, so content below stays utilitarian.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.sand),
        const _Glow(alignment: Alignment(-1.1, -1.05), size: 520, color: AppColors.camel, alpha: 0.9),
        const _Glow(alignment: Alignment(1.2, -0.85), size: 400, color: AppColors.ochre, alpha: 0.55),
        const _Glow(alignment: Alignment(0.1, -0.55), size: 340, color: AppColors.clay, alpha: 0.3),
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({
    required this.alignment,
    required this.size,
    required this.color,
    required this.alpha,
  });

  final Alignment alignment;
  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: alpha),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
