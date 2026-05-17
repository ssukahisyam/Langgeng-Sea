import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/observability/logger.dart';
import '../../../data/database/app_database.dart';
import '../domain/entities/marker.dart';

/// Repository untuk operasi CRUD marker kustom.
class MarkerRepository {
  MarkerRepository(this._db) : _dao = _db.markerDao;

  final AppDatabase _db;
  final MarkerDao _dao;

  final _uuid = const Uuid();

  // =========================================================================
  // Read
  // =========================================================================

  Future<List<AppMarker>> getAll() async {
    final rows = await _dao.findAll();
    return rows.map(_fromRow).toList();
  }

  Stream<List<AppMarker>> watchAll() {
    return _dao.watchAll().map((rows) => rows.map(_fromRow).toList());
  }

  /// Marker yang dibuat user sendiri (PR #33). Used by Dashboard
  /// stats default + filter "Saya Saja" di MarkersListScreen.
  Future<List<AppMarker>> getOwnOnly() async {
    final all = await getAll();
    return all.where((m) => m.datasetId == null).toList();
  }

  Stream<List<AppMarker>> watchOwnOnly() {
    return watchAll()
        .map((list) => list.where((m) => m.datasetId == null).toList());
  }

  /// Marker yang berasal dari dataset tertentu.
  Future<List<AppMarker>> getByDataset(String datasetId) async {
    final all = await getAll();
    return all.where((m) => m.datasetId == datasetId).toList();
  }

  Future<AppMarker?> getById(String id) async {
    final row = await _dao.findById(id);
    return row == null ? null : _fromRow(row);
  }

  // =========================================================================
  // Write
  // =========================================================================

  Future<AppMarker> create({
    required String name,
    required MarkerCategory category,
    required double latitude,
    required double longitude,
    String? notes,
  }) async {
    final now = DateTime.now();
    final marker = AppMarker(
      id: _uuid.v4(),
      name: name,
      category: category,
      latitude: latitude,
      longitude: longitude,
      notes: notes,
      createdAt: now,
    );

    await _dao.insertMarker(
      MarkersCompanion.insert(
        id: marker.id,
        name: marker.name,
        category: marker.category.storageKey,
        latitude: marker.latitude,
        longitude: marker.longitude,
        notes: Value(marker.notes),
        createdAt: now,
      ),
    );

    return marker;
  }

  /// Buat marker yang berasosiasi dengan sebuah dataset import (PR #33).
  /// Dipakai oleh `GpxImporter.import()` untuk persist `<wpt>` dengan
  /// `dataset_id` yang benar. Caller bertanggung jawab untuk
  /// memanggil `ImportedDatasetRepository.recountChildren(datasetId)`
  /// setelah selesai insert batch.
  Future<AppMarker> createForDataset({
    required String datasetId,
    required String name,
    required MarkerCategory category,
    required double latitude,
    required double longitude,
    String? notes,
  }) async {
    final now = DateTime.now();
    final marker = AppMarker(
      id: _uuid.v4(),
      name: name,
      category: category,
      latitude: latitude,
      longitude: longitude,
      notes: notes,
      createdAt: now,
      datasetId: datasetId,
    );

    await _dao.insertMarker(
      MarkersCompanion.insert(
        id: marker.id,
        name: marker.name,
        category: marker.category.storageKey,
        latitude: marker.latitude,
        longitude: marker.longitude,
        notes: Value(marker.notes),
        createdAt: now,
        datasetId: Value(datasetId),
      ),
    );

    return marker;
  }

  Future<void> update(AppMarker marker) async {
    // PR #33: marker imported tidak boleh di-edit. Lempar
    // [StateError] supaya defense in depth — UI sudah hide tombol
    // Edit untuk imported, tapi guard repo mencegah path lain
    // (test, deep link) bypass.
    if (marker.datasetId != null) {
      throw StateError(
        'Marker dari data impor tidak bisa diedit. '
        'Hapus dataset utuh dari Kelola Data Impor.',
      );
    }
    await _dao.updateMarker(
      marker.id,
      MarkersCompanion(
        name: Value(marker.name),
        category: Value(marker.category.storageKey),
        latitude: Value(marker.latitude),
        longitude: Value(marker.longitude),
        notes: Value(marker.notes),
      ),
    );
  }

  /// Ubah kategori sebuah marker dan catat audit log sebelum perubahan.
  ///
  /// Throws [StateError] bila marker dengan [markerId] tidak ditemukan.
  ///
  /// Audit log (Requirement 5.10) dikirim via [Logger] dengan payload
  /// `{markerId, from, to}` sebelum operasi tulis dijalankan, sehingga
  /// jejak perubahan tetap tercatat walaupun query write gagal.
  Future<void> updateCategory(
    String markerId,
    MarkerCategory category,
  ) async {
    final existing = await getById(markerId);
    if (existing == null) {
      throw StateError('Marker $markerId not found');
    }

    Logger.instance.info('marker.category.change', {
      'markerId': markerId,
      'from': existing.category.storageKey,
      'to': category.storageKey,
    });

    await _dao.updateMarker(
      markerId,
      MarkersCompanion(category: Value(category.storageKey)),
    );
  }

  Future<void> delete(String id) => _dao.deleteMarker(id);

  // =========================================================================
  // Private
  // =========================================================================

  AppMarker _fromRow(MarkerRow row) {
    return AppMarker(
      id: row.id,
      name: row.name,
      category: MarkerCategory.fromStorageKey(row.category),
      latitude: row.latitude,
      longitude: row.longitude,
      notes: row.notes,
      createdAt: row.createdAt,
      datasetId: row.datasetId,
    );
  }
}

// =============================================================================
// Riverpod Providers
// =============================================================================

final markerRepositoryProvider = Provider<MarkerRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return MarkerRepository(db);
});

/// Reactive stream of semua marker.
final allMarkersProvider = StreamProvider<List<AppMarker>>((ref) {
  return ref.watch(markerRepositoryProvider).watchAll();
});

/// Fetch single marker by id (one-shot).
final markerByIdProvider =
    FutureProvider.family.autoDispose<AppMarker?, String>((ref, id) {
  return ref.watch(markerRepositoryProvider).getById(id);
});
