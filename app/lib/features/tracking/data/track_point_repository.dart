import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/gps_reading.dart';
import '../../../data/database/app_database.dart';
import '../domain/entities/track_point.dart';
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

final trackPointRepositoryProvider =
    Provider<TrackPointRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TrackPointRepository(db);
});
