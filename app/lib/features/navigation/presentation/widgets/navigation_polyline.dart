import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../map/application/current_reading_provider.dart';
import '../../application/navigation_state.dart';
import '../../domain/entities/navigation_target.dart';

/// Builds the flutter_map layers that visualise an active navigation
/// target. Exposed as a collection of layers (not a single widget)
/// because follow-track needs both a [PolylineLayer] *and* a
/// [MarkerLayer] for the start/end dots; flutter_map expects each
/// child to be a real layer sitting on the map, so returning a
/// `Column` would misplace the children on screen instead of
/// georegistering them.
///
/// Call from `MapScreen.build`:
///
/// ```dart
/// if (navActive != null)
///   ...NavigationPolyline.buildLayers(context, ref, navActive),
/// ```
///
/// Modes:
///   * Go-to: dashed polyline from user → target in primary colour.
///     flutter_map 7.x `Polyline` has no dash pattern so the line is
///     built from hand-sliced segments (~150 m per dash, scaled to
///     total distance). Only polyline — no marker layer.
///   * Follow-track: solid, thick warning-coloured stroke along the
///     reference polyline with a subtle white halo for visibility on
///     busy tiles; a separate [MarkerLayer] places a green "start"
///     dot at pathPoints.first and a red "end" dot at pathPoints.last
///     so the user can orient themselves without reading metadata.
class NavigationPolyline {
  NavigationPolyline._();

  /// How far (in meters) between the midpoint of each dash for go-to
  /// mode. Tuned empirically in the prototype — shorter and the dash
  /// pattern turns into a solid line on zoom 10, longer and you only
  /// see two or three dashes on 200 m runs.
  static const double _gotoDashSpacingMeters = 150.0;

  /// Main stroke width for the follow-track reference polyline. Thicker
  /// than the active haul polyline (strokeWidth 5 at level-2 glow,
  /// see `ActiveHaulPolyline`) so that when the user is recording
  /// *and* following, the reference track reads as the dominant
  /// guidance layer, not a peer.
  static const double _followTrackStrokeWidth = 6.0;

  /// Build the list of map layers for the active navigation target.
  /// Returns an empty list when there is nothing reasonable to draw
  /// (no GPS fix yet, degenerate targets, etc.) — always safe to
  /// spread into `FlutterMap.children`.
  static List<Widget> buildLayers(
    BuildContext context,
    WidgetRef ref,
    NavigationActive state,
  ) {
    final target = state.target;
    final userReading = ref.watch(currentReadingProvider).asData?.value;

    if (target is GotoTarget) {
      if (userReading == null) return const [];
      return [_GotoDashedLayer(from: userReading.latLng, to: target.position)];
    }

    if (target is FollowTrackTarget) {
      final path = target.pathPoints;
      if (path.length < 2) return const [];
      return [
        _FollowTrackStroke(points: path),
        _FollowTrackEndpoints(points: path),
      ];
    }

    return const [];
  }
}

// ===========================================================================
// Go-to — dashed polyline from user to target
// ===========================================================================

class _GotoDashedLayer extends StatelessWidget {
  const _GotoDashedLayer({required this.from, required this.to});

  final LatLng from;
  final LatLng to;

  @override
  Widget build(BuildContext context) {
    final dashes = _dashedSegments(from, to);
    final color = context.colors.primary;
    return PolylineLayer<Object>(
      polylines: [
        for (final seg in dashes)
          Polyline(
            points: seg,
            strokeWidth: 6.0,
            color: color.withValues(alpha: 0.95),
          ),
      ],
    );
  }

  /// Split the great-circle line user→target into roughly equal
  /// dashes + gaps. Uses linear interpolation in (lat, lng) space
  /// which is good enough below ~100 km at our typical latitudes —
  /// the visible artefact of pretending the line is straight on a
  /// Mercator tile is sub-pixel.
  static List<List<LatLng>> _dashedSegments(LatLng from, LatLng to) {
    if (from == to) return const [];

    const mPerDegLat = 111000.0;
    final avgLatRad = (from.latitude + to.latitude) / 2 * math.pi / 180.0;
    final mPerDegLng = mPerDegLat * math.cos(avgLatRad);

    final dLat = (to.latitude - from.latitude) * mPerDegLat;
    final dLng = (to.longitude - from.longitude) * mPerDegLng;
    final totalMeters = math.sqrt(dLat * dLat + dLng * dLng);
    if (totalMeters < 1) return const [];

    // Target 8 dashes for mid-range, min 2, max 40.
    final approxDashCount =
        (totalMeters / NavigationPolyline._gotoDashSpacingMeters)
            .clamp(2.0, 40.0)
            .round();
    final step = 1.0 / (approxDashCount * 2); // each dash + gap
    final segments = <List<LatLng>>[];
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

// ===========================================================================
// Follow-track — solid reference polyline
// ===========================================================================

class _FollowTrackStroke extends StatelessWidget {
  const _FollowTrackStroke({required this.points});

  final List<LatLng> points;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = tokens.warning;
    return PolylineLayer<Object>(
      polylines: [
        // Soft outer glow — same visual trick as ActiveHaulPolyline,
        // reused here so the reference track is legible against busy
        // sea chart tiles.
        Polyline(
          points: points,
          strokeWidth: NavigationPolyline._followTrackStrokeWidth + 4,
          color: color.withValues(alpha: 0.22),
        ),
        Polyline(
          points: points,
          strokeWidth: NavigationPolyline._followTrackStrokeWidth,
          color: color,
          borderStrokeWidth: 1.5,
          borderColor: Colors.white.withValues(alpha: 0.9),
        ),
      ],
    );
  }
}

// ===========================================================================
// Follow-track — start / end dots
// ===========================================================================

class _FollowTrackEndpoints extends StatelessWidget {
  const _FollowTrackEndpoints({required this.points});

  final List<LatLng> points;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return MarkerLayer(
      markers: [
        Marker(
          point: points.first,
          width: 22,
          height: 22,
          alignment: Alignment.center,
          child: _EndpointDot(
            color: tokens.success,
            icon: PhosphorIconsFill.playCircle,
          ),
        ),
        Marker(
          point: points.last,
          width: 22,
          height: 22,
          alignment: Alignment.center,
          child: _EndpointDot(
            color: tokens.danger,
            icon: PhosphorIconsFill.flag,
          ),
        ),
      ],
    );
  }
}

class _EndpointDot extends StatelessWidget {
  const _EndpointDot({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 11),
    );
  }
}
