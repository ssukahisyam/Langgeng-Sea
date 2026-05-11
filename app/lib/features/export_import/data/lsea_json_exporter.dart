import 'dart:convert';

import '../../../features/logbook/domain/entities/catch_item.dart';
import '../../../features/logbook/domain/entities/log_book_entry.dart';
import '../../../features/tracking/domain/entities/haul.dart';
import '../../../features/tracking/domain/entities/track_point.dart';
import '../../../features/tracking/domain/entities/trip.dart';

/// Exports trip data in the proprietary `.lsea.json` format.
///
/// Format spec:
/// ```json
/// {
///   "format": "langgeng-sea-v1",
///   "exportedAt": "ISO-8601",
///   "exportedBy": { "name": "...", "vessel": "..." },
///   "trip": { ... },
///   "markers": []
/// }
/// ```
class LseaJsonExporter {
  /// Export a complete trip with hauls, track points, and logbook data.
  String exportTrip({
    required Trip trip,
    required List<Haul> hauls,
    required Map<String, List<TrackPoint>> pointsByHaul,
    required Map<String, LogBookEntry> logBookByHaul,
    required String userName,
    required String vesselName,
  }) {
    final data = <String, dynamic>{
      'format': 'langgeng-sea-v1',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'exportedBy': {
        'name': userName,
        'vessel': vesselName,
      },
      'trip': _tripToJson(trip, hauls, pointsByHaul, logBookByHaul),
      'markers': <dynamic>[],
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Map<String, dynamic> _tripToJson(
    Trip trip,
    List<Haul> hauls,
    Map<String, List<TrackPoint>> pointsByHaul,
    Map<String, LogBookEntry> logBookByHaul,
  ) {
    return {
      'id': trip.id,
      'name': trip.name,
      'startedAt': trip.startedAt.toUtc().toIso8601String(),
      'endedAt': trip.endedAt?.toUtc().toIso8601String(),
      'status': trip.status.name,
      'homePort': trip.homePort,
      'notes': trip.notes,
      'hauls': hauls
          .map((h) => _haulToJson(h, pointsByHaul, logBookByHaul))
          .toList(),
    };
  }

  Map<String, dynamic> _haulToJson(
    Haul haul,
    Map<String, List<TrackPoint>> pointsByHaul,
    Map<String, LogBookEntry> logBookByHaul,
  ) {
    final points = pointsByHaul[haul.id] ?? [];
    final logBook = logBookByHaul[haul.id];

    return {
      'id': haul.id,
      'orderIndex': haul.orderIndex,
      'name': haul.name,
      'startedAt': haul.startedAt.toUtc().toIso8601String(),
      'endedAt': haul.endedAt?.toUtc().toIso8601String(),
      'status': haul.status.name,
      'trawlWidthMeters': haul.trawlWidthMeters,
      'distanceMeters': haul.distanceMeters,
      'durationSeconds': haul.durationSeconds,
      'avgSpeedKnots': haul.avgSpeedKnots,
      'avgHeadingDegrees': haul.avgHeadingDegrees,
      'sweptAreaM2': haul.sweptAreaM2,
      'notes': haul.notes,
      'trackPoints': points.map(_pointToJson).toList(),
      'logBook': logBook != null ? _logBookToJson(logBook) : null,
    };
  }

  Map<String, dynamic> _pointToJson(TrackPoint pt) {
    return {
      'lat': pt.latitude,
      'lon': pt.longitude,
      'timestamp': pt.timestamp.toUtc().toIso8601String(),
      'speedMps': pt.speedMps,
      'headingDegrees': pt.headingDegrees,
      'accuracyMeters': pt.accuracyMeters,
    };
  }

  Map<String, dynamic> _logBookToJson(LogBookEntry entry) {
    return {
      'weather': entry.weather?.name,
      'wave': entry.wave?.name,
      'fuelLiters': entry.fuelLiters,
      'costRupiah': entry.costRupiah,
      'crewCount': entry.crewCount,
      'notes': entry.notes,
      'catches': entry.catches.map(_catchToJson).toList(),
    };
  }

  Map<String, dynamic> _catchToJson(CatchItem item) {
    return {
      'species': item.species,
      'weightKg': item.weightKg,
    };
  }
}
