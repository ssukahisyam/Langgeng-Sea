import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database/app_database.dart';
import '../domain/entities/catch_item.dart';
import '../domain/entities/log_book_entry.dart';

/// Repository untuk operasi CRUD Log Book.
class LogBookRepository {
  LogBookRepository(this._db) : _dao = _db.logBookDao;

  final AppDatabase _db;
  final LogBookDao _dao;

  final _uuid = const Uuid();

  // =========================================================================
  // Read
  // =========================================================================

  Future<LogBookEntry?> getByHaulId(String haulId) async {
    final row = await _dao.findByHaulId(haulId);
    if (row == null) return null;
    return _assembleEntry(row);
  }

  Future<LogBookEntry?> getByTripId(String tripId) async {
    final row = await _dao.findByTripId(tripId);
    if (row == null) return null;
    return _assembleEntry(row);
  }

  Stream<LogBookEntry?> watchByHaulId(String haulId) {
    return _dao.watchByHaulId(haulId).asyncMap((row) async {
      if (row == null) return null;
      return _assembleEntry(row);
    });
  }

  // =========================================================================
  // Write
  // =========================================================================

  /// Menyimpan (insert/update) log book entry beserta catch items.
  Future<void> save(LogBookEntry entry) async {
    final now = DateTime.now();
    final existing = entry.scope == LogBookScope.haul
        ? await _dao.findByHaulId(entry.haulId!)
        : await _dao.findByTripId(entry.tripId!);

    if (existing == null) {
      // Insert new entry
      await _dao.insertEntry(LogBookEntriesCompanion.insert(
        id: entry.id.isEmpty ? _uuid.v4() : entry.id,
        scope: entry.scope.name,
        tripId: Value(entry.tripId),
        haulId: Value(entry.haulId),
        weather: Value(entry.weather?.name),
        wave: Value(entry.wave?.name),
        fuelLiters: Value(entry.fuelLiters),
        costRupiah: Value(entry.costRupiah),
        crewCount: Value(entry.crewCount),
        notes: Value(entry.notes),
        createdAt: now,
        updatedAt: now,
      ),);

      final entryId = entry.id.isEmpty ? _uuid.v4() : entry.id;
      await _insertCatchItems(entryId, entry.catches);
    } else {
      // Update existing
      await _dao.updateEntry(
        existing.id,
        LogBookEntriesCompanion(
          weather: Value(entry.weather?.name),
          wave: Value(entry.wave?.name),
          fuelLiters: Value(entry.fuelLiters),
          costRupiah: Value(entry.costRupiah),
          crewCount: Value(entry.crewCount),
          notes: Value(entry.notes),
          updatedAt: Value(now),
        ),
      );

      // Replace catch items (delete + re-insert)
      await _dao.deleteCatchItemsByEntry(existing.id);
      await _insertCatchItems(existing.id, entry.catches);
    }
  }

  Future<void> delete(String entryId) => _dao.deleteEntry(entryId);

  // =========================================================================
  // Private helpers
  // =========================================================================

  Future<LogBookEntry> _assembleEntry(LogBookEntryRow row) async {
    final catchRows = await _dao.findCatchItemsByEntry(row.id);
    return LogBookEntry(
      id: row.id,
      scope: LogBookScope.values.firstWhere(
        (s) => s.name == row.scope,
        orElse: () => LogBookScope.haul,
      ),
      tripId: row.tripId,
      haulId: row.haulId,
      catches: catchRows
          .map((c) => CatchItem(
                id: c.id,
                species: c.species,
                weightKg: c.weightKg,
              ),)
          .toList(),
      weather: row.weather == null
          ? null
          : Weather.values.firstWhere(
              (w) => w.name == row.weather,
              orElse: () => Weather.cerah,
            ),
      wave: row.wave == null
          ? null
          : WaveCondition.values.firstWhere(
              (w) => w.name == row.wave,
              orElse: () => WaveCondition.tenang,
            ),
      fuelLiters: row.fuelLiters,
      costRupiah: row.costRupiah,
      crewCount: row.crewCount,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Future<void> _insertCatchItems(
    String logBookEntryId,
    List<CatchItem> catches,
  ) async {
    for (final item in catches) {
      await _dao.insertCatchItem(CatchItemsCompanion.insert(
        id: item.id.isEmpty ? _uuid.v4() : item.id,
        logBookEntryId: logBookEntryId,
        species: item.species,
        weightKg: Value(item.weightKg),
      ),);
    }
  }
}

// =============================================================================
// Riverpod Providers
// =============================================================================

final logBookRepositoryProvider = Provider<LogBookRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return LogBookRepository(db);
});

/// Watches a log book entry by haul ID (reactive).
final logBookByHaulProvider =
    StreamProvider.family.autoDispose<LogBookEntry?, String>((ref, haulId) {
  return ref.watch(logBookRepositoryProvider).watchByHaulId(haulId);
});

/// Fetches a log book entry by trip ID (one-shot).
final logBookByTripProvider =
    FutureProvider.family.autoDispose<LogBookEntry?, String>((ref, tripId) {
  return ref.watch(logBookRepositoryProvider).getByTripId(tripId);
});
