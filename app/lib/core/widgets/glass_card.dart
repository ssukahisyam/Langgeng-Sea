import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// Glass surface level - controls opacity and implied blur intensity.
enum GlassLevel { level1, level2, level3 }

/// A glass-styled card. On M2-era Android mid-rangers (Redmi Note 10 Pro
/// is our target) every `BackdropFilter` costs a full-screen offscreen
/// layer and regularly drops us from 120 → 30 FPS. We therefore render
/// the "frosted glass" look as a heavier, more opaque fill with a thin
/// border + shadow instead of an actual blur. The design system calls
/// this Clean Liquid Glass; without the blur it's just Clean Opaque
/// Glass, and nobody notices.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.level = GlassLevel.level2,
    this.padding = const EdgeInsets.all(AppSizes.sp5),
    this.margin,
    this.borderRadius,
    this.onTap,
    this.elevated = true,
  });

  final Widget child;
  final GlassLevel level;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    // Level1/2/3 used to map to blur amounts; now they map to fill
    // opacity only. The surface colour tokens themselves already bake
    // alpha in (lightSurface1 = 0x99FFFFFF etc.), but on top of a
    // transparent backdrop the perceived contrast is too low without
    // the blur. Composite against the scaffold background ourselves to
    // get a consistent look in light + dark mode.
    final (baseSurface, borderColor) = switch (level) {
      GlassLevel.level1 => (tokens.surface1, tokens.border),
      GlassLevel.level2 => (tokens.surface2, tokens.border),
      GlassLevel.level3 => (tokens.surface3, tokens.borderStrong),
    };

    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final fill = Color.alphaBlend(baseSurface, scaffoldBg);

    final radius = borderRadius ?? BorderRadius.circular(AppSizes.radiusLg);

    Widget content = Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: 1),
      ),
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: content,
        ),
      );
    }

    if (elevated) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: tokens.shadowMd,
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: content,
      );
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: content,
    );
  }
}
