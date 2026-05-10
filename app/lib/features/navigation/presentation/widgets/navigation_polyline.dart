import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../map/application/current_reading_provider.dart';
import '../../application/navigation_state.dart';
import '../../domain/entities/navigation_target.dart';

/// flutter_map layer that renders the active navigation target on the map.
///
/// Go-to mode: short dashed polyline from the user to the target,
/// drawn in primary colour. The dashed look is composed from
/// hand-sliced segments (flutter_map's `Polyline` does not support a
/// dash pattern on the 7.x line, so we build it ourselves). The
/// slicing runs in geographic space -- each dash ~120 m (converted to
/// degrees via a lat-latitude-safe factor), producing roughly 6-10
/// dashes on typical 500 m-5 km runs.
///
/// Follow-track mode (M11b) will extend this widget to highlight the
/// reference polyline with a thicker warning-coloured stroke. For M11a
/// we render an empty layer in that branch so swapping the state to
/// follow-track keeps the map functional pending the M11b diff.
class NavigationPolyline extends ConsumerWidget {
  const NavigationPolyline({super.key, required this.state});

  final NavigationActive state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = state.target;
    final userReading = ref.watch(currentReadingProvider).asData?.value;
    if (userReading == null) {
      // No fix yet -- nothing reasonable to draw. Return an empty
      // PolylineLayer rather than a SizedBox so parents can keep
      // expecting a map layer child type.
      return const PolylineLayer<Object>(polylines: []);
    }

    if (target is GotoTarget) {
      final dashes = _dashedSegments(userReading.latLng, target.position);
      final color = context.colors.primary;
      return PolylineLayer<Object>(
        polylines: [
          for (final seg in dashes)
            Polyline(
              points: seg,
              strokeWidth: 3,
              color: color.withValues(alpha: 0.85),
            ),
        ],
      );
    }

    // Follow-track branch -- final look lands in M11b. Keep an empty
    // layer so widget tests and map composition stay stable.
    return const PolylineLayer<Object>(polylines: []);
  }

  /// Split the great-circle line user->target into roughly equal
  /// dashes + gaps. Uses linear interpolation in (lat, lng) space
  /// which is good enough below ~100 km at our typical latitudes --
  /// the visible artefact of pretending the line is straight on a
  /// Mercator tile is sub-pixel.
  ///
  /// Dash length scales with total distance so very long lines do not
  /// become a solid line (too many dashes) and very short lines get
  /// at least 2 segments.
  static List<List<LatLng>> _dashedSegments(LatLng from, LatLng to) {
    if (from == to) return const [];

    // Rough great-circle distance via haversine would be more
    // accurate, but for visual dashing the planar approximation is
    // fine and avoids the double math cost.
    const mPerDegLat = 111000.0;
    final avgLatRad = (from.latitude + to.latitude) / 2 * math.pi / 180.0;
    final mPerDegLng = mPerDegLat * math.cos(avgLatRad);

    final dLat = (to.latitude - from.latitude) * mPerDegLat;
    final dLng = (to.longitude - from.longitude) * mPerDegLng;
    final totalMeters = math.sqrt(dLat * dLat + dLng * dLng);
    if (totalMeters < 1) return const [];

    // Target 8 dashes for mid-range, min 2, max 40.
    final approxDashCount = (totalMeters / 150).clamp(2.0, 40.0).round();
    final step = 1.0 / (approxDashCount * 2); // each dash + gap
    final segments = <List<LatLng>>[];
    // i = 0 -> dash, i = 1 -> gap, alternating.
    for (var i = 0; i < approxDashCount * 2; i += 2) {
      final t0 = i * step;
      final t1 = (i + 1) * step;
      segments.add([
        _lerpLatLng(from, to, t0),
        _lerpLatLng(from, to, t1),
      ]);
    }
    return segments;
  }

  static LatLng _lerpLatLng(LatLng a, LatLng b, double t) {
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }
}
