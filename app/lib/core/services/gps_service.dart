import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'gps_reading.dart';

/// Status of the device's location subsystem.
enum GpsStatus {
  /// Service disabled in OS settings.
  serviceDisabled,

  /// Permission denied (either once or forever).
  permissionDenied,

  /// Permission deniedForever — can only be recovered via Settings.
  permissionDeniedForever,

  /// All good — stream is emitting.
  ready,

  /// Haven't checked yet.
  unknown,
}

/// Abstraction over geolocator so tests can mock GPS.
abstract class GpsService {
  /// Request the permissions required for tracking.
  /// Returns the resulting [LocationPermission].
  Future<LocationPermission> requestPermission();

  /// Check if OS location services are on.
  Future<bool> isLocationServiceEnabled();

  /// Get current permission status without requesting.
  Future<LocationPermission> checkPermission();

  /// One-shot fetch of the current position (for "center on me" etc.).
  /// Throws if permission not granted or service disabled.
  Future<GpsReading> getCurrentReading();

  /// Continuous stream of GPS readings.
  ///
  /// The default [distanceFilterMeters] of 2m is tuned for trawl
  /// tracking: fine enough to capture slow manoeuvres in port, coarse
  /// enough not to drown metric aggregation in stationary-boat jitter.
  Stream<GpsReading> watchPosition({
    double distanceFilterMeters = 2,
  });

  /// Broadcast stream of OS location-service on/off transitions. Used
  /// by the map screen to auto-dismiss the "activate GPS" sheet when
  /// the user toggles the service from system Settings and comes back.
  Stream<ServiceStatus> watchServiceStatus();

  /// Opens the device's location settings screen.
  Future<bool> openLocationSettings();

  /// Opens the app's own permission settings screen.
  Future<bool> openAppSettingsScreen();
}

/// Default implementation backed by the `geolocator` package.
class GeolocatorGpsService implements GpsService {
  @override
  Future<LocationPermission> requestPermission() {
    return Geolocator.requestPermission();
  }

  @override
  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  @override
  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<GpsReading> getCurrentReading() async {
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 30),
      ),
    );
    return _toReading(pos);
  }

  @override
  Stream<GpsReading> watchPosition({double distanceFilterMeters = 2}) {
    // LocationAccuracy.high (not bestForNavigation) keeps the radio
    // duty cycle reasonable — we saw ~40% battery/hr with
    // bestForNavigation on a Redmi Note 10 Pro, vs ~15% on high. The
    // accuracy difference is negligible for trawl-speed movement.
    //
    // distanceFilter = 2m drops stationary jitter without losing
    // responsiveness when the boat starts moving. The tracking
    // controller additionally gates readings whose reported accuracy
    // is >50m before folding them into live metrics.
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters.toInt(),
      ),
    ).map(_toReading);
  }

  @override
  Stream<ServiceStatus> watchServiceStatus() {
    return Geolocator.getServiceStatusStream();
  }

  @override
  Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  @override
  Future<bool> openAppSettingsScreen() {
    return Geolocator.openAppSettings();
  }

  GpsReading _toReading(Position p) {
    // Geolocator marks invalid fields with sentinel values; treat them
    // as null so downstream code can do nullable math safely.
    double? nullIfInvalid(double v) => v.isFinite && v != 0.0 ? v : null;
    return GpsReading(
      latitude: p.latitude,
      longitude: p.longitude,
      timestamp: p.timestamp,
      accuracyMeters: p.accuracy.isFinite && p.accuracy > 0 ? p.accuracy : null,
      altitudeMeters: p.altitude.isFinite ? p.altitude : null,
      speedMps: p.speed.isFinite && p.speed >= 0 ? p.speed : null,
      headingDegrees: nullIfInvalid(p.heading),
    );
  }
}

/// Riverpod provider so the impl can be swapped in tests.
final gpsServiceProvider = Provider<GpsService>((ref) {
  return GeolocatorGpsService();
});

/// Live stream of GPS readings. Null while waiting for first fix.
final currentReadingProvider = StreamProvider<GpsReading>((ref) {
  final svc = ref.watch(gpsServiceProvider);
  return svc.watchPosition();
});
