import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database/app_database.dart';
import '../domain/entities/haul.dart';
import 'mappers.dart';

/// CRUD & lifecycle for [Haul]s.
class HaulRepository {
  HaulRepository(this._db) : _dao = _db.haulDao;

  final AppDatabase _db;
  final HaulDao _dao;

  final _uuid = const Uuid();

  Future<Haul?> getById(String id) async {
    final row = await _dao.findById(id);
    return row == null ? null : HaulMapper.fromRow(row);
  }

  /// Returns the haul currently being recorded, if any.
  /// Used for crash recovery on app start.
  Future<Haul?> getRecording() async {
    final row = await _dao.findRecording();
    return row == null ? null : HaulMapper.fromRow(row);
  }

  Stream<Haul?> watchRecording() {
    return _dao.watchRecording().map(
          (row) => row == null ? null : HaulMapper.fromRow(row),
        );
  }

  Future<List<Haul>> listByTrip(String tripId) async {
    final rows = await _dao.findByTripId(tripId);
    return rows.map(HaulMapper.fromRow).toList();
  }

  Stream<List<Haul>> watchByTrip(String tripId) {
    return _dao
        .watchByTripId(tripId)
        .map((rows) => rows.map(HaulMapper.fromRow).toList());
  }

  /// Creates a new haul in [HaulStatus.recording] state. Assigns the next
  /// `order_index` automatically (1 for the first haul of a trip).
  Future<Haul> startHaul({
    required String tripId,
    required double trawlWidthMeters,
    DateTime? startedAt,
  }) async {
    final nextOrder = await _dao.highestOrderIndex(tripId) + 1;
    final haul = Haul(
      id: _uuid.v4(),
      tripId: tripId,
      orderIndex: nextOrder,
      startedAt: startedAt ?? DateTime.now(),
      status: HaulStatus.recording,
      trawlWidthMeters: trawlWidthMeters,
    );
    await _dao.insertHaul(HaulMapper.toInsertCompanion(haul));
    return haul;
  }

  Future<void> finalizeHaul(Haul haul) async {
    await _dao.updateHaul(haul.id, HaulMapper.toUpdateCompanion(haul));
  }

  Future<void> rename(String haulId, String? name) async {
    final existing = await getById(haulId);
    if (existing == null) return;
    await _dao.updateHaul(
      haulId,
      HaulMapper.toUpdateCompanion(existing.copyWith(name: name)),
    );
  }

  Future<void> deleteHaul(String haulId) => _dao.deleteHaul(haulId);
}

final haulRepositoryProvider = Provider<HaulRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return HaulRepository(db);
});

final recordingHaulProvider = StreamProvider<Haul?>((ref) {
  return ref.watch(haulRepositoryProvider).watchRecording();
});
