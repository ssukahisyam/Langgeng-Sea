import 'dart:async';

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
///
/// AUTO-DETECT: subscribes to [Geolocator.getServiceStatusStream] so
/// that when the user toggles GPS on/off in OS settings and comes
/// back to the app, the state updates automatically — no need to
/// kill & relaunch the app.
///
/// Note: this provider is NOT auto-dispose so the service subscription
/// stays alive for the app lifetime. The previous autoDispose version
/// rebuilt on every nav change, losing the subscription.
class LocationPermissionController
    extends Notifier<LocationPermissionState> {
  StreamSubscription<ServiceStatus>? _serviceStatusSub;

  @override
  LocationPermissionState build() {
    _subscribeServiceStatus();
    ref.onDispose(() {
      _serviceStatusSub?.cancel();
      _serviceStatusSub = null;
    });
    return LocationPermissionState.unknown;
  }

  GpsService get _svc => ref.read(gpsServiceProvider);

  /// Listen to OS-level GPS service status changes. When the user
  /// toggles GPS on/off from the notification shade or Settings, this
  /// fires and we re-evaluate permission state in one go.
  void _subscribeServiceStatus() {
    _serviceStatusSub?.cancel();
    _serviceStatusSub = Geolocator.getServiceStatusStream().listen(
      (status) async {
        if (status == ServiceStatus.enabled) {
          // Service just got turned on — still need to verify
          // permission (user might have revoked it earlier).
          final perm = await _svc.checkPermission();
          state = _mapPermission(perm);
        } else {
          state = LocationPermissionState.serviceDisabled;
        }
      },
      onError: (_) {
        // Stream error is non-fatal — next explicit check() will
        // re-establish truth.
      },
    );
  }

  /// One-shot check. Screens call this on mount and on app resume.
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
    // When user comes back, either the ServiceStatusStream fires
    // (GPS toggled on) or the caller should invoke check() manually
    // via MapScreen's lifecycle observer.
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

final locationPermissionProvider =
    NotifierProvider<LocationPermissionController, LocationPermissionState>(
  LocationPermissionController.new,
);
