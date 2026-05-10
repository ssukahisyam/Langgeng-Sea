import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/gps_reading.dart';
import '../../../core/settings/application/app_settings_provider.dart';
import '../../../core/settings/domain/entities/app_settings.dart';
import '../../../core/utils/geo_calculator.dart';
import '../../map/application/current_reading_provider.dart';
import '../data/navigation_alert_service.dart';
import '../domain/entities/navigation_progress.dart';
import '../domain/entities/navigation_target.dart';
import 'navigation_constants.dart';
import 'navigation_state.dart';

/// Orchestrates goto (M11a) and follow-track (M11b) navigation.
///
/// - Subscribes to [currentReadingProvider] while a target is active.
/// - On each reading recomputes a [NavigationProgress] snapshot.
/// - Runs the alarm state machine in [navigation_state.dart]:
///     * normal → arrivingCountdown (start 3s timer)
///     * arrivingCountdown → arrived (fires "sudah sampai" alarm)
///     * arrived is sticky until the user hits Stop — anti-spam.
/// - Off-route / back-on-route transitions are stubbed with TODOs
///   so M11b can wire them without re-plumbing the dispatch layer.
///
/// Navigation intentionally does NOT survive app restart: the state
/// is pure in-memory and resets to [NavigationIdle] on boot. Users
/// typically start navigation after they are already at sea, and
/// resuming a stale "pandu ke sini" from a previous session tended
/// to confuse testers in the prototype.
class NavigationController extends Notifier<NavigationState> {
  /// GPS subscription, nulled on stop / idle.
  ProviderSubscription<AsyncValue<GpsReading>>? _gpsSub;

  /// Debounce timer for alarm transitions. Reset on every transition
  /// so flip-flopping around the radius cancels an in-flight countdown
  /// (no spam on borderline cases).
  Timer? _debounce;

  @override
  NavigationState build() {
    ref.onDispose(_cleanup);
    return const NavigationIdle();
  }

  // =========================================================================
  // Public API — callers: map_screen long-press, marker_info_sheet, etc.
  // =========================================================================

  /// Start go-to navigation. Idempotent: starting a second target
  /// replaces the first (rare in practice — user would have to hit
  /// two long-presses back to back).
  void startGoto(GotoTarget target) {
    _debounce?.cancel();
    _debounce = null;
    state = NavigationActive(
      target: target,
      startedAt: DateTime.now(),
      progress: NavigationProgress.empty,
      alarmState: NavigationAlarmState.normal,
    );
    _subscribeGps();
  }

  /// Stub for M11b. Declared here so MapScreen wiring doesn't need a
  /// second PR to hook up follow-track; the branch in `_onReading`
  /// that actually handles follow-track lands in M11b.
  void startFollowTrack(FollowTrackTarget target) {
    _debounce?.cancel();
    _debounce = null;
    state = NavigationActive(
      target: target,
      startedAt: DateTime.now(),
      progress: NavigationProgress.empty,
      alarmState: NavigationAlarmState.normal,
    );
    _subscribeGps();
  }

  /// Stop navigation. Clears timers, cancels GPS subscription,
  /// resets to idle.
  void stop() {
    _cleanup();
    state = const NavigationIdle();
  }

  // =========================================================================
  // GPS subscription plumbing
  // =========================================================================

  void _subscribeGps() {
    _gpsSub?.close();
    _gpsSub = ref.listen<AsyncValue<GpsReading>>(
      currentReadingProvider,
      (_, next) {
        next.whenData(_onReading);
      },
      fireImmediately: true,
    );
  }

  void _cleanup() {
    _debounce?.cancel();
    _debounce = null;
    _gpsSub?.close();
    _gpsSub = null;
  }

  // =========================================================================
  // Per-tick progress + alarm machine
  // =========================================================================

  void _onReading(GpsReading reading) {
    final s = state;
    if (s is! NavigationActive) return;

    final progress = _computeProgress(s.target, reading);
    final nextAlarm = _advanceAlarmState(s.alarmState, s.target, progress);

    state = s.copyWith(progress: progress, alarmState: nextAlarm);

    if (nextAlarm != s.alarmState) {
      _onAlarmStateChanged(s.alarmState, nextAlarm, s.target, progress);
    }
  }

