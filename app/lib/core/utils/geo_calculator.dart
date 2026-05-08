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
}
