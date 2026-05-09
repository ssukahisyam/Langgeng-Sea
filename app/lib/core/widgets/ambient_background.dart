import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Atmospheric backdrop with gradient + radial color blobs.
///
/// PERFORMANCE NOTE: this widget intentionally does NOT use
/// `BackdropFilter` / `ImageFilter.blur`. Blur-as-layer forces Flutter
/// to rasterise the full viewport to an intermediate buffer every
/// frame — a ~10-20ms main-thread hit on mid-range Android (SD720G),
/// which showed up as app-wide lag when tapping tabs / buttons.
///
/// The "glass depth" feel is instead produced by:
///   1. A linear gradient (pure paint, trivially cached).
///   2. Optional RadialGradient "blobs" — also pure paint, compiled
///      once per build then cached until theme changes.
///
/// Result: the background is effectively free at runtime (single
/// decoration layer), while visually keeping the same hue layering
/// the old design had.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({
    super.key,
    required this.child,
    this.showBlobs = true,
  });

  final Widget child;
  final bool showBlobs;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Stack(
      children: [
        // Base ambient gradient.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: tokens.ambientGradient),
          ),
        ),
        if (showBlobs) ...[
          // Top-right warm blob (secondary).
          Positioned(
            top: -80,
            right: -60,
            child: _Blob(
              size: 260,
              color: colors.secondary
                  .withValues(alpha: context.isDark ? 0.18 : 0.15),
            ),
          ),
          // Bottom-left cool blob (primary).
          Positioned(
            bottom: 100,
            left: -80,
            child: _Blob(
              size: 280,
              color: colors.primary
                  .withValues(alpha: context.isDark ? 0.22 : 0.2),
            ),
          ),
        ],
        child,
      ],
    );
  }
}

/// Radial-gradient circle, wrapped in IgnorePointer so it never blocks
/// taps on the content stacked above.
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
