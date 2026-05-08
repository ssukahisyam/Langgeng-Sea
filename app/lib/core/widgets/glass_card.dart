import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// Glass surface level - controls opacity and blur intensity.
enum GlassLevel { level1, level2, level3 }

/// A glassmorphic card with backdrop blur.
/// Core primitive for the Clean Liquid Glass design system.
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

    final (surfaceColor, blurAmount, borderColor) = switch (level) {
      GlassLevel.level1 => (
          tokens.surface1,
          AppSizes.blurGlass1,
          tokens.border,
        ),
      GlassLevel.level2 => (
          tokens.surface2,
          AppSizes.blurGlass2,
          tokens.border,
        ),
      GlassLevel.level3 => (
          tokens.surface3,
          AppSizes.blurGlass3,
          tokens.borderStrong,
        ),
    };

    final radius = borderRadius ?? BorderRadius.circular(AppSizes.radiusLg);

    Widget content = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: radius,
            border: Border.all(color: borderColor, width: 1),
          ),
          padding: padding,
          child: child,
        ),
      ),
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
