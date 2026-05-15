import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../data/database/app_database.dart';
import '../../marker/data/marker_repository.dart';
import '../../marker/domain/entities/marker.dart';
import '../../../features/tracking/data/haul_repository.dart';
import '../../../features/tracking/data/mappers.dart';
import '../../../features/tracking/domain/entities/haul.dart';
import '../../../features/tracking/domain/entities/track_point.dart';
import '../../../features/tracking/domain/entities/trip.dart';

/// Generates GPX 1.1 XML from haul/trip track data.
///
/// Uses [StringBuffer] for simplicity — GPX structure is flat enough
/// that a full XML builder (like the `xml` package) isn't warranted.
class GpxExporter {
  /// Export a single haul as a GPX `<trk>`.
  String exportHaul(Haul haul, List<TrackPoint> points) {
    final buf = StringBuffer();
    _writeHeader(buf);
    _writeTrack(buf, haul.displayName(), points);
    _writeFooter(buf);
    return buf.toString();
  }

  /// Export an entire trip (all hauls) as a multi-track GPX.
  String exportTrip(
    Trip trip,
    List<Haul> hauls,
    Map<String, List<TrackPoint>> pointsByHaul,
  ) {
    final buf = StringBuffer();
    _writeHeader(buf);

    for (final haul in hauls) {
      final points = pointsByHaul[haul.id] ?? [];
      _writeTrack(buf, haul.displayName(), points);
    }

    _writeFooter(buf);
    return buf.toString();
  }

  void _writeHeader(StringBuffer buf) {
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln(
      '<gpx version="1.1" creator="Langgeng Sea" '
      'xmlns="http://www.topografix.com/GPX/1/1" '
      'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
      'xsi:schemaLocation="http://www.topografix.com/GPX/1/1 '
      'http://www.topografix.com/GPX/1/1/gpx.xsd">',
    );
  }

  void _writeTrack(StringBuffer buf, String name, List<TrackPoint> points) {
    buf.writeln('  <trk>');
    buf.writeln('    <name>${_escapeXml(name)}</name>');
    buf.writeln('    <trkseg>');

    for (final pt in points) {
      buf.write(
        '      <trkpt lat="${pt.latitude}" lon="${pt.longitude}">',
      );
      buf.write('<time>${pt.timestamp.toUtc().toIso8601String()}</time>');
      if (pt.speedMps != null) {
        buf.write('<speed>${pt.speedMps!.toStringAsFixed(2)}</speed>');
      }
      buf.writeln('</trkpt>');
    }

    buf.writeln('    </trkseg>');
    buf.writeln('  </trk>');
  }

  void _writeFooter(StringBuffer buf) {
    buf.writeln('</gpx>');
  }

  String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Write GPX `<wpt>` elements for markers / waypoints.
  void _writeWaypoints(StringBuffer buf, List<AppMarker> markers) {
    for (final m in markers) {
      buf.write(
        '  <wpt lat="${m.latitude}" lon="${m.longitude}">',
      );
      buf.write('<name>${_escapeXml(m.name)}</name>');
      if (m.notes != null && m.notes!.isNotEmpty) {
        buf.write('<desc>${_escapeXml(m.notes!)}</desc>');
      }
      buf.writeln('</wpt>');
    }
  }

  /// Export all data based on user selection. Returns a temporary .gpx file.
  ///
  /// Issue 6 fix: supports selective export — tracks only, markers only,
  /// or both. Called from [ExportScreen].
  Future<File> exportAll({
    required bool includeTracks,
    required bool includeMarkers,
    List<Haul> hauls = const [],
    Map<String, List<TrackPoint>> pointsByHaul = const {},
    List<AppMarker> markers = const [],
  }) async {
    final buf = StringBuffer();
    _writeHeader(buf);

    if (includeMarkers) {
      _writeWaypoints(buf, markers);
    }

    if (includeTracks) {
      for (final haul in hauls) {
        final points = pointsByHaul[haul.id] ?? [];
        if (points.isNotEmpty) {
          _writeTrack(buf, haul.displayName(), points);
        }
      }
    }

    _writeFooter(buf);

    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/langgeng_sea_$timestamp.gpx');
    await file.writeAsString(buf.toString());
    return file;
  }
}

/// Riverpod provider for [GpxExporter].
///
/// This is a higher-level wrapper that fetches data from repositories
/// then delegates to [GpxExporter.exportAll].
class GpxExporterService {
  GpxExporterService(this._ref);

  final Ref _ref;
  final _exporter = GpxExporter();

  /// Export all available data with given filters.
  Future<File> exportAll({
    required bool includeTracks,
    required bool includeMarkers,
  }) async {
    List<Haul> hauls = [];
    Map<String, List<TrackPoint>> pointsByHaul = {};
    List<AppMarker> markers = [];

    if (includeTracks) {
      // Fix: previous code called listAll()/getTrackPoints() which don't
      // exist on HaulRepository — methods threw and the silent catch in
      // the export screen produced an empty <gpx/> file. We now use the
      // real APIs: listAllCompleted() + the track-point DAO directly.
      final haulRepo = _ref.read(haulRepositoryProvider);
      hauls = await haulRepo.listAllCompleted();
      final db = _ref.read(appDatabaseProvider);
      for (final haul in hauls) {
        final rows = await db.trackPointDao.findByHaulId(haul.id);
        pointsByHaul[haul.id] = rows.map(TrackPointMapper.fromRow).toList();
      }
    }

    if (includeMarkers) {
      markers = await _ref.read(markerRepositoryProvider).getAll();
    }

    return _exporter.exportAll(
      includeTracks: includeTracks,
      includeMarkers: includeMarkers,
      hauls: hauls,
      pointsByHaul: pointsByHaul,
      markers: markers,
    );
  }
}

final gpxExporterProvider = Provider<GpxExporterService>((ref) {
  return GpxExporterService(ref);
});
