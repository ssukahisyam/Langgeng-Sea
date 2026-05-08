import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Atmospheric backdrop with gradient + soft blur blobs.
/// Creates the "underwater depth" feeling across all screens.
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
        // Ambient gradient
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
              color: colors.secondary.withValues(alpha: context.isDark ? 0.18 : 0.15),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: _Blob(
              size: 280,
              color: colors.primary.withValues(alpha: context.isDark ? 0.22 : 0.2),
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
