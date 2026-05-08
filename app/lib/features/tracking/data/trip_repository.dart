import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database/app_database.dart';
import '../domain/entities/trip.dart';
import 'mappers.dart';

/// CRUD & lifecycle for [Trip]s. Thin wrapper around [TripDao] that
/// returns domain entities rather than Drift rows.
class TripRepository {
  TripRepository(this._db) : _dao = _db.tripDao;

  final AppDatabase _db;
  final TripDao _dao;

  final _uuid = const Uuid();

  Future<Trip?> getActiveTrip() async {
    final row = await _dao.findActive();
    return row == null ? null : TripMapper.fromRow(row);
  }

  Stream<Trip?> watchActiveTrip() {
    return _dao.watchActive().map((row) => row == null ? null : TripMapper.fromRow(row));
  }

  Future<Trip?> getById(String id) async {
    final row = await _dao.findById(id);
    return row == null ? null : TripMapper.fromRow(row);
  }

  /// Creates a new trip in [TripStatus.active] state. Idempotent-ish:
  /// callers should [getActiveTrip] first and only create when null.
  Future<Trip> createTrip({
    String? name,
    String? homePort,
    DateTime? startedAt,
  }) async {
    final now = startedAt ?? DateTime.now();
    final trip = Trip(
      id: _uuid.v4(),
      name: name,
      startedAt: now,
      status: TripStatus.active,
      homePort: homePort,
    );
    await _dao.insertTrip(TripMapper.toInsertCompanion(trip));
    return trip;
  }

  Future<void> endTrip(String tripId, {DateTime? endedAt}) async {
    final existing = await getById(tripId);
    if (existing == null) return;
    final updated = existing.copyWith(
      status: TripStatus.completed,
      endedAt: endedAt ?? DateTime.now(),
    );
    await _dao.updateTrip(tripId, TripMapper.toUpdateCompanion(updated));
  }

  Future<void> rename(String tripId, String? name) async {
    final existing = await getById(tripId);
    if (existing == null) return;
    await _dao.updateTrip(
      tripId,
      TripMapper.toUpdateCompanion(existing.copyWith(name: name)),
    );
  }

  Future<void> deleteTrip(String tripId) => _dao.deleteTrip(tripId);

  /// Returns the active trip, or creates a new one atomically. Used by
  /// "MULAI TEBAR" so the user doesn't have to explicitly start a trip.
  Future<Trip> getOrStartActiveTrip() async {
    final existing = await getActiveTrip();
    if (existing != null) return existing;
    return createTrip();
  }
}

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TripRepository(db);
});

final activeTripProvider = StreamProvider<Trip?>((ref) {
  return ref.watch(tripRepositoryProvider).watchActiveTrip();
});
