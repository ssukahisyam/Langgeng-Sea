import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'track_point_dao.g.dart';

@DriftAccessor(tables: [TrackPoints])
class TrackPointDao extends DatabaseAccessor<AppDatabase>
    with _$TrackPointDaoMixin {
  TrackPointDao(super.db);

  /// Single point insert. Called on every GPS tick while tracking, so it
  /// needs to be cheap. No transaction overhead.
  Future<int> insertPoint(TrackPointsCompanion row) =>
      into(trackPoints).insert(row);

  /// Bulk insert for imports / test fixtures.
  Future<void> insertAll(List<TrackPointsCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAll(trackPoints, rows));
  }

  Future<List<TrackPointRow>> findByHaulId(String haulId) {
    return (select(trackPoints)
          ..where((p) => p.haulId.equals(haulId))
          ..orderBy([(p) => OrderingTerm.asc(p.timestamp)]))
        .get();
  }

  /// Reactive stream of points for a haul — used to drive the live polyline.
  Stream<List<TrackPointRow>> watchByHaulId(String haulId) {
    return (select(trackPoints)
          ..where((p) => p.haulId.equals(haulId))
          ..orderBy([(p) => OrderingTerm.asc(p.timestamp)]))
        .watch();
  }

  Future<int> countForHaul(String haulId) async {
    final row = await (selectOnly(trackPoints)
          ..addColumns([trackPoints.id.count()])
          ..where(trackPoints.haulId.equals(haulId)))
        .getSingle();
    return row.read(trackPoints.id.count()) ?? 0;
  }

  Future<int> deleteByHaulId(String haulId) =>
      (delete(trackPoints)..where((p) => p.haulId.equals(haulId))).go();
}
