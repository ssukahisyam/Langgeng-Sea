import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/gps_reading.dart';
import '../../../data/database/app_database.dart';
import '../domain/entities/track_point.dart';
import 'haul_repository.dart';
import 'mappers.dart';

/// High-write-volume persistence for GPS points belonging to a haul.
///
/// Every fix the tracking controller keeps is written through here. The
/// insert is single-statement (no transaction) so the per-tick overhead
/// stays small even for 12-hour trips.
class TrackPointRepository {
  TrackPointRepository(this._db) : _dao = _db.trackPointDao;

  final AppDatabase _db;
  final TrackPointDao _dao;

  /// Persist a GpsReading against an active haul. Returns the generated
  /// point id.
  Future<int> appendReading({
    required String haulId,
    required GpsReading reading,
  }) {
    final point = TrackPoint(
      haulId: haulId,
      latitude: reading.latitude,
      longitude: reading.longitude,
      timestamp: reading.timestamp,
      speedMps: reading.speedMps,
      headingDegrees: reading.headingDegrees,
      accuracyMeters: reading.accuracyMeters,
      altitudeMeters: reading.altitudeMeters,
    );
    return _dao.insertPoint(TrackPointMapper.toInsertCompanion(point));
  }

  Future<List<TrackPoint>> getByHaul(String haulId) async {
    final rows = await _dao.findByHaulId(haulId);
    return rows.map(TrackPointMapper.fromRow).toList();
  }

  Stream<List<TrackPoint>> watchByHaul(String haulId) {
    return _dao
        .watchByHaulId(haulId)
        .map((rows) => rows.map(TrackPointMapper.fromRow).toList());
  }

  Future<int> countForHaul(String haulId) => _dao.countForHaul(haulId);
}

final trackPointRepositoryProvider = Provider<TrackPointRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TrackPointRepository(db);
});

/// Watches the points of a specific haul. Used by the haul detail screen
/// to render the polyline even while a haul is still recording.
final trackPointsByHaulProvider =
    StreamProvider.family.autoDispose<List<TrackPoint>, String>((ref, haulId) {
  return ref.watch(trackPointRepositoryProvider).watchByHaul(haulId);
});

/// Loads every point of every haul belonging to [tripId].
///
/// The returned map is keyed by haul id so the trip-detail map can render
/// each haul as its own colored polyline without redistributing the
/// points itself.
final pointsByHaulForTripProvider = FutureProvider.family
    .autoDispose<Map<String, List<TrackPoint>>, String>((ref, tripId) async {
  final haulRepo = ref.watch(haulRepositoryProvider);
  final pointRepo = ref.watch(trackPointRepositoryProvider);

  final hauls = await haulRepo.listByTrip(tripId);
  if (hauls.isEmpty) return const {};

  // N queries (one per haul) is fine at MVP scale (≤10 hauls/trip).
  // Parallelize with Future.wait for a small but free speed-up.
  final results = await Future.wait(
    hauls.map((h) async {
      final points = await pointRepo.getByHaul(h.id);
      return MapEntry(h.id, points);
    }),
  );
  return Map.fromEntries(results);
});
