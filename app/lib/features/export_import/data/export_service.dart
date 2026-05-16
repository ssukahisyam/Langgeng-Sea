import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../features/logbook/data/log_book_repository.dart';
import '../../../features/logbook/domain/entities/log_book_entry.dart';
import '../../../features/marker/data/marker_repository.dart';
import '../../../features/marker/domain/entities/marker.dart';
import '../../../features/tracking/data/haul_repository.dart';
import '../../../features/tracking/data/track_point_repository.dart';
import '../../../features/tracking/data/trip_repository.dart';
import '../../../features/tracking/domain/entities/haul.dart';
import '../../../features/tracking/domain/entities/track_point.dart';
import '../../../features/tracking/domain/entities/trip.dart';
import 'gpx_exporter.dart';
import 'lsea_json_exporter.dart';

/// Available export formats.
enum ExportFormat { lseaJson, gpx }

/// Orchestrates the export pipeline:
/// 1. Fetch trip + hauls + track points + logbook from repositories
/// 2. Call the appropriate exporter
/// 3. Write to a temp file
/// 4. Return the [File] path for sharing
class ExportService {
  ExportService({
    required this.tripRepository,
    required this.haulRepository,
    required this.trackPointRepository,
    required this.logBookRepository,
    required this.markerRepository,
  });

  final TripRepository tripRepository;
  final HaulRepository haulRepository;
  final TrackPointRepository trackPointRepository;
  final LogBookRepository logBookRepository;
  final MarkerRepository markerRepository;

  final _gpxExporter = GpxExporter();
  final _lseaExporter = LseaJsonExporter();

  /// Generate an export file for the given trip and return the temp [File].
  Future<File> exportTrip({
    required String tripId,
    required ExportFormat format,
    required String userName,
    required String vesselName,
  }) async {
    // 1. Fetch all data
    final trip = await tripRepository.getById(tripId);
    if (trip == null) {
      throw ArgumentError('Trip dengan ID $tripId tidak ditemukan.');
    }

    final hauls = await haulRepository.listByTrip(tripId);
    final pointsByHaul = <String, List<TrackPoint>>{};
    final logBookByHaul = <String, LogBookEntry>{};

    for (final haul in hauls) {
      pointsByHaul[haul.id] = await trackPointRepository.getByHaul(haul.id);
      final logBook = await logBookRepository.getByHaulId(haul.id);
      if (logBook != null) {
        logBookByHaul[haul.id] = logBook;
      }
    }

    // Markers are global (not scoped to a trip) so we attach all of
    // them. They appear as <wpt> waypoints in the GPX output and as
    // a top-level "markers" array in the .lsea.json output. This is
    // the receiver's most-requested feature: spot lokasi yang sudah
    // ditandai pengirim.
    final List<AppMarker> markers = await markerRepository.getAll();

    // 2. Generate content
    final String content;
    final String extension;

    switch (format) {
      case ExportFormat.gpx:
        content = _gpxExporter.exportTrip(
          trip,
          hauls,
          pointsByHaul,
          markers: markers,
        );
        extension = 'gpx';
      case ExportFormat.lseaJson:
        content = _lseaExporter.exportTrip(
          trip: trip,
          hauls: hauls,
          pointsByHaul: pointsByHaul,
          logBookByHaul: logBookByHaul,
          markers: markers,
          userName: userName,
          vesselName: vesselName,
        );
        extension = 'lsea.json';
    }

    // 3. Write to temp directory
    final tempDir = await getTemporaryDirectory();
    final fileName = _buildFileName(trip, hauls, extension);
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(content);

    return file;
  }

  String _buildFileName(Trip trip, List<Haul> hauls, String extension) {
    final datePart = trip.startedAt.toIso8601String().substring(0, 10);
    final tripName = trip.name?.replaceAll(RegExp(r'[^\w]'), '_') ?? 'trip';
    return 'langgeng_sea_${tripName}_$datePart.$extension';
  }
}

// =============================================================================
// Riverpod Provider
// =============================================================================

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(
    tripRepository: ref.watch(tripRepositoryProvider),
    haulRepository: ref.watch(haulRepositoryProvider),
    trackPointRepository: ref.watch(trackPointRepositoryProvider),
    logBookRepository: ref.watch(logBookRepositoryProvider),
    markerRepository: ref.watch(markerRepositoryProvider),
  );
});
