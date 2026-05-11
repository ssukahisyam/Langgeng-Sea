import 'package:drift/drift.dart';

import '../app_database.dart';

part 'trip_dao.g.dart';

@DriftAccessor(tables: [Trips])
class TripDao extends DatabaseAccessor<AppDatabase> with _$TripDaoMixin {
  TripDao(super.db);

  Future<void> insertTrip(TripsCompanion row) => into(trips).insert(row);

  Future<TripRow?> findById(String id) =>
      (select(trips)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// At most one active trip exists at a time (MVP invariant).
  Future<TripRow?> findActive() {
    return (select(trips)
          ..where((t) => t.status.equals('active'))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Reactive variant for UI that needs to show "active trip" badges.
  Stream<TripRow?> watchActive() {
    return (select(trips)
          ..where((t) => t.status.equals('active'))
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<List<TripRow>> findAll() {
    return (select(trips)
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
  }

  Stream<List<TripRow>> watchAll() {
    return (select(trips)
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .watch();
  }

  Future<int> updateTrip(String id, TripsCompanion values) =>
      (update(trips)..where((t) => t.id.equals(id))).write(values);

  Future<int> deleteTrip(String id) =>
      (delete(trips)..where((t) => t.id.equals(id))).go();
}