  NavigationProgress _computeProgress(
    NavigationTarget target,
    GpsReading reading,
  ) {
    final userPos = reading.latLng;
    switch (target) {
      case GotoTarget(position: final pos):
        final distance = GeoCalculator.haversineMeters(userPos, pos);
        return NavigationProgress(
          distanceToTargetMeters: distance,
          bearingDegrees: GeoCalculator.bearingDegrees(userPos, pos),
          etaSeconds: _etaSeconds(distance, reading.speedMps),
          crossTrackMeters: 0,
          percentAlongPath: 0,
        );
      case FollowTrackTarget():
        // M11b wires the follow-track math here. For M11a we still
        // compute something sensible so the panel renders: distance
        // and bearing to the last polyline point.
        if (target.pathPoints.isEmpty) {
          return NavigationProgress.empty;
        }
        final end = target.pathPoints.last;
        final distance = GeoCalculator.haversineMeters(userPos, end);
        return NavigationProgress(
          distanceToTargetMeters: distance,
          bearingDegrees: GeoCalculator.bearingDegrees(userPos, end),
          etaSeconds: _etaSeconds(distance, reading.speedMps),
          crossTrackMeters: 0,
          percentAlongPath: 0,
        );
    }
  }

  double? _etaSeconds(double distanceMeters, double? speedMps) {
    if (speedMps == null ||
        speedMps < NavigationConstants.minSpeedForEtaMps) {
      return null;
    }
    return distanceMeters / speedMps;
  }

  /// Drives the alarm state machine. M11a only implements the goto
  /// branch (normal → arrivingCountdown → arrived). Off-route
  /// transitions land in M11b.
  NavigationAlarmState _advanceAlarmState(
    NavigationAlarmState current,
    NavigationTarget target,
    NavigationProgress progress,
  ) {
    if (target is GotoTarget) {
      final near = progress.distanceToTargetMeters <=
          NavigationConstants.arrivedRadiusMeters;

      switch (current) {
        case NavigationAlarmState.normal:
          if (near) {
            _startArrivedCountdown();
            return NavigationAlarmState.arrivingCountdown;
          }
          return NavigationAlarmState.normal;

        case NavigationAlarmState.arrivingCountdown:
          if (!near) {
            _debounce?.cancel();
            _debounce = null;
            return NavigationAlarmState.normal;
          }
          return NavigationAlarmState.arrivingCountdown;

        case NavigationAlarmState.arrived:
          // Sticky. User must Stop to leave.
          return NavigationAlarmState.arrived;

        default:
          // Off-route branches are follow-track only; collapse to
          // normal if we somehow get here on a GotoTarget.
          return NavigationAlarmState.normal;
      }
    }
    // FollowTrackTarget branch — M11b wires full state machine. M11a
    // keeps it in `normal` so no spurious alarms fire during the
    // transitional period.
    return NavigationAlarmState.normal;
  }

  /// Schedule the "arrived" promotion after the debounce window.
  void _startArrivedCountdown() {
    _debounce?.cancel();
    _debounce = Timer(NavigationConstants.arrivedDebounce, () {
      final s = state;
      if (s is! NavigationActive) return;
      if (s.alarmState != NavigationAlarmState.arrivingCountdown) return;
      state = s.copyWith(alarmState: NavigationAlarmState.arrived);
      _dispatchArrived(s.target);
    });
  }

  // =========================================================================
  // Alarm dispatch
  // =========================================================================

  void _onAlarmStateChanged(
    NavigationAlarmState prev,
    NavigationAlarmState next,
    NavigationTarget target,
    NavigationProgress progress,
  ) {
    // Entry transitions driven by the state machine itself call their
    // own dispatch (_startArrivedCountdown → timer → _dispatchArrived).
    // We keep this hook to notify on the exit side once M11b adds
    // off-route → back-on-route. No-op for M11a.
  }

  Future<void> _dispatchArrived(NavigationTarget target) async {
    final settings = _currentSettings();
    final alertSvc = ref.read(navigationAlertServiceProvider);
    await alertSvc.notifyArrived(
      label: target.displayLabel,
      sound: settings.alarmSoundEnabled,
      vibrate: settings.alarmVibrateEnabled,
    );
  }

  AppSettings _currentSettings() {
    final async = ref.read(appSettingsProvider);
    return async.asData?.value ?? AppSettings.defaults;
  }
}

final navigationControllerProvider =
    NotifierProvider<NavigationController, NavigationState>(
  NavigationController.new,
);
