import '../domain/entities/navigation_progress.dart';
import '../domain/entities/navigation_target.dart';

/// Internal alarm state machine states. Transitions are driven from
/// [NavigationController]. Public because it ships inside
/// [NavigationActive] — tests assert against the value, no one else
/// constructs it.
enum NavigationAlarmState {
  /// Idle inside the route, nothing to alert.
  normal,

  /// Distance ≤ arrivedRadius, counting down the 3s debounce before
  /// firing the "sudah sampai" alarm.
  arrivingCountdown,

  /// "Sudah sampai" was dispatched — no further alarms until the
  /// user stops navigation manually.
  arrived,

  /// Reserved for M11b follow-track: cross-track > offRoute, counting
  /// down the 5s debounce.
  offRouteCountdown,

  /// Reserved for M11b: off-route alarm dispatched.
  offRoute,

  /// Reserved for M11b: user re-entered route radius, 5s settle
  /// before announcing back-on-route.
  returnCountdown,
}

/// Root navigation state. Sealed: either the user is idle (no target)
/// or actively navigating somewhere.
sealed class NavigationState {
  const NavigationState();
}

/// No target selected. Panel hidden, no GPS-driven math running.
class NavigationIdle extends NavigationState {
  const NavigationIdle();
}

/// User is navigating. Latest [progress] recomputed per GPS tick.
class NavigationActive extends NavigationState {
  const NavigationActive({
    required this.target,
    required this.startedAt,
    required this.progress,
    required this.alarmState,
  });

  final NavigationTarget target;
  final DateTime startedAt;

  /// Latest progress snapshot. Set to
  /// [NavigationProgress.empty] on startGoto/startFollowTrack — the
  /// next GPS tick replaces it.
  final NavigationProgress progress;

  /// Bookkeeping for debounce + anti-spam; exposed mainly for tests.
  final NavigationAlarmState alarmState;

  NavigationActive copyWith({
    NavigationTarget? target,
    DateTime? startedAt,
    NavigationProgress? progress,
    NavigationAlarmState? alarmState,
  }) {
    return NavigationActive(
      target: target ?? this.target,
      startedAt: startedAt ?? this.startedAt,
      progress: progress ?? this.progress,
      alarmState: alarmState ?? this.alarmState,
    );
  }
}
