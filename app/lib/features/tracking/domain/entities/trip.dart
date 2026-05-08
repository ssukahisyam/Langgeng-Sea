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
  });

  final String id;
  final String? name;
  final DateTime startedAt;
  final DateTime? endedAt;
  final TripStatus status;
  final String? homePort;
  final String? notes;

  bool get isActive => status == TripStatus.active;

  Trip copyWith({
    String? name,
    DateTime? endedAt,
    TripStatus? status,
    String? homePort,
    String? notes,
  }) =>
      Trip(
        id: id,
        startedAt: startedAt,
        status: status ?? this.status,
        name: name ?? this.name,
        endedAt: endedAt ?? this.endedAt,
        homePort: homePort ?? this.homePort,
        notes: notes ?? this.notes,
      );
}
