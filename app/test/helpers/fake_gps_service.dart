import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:styra/core/services/gps_reading.dart';
import 'package:styra/core/services/gps_service.dart';

/// In-memory GpsService for widget and unit tests.
/// Lets tests drive GPS state without hitting the OS.
class FakeGpsService implements GpsService {
  FakeGpsService({
    this.serviceEnabled = true,
    this.permission = LocationPermission.always,
  });

  bool serviceEnabled;
  LocationPermission permission;

  final StreamController<GpsReading> _controller =
      StreamController<GpsReading>.broadcast();

  GpsReading? _lastReading;

  /// Push a synthetic reading to all listeners.
  void emit(GpsReading reading) {
    _lastReading = reading;
    _controller.add(reading);
  }

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<GpsReading> getCurrentReading() async {
    if (_lastReading == null) {
      throw StateError('No reading emitted yet');
    }
    return _lastReading!;
  }

  /// Mirrors [GeolocatorGpsService.getLastKnownReading]: returns the
  /// most recently emitted reading (test equivalent of the OS cache),
  /// or null on a fresh fake that hasn't emitted yet. Tests that want
  /// to exercise the "no cached fix on first install" branch just
  /// assert against the freshly-constructed fake.
  @override
  Future<GpsReading?> getLastKnownReading() async => _lastReading;

  @override
  Stream<GpsReading> watchPosition({double distanceFilterMeters = 2}) =>
      _controller.stream;

  @override
  Stream<ServiceStatus> watchServiceStatus() =>
      _serviceStatusController.stream;

  /// Test hook: simulate the OS GPS toggle flipping on/off.
  void emitServiceStatus(ServiceStatus status) {
    _serviceStatusController.add(status);
  }

  final StreamController<ServiceStatus> _serviceStatusController =
      StreamController<ServiceStatus>.broadcast();

  @override
  Future<bool> openAppSettingsScreen() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  void dispose() {
    _controller.close();
    _serviceStatusController.close();
  }
}
