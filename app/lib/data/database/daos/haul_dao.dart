import 'package:drift/drift.dart';

import '../app_database.dart';

part 'haul_dao.g.dart';

@DriftAccessor(tables: [Hauls])
class HaulDao extends DatabaseAccessor<AppDatabase> with _$HaulDaoMixin {
  HaulDao(super.db);

  Future<void> insertHaul(HaulsCompanion row) => into(hauls).insert(row);

  Future<HaulRow?> findById(String id) =>
      (select(hauls)..where((h) => h.id.equals(id))).getSingleOrNull();

  /// "Any haul currently in recording state" — used for crash recovery.
  Future<HaulRow?> findRecording() {
    return (select(hauls)
          ..where((h) => h.status.equals('recording'))
          ..limit(1))
        .getSingleOrNull();
  }

  Stream<HaulRow?> watchRecording() {
    return (select(hauls)
          ..where((h) => h.status.equals('recording'))
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<List<HaulRow>> findByTripId(String tripId) {
    return (select(hauls)
          ..where((h) => h.tripId.equals(tripId))
          ..orderBy([(h) => OrderingTerm.asc(h.orderIndex)]))
        .get();
  }

  Stream<List<HaulRow>> watchByTripId(String tripId) {
    return (select(hauls)
          ..where((h) => h.tripId.equals(tripId))
          ..orderBy([(h) => OrderingTerm.asc(h.orderIndex)]))
        .watch();
  }

  /// Highest existing order_index for a trip, or 0 if the trip has no hauls.
  Future<int> highestOrderIndex(String tripId) async {
    final existing = await findByTripId(tripId);
    if (existing.isEmpty) return 0;
    return existing.map((h) => h.orderIndex).reduce((a, b) => a > b ? a : b);
  }

  Future<int> updateHaul(String id, HaulsCompanion values) =>
      (update(hauls)..where((h) => h.id.equals(id))).write(values);

  Future<int> deleteHaul(String id) =>
      (delete(hauls)..where((h) => h.id.equals(id))).go();

  /// All hauls that have been stopped (status == 'completed'), oldest
  /// first. Used by the "Tampilkan Semua Riwayat" map overlay so
  /// polylines render in the order the user sailed them.
  Future<List<HaulRow>> findAllCompleted() {
    return (select(hauls)
          ..where((h) => h.status.equals('completed'))
          ..orderBy([(h) => OrderingTerm.asc(h.startedAt)]))
        .get();
  }

  /// Reactive variant of [findAllCompleted]. The map overlay listens to
  /// this so newly-finished hauls light up the overlay without a
  /// manual refresh.
  Stream<List<HaulRow>> watchAllCompleted() {
    return (select(hauls)
          ..where((h) => h.status.equals('completed'))
          ..orderBy([(h) => OrderingTerm.asc(h.startedAt)]))
        .watch();
  }
}
