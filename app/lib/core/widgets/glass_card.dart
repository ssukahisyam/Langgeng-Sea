import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// Glass surface level — controls tint opacity and border strength.
enum GlassLevel { level1, level2, level3 }

/// A card with a glass-like tint and a shadow for depth.
///
/// PERFORMANCE NOTE: this widget USED to wrap its content in
/// `BackdropFilter(ImageFilter.blur(...))` for the real frosted-glass
/// look. That turned out to be THE single most expensive widget in the
/// app — a typical History/Dashboard screen has 10-20 of these visible,
/// and each blur layer forces Flutter to raster the pixels behind it
/// to an intermediate buffer on every frame. On SD720G that snowballs
/// into 60-120ms of main-thread stalls per scroll tick.
///
/// The blur has been replaced with a solid tinted surface (semi-opaque
/// color chosen from LangTokens) + a subtle border + the existing
/// shadow. Visually still reads as a glassy layered card; at zero
/// runtime paint cost beyond a single filled rounded-rect.
///
/// The `level` parameter is preserved so callers don't need updating —
/// it now only controls tint opacity and border strength.
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

    final (Color surfaceColor, Color borderColor) = switch (level) {
      GlassLevel.level1 => (tokens.surface1, tokens.border),
      GlassLevel.level2 => (tokens.surface2, tokens.border),
      GlassLevel.level3 => (tokens.surface3, tokens.borderStrong),
    };

    final radius = borderRadius ?? BorderRadius.circular(AppSizes.radiusLg);

    // Single composited box: color + border + shadow (if elevated).
    Widget content = Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: 1),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: tokens.shadowMd,
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
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

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: content,
    );
  }
}
