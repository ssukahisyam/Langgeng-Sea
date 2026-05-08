import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/services/gps_service.dart';

/// Semantic state of the location permission flow.
enum LocationPermissionState {
  /// Not checked yet.
  unknown,

  /// Permission granted & location service enabled — good to go.
  ready,

  /// OS-level service disabled (user needs to toggle GPS on).
  serviceDisabled,

  /// Permission denied once. Can still ask again.
  denied,

  /// deniedForever — must open Settings.
  deniedForever,
}

/// Controls the permission + service-enabled flow.
///
/// Call [check] when the screen opens to snapshot current state,
/// then [request] from the bottom sheet to attempt acquisition.
class LocationPermissionController
    extends AutoDisposeNotifier<LocationPermissionState> {
  @override
  LocationPermissionState build() => LocationPermissionState.unknown;

  GpsService get _svc => ref.read(gpsServiceProvider);

  Future<void> check() async {
    final serviceOn = await _svc.isLocationServiceEnabled();
    if (!serviceOn) {
      state = LocationPermissionState.serviceDisabled;
      return;
    }
    final perm = await _svc.checkPermission();
    state = _mapPermission(perm);
  }

  Future<void> request() async {
    final serviceOn = await _svc.isLocationServiceEnabled();
    if (!serviceOn) {
      state = LocationPermissionState.serviceDisabled;
      return;
    }
    final perm = await _svc.requestPermission();
    state = _mapPermission(perm);
  }

  Future<void> openLocationSettings() async {
    await _svc.openLocationSettings();
    // User may come back with it toggled on — re-check on next lifecycle.
  }

  Future<void> openAppSettings() async {
    await _svc.openAppSettingsScreen();
  }

  LocationPermissionState _mapPermission(LocationPermission p) {
    switch (p) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionState.ready;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationPermissionState.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionState.deniedForever;
    }
  }
}

final locationPermissionProvider = AutoDisposeNotifierProvider<
    LocationPermissionController, LocationPermissionState>(
  LocationPermissionController.new,
);
