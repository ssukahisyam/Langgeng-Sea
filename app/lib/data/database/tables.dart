import 'package:drift/drift.dart';

/// Container trip — one day at sea. Holds zero or more hauls.
@DataClassName('TripRow')
class Trips extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// 'active' | 'completed'. Mapped from [TripStatus] in repositories.
  TextColumn get status => text().withLength(min: 1, max: 16)();

  TextColumn get homePort => text().nullable()();
  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A single trawl pass. Belongs to one [Trips] row.
@DataClassName('HaulRow')
class Hauls extends Table {
  TextColumn get id => text()();

  TextColumn get tripId => text().references(Trips, #id,
      onUpdate: KeyAction.cascade, onDelete: KeyAction.cascade)();

  TextColumn get name => text().nullable()();

  /// 1-based index within the trip ("Haul #1", "#2", …).
  IntColumn get orderIndex => integer()();

  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// 'recording' | 'completed'.
  TextColumn get status => text().withLength(min: 1, max: 16)();

  /// Captured at start so later profile edits don't rewrite history.
  RealColumn get trawlWidthMeters => real().withDefault(const Constant(20.0))();

  // Denormalized metrics. Updated on stop so list views don't re-aggregate.
  RealColumn get distanceMeters =>
      real().withDefault(const Constant(0))();
  IntColumn get durationSeconds =>
      integer().withDefault(const Constant(0))();
  RealColumn get avgSpeedKnots => real().nullable()();
  RealColumn get avgHeadingDegrees => real().nullable()();
  RealColumn get sweptAreaM2 => real().withDefault(const Constant(0))();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Raw GPS fix belonging to one haul. High-write-volume table — we index by
/// `(haul_id, timestamp)` for fast haul polyline replays.
@DataClassName('TrackPointRow')
class TrackPoints extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get haulId => text().references(Hauls, #id,
      onUpdate: KeyAction.cascade, onDelete: KeyAction.cascade)();

  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  DateTimeColumn get timestamp => dateTime()();

  RealColumn get speedMps => real().nullable()();
  RealColumn get headingDegrees => real().nullable()();
  RealColumn get accuracyMeters => real().nullable()();
  RealColumn get altitudeMeters => real().nullable()();
}

/// Metadata for a downloaded (or in-progress) offline map region.
///
/// FMTC owns the actual tile bytes in its own store; this table just
/// lets us render the user's "Peta Offline" list without walking the
/// tile cache. Mirrors the domain [OfflineRegion] entity 1-to-1.
@DataClassName('OfflineRegionRow')
class OfflineRegions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  // Bounds stored as four reals so we don't have to serialize/parse.
  RealColumn get north => real()();
  RealColumn get south => real()();
  RealColumn get east => real()();
  RealColumn get west => real()();

  IntColumn get minZoom => integer()();
  IntColumn get maxZoom => integer()();

  /// 'pending' | 'downloading' | 'completed' | 'failed'.
  TextColumn get status => text().withLength(min: 1, max: 16)();

  IntColumn get estimatedTileCount =>
      integer().withDefault(const Constant(0))();
  IntColumn get actualTileCount =>
      integer().withDefault(const Constant(0))();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();

  TextColumn get lastError => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}


/// Log book entry — satu catatan hasil tangkap, cuaca, BBM, dll.
/// Bisa per trip atau per haul (ditentukan oleh field scope).
@DataClassName('LogBookEntryRow')
class LogBookEntries extends Table {
  TextColumn get id => text()();
  TextColumn get scope => text()();
  TextColumn get tripId => text().nullable()();
  TextColumn get haulId => text().nullable()();
  TextColumn get weather => text().nullable()();
  TextColumn get wave => text().nullable()();
  RealColumn get fuelLiters => real().nullable()();
  IntColumn get costRupiah => integer().nullable()();
  IntColumn get crewCount => integer().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Item tangkapan dalam satu log book entry.
@DataClassName('CatchItemRow')
class CatchItems extends Table {
  TextColumn get id => text()();

  TextColumn get logBookEntryId => text().references(LogBookEntries, #id,
      onUpdate: KeyAction.cascade, onDelete: KeyAction.cascade)();

  TextColumn get species => text()();
  RealColumn get weightKg => real().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Marker kustom di peta — spot produktif, karang, pelabuhan, dll.
@DataClassName('MarkerRow')
class Markers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get category => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
