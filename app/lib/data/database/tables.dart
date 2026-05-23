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

  /// Optional FK ke `imported_datasets.id` (PR #33 / schema v10).
  /// `null` = trip dibuat oleh user di device ini. Non-null = trip
  /// hasil import dari file GPX, edit di-block di UI tapi delete
  /// tetap diizinkan dengan auto-cleanup empty dataset.
  ///
  /// Tidak pakai `references()` di sini karena Drift addColumn pada
  /// migration tidak mendukung FK constraint langsung; FK enforcement
  /// di-handle di repository layer + auto-cleanup helper.
  TextColumn get datasetId => text().nullable()();

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

  /// Optional FK ke `imported_datasets.id` (PR #33 / schema v10).
  /// Denormalized dari trip — sebenarnya bisa diturunkan dari
  /// `trip_id`, tapi simpan langsung untuk MapScreen filter query
  /// langsung tanpa join. Selalu match dengan `tripId`'s
  /// `dataset_id` (di-set bersamaan saat import).
  TextColumn get datasetId => text().nullable()();

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

  /// Optional FK ke `imported_datasets.id` (PR #33 / schema v10).
  /// `null` = marker dibuat oleh user sendiri di device ini.
  /// Non-null = marker hasil import dari file GPX, edit di-block
  /// di UI tapi delete tetap diizinkan (auto-cleanup empty dataset
  /// saat child terakhir dihapus).
  TextColumn get datasetId => text().nullable()();

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

  /// User-configurable polyline width in pixels for map track lines.
  /// Range: 4–16, default: 10.
  IntColumn get polylineWidth => integer().withDefault(const Constant(10))();

  /// Mode tracking. Sejak PR #40 (schema v11) mode tracking
  /// dicabut — runtime selalu treat sebagai `'accurate'`. Kolom
  /// dipertahankan untuk backward compat dengan row pre-v11 yang
  /// mungkin masih punya nilai `'normal'` (legacy).
  ///
  /// Default berubah dari `'normal'` (v9-v10) menjadi `'accurate'`
  /// (v11+). Migrasi v11 juga `UPDATE` semua row supaya kolom
  /// konsisten setelah upgrade.
  TextColumn get trackingMode =>
      text().withDefault(const Constant('accurate'))();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  // Pin SQL table name so the migration's raw INSERT / the migration
  // test's sqlite_master lookup / future export tooling all see
  // `app_settings` regardless of the Dart class name.
  @override
  String? get tableName => 'app_settings';
}

/// Dataset hasil import GPX (PR #33 / schema v10).
///
/// Setiap file GPX yang user impor menjadi satu row di tabel ini.
/// Children — marker, trip, haul, trackpoint — di-link via kolom
/// `dataset_id` di tabel masing-masing. Saat user delete dataset
/// row, repository helper akan cascade delete semua children
/// (FK constraint tidak di-enforce di Drift addColumn migration —
/// kita pakai eksplisit cleanup di repository).
///
/// Counter `marker_count` / `trip_count` / `haul_count` di-denormalized
/// supaya Dataset Manager bisa render list cepat tanpa query
/// terpisah. Di-update lewat `recountChildren()` di repo saat user
/// delete child individual.
@DataClassName('ImportedDatasetRow')
class ImportedDatasetsTable extends Table {
  TextColumn get id => text()();
  TextColumn get fileName => text()();
  TextColumn get exporterName => text().nullable()();
  TextColumn get vesselName => text().nullable()();
  DateTimeColumn get exportedAt => dateTime().nullable()();
  DateTimeColumn get importedAt => dateTime()();

  /// Toggle visibility — kalau false, semua child dari dataset ini
  /// di-hide dari MapScreen, MarkersList, dan optionally Dashboard
  /// stats (kalau toggle "Sertakan data impor" di Dashboard off).
  BoolColumn get visible => boolean().withDefault(const Constant(true))();

  IntColumn get markerCount => integer().withDefault(const Constant(0))();
  IntColumn get tripCount => integer().withDefault(const Constant(0))();
  IntColumn get haulCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  String? get tableName => 'imported_datasets';
}
