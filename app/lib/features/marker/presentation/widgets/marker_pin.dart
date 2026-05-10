import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/marker.dart';

/// Draws a tappable map pin for [AppMarker] overlays on the live map.
///
/// - Category-coloured 24dp filled pin icon
/// - Subtle glow under the pin for contrast against the tile
/// - Label pill (10pt, 14-char cap + ellipsis) sits under the pin so
///   users can identify markers without tapping each one. The whole
///   widget is 80×48 (Marker width/height from flutter_map) aligned
///   [Alignment.topCenter] so the tip of the pin lands on the actual
///   coordinate.
class MarkerPin extends StatelessWidget {
  const MarkerPin({
    super.key,
    required this.marker,
    this.onTap,
  });

  final AppMarker marker;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = _categoryColor(context, marker.category);
    final displayLabel = _truncate(marker.name, 14);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Glow + icon
          SizedBox(
            width: 28,
            height: 28,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                PhosphorIconsFill.mapPin,
                size: 24,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Label pill
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 78),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: tokens.surface3.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                border: Border.all(
                  color: tokens.borderStrong,
                  width: 0.5,
                ),
              ),
              child: Text(
                displayLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.1,
                  color: context.colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _truncate(String input, int maxChars) {
    if (input.length <= maxChars) return input;
    return '${input.substring(0, maxChars)}…';
  }

  Color _categoryColor(BuildContext context, MarkerCategory cat) {
    final tokens = context.tokens;
    return switch (cat) {
      MarkerCategory.productive => tokens.success,
      MarkerCategory.hazard => tokens.danger,
      MarkerCategory.port => context.colors.primary,
      MarkerCategory.other => tokens.textSecondary,
    };
  }
}
