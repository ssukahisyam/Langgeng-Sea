/// Status of a single haul (one cycle of tebar → tarik → angkat).
enum HaulStatus {
  /// Currently being tracked — new points are being appended.
  recording,

  /// Stopped by user. Metrics are final.
  completed,
}

/// One trawl pass within a trip.
///
/// `distanceMeters`, `durationSeconds`, `avgSpeedKnots`, `avgHeadingDegrees`,
/// and `sweptAreaM2` are denormalized from the underlying track points so the
/// riwayat list can show them without recomputing.
class Haul {
  const Haul({
    required this.id,
    required this.tripId,
    required this.orderIndex,
    required this.startedAt,
    required this.status,
    required this.trawlWidthMeters,
    this.name,
    this.endedAt,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.avgSpeedKnots,
    this.avgHeadingDegrees,
    this.sweptAreaM2 = 0,
    this.notes,
    this.colorValue,
  });

  final String id;
  final String tripId;

  /// 1-based position within the parent trip (Haul #1, #2, …).
  final int orderIndex;

  /// Optional user-given name. Falls back to "Haul #N" in UI if null.
  final String? name;

  final DateTime startedAt;
  final DateTime? endedAt;
  final HaulStatus status;

  /// Trawl opening width captured at time of recording (may drift from
  /// profile settings if user changes equipment mid-trip).
  final double trawlWidthMeters;

  final double distanceMeters;
  final int durationSeconds;
  final double? avgSpeedKnots;
  final double? avgHeadingDegrees;
  final double sweptAreaM2;

  final String? notes;

  /// User-picked polyline colour stored as ARGB32. `null` = use palette
  /// fallback (AppColors.resolveHaulColor picks from the deterministic
  /// order-index palette).
  final int? colorValue;

  Duration get duration => Duration(seconds: durationSeconds);

  /// Display name: user-given or "Haul #N" fallback.
  String displayName() => name ?? 'Haul #$orderIndex';

  bool get isRecording => status == HaulStatus.recording;

  Haul copyWith({
    String? name,
    DateTime? endedAt,
    HaulStatus? status,
    double? distanceMeters,
    int? durationSeconds,
    double? avgSpeedKnots,
    double? avgHeadingDegrees,
    double? sweptAreaM2,
    String? notes,
    int? colorValue,

    /// When true, explicitly reset [colorValue] to null (fall back to
    /// the palette auto-assignment). Takes precedence over
    /// [colorValue] if both are supplied.
    bool clearColor = false,
  }) {
    return Haul(
      id: id,
      tripId: tripId,
      orderIndex: orderIndex,
      startedAt: startedAt,
      status: status ?? this.status,
      trawlWidthMeters: trawlWidthMeters,
      name: name ?? this.name,
      endedAt: endedAt ?? this.endedAt,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      avgSpeedKnots: avgSpeedKnots ?? this.avgSpeedKnots,
      avgHeadingDegrees: avgHeadingDegrees ?? this.avgHeadingDegrees,
      sweptAreaM2: sweptAreaM2 ?? this.sweptAreaM2,
      notes: notes ?? this.notes,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
    );
  }
}
