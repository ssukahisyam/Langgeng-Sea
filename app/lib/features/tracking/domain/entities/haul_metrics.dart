/// Snapshot of live or final metrics for a haul.
///
/// Live variant is re-emitted by the tracking controller during recording;
/// final variant is persisted to the [Haul] row on stop.
class HaulMetrics {
  const HaulMetrics({
    required this.distanceMeters,
    required this.duration,
    this.avgSpeedKnots,
    this.currentSpeedKnots,
    this.avgHeadingDegrees,
    this.currentHeadingDegrees,
    this.sweptAreaM2 = 0,
    this.pointCount = 0,
  });

  static const empty = HaulMetrics(
    distanceMeters: 0,
    duration: Duration.zero,
  );

  final double distanceMeters;
  final Duration duration;

  /// Averages (used in haul summary).
  final double? avgSpeedKnots;
  final double? avgHeadingDegrees;

  /// Instantaneous values (used in live stats panel).
  final double? currentSpeedKnots;
  final double? currentHeadingDegrees;

  final double sweptAreaM2;
  final int pointCount;

  HaulMetrics copyWith({
    double? distanceMeters,
    Duration? duration,
    double? avgSpeedKnots,
    double? currentSpeedKnots,
    double? avgHeadingDegrees,
    double? currentHeadingDegrees,
    double? sweptAreaM2,
    int? pointCount,
  }) =>
      HaulMetrics(
        distanceMeters: distanceMeters ?? this.distanceMeters,
        duration: duration ?? this.duration,
        avgSpeedKnots: avgSpeedKnots ?? this.avgSpeedKnots,
        currentSpeedKnots: currentSpeedKnots ?? this.currentSpeedKnots,
        avgHeadingDegrees: avgHeadingDegrees ?? this.avgHeadingDegrees,
        currentHeadingDegrees:
            currentHeadingDegrees ?? this.currentHeadingDegrees,
        sweptAreaM2: sweptAreaM2 ?? this.sweptAreaM2,
        pointCount: pointCount ?? this.pointCount,
      );
}
