// Migration test for AppDatabase.
//
// Verifies the v1 → v4 upgrade path adds the tables introduced in later
// milestones (offline_regions at v2; log_book_entries, catch_items,
// markers at v3; user_profiles at v4) without losing any existing data.
//
// drift_dev ships schema-version helpers (`dart run drift_dev schema
// dump`) but we don't have a dumped `drift_schemas/` directory yet, so
// this test uses raw SQL to pre-populate a v1-equivalent schema before
// AppDatabase sees the database.
//
// The trick: NativeDatabase.memory(setup: (raw) { … }) gives us access
// to the raw `sqlite3` handle *before* Drift runs its migration
// strategy. We create the v1 tables and set user_version=1 there, then
// Drift reads user_version, sees schemaVersion=4, and runs onUpgrade.

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langgeng_sea/data/database/app_database.dart';

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

  group('AppDatabase migration v1 → v4', () {
    late AppDatabase db;

    setUp(() {
      final now = DateTime(2025, 1, 1, 6).millisecondsSinceEpoch ~/ 1000;

      // Build a v1 schema + sample data DIRECTLY on the raw sqlite3
      // handle, before Drift inspects user_version.
      db = AppDatabase.forTesting(NativeDatabase.memory(setup: (raw) {
        raw
          ..execute('PRAGMA user_version = 1;')
          ..execute(_v1CreateTrips)
          ..execute(_v1CreateHauls)
          ..execute(_v1CreateTrackPoints);

        raw.execute(
          "INSERT INTO trips (id, name, started_at, status, "
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
      }));
    });

    tearDown(() async {
      await db.close();
    });

    test('onUpgrade runs and reaches schemaVersion 4', () async {
      // Any query forces the migration to run.
      final row = await db
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(
        row.data.values.first,
        4,
        reason: 'migration should land at schemaVersion 4',
      );
    });

    test('existing trip row survives the migration', () async {
      final trips = await db
          .customSelect(
              "SELECT id, name, status FROM trips WHERE id = 'trip-1'")
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
      expect((haul['distance_meters'] as num).toDouble(),
          closeTo(1234.5, 0.01));
      expect((haul['swept_area_m2'] as num).toDouble(),
          closeTo(24690.0, 0.01));
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
              'SELECT name, vessel_name FROM user_profiles WHERE id = 1')
          .getSingle();
      expect(profile.data['name'], 'Pak Hasan');
      expect(profile.data['vessel_name'], 'KM Harapan');
    });
  });
}

/// Asserts a table with [name] exists in `sqlite_master`.
Future<void> _expectTableExists(AppDatabase db, String name) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master "
        "WHERE type='table' AND name = ?",
        variables: [Variable.withString(name)],
      )
      .get();
  expect(
    rows,
    hasLength(1),
    reason: 'expected table $name to exist after migration',
  );
}
