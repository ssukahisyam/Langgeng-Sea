import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Atmospheric backdrop — just a gradient fill.
///
/// In the original design the blobs were rendered via `BackdropFilter`
/// to create a soft "depth of field" effect. On our target device
/// (Redmi Note 10 Pro, SD720G) that layer costs us ~30 ms per frame,
/// which drops the whole app from 120 Hz into stutter-land. We keep
/// the `showBlobs` flag around so future high-end builds can re-enable
/// cheap RadialGradient blobs, but the default is OFF — and the blur
/// filter that used to back them is gone entirely.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({
    super.key,
    required this.child,
    this.showBlobs = false,
  });

  final Widget child;
  final bool showBlobs;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: tokens.ambientGradient),
          ),
        ),
        if (showBlobs) ...[
          Positioned(
            top: -80,
            right: -60,
            child: _Blob(
              size: 260,
              color: colors.secondary
                  .withValues(alpha: context.isDark ? 0.18 : 0.15),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: _Blob(
              size: 280,
              color:
                  colors.primary.withValues(alpha: context.isDark ? 0.22 : 0.2),
            ),
          ),
        ],
        child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
