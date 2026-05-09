import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Ramer–Douglas–Peucker polyline simplification, pure Dart.
///
/// Given a dense GPS trace (we typically record a fix every 2 m), we want
/// to throw away points that don't meaningfully change the shape so the
/// overlay renderer can draw 10× the hauls at 60fps. This is the
/// standard approach.
///
/// [toleranceMeters] controls how aggressively we simplify:
///   *   5 m — very conservative, keeps almost every wiggle
///   *  20 m — default for the "Tampilkan Semua Riwayat" overlay
///   * 100 m — for very-zoomed-out dashboard previews
///
/// The routine uses the **perpendicular distance** from each candidate
/// point to the chord between the current segment's endpoints. Distance
/// is computed in equirectangular-approx metres so we don't have to
/// project into UTM for every segment — plenty accurate for trawl-scale
/// polylines (<50 km) at tolerances ≥ a few metres.
class PolylineSimplifier {
  PolylineSimplifier._();

  /// Simplify [points] to contain fewer vertices while staying within
  /// [toleranceMeters] of the original shape.
  ///
  /// Returns the input unchanged when it has fewer than 3 points or
  /// [toleranceMeters] ≤ 0. The first and last points are always
  /// preserved.
  static List<LatLng> simplify(
    List<LatLng> points, {
    double toleranceMeters = 20,
  }) {
    if (points.length < 3 || toleranceMeters <= 0) {
      return List<LatLng>.unmodifiable(points);
    }

    final keep = List<bool>.filled(points.length, false);
    keep[0] = true;
    keep[points.length - 1] = true;

    // Iterative RDP (avoids stack blow-up on very long traces).
    final stack = <_Segment>[_Segment(0, points.length - 1)];
    while (stack.isNotEmpty) {
      final seg = stack.removeLast();
      if (seg.end <= seg.start + 1) continue;

      final a = points[seg.start];
      final b = points[seg.end];

      var maxDist = -1.0;
      var maxIdx = -1;
      for (var i = seg.start + 1; i < seg.end; i++) {
        final d = _perpendicularDistanceMeters(points[i], a, b);
        if (d > maxDist) {
          maxDist = d;
          maxIdx = i;
        }
      }

      if (maxIdx >= 0 && maxDist > toleranceMeters) {
        keep[maxIdx] = true;
        stack
          ..add(_Segment(seg.start, maxIdx))
          ..add(_Segment(maxIdx, seg.end));
      }
    }

    final out = <LatLng>[];
    for (var i = 0; i < points.length; i++) {
      if (keep[i]) out.add(points[i]);
    }
    return out;
  }

  /// Perpendicular distance in metres from [p] to the segment [a]-[b].
  ///
  /// Uses the equirectangular projection centred on `a`. For the short
  /// segments we're dealing with (chunks of a few hundred metres) the
  /// error vs true great-circle is well under 0.1%.
  static double _perpendicularDistanceMeters(LatLng p, LatLng a, LatLng b) {
    const earthMetersPerRadian = 6371000.0;
    final lat0 = a.latitude * math.pi / 180.0;
    final cosLat = math.cos(lat0);

    double toX(double lonDeg) =>
        (lonDeg - a.longitude) * math.pi / 180.0 * cosLat * earthMetersPerRadian;
    double toY(double latDeg) =>
        (latDeg - a.latitude) * math.pi / 180.0 * earthMetersPerRadian;

    final ax = 0.0;
    final ay = 0.0;
    final bx = toX(b.longitude);
    final by = toY(b.latitude);
    final px = toX(p.longitude);
    final py = toY(p.latitude);

    final dx = bx - ax;
    final dy = by - ay;
    final lenSq = dx * dx + dy * dy;

    if (lenSq == 0) {
      // a and b coincide — fall back to point distance.
      final ddx = px - ax;
      final ddy = py - ay;
      return math.sqrt(ddx * ddx + ddy * ddy);
    }

    // Project p onto segment (clamped) for a robust distance even when
    // the "perpendicular" foot falls outside the segment.
    var t = ((px - ax) * dx + (py - ay) * dy) / lenSq;
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    final projX = ax + t * dx;
    final projY = ay + t * dy;
    final ex = px - projX;
    final ey = py - projY;
    return math.sqrt(ex * ex + ey * ey);
  }
}

class _Segment {
  const _Segment(this.start, this.end);
  final int start;
  final int end;
}
