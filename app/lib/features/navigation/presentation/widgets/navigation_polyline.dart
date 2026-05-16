
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/settings/application/app_settings_provider.dart';
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
///   * Go-to: solid polyline from user → target in primary colour.
///   * Follow-track: solid, thick warning-coloured stroke along the
///     reference polyline with a subtle white halo for visibility on
///     busy tiles; a separate [MarkerLayer] places a green "start"
///     dot at pathPoints.first and a red "end" dot at pathPoints.last
///     so the user can orient themselves without reading metadata.
class NavigationPolyline {
  NavigationPolyline._();

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
    // Navigation polyline is always thicker than the user-configured
    // width to stand out as guidance. Use user width + 2.
    final userWidth = ref.watch(polylineWidthProvider);
    final navWidth = userWidth + 2;

    if (target is GotoTarget) {
      if (userReading == null) return const [];
      return [
        _GotoSolidLayer(
          from: userReading.latLng,
          to: target.position,
          strokeWidth: navWidth,
        ),
      ];
    }

    if (target is FollowTrackTarget) {
      final path = target.pathPoints;
      if (path.length < 2) return const [];
      return [
        _FollowTrackStroke(
          points: path,
          strokeWidth: navWidth,
          percentTraveled: state.progress.percentAlongPath,
        ),
        _FollowTrackEndpoints(points: path),
      ];
    }

    return const [];
  }
}

// ===========================================================================
// Go-to — solid polyline from user to target
// ===========================================================================

class _GotoSolidLayer extends StatelessWidget {
  const _GotoSolidLayer({
    required this.from,
    required this.to,
    required this.strokeWidth,
  });

  final LatLng from;
  final LatLng to;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.primary;
    return PolylineLayer<Object>(
      polylines: [
        Polyline(
          points: [from, to],
          strokeWidth: strokeWidth,
          color: color.withValues(alpha: 0.95),
          borderStrokeWidth: 1.5,
          borderColor: Colors.white.withValues(alpha: 0.5),
        ),
      ],
    );
  }
}

// ===========================================================================
// Follow-track — solid reference polyline
// ===========================================================================

class _FollowTrackStroke extends StatelessWidget {
  const _FollowTrackStroke({
    required this.points,
    required this.strokeWidth,
    required this.percentTraveled,
  });

  final List<LatLng> points;
  final double strokeWidth;
  final double percentTraveled;

  /// Splits the polyline at the given percentage and returns
  /// [traveled, remaining] point lists.
  (List<LatLng>, List<LatLng>) _splitAtPercent() {
    if (percentTraveled <= 0) return (const [], points);
    if (percentTraveled >= 1) return (points, const []);

    // Calculate total length and find the split point.
    final distances = <double>[];
    double totalDist = 0;
    for (int i = 1; i < points.length; i++) {
      final d = _haversine(points[i - 1], points[i]);
      distances.add(d);
      totalDist += d;
    }
    if (totalDist == 0) return (points, const []);

    final targetDist = totalDist * percentTraveled;
    double accumulated = 0;

    for (int i = 0; i < distances.length; i++) {
      final segDist = distances[i];
      if (accumulated + segDist >= targetDist) {
        // Interpolate within this segment.
        final frac = (targetDist - accumulated) / segDist;
        final splitPoint = LatLng(
          points[i].latitude + (points[i + 1].latitude - points[i].latitude) * frac,
          points[i].longitude + (points[i + 1].longitude - points[i].longitude) * frac,
        );
        final traveled = [...points.sublist(0, i + 1), splitPoint];
        final remaining = [splitPoint, ...points.sublist(i + 1)];
        return (traveled, remaining);
      }
      accumulated += segDist;
    }
    return (points, const []);
  }

  static double _haversine(LatLng a, LatLng b) {
    const R = 6371000.0; // Earth radius in meters
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
    return 2 * R * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final activeColor = tokens.warning;
    // Traveled portion is greyed out.
    const traveledColor = Color(0xFF9CA3AF); // grey-400

    final (traveled, remaining) = _splitAtPercent();

    return PolylineLayer<Object>(
      polylines: [
        // Soft outer glow for the whole path
        if (remaining.length >= 2)
          Polyline(
            points: remaining,
            strokeWidth: strokeWidth + 4,
            color: activeColor.withValues(alpha: 0.22),
          ),
        // Traveled (grey, faded)
        if (traveled.length >= 2)
          Polyline(
            points: traveled,
            strokeWidth: strokeWidth,
            color: traveledColor.withValues(alpha: 0.6),
            borderStrokeWidth: 1.0,
            borderColor: Colors.white.withValues(alpha: 0.4),
          ),
        // Remaining (bright warning color)
        if (remaining.length >= 2)
          Polyline(
            points: remaining,
            strokeWidth: strokeWidth,
            color: activeColor,
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
