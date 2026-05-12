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
/// on the marker coordinate when the enclosing `Marker` is anchored
/// per [MarkerPin.markerAlignment] below.
///
/// The circle is filled with the category colour. Inside the circle,
/// a white category icon (ikan / warning / jangkar / mapPin) mirrors
/// the iconography used in the "Penanda Saya" list so the user
/// instantly recognises what a pin represents — same visual language
/// in both places.
///
/// ## Label visibility (zoom-aware)
///
/// When [showLabel] is true, a translucent pill with the marker name
/// is rendered BELOW the pin tip. The convention from Google/Apple
/// Maps is to auto-show labels only when the user has zoomed in
/// enough to need them; callers set this by comparing the map
/// camera's current zoom to [MarkerPin.labelZoomThreshold].
///
/// ## Geometry contract
///
/// The enclosing `Marker` must use [MarkerPin.markerSize] and
/// [MarkerPin.markerAlignment]. Both depend on [showLabel] because
/// adding the label extends the widget bounds downward, which in
/// turn shifts where "bottom-center" lands relative to the pin tip.
///
/// ```
///   showLabel = false            showLabel = true
///   ─────────────                ─────────────
///   ┌──────────┐  y=0            ┌──────────┐  y=0
///   │  (pin)   │                 │  (pin)   │
///   │  36×46   │                 │  36×46   │
///   │     ↓    │  y=46 (tip)     │     ↓    │  y=46 (tip)
///   └──────────┘  ← anchor       ├──────────┤
///                                │  label   │
///                                │  pill    │
///                                └──────────┘  y=64
///                                              ← anchor lands here
///                                              if we used
///                                              bottomCenter, so we
///                                              use Alignment(0,
///                                              0.4375) to push the
///                                              anchor back up to
///                                              the tip.
/// ```
///
/// See [MarkerPin.markerAlignment] for the derivation.
class MarkerPin extends StatelessWidget {
  const MarkerPin({
    super.key,
    required this.marker,
    this.showLabel = false,
    this.onTap,
  });

  final AppMarker marker;

  /// Whether to render the name label pill under the pin. When false,
  /// only the teardrop glyph is drawn and the overall height shrinks
  /// by [_labelRegionHeight] — the enclosing `Marker` must use
  /// [markerSize] / [markerAlignment] with the SAME `showLabel` value
  /// so the tip registration stays correct.
  final bool showLabel;

  final VoidCallback? onTap;

  /// Pin glyph dimensions (constant; label is layered below).
  static const double _pinWidth = 36;
  static const double _pinHeight = 46;

  /// Height reserved for the label pill + the gap between pin & pill.
  static const double _labelRegionHeight = 18;

  /// Zoom at which labels should start appearing. Below this we only
  /// draw glyphs; above, callers pass `showLabel: true`. Tuned so
  /// that at city-overview zooms the map doesn't flood with pill
  /// text, but once the user zooms in on a port or channel the
  /// names are immediately legible.
  static const double labelZoomThreshold = 14.0;

  /// Returns the `width`/`height` the enclosing `Marker` must use.
  /// Grows by [_labelRegionHeight] when [showLabel] is on.
  static Size markerSize({required bool showLabel}) => Size(
        _pinWidth,
        showLabel ? _pinHeight + _labelRegionHeight : _pinHeight,
      );

  /// Returns the `alignment` the enclosing `Marker` must use so the
  /// pin tip lands exactly on the lat/lng.
  ///
  /// With no label the widget height equals the pin height and the
  /// tip *is* the bottom, so `bottomCenter` works.
  ///
  /// With a label the widget height is `pinH + labelRegionH`. The tip
  /// sits at y = pinH inside the widget (not y = height). Flutter's
  /// `Alignment(0, y)` anchors to the y-position (height/2) + (y *
  /// height/2), so we solve for the y that places the anchor at the
  /// tip: `y = (2 * pinH / totalH) - 1`. Pre-computed below to avoid
  /// floating-point math in the hot rebuild path.
  static Alignment markerAlignment({required bool showLabel}) {
    if (!showLabel) return Alignment.bottomCenter;
    // (2 * 46 / 64) - 1 = 0.4375
    return const Alignment(0, 0.4375);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final fillColor = _categoryColor(context, marker.category);
    final icon = _categoryIcon(marker.category);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: _pinWidth,
        height: showLabel ? _pinHeight + _labelRegionHeight : _pinHeight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // --- Pin glyph (circle + tail) -------------------------------
            SizedBox(
              width: _pinWidth,
              height: _pinHeight,
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
            // --- Name label pill (zoom-gated by caller) ------------------
            if (showLabel) ...[
              const SizedBox(height: 2),
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
                    _truncate(marker.name, 14),
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
