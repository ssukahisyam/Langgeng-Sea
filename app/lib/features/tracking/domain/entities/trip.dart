enum TripStatus { active, completed }

/// A single day at sea — a container for hauls.
///
/// MVP assumption (per PRD §2.2): trips are daily. We still expose
/// [startedAt] / [endedAt] instead of just a date so long trips work later.
class Trip {
  const Trip({
    required this.id,
    required this.startedAt,
    required this.status,
    this.name,
    this.endedAt,
    this.homePort,
    this.notes,
    this.colorValue,
  });

  final String id;
  final String? name;
  final DateTime startedAt;
  final DateTime? endedAt;
  final TripStatus status;
  final String? homePort;
  final String? notes;

  /// User-picked polyline colour for this trip, stored as ARGB32.
  /// `null` = use palette fallback (polyline renderer picks from the
  /// per-order haul palette via [AppColors.resolveHaulColor]). Mirrors
  /// the shape of [Haul.colorValue] so both Trip and Haul tracks can
  /// be recoloured independently. Persisted in schema v7.
  final int? colorValue;

  bool get isActive => status == TripStatus.active;

  Trip copyWith({
    String? name,
    DateTime? endedAt,
    TripStatus? status,
    String? homePort,
    String? notes,
    int? colorValue,

    /// When true, explicitly reset [colorValue] to null (fall back to
    /// the palette auto-assignment). Takes precedence over
    /// [colorValue] if both are supplied.
    bool clearColor = false,
  }) =>
      Trip(
        id: id,
        startedAt: startedAt,
        status: status ?? this.status,
        name: name ?? this.name,
        endedAt: endedAt ?? this.endedAt,
        homePort: homePort ?? this.homePort,
        notes: notes ?? this.notes,
        colorValue: clearColor ? null : (colorValue ?? this.colorValue),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Trip &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          startedAt == other.startedAt &&
          endedAt == other.endedAt &&
          status == other.status &&
          homePort == other.homePort &&
          notes == other.notes &&
          colorValue == other.colorValue;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        startedAt,
        endedAt,
        status,
        homePort,
        notes,
        colorValue,
      );
}
