import 'package:drift/drift.dart';

import '../app_database.dart';

part 'app_settings_dao.g.dart';

/// DAO for the single-row `app_settings` table (device-local preferences).
///
/// The Drift table class is [AppSettingsTable] (renamed from the
/// original `AppSettings` to avoid clashing with the domain entity
/// `core/settings/domain/entities/app_settings.dart` which is exposed
/// to the UI layer). SQL table name is still `app_settings` via the
/// pinned `tableName` override.
///
/// Invariant: exactly one row with id = [kSettingsRowId] always exists.
/// The migration seeds that row on first upgrade, so all reads are
/// null-free. Tests that spin up a fresh `AppDatabase.forTesting`
/// automatically get the seeded row via [ensureSeeded] on first
/// access (defensive — migrations seed it via raw SQL too).
@DriftAccessor(tables: [AppSettingsTable])
class AppSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$AppSettingsDaoMixin {
  AppSettingsDao(super.db);

  /// Single sentinel id so a second row can never sneak in.
  static const int kSettingsRowId = 1;

  /// One-shot read. Always returns a row: the migration seeds the
  /// defaults (sound on, vibrate on) so callers don't null-check.
  Future<AppSettingsRow> getSingle() async {
    await ensureSeeded();
    return (select(appSettingsTable)
          ..where((t) => t.id.equals(kSettingsRowId))
          ..limit(1))
        .getSingle();
  }

  /// Reactive read for the settings switches UI and the navigation
  /// controller (which watches sound/vibrate to decide whether to emit
  /// a TTS/haptic alert).
  Stream<AppSettingsRow> watchSingle() async* {
    await ensureSeeded();
    yield* (select(appSettingsTable)
          ..where((t) => t.id.equals(kSettingsRowId))
          ..limit(1))
        .watchSingle();
  }

  /// Set the "alarm sound (TTS) enabled" flag.
  Future<void> updateSoundEnabled(bool value) async {
    await ensureSeeded();
    await (update(appSettingsTable)..where((t) => t.id.equals(kSettingsRowId)))
        .write(
      AppSettingsTableCompanion(
        alarmSoundEnabled: Value(value),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Set the "alarm vibrate enabled" flag.
  Future<void> updateVibrateEnabled(bool value) async {
    await ensureSeeded();
    await (update(appSettingsTable)..where((t) => t.id.equals(kSettingsRowId)))
        .write(
      AppSettingsTableCompanion(
        alarmVibrateEnabled: Value(value),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Set the polyline width (in pixels). Clamped to [4, 16] by caller.
  Future<void> setPolylineWidth(int width) async {
    await ensureSeeded();
    await (update(appSettingsTable)..where((t) => t.id.equals(kSettingsRowId)))
        .write(
      AppSettingsTableCompanion(
        polylineWidth: Value(width),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Set the tracking mode (PR #29). Caller passes the canonical
  /// string from `TrackingMode.dbValue` ('normal' | 'accurate').
  /// Persisted as TEXT supaya stable across refactor enum di Dart;
  /// domain layer (`TrackingMode.fromDbValue`) handle parsing balik
  /// dengan fallback ke 'normal' untuk nilai tidak dikenal.
  Future<void> setTrackingMode(String value) async {
    await ensureSeeded();
    await (update(appSettingsTable)..where((t) => t.id.equals(kSettingsRowId)))
        .write(
      AppSettingsTableCompanion(
        trackingMode: Value(value),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Idempotent: inserts the sentinel row if missing. The schema
  /// migration already seeds it on upgrade paths, but fresh unit tests
  /// sometimes open an AppDatabase against an in-memory executor that
  /// skipped the migration step (because onCreate was used and Drift's
  /// INSERT isn't embedded there). Calling this on every read keeps the
  /// invariant at trivial cost (one WHERE on an int PK).
  Future<void> ensureSeeded() async {
    final existing = await (select(appSettingsTable)
          ..where((t) => t.id.equals(kSettingsRowId))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return;
    await into(appSettingsTable).insert(
      AppSettingsTableCompanion.insert(
        id: const Value(kSettingsRowId),
        updatedAt: DateTime.now(),
      ),
    );
  }
}
