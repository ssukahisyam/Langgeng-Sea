import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/marker.dart';

/// Tappable map pin for [AppMarker] overlays on the live map.
///
/// Shape: classic teardrop pin — a filled circle with a downward-
/// pointing tail that tapers to a single pixel. The tip lands exactly
/// on the marker coordinate when the enclosing `Marker` is aligned
/// `Alignment.bottomCenter`.
///
/// The circle is filled with the category colour. Inside the circle,
/// a white category icon (ikan / warning / jangkar / mapPin) mirrors
/// the iconography used in the "Penanda Saya" list so the user
/// instantly recognises what a pin represents — same visual language
/// in both places.
///
/// A translucent label pill sits BELOW the tip with a small gap so it
/// doesn't collide with the pin itself. Capped at 14 characters + "…".
///
/// Layout contract:
///   • Outer `Marker` must be `width: 80, height: 64` with
///     `alignment: Alignment.bottomCenter`.
///   • Pin glyph is 36w × 46h (circle top, tail bottom).
///   • Label pill lives in the remaining 18dp under the tip.
class MarkerPin extends StatelessWidget {
  const MarkerPin({
    super.key,
    required this.marker,
    this.onTap,
  });

  final AppMarker marker;
  final VoidCallback? onTap;

  /// Target width used by the enclosing `Marker`. Exported so callers
  /// stay in sync without hard-coding numbers.
  static const double width = 80;

  /// Target height used by the enclosing `Marker`.
  static const double height = 64;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final fillColor = _categoryColor(context, marker.category);
    final icon = _categoryIcon(marker.category);
    final displayLabel = _truncate(marker.name, 14);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // --- Pin glyph (circle + tail) -------------------------------
            SizedBox(
              width: 36,
              height: 46,
              child: CustomPaint(
                painter: _PinShapePainter(
                  fill: fillColor,
                  stroke: Colors.white,
                ),
                child: Padding(
                  // Push icon up so it sits centered in the circle
                  // (top 36dp of the 46dp canvas), not on the tail.
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Center(
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            // --- Name label pill -----------------------------------------
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 78),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
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
                    fontSize: 9.5,
                    height: 1.1,
                    color: context.colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _truncate(String input, int maxChars) {
    if (input.length <= maxChars) return input;
    return '${input.substring(0, maxChars)}…';
  }

  /// Colour per category. Matches the "Penanda Saya" list so the same
  /// palette applies in both views.
  Color _categoryColor(BuildContext context, MarkerCategory cat) {
    final tokens = context.tokens;
    return switch (cat) {
      MarkerCategory.productive => tokens.success,
      MarkerCategory.hazard => tokens.danger,
      MarkerCategory.port => context.colors.primary,
      MarkerCategory.other => tokens.textSecondary,
    };
  }

  /// Category icon shown inside the pin circle. Mirrors
  /// [MarkersListScreen] tile icons so the visual language is
  /// consistent between the list and the map overlay.
  IconData _categoryIcon(MarkerCategory cat) => switch (cat) {
        MarkerCategory.productive => PhosphorIconsFill.fishSimple,
        MarkerCategory.hazard => PhosphorIconsFill.warning,
        MarkerCategory.port => PhosphorIconsFill.anchor,
        MarkerCategory.other => PhosphorIconsFill.mapPin,
      };
}

/// Paints the teardrop pin shape on a 36 × 46 canvas.
///
/// The geometry: a circle of radius 18 centered at (18, 18) occupies
/// the top 36dp. From the two tangent points ~35° off vertical, two
/// straight lines converge at the tip — (18, 46) — forming the tail.
/// Filling and stroking the resulting closed path draws one
/// continuous pin in a single allocation, which is cheaper than
/// stacking a Container + Triangle painter.
///
/// A soft shadow (drawShadow) + 1.5dp white outline improve contrast
/// against busy OSM / OpenSeaMap tiles — without them a red hazard
/// pin on a rocky coast blends in.
class _PinShapePainter extends CustomPainter {
  const _PinShapePainter({required this.fill, required this.stroke});

  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    const circleRadius = 18.0;
    final circleCenter = Offset(size.width / 2, circleRadius);

    // Tangent angle picked so the tail visually merges with the
    // circle edge (no kink). ±35° off vertical is the sweet spot:
    // smaller => too pointy, larger => tail looks "pasted on".
    const tailAngleRad = 0.6108; // ≈ 35°
    final sinA = math.sin(tailAngleRad);
    final cosA = math.cos(tailAngleRad);

    final leftTangent = Offset(
      circleCenter.dx - circleRadius * sinA,
      circleCenter.dy + circleRadius * cosA,
    );
    final rightTangent = Offset(
      circleCenter.dx + circleRadius * sinA,
      circleCenter.dy + circleRadius * cosA,
    );
    final tip = Offset(size.width / 2, size.height);

    final path = Path()
      ..moveTo(leftTangent.dx, leftTangent.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(rightTangent.dx, rightTangent.dy)
      ..arcToPoint(
        leftTangent,
        radius: const Radius.circular(circleRadius),
        clockwise: false,
        largeArc: true,
      )
      ..close();

    // Soft drop shadow (offset 1dp down, blur 3dp) for elevation cue.
    canvas.drawShadow(
      path.shift(const Offset(0, 1)),
      Colors.black38,
      3,
      true,
    );

    // Fill
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = fill;
    canvas.drawPath(path, fillPaint);

    // White outline — separates the pin from tiles of the same colour
    // family (e.g. red hazard pin on coastal red-flag symbology).
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = stroke.withValues(alpha: 0.95);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _PinShapePainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.stroke != stroke;
}
