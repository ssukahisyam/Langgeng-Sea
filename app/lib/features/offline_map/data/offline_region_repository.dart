import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../domain/entities/offline_region.dart';
import 'offline_region_mapper.dart';

/// CRUD for the metadata rows that back the "Peta Offline" screen.
class OfflineRegionRepository {
  OfflineRegionRepository(AppDatabase db) : _dao = db.offlineRegionDao;

  final OfflineRegionDao _dao;

  Future<void> insert(OfflineRegion region) =>
      _dao.insertRegion(OfflineRegionMapper.toInsertCompanion(region));

  Future<OfflineRegion?> getById(String id) async {
    final row = await _dao.findById(id);
    return row == null ? null : OfflineRegionMapper.fromRow(row);
  }

  Future<List<OfflineRegion>> listAll() async {
    final rows = await _dao.findAll();
    return rows.map(OfflineRegionMapper.fromRow).toList();
  }

  Stream<List<OfflineRegion>> watchAll() {
    return _dao
        .watchAll()
        .map((rows) => rows.map(OfflineRegionMapper.fromRow).toList());
  }

  Future<void> update(OfflineRegion region) async {
    await _dao.updateRegion(
      region.id,
      OfflineRegionMapper.toUpdateCompanion(region),
    );
  }

  Future<void> delete(String id) => _dao.deleteRegion(id);
}

final offlineRegionRepositoryProvider =
    Provider<OfflineRegionRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return OfflineRegionRepository(db);
});

/// Reactive list for the Peta Offline screen.
final offlineRegionsProvider = StreamProvider<List<OfflineRegion>>((ref) {
  return ref.watch(offlineRegionRepositoryProvider).watchAll();
});
