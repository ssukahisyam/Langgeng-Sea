import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database/app_database.dart';
import '../domain/entities/trip.dart';
import '../domain/entities/trip_summary.dart';
import 'mappers.dart';

/// CRUD, lifecycle, and summary reads for [Trip]s. Thin wrapper around
/// [TripDao] that returns domain entities rather than Drift rows.
class TripRepository {
  TripRepository(this._db) : _dao = _db.tripDao;

  final AppDatabase _db;
  final TripDao _dao;

  final _uuid = const Uuid();

  // =========================================================================
  // Lifecycle / CRUD
  // =========================================================================

  Future<Trip?> getActiveTrip() async {
    final row = await _dao.findActive();
    return row == null ? null : TripMapper.fromRow(row);
  }

  Stream<Trip?> watchActiveTrip() {
    return _dao.watchActive().map(
          (row) => row == null ? null : TripMapper.fromRow(row),
        );
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

  // =========================================================================
  // Summaries (History list)
  // =========================================================================

  /// Load all trips plus their aggregated metrics in one pass.
  ///
  /// Sorted newest-first. One query for trips, one per trip for hauls —
  /// the join is done in-memory, which is fine up to O(thousands of
  /// trips) and avoids a hand-written raw SQL GROUP BY.
  Future<List<TripSummary>> listSummaries() async {
    final tripRows = await _dao.findAll();
    if (tripRows.isEmpty) return const [];

    final haulDao = _db.haulDao;
    final result = <TripSummary>[];
    for (final t in tripRows) {
      final hauls = await haulDao.findByTripId(t.id);
      result.add(
        TripSummary(
          trip: TripMapper.fromRow(t),
          haulCount: hauls.length,
          totalDistanceMeters: hauls.fold<double>(
            0,
            (sum, h) => sum + h.distanceMeters,
          ),
          totalDurationSeconds: hauls.fold<int>(
            0,
            (sum, h) => sum + h.durationSeconds,
          ),
          totalSweptAreaM2: hauls.fold<double>(
            0,
            (sum, h) => sum + h.sweptAreaM2,
          ),
        ),
      );
    }
    return result;
  }

  /// Reactive stream that re-fires whenever the trips table changes.
  /// Haul-only edits won't re-fire this — the haul list screen shows the
  /// fresh haul summary directly via [watchByTrip].
  Stream<List<TripSummary>> watchSummaries() {
    return _dao.watchAll().asyncMap((_) => listSummaries());
  }
}

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TripRepository(db);
});

final activeTripProvider = StreamProvider<Trip?>((ref) {
  return ref.watch(tripRepositoryProvider).watchActiveTrip();
});

/// Reactive list of [TripSummary] for the History screen.
final tripSummariesProvider = StreamProvider<List<TripSummary>>((ref) {
  return ref.watch(tripRepositoryProvider).watchSummaries();
});

/// Single-trip watcher used by the detail screen.
final tripByIdProvider =
    FutureProvider.family.autoDispose<Trip?, String>((ref, id) {
  return ref.watch(tripRepositoryProvider).getById(id);
});
