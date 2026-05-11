import 'package:drift/drift.dart';

import '../app_database.dart';

part 'marker_dao.g.dart';

@DriftAccessor(tables: [Markers])
class MarkerDao extends DatabaseAccessor<AppDatabase> with _$MarkerDaoMixin {
  MarkerDao(super.db);

  Future<void> insertMarker(MarkersCompanion row) =>
      into(markers).insert(row);

  Future<List<MarkerRow>> findAll() {
    return (select(markers)
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .get();
  }

  Stream<List<MarkerRow>> watchAll() {
    return (select(markers)
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .watch();
  }

  Future<MarkerRow?> findById(String id) =>
      (select(markers)..where((m) => m.id.equals(id))).getSingleOrNull();

  Future<int> updateMarker(String id, MarkersCompanion values) =>
      (update(markers)..where((m) => m.id.equals(id))).write(values);

  Future<int> deleteMarker(String id) =>
      (delete(markers)..where((m) => m.id.equals(id))).go();
}
