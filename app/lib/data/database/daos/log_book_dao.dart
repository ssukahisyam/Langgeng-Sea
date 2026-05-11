import 'package:drift/drift.dart';

import '../app_database.dart';

part 'log_book_dao.g.dart';

@DriftAccessor(tables: [LogBookEntries, CatchItems])
class LogBookDao extends DatabaseAccessor<AppDatabase> with _$LogBookDaoMixin {
  LogBookDao(super.db);

  // =========================================================================
  // LogBookEntries
  // =========================================================================

  Future<void> insertEntry(LogBookEntriesCompanion row) =>
      into(logBookEntries).insert(row);

  Future<LogBookEntryRow?> findByHaulId(String haulId) =>
      (select(logBookEntries)..where((e) => e.haulId.equals(haulId)))
          .getSingleOrNull();

  Future<LogBookEntryRow?> findByTripId(String tripId) =>
      (select(logBookEntries)..where((e) => e.tripId.equals(tripId)))
          .getSingleOrNull();

  Stream<LogBookEntryRow?> watchByHaulId(String haulId) =>
      (select(logBookEntries)..where((e) => e.haulId.equals(haulId)))
          .watchSingleOrNull();

  Future<int> updateEntry(String id, LogBookEntriesCompanion values) =>
      (update(logBookEntries)..where((e) => e.id.equals(id))).write(values);

  Future<int> deleteEntry(String id) =>
      (delete(logBookEntries)..where((e) => e.id.equals(id))).go();

  // =========================================================================
  // CatchItems
  // =========================================================================

  Future<void> insertCatchItem(CatchItemsCompanion row) =>
      into(catchItems).insert(row);

  Future<List<CatchItemRow>> findCatchItemsByEntry(String logBookEntryId) =>
      (select(catchItems)
            ..where((c) => c.logBookEntryId.equals(logBookEntryId)))
          .get();

  Future<int> deleteCatchItemsByEntry(String logBookEntryId) =>
      (delete(catchItems)
            ..where((c) => c.logBookEntryId.equals(logBookEntryId)))
          .go();
}
