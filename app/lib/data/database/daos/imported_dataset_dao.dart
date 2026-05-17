import 'package:drift/drift.dart';

import '../app_database.dart';

part 'imported_dataset_dao.g.dart';

/// DAO untuk tabel `imported_datasets` (PR #33 / schema v10).
///
/// Setiap row mewakili satu file GPX yang user impor. Children
/// (marker, trip, haul) di-link via FK soft (`dataset_id` text
/// kolom). Counter denormalized di-update lewat raw SQL recount
/// supaya MapScreen filter dan Dataset Manager bisa render tanpa
/// query terpisah per dataset.
@DriftAccessor(tables: [ImportedDatasetsTable, Markers, Trips, Hauls])
class ImportedDatasetDao extends DatabaseAccessor<AppDatabase>
    with _$ImportedDatasetDaoMixin {
  ImportedDatasetDao(super.db);

  // ---------------------------------------------------------------------
  // CRUD basics
  // ---------------------------------------------------------------------

  Future<void> insertDataset(ImportedDatasetsTableCompanion row) =>
      into(importedDatasetsTable).insert(row);

  Future<ImportedDatasetRow?> findById(String id) {
    return (select(importedDatasetsTable)..where((d) => d.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<ImportedDatasetRow>> getAll() {
    return (select(importedDatasetsTable)
          ..orderBy([(d) => OrderingTerm.desc(d.importedAt)]))
        .get();
  }

  Stream<List<ImportedDatasetRow>> watchAll() {
    return (select(importedDatasetsTable)
          ..orderBy([(d) => OrderingTerm.desc(d.importedAt)]))
        .watch();
  }

  /// Stream id-id dataset yang `visible = true`. Dipakai oleh
  /// MapScreen / MarkersList untuk filter cepat tanpa harus
  /// load semua row dataset.
  Stream<Set<String>> watchVisibleIds() {
    return (select(importedDatasetsTable)..where((d) => d.visible.equals(true)))
        .watch()
        .map((rows) => rows.map((r) => r.id).toSet());
  }

  // ---------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------

  Future<int> setVisible(String id, bool visible) {
    return (update(importedDatasetsTable)..where((d) => d.id.equals(id)))
        .write(ImportedDatasetsTableCompanion(visible: Value(visible)));
  }

  Future<int> deleteDataset(String id) {
    return (delete(importedDatasetsTable)..where((d) => d.id.equals(id))).go();
  }

  /// Cascade delete semua child dari dataset, lalu hapus dataset row.
  /// Drift tidak enforce FK constraint untuk soft-FK kolom yang
  /// di-add lewat migration — kita do it manually di transaction.
  Future<void> deleteDatasetCascade(String id) async {
    await transaction(() async {
      // Order: trackpoints (lewat haul cascade existing) -> hauls ->
      // trips -> markers -> dataset row.
      // Hauls existing cascade dari trips (FK keras), jadi cukup
      // delete trips dengan dataset_id = id, hauls otomatis hilang.
      // Tapi defensive: ada haul yang punya dataset_id tapi
      // trip-nya tidak ada -- delete by hauls.dataset_id juga.
      await (delete(hauls)..where((h) => h.datasetId.equals(id))).go();
      await (delete(trips)..where((t) => t.datasetId.equals(id))).go();
      await (delete(markers)..where((m) => m.datasetId.equals(id))).go();
      await (delete(importedDatasetsTable)..where((d) => d.id.equals(id))).go();
    });
  }

  // ---------------------------------------------------------------------
  // Recount denormalized counters
  // ---------------------------------------------------------------------

  /// Hitung ulang `marker_count`, `trip_count`, `haul_count` dari
  /// child rows dan simpan ke dataset row. Dipanggil setelah user
  /// delete child individual atau setelah import selesai.
  Future<void> recountChildren(String id) async {
    final markerCount = await _countByDatasetId(markers, id);
    final tripCount = await _countByDatasetId(trips, id);
    final haulCount = await _countByDatasetId(hauls, id);
    await (update(importedDatasetsTable)..where((d) => d.id.equals(id))).write(
      ImportedDatasetsTableCompanion(
        markerCount: Value(markerCount),
        tripCount: Value(tripCount),
        haulCount: Value(haulCount),
      ),
    );
  }

  Future<int> _countByDatasetId(
    TableInfo<Table, dynamic> table,
    String datasetId,
  ) async {
    final result = await customSelect(
      'SELECT COUNT(*) AS c FROM ${table.actualTableName} '
      'WHERE dataset_id = ?',
      variables: [Variable.withString(datasetId)],
      readsFrom: {table},
    ).getSingle();
    return result.data['c'] as int;
  }

  /// Hapus dataset row kalau semua child sudah 0 setelah recount.
  /// Idempotent — kalau dataset tidak ada lagi, no-op.
  Future<bool> autoCleanupIfEmpty(String id) async {
    final row = await findById(id);
    if (row == null) return false;
    final isEmpty = row.markerCount == 0 &&
        row.tripCount == 0 &&
        row.haulCount == 0;
    if (!isEmpty) return false;
    await deleteDataset(id);
    return true;
  }
}
