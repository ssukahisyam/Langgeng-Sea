// Migration test for AppDatabase.
//
// Verifies the v1 → v10 upgrade path adds the tables introduced in later
// milestones (offline_regions at v2; log_book_entries, catch_items,
// markers at v3; user_profiles at v4; hauls.color_value at v5;
// app_settings at v6; trips.color_value at v7;
// app_settings.polyline_width at v8; app_settings.tracking_mode at v9;
// imported_datasets + dataset_id columns at v10) without losing any
// existing data.
//
// drift_dev ships schema-version helpers (`dart run drift_dev schema
// dump`) but we don't have a dumped `drift_schemas/` directory yet, so
// this test uses raw SQL to pre-populate a v1-equivalent schema before
// AppDatabase sees the database.
//
// The trick: NativeDatabase.memory(setup: (raw) { … }) gives us access
// to the raw `sqlite3` handle *before* Drift runs its migration
// strategy. We create the v1 tables and set user_version=1 there, then
// Drift reads user_version, sees schemaVersion=8, and runs onUpgrade.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:styra/data/database/app_database.dart';

const _v1CreateTrips = '''
CREATE TABLE trips (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NULL,
  started_at INTEGER NOT NULL,
  ended_at INTEGER NULL,
  status TEXT NOT NULL,
  home_port TEXT NULL,
  notes TEXT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
''';

const _v1CreateHauls = '''
CREATE TABLE hauls (
  id TEXT NOT NULL PRIMARY KEY,
  trip_id TEXT NOT NULL REFERENCES trips (id) ON UPDATE CASCADE ON DELETE CASCADE,
  name TEXT NULL,
  order_index INTEGER NOT NULL,
  started_at INTEGER NOT NULL,
  ended_at INTEGER NULL,
  status TEXT NOT NULL,
  trawl_width_meters REAL NOT NULL DEFAULT 20.0,
  distance_meters REAL NOT NULL DEFAULT 0,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  avg_speed_knots REAL NULL,
  avg_heading_degrees REAL NULL,
  swept_area_m2 REAL NOT NULL DEFAULT 0,
  notes TEXT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
''';

