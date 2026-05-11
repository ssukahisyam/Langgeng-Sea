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

  /// Optional user-picked color for this trip's polyline in history &
  /// map overlays. Stored as an ARGB32 int. `null` = "use palette
  /// fallback" (resolveHaulColor picks per haul from
  /// [AppColors.haulColors] by order index). Mirrors
  /// [Hauls.colorValue]. Added in schema v7.
  IntColumn get colorValue => integer().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A single trawl pass. Belongs to one [Trips] row.
@DataClassName('HaulRow')
class Hauls extends Table {
  TextColumn get id => text()();

  TextColumn get tripId => text().references(
        Trips,
        #id,
        onUpdate: KeyAction.cascade,
        onDelete: KeyAction.cascade,
      )();

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
  RealColumn get distanceMeters => real().withDefault(const Constant(0))();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  RealColumn get avgSpeedKnots => real().nullable()();
  RealColumn get avgHeadingDegrees => real().nullable()();
  RealColumn get sweptAreaM2 => real().withDefault(const Constant(0))();

  /// Optional user-picked color for this haul's polyline in history &
  /// map overlays. Stored as an ARGB32 int. `null` = "use palette
  /// fallback" (resolveHaulColor picks from [AppColors.haulColors] by
  /// order index). Added in schema v5.
  IntColumn get colorValue => integer().nullable()();

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

  TextColumn get haulId => text().references(
        Hauls,
        #id,
        onUpdate: KeyAction.cascade,
        onDelete: KeyAction.cascade,
      )();

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
  IntColumn get actualTileCount => integer().withDefault(const Constant(0))();
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

  TextColumn get logBookEntryId => text().references(
        LogBookEntries,
        #id,
        onUpdate: KeyAction.cascade,
        onDelete: KeyAction.cascade,
      )();

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

/// Profil pengguna — single-row table (MVP hanya mendukung satu profil).
///
/// Ditulis oleh onboarding (M8) dan bisa diedit dari layar Pengaturan.
/// `id` di-fix ke 1 agar ada invariant "paling banyak satu baris".
@DataClassName('UserProfileRow')
class UserProfiles extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get vesselName => text()();
  RealColumn get vesselGt => real().nullable()();
  TextColumn get homePort => text().nullable()();
  RealColumn get trawlWidthMeters => real().withDefault(const Constant(20.0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Preferensi aplikasi per-device (bukan per-user). Mirip pola
/// [UserProfiles]: baris tunggal dengan `id` dipatok ke 1, sehingga
/// tidak ada null-handling di layer repository. Ditambahkan di schema
/// v6 (M11) untuk menampung toggle alarm navigasi (TTS + getar).
///
/// Domain separation: [UserProfiles] menjawab "siapa user-nya",
/// domain entity `AppSettings` menjawab "preferensi aplikasi di
/// device ini". Kalau multi-user datang di v2, [UserProfiles] akan
/// per-user tapi app_settings tetap per-device.
///
/// Class di-rename `AppSettingsTable` (dengan [tableName] dipatok ke
/// `app_settings`) supaya tidak bentrok nama dengan domain entity
/// `core/settings/domain/entities/app_settings.dart` yang dipakai
/// oleh repo + UI. SQL table name tetap `app_settings`, generated
/// row class tetap `AppSettingsRow`, generated getter DB jadi
/// `appSettingsTable`, companion jadi `AppSettingsTableCompanion`.
@DataClassName('AppSettingsRow')
class AppSettingsTable extends Table {
  IntColumn get id => integer()();
  BoolColumn get alarmSoundEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get alarmVibrateEnabled =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  // Pin SQL table name so the migration's raw INSERT / the migration
  // test's sqlite_master lookup / future export tooling all see
  // `app_settings` regardless of the Dart class name.
  @override
  String? get tableName => 'app_settings';
}
