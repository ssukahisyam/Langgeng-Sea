import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'daos/haul_dao.dart';
import 'daos/track_point_dao.dart';
import 'daos/trip_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The single Drift database for Langgeng Sea.
///
/// Local-only (per PRD §11 / NFR-05). Backed by a SQLite file in the
/// app's documents directory. Schema version bumps must ship a migration
/// in [MigrationStrategy.onUpgrade].
@DriftDatabase(
  tables: [Trips, Hauls, TrackPoints],
  daos: [TripDao, HaulDao, TrackPointDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test-only constructor that uses an in-memory SQLite.
  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Help the GPS write path — most reads are per-haul time series.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_track_points_haul_ts '
            'ON track_points (haul_id, timestamp)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_hauls_trip_order '
            'ON hauls (trip_id, order_index)',
          );
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'langgeng_sea.sqlite'));

    // Android workaround: some OEMs' build of SQLite is too old.
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    return NativeDatabase.createInBackground(file, logStatements: false);
  });
}

/// Process-wide singleton so DAOs can be looked up from anywhere.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
