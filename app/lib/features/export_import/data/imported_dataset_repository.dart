import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/observability/logger.dart';
import '../../../data/database/app_database.dart';
import '../domain/entities/imported_dataset.dart';

/// Repository untuk operasi CRUD `ImportedDataset` (PR #33).
///
/// Membungkus [ImportedDatasetDao] supaya feature code (UI, services)
/// kerja dengan domain entity [ImportedDataset], bukan Drift row class
/// langsung. Concerns:
/// - Mapping row -> entity dan sebaliknya
/// - UUID generation di create
/// - Auto-cleanup saat semua child child sudah dihapus user
/// - Cascade delete saat user delete dataset utuh
class ImportedDatasetRepository {
  ImportedDatasetRepository(this._db) : _dao = _db.importedDatasetDao;

  final AppDatabase _db;
  final ImportedDatasetDao _dao;
  final _uuid = const Uuid();

  // ---------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------

  Future<List<ImportedDataset>> getAll() async {
    final rows = await _dao.getAll();
    return rows.map(_fromRow).toList();
  }

  Stream<List<ImportedDataset>> watchAll() =>
      _dao.watchAll().map((rows) => rows.map(_fromRow).toList());

  /// Stream id-id dataset yang `visible = true`. Dipakai oleh
  /// MapScreen + MarkersList untuk filter cepat.
  Stream<Set<String>> watchVisibleIds() => _dao.watchVisibleIds();

  Future<ImportedDataset?> getById(String id) async {
    final row = await _dao.findById(id);
    return row == null ? null : _fromRow(row);
  }

  // ---------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------

  /// Buat dataset row baru saat user import file GPX. Counter
  /// awalnya 0; nanti di-recount setelah children selesai di-insert.
  Future<ImportedDataset> create({
    required String fileName,
    String? exporterName,
    String? vesselName,
    DateTime? exportedAt,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final dataset = ImportedDataset(
      id: id,
      fileName: fileName,
      exporterName: exporterName,
      vesselName: vesselName,
      exportedAt: exportedAt,
      importedAt: now,
      visible: true,
      markerCount: 0,
      tripCount: 0,
      haulCount: 0,
    );
    await _dao.insertDataset(
      ImportedDatasetsTableCompanion.insert(
        id: id,
        fileName: fileName,
        importedAt: now,
        exporterName: exporterName == null
            ? const Value.absent()
            : Value(exporterName),
        vesselName:
            vesselName == null ? const Value.absent() : Value(vesselName),
        exportedAt:
            exportedAt == null ? const Value.absent() : Value(exportedAt),
      ),
    );
    Logger.instance.info('import.dataset_created', {
      'id': id,
      'fileName': fileName,
    });
    return dataset;
  }

  Future<void> setVisible(String id, bool visible) async {
    await _dao.setVisible(id, visible);
    Logger.instance.info('import.dataset_visibility', {
      'id': id,
      'visible': visible,
    });
  }

  /// Hapus dataset utuh + cascade semua child (marker, trip, haul,
  /// trackpoint via cascade FK existing dari haul). Idempotent.
  Future<void> delete(String id) async {
    await _dao.deleteDatasetCascade(id);
    Logger.instance.info('import.dataset_deleted', {'id': id});
  }

  /// Recount denormalized counter setelah user delete child individual.
  /// Caller wajib panggil ini setelah delete trip / haul / marker
  /// imported supaya counter di Dataset Manager tetap akurat.
  Future<void> recountChildren(String id) async {
    await _dao.recountChildren(id);
  }

  /// Cek apakah dataset masih punya child. Kalau tidak, hapus row
  /// supaya Dataset Manager tidak menumpuk dataset kosong.
  /// Idempotent — kalau dataset sudah hilang, no-op.
  Future<bool> autoCleanupIfEmpty(String id) async {
    // Recount dulu supaya counter up-to-date sebelum cek isEmpty.
    await _dao.recountChildren(id);
    final removed = await _dao.autoCleanupIfEmpty(id);
    if (removed) {
      Logger.instance.info('import.dataset_auto_cleaned', {'id': id});
    }
    return removed;
  }

  // ---------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------

  ImportedDataset _fromRow(ImportedDatasetRow row) {
    return ImportedDataset(
      id: row.id,
      fileName: row.fileName,
      exporterName: row.exporterName,
      vesselName: row.vesselName,
      exportedAt: row.exportedAt,
      importedAt: row.importedAt,
      visible: row.visible,
      markerCount: row.markerCount,
      tripCount: row.tripCount,
      haulCount: row.haulCount,
    );
  }
}

// =============================================================================
// Providers
// =============================================================================

/// Singleton repository scope app.
final importedDatasetRepositoryProvider =
    Provider<ImportedDatasetRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ImportedDatasetRepository(db);
});

/// Stream semua dataset, sorted desc by importedAt. UI watch ini di
/// Settings tile counter, Dataset Manager screen, dan MapScreen
/// overlay panel.
final importedDatasetsProvider = StreamProvider<List<ImportedDataset>>((ref) {
  return ref.watch(importedDatasetRepositoryProvider).watchAll();
});

/// Set id dataset yang sedang visible. Dipakai oleh markers /
/// history overlay providers untuk filter peta.
final visibleDatasetIdsProvider = StreamProvider<Set<String>>((ref) {
  return ref.watch(importedDatasetRepositoryProvider).watchVisibleIds();
});
