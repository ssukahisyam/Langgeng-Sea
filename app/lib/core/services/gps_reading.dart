import 'package:latlong2/latlong.dart';

/// Immutable snapshot of a GPS fix.
/// Full freezed migration happens in M2 when we introduce the data layer.
class GpsReading {
  const GpsReading({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracyMeters,
    this.altitudeMeters,
    this.speedMps,
    this.headingDegrees,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;

  /// Horizontal accuracy in meters (null if unknown).
  final double? accuracyMeters;

  /// Altitude in meters above sea level (null if unknown).
  final double? altitudeMeters;

  /// Speed over ground in meters per second.
  final double? speedMps;

  /// True heading (course over ground) in degrees 0-359.
  /// Only meaningful when speed > ~0.5 m/s — otherwise jitters.
  final double? headingDegrees;

  LatLng get latLng => LatLng(latitude, longitude);

  /// Speed in knots (1 knot = 0.51444 m/s).
  double? get speedKnots {
    final v = speedMps;
    if (v == null) return null;
    return v / 0.5144444;
  }

  /// Speed in km/h.
  double? get speedKmh {
    final v = speedMps;
    if (v == null) return null;
    return v * 3.6;
  }

  /// True when heading is considered reliable (speed above threshold).
  bool get hasReliableHeading {
    final v = speedMps;
    final h = headingDegrees;
    return h != null && v != null && v > 0.5;
  }
}

/// Quality tiers for GPS accuracy, used for UI color coding.
enum GpsAccuracyTier {
  /// Excellent: <= 10m horizontal error.
  good,

  /// Acceptable: 10-20m.
  medium,

  /// Poor: > 20m. PRD FR-03.9 says warn user.
  poor,

  /// No reading yet.
  unknown,
}

extension GpsAccuracyTierX on GpsReading? {
  GpsAccuracyTier get accuracyTier {
    final r = this;
    if (r == null) return GpsAccuracyTier.unknown;
    final a = r.accuracyMeters;
    if (a == null) return GpsAccuracyTier.unknown;
    if (a <= 10) return GpsAccuracyTier.good;
    if (a <= 20) return GpsAccuracyTier.medium;
    return GpsAccuracyTier.poor;
  }
}
