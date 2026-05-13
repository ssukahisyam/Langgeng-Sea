import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xml/xml.dart';

import '../../../core/observability/logger.dart';
import '../../../core/services/gps_reading.dart';
import '../../marker/data/marker_repository.dart';
import '../../marker/domain/entities/marker.dart';
import '../../tracking/data/haul_repository.dart';
import '../../tracking/data/track_point_repository.dart';
import '../../tracking/data/trip_repository.dart';
import '../../tracking/domain/entities/haul.dart';

class GpxSyncService {
  GpxSyncService(
    this._tripRepo,
    this._haulRepo,
    this._pointRepo,
    this._markerRepo,
  );

  final TripRepository _tripRepo;
  final HaulRepository _haulRepo;
  final TrackPointRepository _pointRepo;
  final MarkerRepository _markerRepo;

  /// Export semua Marker dan Trip ke file GPX dan share
  Future<void> exportToGpx() async {
    try {
      final builder = XmlBuilder();
      builder.processing('xml', 'version="1.0" encoding="UTF-8"');
      builder.element('gpx', attributes: {
        'version': '1.1',
        'creator': 'Langgeng Sea',
        'xmlns': 'http://www.topografix.com/GPX/1/1',
      }, nest: () async {
        // 1. Export Markers as Waypoints
        final markers = await _markerRepo.getAll();
        for (final marker in markers) {
          builder.element('wpt', attributes: {
            'lat': marker.latitude.toString(),
            'lon': marker.longitude.toString(),
          }, nest: () {
            builder.element('name', nest: marker.name);
            builder.element('desc', nest: 'Category: ${marker.category.name}\nNotes: ${marker.notes ?? ''}');
          });
        }

        // 2. Export Trips as Tracks
        final tripSummaries = await _tripRepo.listSummaries();
        for (final summary in tripSummaries) {
          final trip = summary.trip;
          builder.element('trk', nest: () async {
            builder.element('name', nest: trip.name ?? 'Trip ${trip.startedAt.toIso8601String()}');
            if (trip.homePort != null) {
              builder.element('desc', nest: 'Home Port: ${trip.homePort}');
            }

            final hauls = await _haulRepo.listByTrip(trip.id);
            for (final haul in hauls) {
              builder.element('trkseg', nest: () async {
                final points = await _pointRepo.getByHaul(haul.id);
                for (final point in points) {
                  builder.element('trkpt', attributes: {
                    'lat': point.latitude.toString(),
                    'lon': point.longitude.toString(),
                  }, nest: () {
                    builder.element('ele', nest: point.altitudeMeters.toString());
                    builder.element('time', nest: point.timestamp.toIso8601String());
                  });
                }
              });
            }
          });
        }
      });

      final xmlString = builder.buildDocument().toXmlString(pretty: true);
      
      final tempDir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${tempDir.path}/LanggengSea_Backup_$dateStr.gpx');
      await file.writeAsString(xmlString);

      await Share.shareXFiles([XFile(file.path)], text: 'Langgeng Sea GPX Backup');
    } catch (e, st) {
      Logger.instance.error('gpx.export.error', e, st);
      rethrow;
    }
  }

  /// Import GPX file and merge to database
  Future<int> importFromGpx() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Wait, extension filter doesn't always work perfectly on Android
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return 0;
      
      final file = File(result.files.single.path!);
      final xmlString = await file.readAsString();
      final document = XmlDocument.parse(xmlString);
      
      int importedCount = 0;

      // 1. Parse Waypoints
      final wpts = document.findAllElements('wpt');
      for (final wpt in wpts) {
        final latStr = wpt.getAttribute('lat');
        final lonStr = wpt.getAttribute('lon');
        if (latStr == null || lonStr == null) continue;

        final lat = double.tryParse(latStr) ?? 0.0;
        final lon = double.tryParse(lonStr) ?? 0.0;
        
        final name = wpt.findElements('name').firstOrNull?.innerText ?? 'Imported Marker';
        
        await _markerRepo.create(
          name: name,
          category: MarkerCategory.lainnya, // Default category
          latitude: lat,
          longitude: lon,
          notes: 'Imported from GPX',
        );
        importedCount++;
      }

      // 2. Parse Tracks (Trips)
      // Since saving a large GPX could take time, we do it sequentially.
      // TrackPointRepository only has appendReading which takes GpsReading. We'll construct dummy GpsReadings or directly use Dao.
      // Wait, TrackPointRepository has no public raw insert. We'll use appendReading.
      /*
      import '../../../core/services/gps_reading.dart';
      */
      
      final trks = document.findAllElements('trk');
      for (final trk in trks) {
        final name = trk.findElements('name').firstOrNull?.innerText;
        final trip = await _tripRepo.createTrip(name: name ?? 'Imported Trip');
        // Close trip right away since it's imported history
        await _tripRepo.endTrip(trip.id, endedAt: DateTime.now());
        importedCount++;

        final trksegs = trk.findElements('trkseg');
        for (final trkseg in trksegs) {
          final haul = await _haulRepo.startHaul(
            tripId: trip.id,
            trawlWidthMeters: 50.0, // Default
          );
          
          final trkpts = trkseg.findElements('trkpt');
          for (final pt in trkpts) {
            final lat = double.tryParse(pt.getAttribute('lat') ?? '0') ?? 0;
            final lon = double.tryParse(pt.getAttribute('lon') ?? '0') ?? 0;
            final ele = double.tryParse(pt.findElements('ele').firstOrNull?.innerText ?? '0') ?? 0;
            final timeStr = pt.findElements('time').firstOrNull?.innerText;
            final time = timeStr != null ? DateTime.tryParse(timeStr) ?? DateTime.now() : DateTime.now();

            await _pointRepo.appendReading(
              haulId: haul.id,
              reading: GpsReading(
                latitude: lat,
                longitude: lon,
                timestamp: time,
                altitudeMeters: ele,
              ),
            );
          }
          await _haulRepo.finalizeHaul(haul.copyWith(status: HaulStatus.completed));
        }
      }

      return importedCount;
    } catch (e, st) {
      Logger.instance.error('gpx.import.error', e, st);
      rethrow;
    }
  }
}

final gpxSyncServiceProvider = Provider<GpxSyncService>((ref) {
  return GpxSyncService(
    ref.watch(tripRepositoryProvider),
    ref.watch(haulRepositoryProvider),
    ref.watch(trackPointRepositoryProvider),
    ref.watch(markerRepositoryProvider),
  );
});
