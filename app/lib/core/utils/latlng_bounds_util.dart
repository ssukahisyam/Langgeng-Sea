import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Helpers for computing map camera targets from a set of points.
class LatLngBoundsUtil {
  LatLngBoundsUtil._();

  /// Build tight bounds around [points], inflated by [paddingDegrees] so
  /// markers don't sit flush against the map edges.
  ///
  /// Returns `null` when the point set is empty — callers should then
  /// fall back to a sensible default camera.
  static LatLngBounds? fromPoints(
    Iterable<LatLng> points, {
    double paddingDegrees = 0.005,
  }) {
    final iterator = points.iterator;
    if (!iterator.moveNext()) return null;

    var minLat = iterator.current.latitude;
    var maxLat = minLat;
    var minLng = iterator.current.longitude;
    var maxLng = minLng;

    while (iterator.moveNext()) {
      final p = iterator.current;
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    // Guard against zero-size bounds (single point or colinear samples).
    if (maxLat - minLat < paddingDegrees * 2) {
      minLat -= paddingDegrees;
      maxLat += paddingDegrees;
    }
    if (maxLng - minLng < paddingDegrees * 2) {
      minLng -= paddingDegrees;
      maxLng += paddingDegrees;
    }

    return LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
  }
}