const _v1CreateTrackPoints = '''
CREATE TABLE track_points (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  haul_id TEXT NOT NULL REFERENCES hauls (id) ON UPDATE CASCADE ON DELETE CASCADE,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  timestamp INTEGER NOT NULL,
  speed_mps REAL NULL,
  heading_degrees REAL NULL,
  accuracy_meters REAL NULL,
  altitude_meters REAL NULL
);
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppDatabase migration v1 → v11', () {
    late AppDatabase db;

    setUp(() {
      final now = DateTime(2025, 1, 1, 6).millisecondsSinceEpoch ~/ 1000;

      // Build a v1 schema + sample data DIRECTLY on the raw sqlite3
      // handle, before Drift inspects user_version.
      db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (raw) {
            raw
              ..execute('PRAGMA user_version = 1;')
              ..execute(_v1CreateTrips)
              ..execute(_v1CreateHauls)
              ..execute(_v1CreateTrackPoints);

            raw.execute(
              'INSERT INTO trips (id, name, started_at, status, '
              'created_at, updated_at) '
              "VALUES ('trip-1', 'Test Trip', ?, 'completed', ?, ?);",
              [now, now, now],
            );
            raw.execute(
              'INSERT INTO hauls (id, trip_id, order_index, started_at, status, '
              'trawl_width_meters, distance_meters, duration_seconds, '
              'swept_area_m2, created_at, updated_at) '
              "VALUES ('haul-1', 'trip-1', 1, ?, 'completed', 20.0, "
              '1234.5, 3600, 24690.0, ?, ?);',
              [now, now, now],
            );
            raw.execute(
              'INSERT INTO track_points (haul_id, latitude, longitude, timestamp) '
              "VALUES ('haul-1', -7.2, 113.4, ?);",
              [now],
            );
          },
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('onUpgrade runs and reaches schemaVersion 11', () async {
      // Any query forces the migration to run.
      final result = await db.customSelect('PRAGMA user_version').getSingle();
      final userVersion = result.data['user_version'] as int;
      expect(
        userVersion,
        11,
        reason: 'migration should land at schemaVersion 11',
      );
    });

    test('existing trip row survives the migration', () async {
      final trips = await db
          .customSelect(
            "SELECT id, name, status FROM trips WHERE id = 'trip-1'",
          )
          .get();
      expect(trips, hasLength(1));
      expect(trips.single.data['name'], 'Test Trip');
      expect(trips.single.data['status'], 'completed');
    });

    test('existing haul row survives the migration', () async {
      final hauls = await db
          .customSelect(
            'SELECT id, trip_id, distance_meters, swept_area_m2 '
            "FROM hauls WHERE id = 'haul-1'",
          )
          .get();
      expect(hauls, hasLength(1));
      final haul = hauls.single.data;
      expect(haul['trip_id'], 'trip-1');
      expect(
        (haul['distance_meters'] as num).toDouble(),
        closeTo(1234.5, 0.01),
      );
      expect(
        (haul['swept_area_m2'] as num).toDouble(),
        closeTo(24690.0, 0.01),
      );
    });

    test('existing track point survives the migration', () async {
      final points = await db
          .customSelect(
            'SELECT haul_id, latitude, longitude '
            "FROM track_points WHERE haul_id = 'haul-1'",
          )
          .get();
      expect(points, hasLength(1));
      expect(points.single.data['haul_id'], 'haul-1');
    });

    test('offline_regions table exists after upgrade (v2)', () async {
      await _expectTableExists(db, 'offline_regions');
    });

    test('log_book_entries table exists after upgrade (v3)', () async {
      await _expectTableExists(db, 'log_book_entries');
    });

    test('catch_items table exists after upgrade (v3)', () async {
      await _expectTableExists(db, 'catch_items');
    });

    test('markers table exists after upgrade (v3)', () async {
      await _expectTableExists(db, 'markers');
    });

    test('user_profiles table exists after upgrade (v4)', () async {
      await _expectTableExists(db, 'user_profiles');
    });

    test('hauls.color_value column exists after upgrade (v5)', () async {
      final rows = await db.customSelect('PRAGMA table_info(hauls)').get();
      final colNames = rows.map((r) => r.data['name'] as String).toList();
      expect(
        colNames,
        contains('color_value'),
        reason: 'v5 migration should add hauls.color_value column',
      );
    });

    test('legacy hauls.color_value defaults to NULL for pre-v5 rows', () async {
      final rows = await db
          .customSelect(
            "SELECT color_value FROM hauls WHERE id = 'haul-1'",
          )
          .get();
      expect(rows, hasLength(1));
      expect(rows.single.data['color_value'], isNull);
    });

    test('app_settings table exists after upgrade (v6)', () async {
      await _expectTableExists(db, 'app_settings');
    });

    test('trips.color_value column exists after upgrade (v7)', () async {
      final rows = await db.customSelect('PRAGMA table_info(trips)').get();
      final colNames = rows.map((r) => r.data['name'] as String).toList();
      expect(
        colNames,
        contains('color_value'),
        reason: 'v7 migration should add trips.color_value column',
      );
    });

    test('legacy trips.color_value defaults to NULL for pre-v7 rows', () async {
      final rows = await db
          .customSelect(
            "SELECT color_value FROM trips WHERE id = 'trip-1'",
          )
          .get();
      expect(rows, hasLength(1));
      expect(rows.single.data['color_value'], isNull);
    });

    test('app_settings is seeded with alarms both ON after v5 -> v6 upgrade',
        () async {
      final rows = await db
          .customSelect(
            'SELECT id, alarm_sound_enabled, alarm_vibrate_enabled, '
            'updated_at FROM app_settings WHERE id = 1',
          )
          .get();
      expect(
        rows,
        hasLength(1),
        reason: 'migration should seed exactly one app_settings row',
      );
      final r = rows.single.data;
      // Drift stores bool as 0/1 via custom SQL, but the seed uses
      // literal 1 values so we compare against the numeric form.
      expect(r['alarm_sound_enabled'], 1);
      expect(r['alarm_vibrate_enabled'], 1);
      expect(r['updated_at'], isNotNull);
    });

    test('app_settings row is a singleton (PK = 1)', () async {
      // Attempting to insert a second row with id=1 must fail; inserting
      // with a different PK is mechanically possible in SQLite but the
      // domain invariant is enforced by the DAO -- guarding here keeps
      // the migration test honest.
      final count = await db
          .customSelect('SELECT COUNT(*) AS c FROM app_settings')
          .getSingle();
      expect(count.data['c'], 1);
    });

    test('new tables are writable after migration', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await db.customStatement(
        'INSERT INTO markers (id, name, category, latitude, longitude, '
        "created_at) VALUES ('m1', 'Spot A', 'productive', -7.2, 113.4, ?)",
        [now],
      );
      final markers = await db
          .customSelect('SELECT COUNT(*) AS c FROM markers')
          .getSingle();
      expect(markers.data['c'], 1);

      // user_profiles — single-row pattern (id fixed to 1).
      await db.customStatement(
        'INSERT INTO user_profiles (id, name, vessel_name, '
        'trawl_width_meters, created_at, updated_at) '
        "VALUES (1, 'Pak Hasan', 'KM Harapan', 20, ?, ?)",
        [now, now],
      );
      final profile = await db
          .customSelect(
            'SELECT name, vessel_name FROM user_profiles WHERE id = 1',
          )
          .getSingle();
      expect(profile.data['name'], 'Pak Hasan');
      expect(profile.data['vessel_name'], 'KM Harapan');
    });

    test('app_settings.polyline_width column exists after upgrade (v8)',
        () async {
      final rows =
          await db.customSelect('PRAGMA table_info(app_settings)').get();
      final colNames = rows.map((r) => r.data['name'] as String).toList();
      expect(
        colNames,
        contains('polyline_width'),
        reason: 'v8 migration should add app_settings.polyline_width column',
      );
    });

    test('polyline_width defaults to 10 for pre-v8 rows', () async {
      final rows = await db
          .customSelect(
            'SELECT polyline_width FROM app_settings WHERE id = 1',
          )
          .get();
      expect(rows, hasLength(1));
      expect(rows.single.data['polyline_width'], 10);
    });

    test('app_settings.tracking_mode column exists after upgrade (v9)',
        () async {
      final rows =
          await db.customSelect('PRAGMA table_info(app_settings)').get();
      final colNames = rows.map((r) => r.data['name'] as String).toList();
      expect(
        colNames,
        contains('tracking_mode'),
        reason: 'v9 migration should add app_settings.tracking_mode column',
      );
    });

    test("tracking_mode is 'accurate' after v11 migration", () async {
      // PR #29 (v9): default ke 'normal'.
      // PR #40 (v11): mode tracking dicabut, semua row di-update ke
      // 'accurate'. Test ini start dari schema v8 (sebelum kolom ini
      // ada), jadi setelah onUpgrade run sampai v11 kolom harus
      // bernilai 'accurate' — bukan 'normal' lagi.
      final rows = await db
          .customSelect(
            'SELECT tracking_mode FROM app_settings WHERE id = 1',
          )
          .get();
      expect(rows, hasLength(1));
      expect(rows.single.data['tracking_mode'], 'accurate');
    });

    test('imported_datasets table exists after upgrade (v10)', () async {
      await _expectTableExists(db, 'imported_datasets');
    });

    test('markers.dataset_id column exists after upgrade (v10)', () async {
      final rows = await db.customSelect('PRAGMA table_info(markers)').get();
      final colNames = rows.map((r) => r.data['name'] as String).toList();
      expect(
        colNames,
        contains('dataset_id'),
        reason: 'v10 migration should add markers.dataset_id column',
      );
    });

    test('trips.dataset_id column exists after upgrade (v10)', () async {
      final rows = await db.customSelect('PRAGMA table_info(trips)').get();
      final colNames = rows.map((r) => r.data['name'] as String).toList();
      expect(
        colNames,
        contains('dataset_id'),
        reason: 'v10 migration should add trips.dataset_id column',
      );
    });

    test('hauls.dataset_id column exists after upgrade (v10)', () async {
      final rows = await db.customSelect('PRAGMA table_info(hauls)').get();
      final colNames = rows.map((r) => r.data['name'] as String).toList();
      expect(
        colNames,
        contains('dataset_id'),
        reason: 'v10 migration should add hauls.dataset_id column',
      );
    });

    test('legacy markers/trips/hauls.dataset_id default to NULL', () async {
      // PR #33: existing rows yang dibuat user di device ini sebelum
      // upgrade harus dapat dataset_id = NULL (= "data milik user
      // sendiri"), bukan random / corrupt value.
      final markerRows =
          await db.customSelect("SELECT dataset_id FROM markers").get();
      // Trip-1 + Haul-1 di-seed di setUp.
      final tripRows = await db
          .customSelect("SELECT dataset_id FROM trips WHERE id = 'trip-1'")
          .get();
      final haulRows = await db
          .customSelect("SELECT dataset_id FROM hauls WHERE id = 'haul-1'")
          .get();
      // Markers table di-seed di test 'new tables are writable' yang
      // jalan terpisah; di sini cukup verify trip & haul.
      for (final row in markerRows) {
        expect(row.data['dataset_id'], isNull);
      }
      expect(tripRows, hasLength(1));
      expect(tripRows.single.data['dataset_id'], isNull);
      expect(haulRows, hasLength(1));
      expect(haulRows.single.data['dataset_id'], isNull);
    });

    test('imported_datasets table is writable after migration', () async {
      // Round-trip: insert dataset row, verify counter defaults,
      // verify visible default true.
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.customStatement(
        'INSERT INTO imported_datasets '
        '(id, file_name, imported_at) '
        "VALUES ('ds-1', 'test.gpx', ?)",
        [now],
      );
      final rows = await db
          .customSelect(
            "SELECT id, file_name, visible, marker_count, trip_count, "
            "haul_count, exporter_name, vessel_name "
            "FROM imported_datasets WHERE id = 'ds-1'",
          )
          .get();
      expect(rows, hasLength(1));
      final r = rows.single.data;
      expect(r['file_name'], 'test.gpx');
      expect(r['visible'], 1, reason: 'default visible = true');
      expect(r['marker_count'], 0);
      expect(r['trip_count'], 0);
      expect(r['haul_count'], 0);
      expect(r['exporter_name'], isNull);
      expect(r['vessel_name'], isNull);
    });
  });
}

/// Asserts a table with [name] exists in `sqlite_master`.
Future<void> _expectTableExists(AppDatabase db, String name) async {
  final rows = await db.customSelect(
    'SELECT name FROM sqlite_master '
    "WHERE type='table' AND name = ?",
    variables: [Variable.withString(name)],
  ).get();
  expect(
    rows,
    hasLength(1),
    reason: 'expected table $name to exist after migration',
  );
}
