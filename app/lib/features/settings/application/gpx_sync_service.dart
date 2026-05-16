import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xml/xml.dart';

import '../../../core/observability/logger.dart';
import '../../../core/services/gps_reading.dart';
import '../../export_import/data/gpx_exporter.dart';
import '../../marker/data/marker_repository.dart';
import '../../marker/domain/entities/marker.dart';
import '../../tracking/data/haul_repository.dart';
import '../../tracking/data/track_point_repository.dart';
import '../../tracking/data/trip_repository.dart';
import '../../tracking/domain/entities/haul.dart';

/// One-tap GPX export/import surfaced on the Settings screen.
///
/// This is a thin convenience wrapper:
///
/// - [exportToGpx] delegates to [GpxExporterService] (which uses an
///   `XmlBuilder` properly — the previous string-buffer + nested-async
///   approach silently produced a self-closing `<gpx ... />` because
///   `XmlBuilder.element(..., nest: () async { ... })` does not await
///   the callback). Then opens the share sheet so the user can hand
///   the file to a backup app, email, or another HP.
///
/// - [importFromGpx] picks a `.gpx` file, parses waypoints + tracks,
///   and reconstructs them as Markers + Trips/Hauls/TrackPoints in
///   the local DB. Designed to round-trip data exported by
///   [exportToGpx], plus accept generic GPX files from third-party
///   apps (Garmin, Strava, OsmAnd) — those will only contribute
///   waypoints + raw track points, not Langgeng-Sea-specific haul
///   metadata.
class GpxSyncService {
  GpxSyncService(
    this._ref,
    this._tripRepo,
    this._haulRepo,
    this._pointRepo,
    this._markerRepo,
  );

  final Ref _ref;
  final TripRepository _tripRepo;
  final HaulRepository _haulRepo;
  final TrackPointRepository _pointRepo;
  final MarkerRepository _markerRepo;

  /// Export EVERYTHING (all hauls + all markers) to a single .gpx and
  /// hand it to the system share sheet.
  Future<void> exportToGpx() async {
    try {
      final exporter = _ref.read(gpxExporterProvider);
      final result = await exporter.exportAll(
        includeTracks: true,
        includeMarkers: true,
      );
      if (result.isEmpty) {
        Logger.instance.info('gpx.export.empty', const {});
        // Caller surfaces a snackbar; we still share the (mostly-)empty
        // file so the user gets feedback that the action ran.
      }
      await Share.shareXFiles(
        [XFile(result.file.path)],
        text: 'Backup GPX Langgeng Sea',
        subject: 'Backup data Langgeng Sea',
      );
    } catch (e, st) {
      Logger.instance.error('gpx.export.error', e, st);
      rethrow;
    }
  }

  /// Pick a `.gpx` file from the device, parse it, and merge into the
  /// local DB. Returns the total number of items inserted (hauls +
  /// markers). 0 means the user cancelled the picker.
  Future<int> importFromGpx() async {
    try {
      // FileType.custom + allowedExtensions is unreliable on some
      // Android OEMs (Xiaomi, Samsung) — they show an empty picker
      // and the user has to "tap anywhere" to escape. FileType.any
      // works universally; we just validate the extension after pick.
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return 0;

      final picked = result.files.single;
      final path = picked.path;
      if (path == null) return 0;
      if (!path.toLowerCase().endsWith('.gpx')) {
        throw const FormatException(
          'Bukan file GPX. Pilih file dengan ekstensi .gpx',
        );
      }

      final file = File(path);
      final xmlString = await file.readAsString();
      final document = XmlDocument.parse(xmlString);

      var importedCount = 0;

      // 1. Waypoints → Markers.
      for (final wpt in document.findAllElements('wpt')) {
        final latStr = wpt.getAttribute('lat');
        final lonStr = wpt.getAttribute('lon');
        final lat = double.tryParse(latStr ?? '');
        final lon = double.tryParse(lonStr ?? '');
        if (lat == null || lon == null) continue;
        final name = wpt
                .findElements('name')
                .firstOrNull
                ?.innerText
                .trim() ??
            '';
        final desc = wpt.findElements('desc').firstOrNull?.innerText.trim();
        await _markerRepo.create(
          name: name.isEmpty ? 'Waypoint' : name,
          category: MarkerCategory.other,
          latitude: lat,
          longitude: lon,
          notes: (desc == null || desc.isEmpty)
              ? 'Diimpor dari GPX'
              : desc,
        );
        importedCount++;
      }

      // 2. Tracks → Trip + Hauls + TrackPoints.
      // Each <trk> becomes a fresh Trip with status=completed; each
      // <trkseg> becomes one Haul under that trip. We replay every
      // <trkpt> through TrackPointRepository.appendReading so the
      // existing aggregate computation (distance, duration) runs, then
      // finalize the haul.
      for (final trk in document.findAllElements('trk')) {
        final tripName = trk
            .findElements('name')
            .firstOrNull
            ?.innerText
            .trim();
        final trip = await _tripRepo.createTrip(
          name: (tripName == null || tripName.isEmpty)
              ? 'Trip Diimpor'
              : tripName,
        );
        importedCount++;

        for (final trkseg in trk.findElements('trkseg')) {
          final haul = await _haulRepo.startHaul(
            tripId: trip.id,
            trawlWidthMeters: 20.0,
          );
          for (final pt in trkseg.findElements('trkpt')) {
            final lat = double.tryParse(pt.getAttribute('lat') ?? '');
            final lon = double.tryParse(pt.getAttribute('lon') ?? '');
            if (lat == null || lon == null) continue;
            final ele = double.tryParse(
                pt.findElements('ele').firstOrNull?.innerText ?? '');
            final timeStr =
                pt.findElements('time').firstOrNull?.innerText.trim();
            final time =
                (timeStr != null) ? DateTime.tryParse(timeStr) : null;
            await _pointRepo.appendReading(
              haulId: haul.id,
              reading: GpsReading(
                latitude: lat,
                longitude: lon,
                timestamp: time ?? DateTime.now(),
                altitudeMeters: ele,
              ),
            );
          }
          await _haulRepo
              .finalizeHaul(haul.copyWith(status: HaulStatus.completed));
        }

        await _tripRepo.endTrip(trip.id, endedAt: DateTime.now());
      }

      Logger.instance.info('gpx.import.done', {'imported': importedCount});
      return importedCount;
    } catch (e, st) {
      Logger.instance.error('gpx.import.error', e, st);
      rethrow;
    }
  }
}

final gpxSyncServiceProvider = Provider<GpxSyncService>((ref) {
  return GpxSyncService(
    ref,
    ref.watch(tripRepositoryProvider),
    ref.watch(haulRepositoryProvider),
    ref.watch(trackPointRepositoryProvider),
    ref.watch(markerRepositoryProvider),
  );
});
