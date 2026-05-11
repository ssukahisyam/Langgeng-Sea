import 'package:drift/drift.dart';

import '../app_database.dart';

part 'offline_region_dao.g.dart';

@DriftAccessor(tables: [OfflineRegions])
class OfflineRegionDao extends DatabaseAccessor<AppDatabase>
    with _$OfflineRegionDaoMixin {
  OfflineRegionDao(super.db);

  Future<void> insertRegion(OfflineRegionsCompanion row) =>
      into(offlineRegions).insert(row);

  Future<OfflineRegionRow?> findById(String id) =>
      (select(offlineRegions)..where((r) => r.id.equals(id)))
          .getSingleOrNull();

  Future<List<OfflineRegionRow>> findAll() {
    return (select(offlineRegions)
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
        .get();
  }

  Stream<List<OfflineRegionRow>> watchAll() {
    return (select(offlineRegions)
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
        .watch();
  }

  Future<int> updateRegion(String id, OfflineRegionsCompanion values) =>
      (update(offlineRegions)..where((r) => r.id.equals(id))).write(values);

  Future<int> deleteRegion(String id) =>
      (delete(offlineRegions)..where((r) => r.id.equals(id))).go();
}
