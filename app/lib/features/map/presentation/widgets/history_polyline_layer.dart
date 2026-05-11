import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/contrast_ratio.dart';
import '../../application/history_overlay_providers.dart';

/// WCAG-compliant polyline layer for the History_Overlay.
///
/// Renders each [HaulTrackRender] as a compound stroke: an outer
/// semi-transparent "hit area" for tap detection, a white border for
/// contrast against dark tiles, and the main coloured stroke.
///
/// The compound approach meets Requirement 3.1 (WCAG 4.5:1 contrast)
/// by adding a white border underneath the colour stroke — this
/// guarantees the polyline is distinguishable against both light OSM
/// land tiles (~#f2efe9) and dark sea tiles (~#aad3df).
///
/// Tap detection uses `flutter_map`'s built-in `PolylineLayer.hitNotifier`
/// with an [onTrackTap] callback that bubbles the tapped [HaulTrackRender]
/// up to the parent widget (typically `MapScreen`) which then shows the
/// [TrackPopup].
///
/// _Requirements: 3.1, 3.2, 3.3, 3.5, 3.6_
class HistoryPolylineLayer extends StatefulWidget {
  const HistoryPolylineLayer({
    super.key,
    required this.tracks,
    required this.onTrackTap,
    this.isBackground = false,
  });

  /// The tracks to render as polylines.
  final List<HaulTrackRender> tracks;

  /// Called when the user taps on a track polyline. The callback
  /// receives the tapped [HaulTrackRender] and the tap position in
  /// local (widget) coordinates for popup placement.
  final void Function(HaulTrackRender track, Offset tapPosition) onTrackTap;

  /// When `true`, renders tracks at lower opacity (context layer).
  /// When `false`, renders at full saturation (focused layer).
  final bool isBackground;

  @override
  State<HistoryPolylineLayer> createState() => _HistoryPolylineLayerState();
}

class _HistoryPolylineLayerState extends State<HistoryPolylineLayer> {
  final LayerHitNotifier<HaulTrackRender> _hitNotifier = ValueNotifier(null);

  @override
  Widget build(BuildContext context) {
    if (widget.tracks.isEmpty) return const SizedBox.shrink();

    final polylines = <Polyline<HaulTrackRender>>[];

    for (final track in widget.tracks) {
      final color = AppColors.resolveHaulColor(
        colorValue: track.colorValue,
        orderIndex: track.orderIndex,
      );

      if (widget.isBackground) {
        // Background layer: thinner, lower alpha, no border.
        polylines.add(
          Polyline<HaulTrackRender>(
            points: track.points,
            strokeWidth: 3,
            color: color.withValues(alpha: 0.28),
            hitValue: track,
          ),
        );
      } else {
        // Focused layer: compound stroke for WCAG compliance.
        // 1. White border for contrast
        final borderColor = _borderColorForContrast(color);
        polylines.add(
          Polyline<HaulTrackRender>(
            points: track.points,
            strokeWidth: 6,
            color: borderColor.withValues(alpha: 0.40),
            hitValue: track,
          ),
        );
        // 2. Main colour stroke
        polylines.add(
          Polyline<HaulTrackRender>(
            points: track.points,
            strokeWidth: 4,
            color: color.withValues(alpha: 0.75),
            borderStrokeWidth: 0.6,
            borderColor: Colors.white.withValues(alpha: 0.35),
            hitValue: track,
          ),
        );
      }
    }

    return GestureDetector(
      onTapUp: _onTap,
      child: PolylineLayer<HaulTrackRender>(
        polylines: polylines,
        hitNotifier: _hitNotifier,
      ),
    );
  }

  void _onTap(TapUpDetails details) {
    final hit = _hitNotifier.value;
    if (hit == null || hit.hitValues.isEmpty) return;
    // Take the topmost (last-rendered) hit value.
    final track = hit.hitValues.last;
    widget.onTrackTap(track, details.localPosition);
  }

  /// Choose a border colour that maximises contrast against the main
  /// stroke. For light colours, use a dark border; for dark colours,
  /// use white.
  Color _borderColorForContrast(Color main) {
    const white = Color(0xFFFFFFFF);
    const dark = Color(0xFF1A1A1A);
    final crWhite = contrastRatio(main, white);
    final crDark = contrastRatio(main, dark);
    return crWhite >= crDark ? white : dark;
  }
}
