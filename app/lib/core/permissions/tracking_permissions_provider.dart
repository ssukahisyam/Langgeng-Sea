import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../features/tracking/application/tracking_permission_flow.dart';
import '../observability/logger.dart';
import '../services/gps_service.dart';

/// Snapshot dari tiga permission yang relevan untuk tracking di
/// Langgeng Sea.
///
/// PR #41 — sebelumnya status permission dicek lokal di tiap tile
/// dengan `WidgetsBindingObserver` masing-masing. Itu menyebabkan
/// inkonsistensi (notif tidak punya tile sama sekali) dan duplicate
/// observer. Sekarang ada satu provider yang reactive update semua,
/// digunakan oleh:
/// - `DeviceStatusCard` (Settings — toggle UI per permission)
/// - `PermissionChecklistSheet` (gating saat tap MULAI)
/// - `TrackingStatusChip` (indikator BG di top bar saat tracking)
class TrackingPermissionsState {
  const TrackingPermissionsState({
    required this.location,
    required this.notification,
    required this.battery,
  });

  /// `ACCESS_FINE_LOCATION` status. Wajib granted untuk tracking
  /// jalan sama sekali — kalau denied, app harusnya tidak bisa start.
  final PermissionStatus location;

  /// `POST_NOTIFICATIONS` status (Android 13+). Wajib untuk
  /// foreground service notification. Di Android <13 selalu return
  /// `granted`.
  final PermissionStatus notification;

  /// `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` status. Tidak wajib tapi
  /// sangat dianjurkan supaya tracking jalan stabil saat layar mati.
  /// Di iOS / non-Android selalu `denied` (tapi tile self-hide di
  /// platform tsb).
  final PermissionStatus battery;

  /// Semua permission wajib granted (location + notification).
  /// Battery exemption tidak masuk required check supaya app tetap
  /// bisa start meski user tolak — degraded mode.
  bool get allRequired => location.isGranted && notification.isGranted;

  /// Semua permission granted termasuk battery exemption — tracking
  /// optimal saat layar mati.
  bool get allOptimal => allRequired && battery.isGranted;

  /// Loading sentinel — semua status `denied` saat provider belum
  /// pernah refresh. Caller bisa pakai ini untuk hide UI sampai
  /// status realistis.
  static const TrackingPermissionsState loading = TrackingPermissionsState(
    location: PermissionStatus.denied,
    notification: PermissionStatus.denied,
    battery: PermissionStatus.denied,
  );

  TrackingPermissionsState copyWith({
    PermissionStatus? location,
    PermissionStatus? notification,
    PermissionStatus? battery,
  }) =>
      TrackingPermissionsState(
        location: location ?? this.location,
        notification: notification ?? this.notification,
        battery: battery ?? this.battery,
      );
}

/// Notifier yang mengelola status 3 permission.
///
/// Refresh:
/// - Otomatis di [build] saat provider pertama dibaca.
/// - Otomatis saat `AppLifecycleState.resumed` (user balik dari
///   Settings sistem) — observer di-pasang di [build] dan dibersihkan
///   lewat `ref.onDispose`.
/// - Manual lewat [refresh] kalau caller tahu status berubah (mis.
///   habis call request).
class TrackingPermissionsNotifier extends Notifier<TrackingPermissionsState> {
  _LifecycleListener? _listener;

  @override
  TrackingPermissionsState build() {
    _listener = _LifecycleListener(refresh);
    WidgetsBinding.instance.addObserver(_listener!);
    ref.onDispose(() {
      if (_listener != null) {
        WidgetsBinding.instance.removeObserver(_listener!);
        _listener = null;
      }
    });

    // Async initial fetch — state mulai di loading sentinel lalu
    // di-update setelah platform channels balik.
    Future.microtask(refresh);
    return TrackingPermissionsState.loading;
  }

  /// Re-cek semua permission status. Idempotent.
  Future<void> refresh() async {
    try {
      final results = await Future.wait([
        Permission.location.status,
        Permission.notification.status,
        Platform.isAndroid
            ? Permission.ignoreBatteryOptimizations.status
            : Future.value(PermissionStatus.denied),
      ]);
      state = TrackingPermissionsState(
        location: results[0],
        notification: results[1],
        battery: results[2],
      );
    } catch (e) {
      Logger.instance.warn(
        'permission.refresh_failed',
        {'error': e.toString()},
      );
    }
  }

  /// Request `ACCESS_FINE_LOCATION`. Saat user pernah tolak permanent,
  /// ini akan no-op — caller harus arahkan ke `openAppSettings()`.
  Future<PermissionStatus> requestLocation() async {
    final status = await Permission.location.request().timeout(
          const Duration(seconds: 12),
          onTimeout: () => PermissionStatus.denied,
        );
    state = state.copyWith(location: status);
    return status;
  }

  /// Request `POST_NOTIFICATIONS` (Android 13+).
  Future<PermissionStatus> requestNotification() async {
    final status = await Permission.notification.request().timeout(
          const Duration(seconds: 12),
          onTimeout: () => PermissionStatus.denied,
        );
    state = state.copyWith(notification: status);
    return status;
  }

  /// Request `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (Android only).
  /// Di iOS / non-Android no-op dengan return denied.
  Future<PermissionStatus> requestBattery() async {
    if (!Platform.isAndroid) return PermissionStatus.denied;
    final status =
        await Permission.ignoreBatteryOptimizations.request().timeout(
              const Duration(seconds: 12),
              onTimeout: () => PermissionStatus.denied,
            );
    state = state.copyWith(battery: status);
    return status;
  }

  /// Buka Settings sistem untuk permission yang `permanentlyDenied`.
  /// User harus toggle manual dari sana — OS tidak izinkan request
  /// dialog lagi setelah permanent deny.
  Future<bool> openSystemSettings() => openAppSettings();
}

final trackingPermissionsProvider =
    NotifierProvider<TrackingPermissionsNotifier, TrackingPermissionsState>(
  TrackingPermissionsNotifier.new,
);

/// Convenience: gate untuk start tracking. Jalankan request flow
/// kalau ada permission yang missing, return final state.
///
/// Wraps existing [ensureTrackingPermissions] supaya kita tidak
/// kehilangan logic SDK-aware (background_location di API 30+ buka
/// settings, bukan dialog).
final trackingPermissionGateProvider = Provider<TrackingPermissionGate>((ref) {
  return TrackingPermissionGate(
    gps: ref.read(gpsServiceProvider),
    handler: RealPermissionHandler(),
    refreshState: () =>
        ref.read(trackingPermissionsProvider.notifier).refresh(),
  );
});

class TrackingPermissionGate {
  TrackingPermissionGate({
    required this.gps,
    required this.handler,
    required this.refreshState,
  });

  final GpsService gps;
  final PermissionHandler handler;
  final Future<void> Function() refreshState;

  /// Run pre-flight permission check + request flow. Caller di UI
  /// gunakan return value-nya untuk decide apakah lanjut start
  /// tracking atau tampilkan banner error.
  Future<TrackingPermissionResult> ensure({
    required void Function(String explanationId) showRationale,
  }) async {
    final result = await ensureTrackingPermissions(
      gps: gps,
      handler: handler,
      showRationale: showRationale,
    );
    // Sync state provider supaya UI lain ikut update.
    await refreshState();
    return result;
  }
}

/// Lifecycle observer yang trigger callback saat app resume.
class _LifecycleListener extends WidgetsBindingObserver {
  _LifecycleListener(this._onResume);

  final VoidCallback _onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onResume();
    }
  }
}
