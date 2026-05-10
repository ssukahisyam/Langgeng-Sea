/// Immutable per-tick progress snapshot of the active navigation.
///
/// Recomputed in NavigationController._onGpsReading; the panel and the
/// bearing-arrow overlay render purely from this value object. Fields
/// are documented so M11b follow-track can extend semantics without a
/// new class.
class NavigationProgress {
  const NavigationProgress({
    required this.distanceToTargetMeters,
    required this.bearingDegrees,
    required this.etaSeconds,
    required this.crossTrackMeters,
    required this.percentAlongPath,
  });

  /// Distance user→target in meters. For goto this is the direct
  /// haversine; for follow-track this is the haversine to the last
  /// polyline point (target = end of path).
  final double distanceToTargetMeters;

  /// Initial compass bearing from user to target, in degrees 0..360.
  final double bearingDegrees;

  /// ETA seconds (instantaneous speed) — null when speed < 0.25 m/s
  /// (≈ 0.5 knots), i.e. boat is effectively stationary.
  final double? etaSeconds;

  /// Perpendicular distance to the reference polyline. Always 0 in
  /// goto mode; non-zero only in follow-track.
  final double crossTrackMeters;

  /// Fraction of the reference polyline already traversed (0..1).
  /// Always 0 in goto mode.
  final double percentAlongPath;

  /// Placeholder used by [NavigationActive] before the first GPS tick
  /// arrives, so the panel can render without null-guarding every
  /// field.
  static const NavigationProgress empty = NavigationProgress(
    distanceToTargetMeters: 0,
    bearingDegrees: 0,
    etaSeconds: null,
    crossTrackMeters: 0,
    percentAlongPath: 0,
  );

  NavigationProgress copyWith({
    double? distanceToTargetMeters,
    double? bearingDegrees,
    Object? etaSeconds = _sentinel,
    double? crossTrackMeters,
    double? percentAlongPath,
  }) {
    return NavigationProgress(
      distanceToTargetMeters:
          distanceToTargetMeters ?? this.distanceToTargetMeters,
      bearingDegrees: bearingDegrees ?? this.bearingDegrees,
      etaSeconds: identical(etaSeconds, _sentinel)
          ? this.etaSeconds
          : etaSeconds as double?,
      crossTrackMeters: crossTrackMeters ?? this.crossTrackMeters,
      percentAlongPath: percentAlongPath ?? this.percentAlongPath,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NavigationProgress &&
        other.distanceToTargetMeters == distanceToTargetMeters &&
        other.bearingDegrees == bearingDegrees &&
        other.etaSeconds == etaSeconds &&
        other.crossTrackMeters == crossTrackMeters &&
        other.percentAlongPath == percentAlongPath;
  }

  @override
  int get hashCode => Object.hash(
        distanceToTargetMeters,
        bearingDegrees,
        etaSeconds,
        crossTrackMeters,
        percentAlongPath,
      );
}

/// Sentinel to let copyWith(etaSeconds: null) clear the field.
const Object _sentinel = Object();
