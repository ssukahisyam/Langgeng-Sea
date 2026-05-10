/// Threshold + debounce constants for navigation alarm state machine.
///
/// Kept in one place so post-MVP tuning based on real-device logs is a
/// single-file edit. Values rationalised in m11-notes.md — threshold
/// table.
class NavigationConstants {
  NavigationConstants._();

  /// Distance in meters at which a go-to target is considered reached.
  /// Tuned for consumer-GPS accuracy (3-5m nominal + jitter).
  static const double arrivedRadiusMeters = 15.0;

  /// Distance in meters at which the user is considered off the
  /// reference polyline for follow-track. Exercised in M11b; declared
  /// here already so both PRs share constants.
  static const double offRouteMeters = 30.0;

  /// Debounce duration before dispatching the "arrived" alarm.
  /// Prevents spam when the user hovers around the arrival radius.
  static const Duration arrivedDebounce = Duration(seconds: 3);

  /// Debounce duration for off-route and back-on-route transitions
  /// (follow-track, M11b).
  static const Duration offRouteDebounce = Duration(seconds: 5);

  /// Minimum speed to publish a non-null ETA. Below this the boat is
  /// effectively stationary and ETA is meaningless (would divide by
  /// zero / explode to hours).
  ///
  /// 0.25 m/s ≈ 0.5 knots ≈ typical boat-at-anchor noise floor.
  static const double minSpeedForEtaMps = 0.25;
}
