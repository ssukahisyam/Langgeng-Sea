import 'package:latlong2/latlong.dart';

/// A single GPS fix recorded while a haul is being tracked.
///
/// Stored densely (every N seconds) so we can reconstruct the haul's
/// polyline, compute its metrics, and export it.
class TrackPoint {
  const TrackPoint({
    required this.haulId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.speedMps,
    this.headingDegrees,
    this.accuracyMeters,
    this.altitudeMeters,
    this.id,
  });

  /// Auto-increment row id. Null for in-memory points not yet persisted.
  final int? id;

  /// FK to the owning [Haul].
  final String haulId;

  final double latitude;
  final double longitude;
  final DateTime timestamp;

  /// Speed over ground in m/s (geolocator's native unit).
  final double? speedMps;

  /// True heading 0-359° — may be null when stationary.
  final double? headingDegrees;

  /// Horizontal accuracy in meters.
  final double? accuracyMeters;

  /// Altitude (m above sea level) — rarely useful at sea but stored for
  /// completeness / future features.
  final double? altitudeMeters;

  LatLng get latLng => LatLng(latitude, longitude);
}
