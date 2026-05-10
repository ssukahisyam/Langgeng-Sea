import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Pure geospatial math used by the haul metric calculator.
///
/// Stateless and side-effect free — easy to unit test offline.
class GeoCalculator {
  GeoCalculator._();

  /// Mean radius of Earth in meters. WGS84 mean — good enough for haul
  /// distances (<~50 km) where great-circle approximation is <0.5% off.
  static const double _earthRadiusMeters = 6371000;

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;
  static double _toDegrees(double radians) => radians * 180.0 / math.pi;

  /// Great-circle distance between two points in meters (Haversine).
  static double haversineMeters(LatLng a, LatLng b) {
    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);
    final dLat = _toRadians(b.latitude - a.latitude);
    final dLon = _toRadians(b.longitude - a.longitude);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.asin(math.min(1.0, math.sqrt(h)));
    return _earthRadiusMeters * c;
  }

  /// Sum of pairwise haversine distances along an ordered polyline.
  /// Returns 0 for empty or single-point inputs.
  static double totalDistanceMeters(List<LatLng> points) {
    if (points.length < 2) return 0;
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += haversineMeters(points[i - 1], points[i]);
    }
    return total;
  }

  /// Circular mean of a list of bearings (degrees).
  ///
  /// Plain arithmetic mean fails across the 359°/0° wrap-around. This
  /// converts each bearing to a unit vector, averages, then re-projects.
  /// Returns `null` for an empty input.
  static double? circularMeanDegrees(Iterable<double> bearingsDeg) {
    var n = 0;
    var sumSin = 0.0;
    var sumCos = 0.0;
    for (final b in bearingsDeg) {
      if (!b.isFinite) continue;
      final r = _toRadians(b);
      sumSin += math.sin(r);
      sumCos += math.cos(r);
      n++;
    }
    if (n == 0) return null;
    final avg = math.atan2(sumSin / n, sumCos / n);
    return (_toDegrees(avg) + 360.0) % 360.0;
  }

  /// Approximated trawl swept area in m² = track length × trawl opening.
  ///
  /// Good enough for straight hauls. For future precision we could buffer
  /// the polyline and use the true union area (noted as v2 in design doc).
  static double sweptAreaM2({
    required double distanceMeters,
    required double trawlWidthMeters,
  }) {
    if (distanceMeters <= 0 || trawlWidthMeters <= 0) return 0;
    return distanceMeters * trawlWidthMeters;
  }

  /// 1 m/s = 1.943844 knots. Exposed as a static helper so live UI and
  /// final metrics stay consistent.
  static double mpsToKnots(double mps) => mps * 1.943844;

  // =========================================================================
  // Navigation helpers (M11)
  //
  // Pure Dart implementations of the spherical formulae we need for
  // go-to and follow-track guidance. Formulae sourced from Movable
  // Type Scripts — Latitude/Longitude calculations
  //   https://www.movable-type.co.uk/scripts/latlong.html
  //
  // Rationale for not pulling in turf_dart: ~200 KB of bundle for three
  // ~8-line functions we already have a precedent for in this class.
  // See m11-navigation-spec.md §3 for the full decision log.
  // =========================================================================

  /// Initial compass bearing from [from] to [to], in degrees 0..360
  /// (0 = north, 90 = east). Great-circle initial bearing — the true
  /// course over ground at [from] if the user heads straight at [to].
  ///
  /// Reference: Movable Type Scripts — "Bearing".
  static double bearingDegrees(LatLng from, LatLng to) {
    final lat1 = _toRadians(from.latitude);
    final lat2 = _toRadians(to.latitude);
    final dLon = _toRadians(to.longitude - from.longitude);

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final theta = math.atan2(y, x);
    return (_toDegrees(theta) + 360.0) % 360.0;
  }

  /// Perpendicular (cross-track) distance from [point] to the great-circle
  /// line running through [segStart] → [segEnd]. Returned value is the
  /// absolute distance in meters; sign (left vs right of line) is not
  /// preserved because consumers only need magnitude for off-route
  /// detection.
  ///
  /// Pure spherical cross-track distance:
  ///   dXt = asin( sin(d13 / R) * sin(θ13 − θ12) ) * R
  /// where d13 is the haversine from segStart to point and θ12, θ13 are
  /// the bearings segStart→segEnd and segStart→point respectively.
  /// Reference: Movable Type Scripts — "Cross-track distance".
  ///
  /// Degenerate segment ([segStart] == [segEnd]) falls back to the
  /// straight haversine from [point] to the collapsed segment point,
  /// so callers don't have to pre-validate polylines.
  static double crossTrackDistanceMeters(
    LatLng point,
    LatLng segStart,
    LatLng segEnd,
  ) {
    // Collapsed segment → just haversine to the single point.
    if (segStart.latitude == segEnd.latitude &&
        segStart.longitude == segEnd.longitude) {
      return haversineMeters(point, segStart);
    }

    final d13 = haversineMeters(segStart, point) / _earthRadiusMeters;
    final theta13 =
        _toRadians(bearingDegrees(segStart, point));
    final theta12 = _toRadians(bearingDegrees(segStart, segEnd));

    final dXt =
        math.asin(math.sin(d13) * math.sin(theta13 - theta12)) *
            _earthRadiusMeters;
    return dXt.abs();
  }

  /// Record type mirroring the shape documented in
  /// m11-navigation-spec.md §3: minimum distance from [point] to any
  /// segment of [polyline], plus the index of that segment (0-based,
  /// matching the `polyline[i] → polyline[i+1]` segment).
  ///
  /// For polylines with fewer than 2 points the result is `(0, 0)` —
  /// callers should guard against empty polylines before invoking. The
  /// "distance" in those edge cases is the haversine to the single
  /// point (if any) or 0 (empty).
  static ({double distanceMeters, int nearestSegmentIndex})
      nearestPointOnPolyline(
    LatLng point,
    List<LatLng> polyline,
  ) {
    if (polyline.isEmpty) {
      return (distanceMeters: 0, nearestSegmentIndex: 0);
    }
    if (polyline.length == 1) {
      return (
        distanceMeters: haversineMeters(point, polyline.first),
        nearestSegmentIndex: 0,
      );
    }

    var bestIdx = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < polyline.length - 1; i++) {
      final segStart = polyline[i];
      final segEnd = polyline[i + 1];
      final d = _distanceToSegmentMeters(point, segStart, segEnd);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return (distanceMeters: bestDist, nearestSegmentIndex: bestIdx);
  }

  /// Great-circle length of [polyline] = sum of pairwise haversine
  /// distances. Alias for [totalDistanceMeters] kept under its own
  /// name so navigation math reads naturally at call sites.
  static double polylineLengthMeters(List<LatLng> polyline) =>
      totalDistanceMeters(polyline);

  /// Progress along [polyline] of the projection of [point], as a
  /// fraction in [0, 1]. 0 = at start, 1 = at end.
  ///
  /// [nearestSegmentIndex] is optional: if the caller already ran
  /// [nearestPointOnPolyline] and has the hint, we skip re-iterating
  /// to find it. Otherwise we compute it here.
  ///
  /// Projection is approximated as "distance from start to nearest
  /// point on the nearest segment, divided by total length". Exact
  /// projection on a sphere is expensive and not observably better
  /// for our purposes (coastal polylines, zoom-15 scale).
  static double percentAlongPolyline(
    LatLng point,
    List<LatLng> polyline, {
    int? nearestSegmentIndex,
  }) {
    if (polyline.length < 2) return 0;
    final totalLength = polylineLengthMeters(polyline);
    if (totalLength <= 0) return 0;

    final idx = nearestSegmentIndex ??
        nearestPointOnPolyline(point, polyline).nearestSegmentIndex;

    // Accumulate length of all full segments up to (but not including)
    // the nearest one.
    var traversed = 0.0;
    for (var i = 0; i < idx; i++) {
      traversed += haversineMeters(polyline[i], polyline[i + 1]);
    }

    // Add the partial distance into the nearest segment — planar
    // projection of the point onto the great-circle segment.
    final segStart = polyline[idx];
    final segEnd = polyline[idx + 1];
    final segLen = haversineMeters(segStart, segEnd);
    if (segLen > 0) {
      final alongSeg = _alongTrackMeters(point, segStart, segEnd)
          .clamp(0.0, segLen);
      traversed += alongSeg;
    }

    final ratio = traversed / totalLength;
    if (ratio.isNaN || !ratio.isFinite) return 0;
    return ratio.clamp(0.0, 1.0);
  }

  // ---- internal helpers ---------------------------------------------------

  /// Distance from [point] to the *segment* (finite line) from [a] to
  /// [b], honouring the endpoints: if the foot of the perpendicular
  /// falls outside [a..b], the distance collapses to the nearest
  /// endpoint haversine. This is the primitive [nearestPointOnPolyline]
  /// calls for every segment.
  static double _distanceToSegmentMeters(LatLng point, LatLng a, LatLng b) {
    if (a.latitude == b.latitude && a.longitude == b.longitude) {
      return haversineMeters(point, a);
    }
    final segLen = haversineMeters(a, b);
    final along = _alongTrackMeters(point, a, b);
    if (along <= 0) return haversineMeters(point, a);
    if (along >= segLen) return haversineMeters(point, b);
    return crossTrackDistanceMeters(point, a, b);
  }

  /// Along-track distance from [segStart] to the foot of the
  /// perpendicular dropped from [point] onto the great-circle line
  /// segStart→segEnd. Can be negative (point "behind" segStart) or
  /// larger than segment length (point "past" segEnd).
  ///
  ///   dAt = acos( cos(d13 / R) / cos(dXt / R) ) * R
  /// with sign taken from the direction of travel along the segment.
  /// Reference: Movable Type Scripts — "Along-track distance".
  static double _alongTrackMeters(LatLng point, LatLng segStart, LatLng segEnd) {
    final d13 = haversineMeters(segStart, point) / _earthRadiusMeters;
    final theta13 = _toRadians(bearingDegrees(segStart, point));
    final theta12 = _toRadians(bearingDegrees(segStart, segEnd));

    final dXt = math.asin(math.sin(d13) * math.sin(theta13 - theta12));
    final cosDxt = math.cos(dXt);
    // Numerical guard — clamp the acos argument to [-1, 1] so floating
    // jitter at the endpoints doesn't blow up with NaN.
    final ratio =
        (math.cos(d13) / (cosDxt == 0 ? 1e-12 : cosDxt)).clamp(-1.0, 1.0);
    final dAt = math.acos(ratio) * _earthRadiusMeters;

    // Sign: if the relative bearing is > 90° from the segment bearing,
    // the projection is behind segStart.
    final relBearing = (theta13 - theta12).abs();
    final behind = relBearing > math.pi / 2 && relBearing < 3 * math.pi / 2;
    return behind ? -dAt : dAt;
  }
}
