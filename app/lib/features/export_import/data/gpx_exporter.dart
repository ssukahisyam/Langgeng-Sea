import 'package:xml/xml.dart';

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

import '../../../core/observability/logger.dart';
import '../../../data/database/app_database.dart';
import '../../marker/data/marker_repository.dart';
import '../../marker/domain/entities/marker.dart';
import '../../tracking/data/haul_repository.dart';
import '../../tracking/data/mappers.dart';
import '../../tracking/domain/entities/haul.dart';
import '../../tracking/domain/entities/track_point.dart';
import '../../tracking/domain/entities/trip.dart';

/// Generates GPX 1.1 XML from haul/trip track data.
///
/// Implementation now uses the `xml` package (already in pubspec) so the
/// output is always well-formed and properly escaped, regardless of edge
/// cases (empty hauls, empty trip, special characters in names, etc).
///
/// The previous string-buffer implementation produced a self-closing
/// root `<gpx ... />` element when the trip had no hauls or all hauls
/// had no track points, which made the file look broken to users
/// ("hanya menghasilkan tag gpx kosong"). The builder below always
/// emits at minimum a `<metadata>` block so the file is informative
/// even when no track data is available, and emits a `<trk>` per haul
/// so the receiver can see which hauls existed even when they have no
/// fixes recorded.
///
/// GPX namespace + Langgeng Sea custom extensions (`xmlns:lsea`) make
/// it possible to round-trip extra fields (haul stats, marker
/// category, trawl width) without breaking compatibility with
/// generic GPX consumers like Google Earth, Garmin BaseCamp, or
/// QGIS — they just ignore the unknown extension namespace.
class GpxExporter {
  static const String _gpxNs = 'http://www.topografix.com/GPX/1/1';
  static const String _xsiNs = 'http://www.w3.org/2001/XMLSchema-instance';
  static const String _lseaNs = 'https://langgengsea.id/gpx/extensions/v1';
  static const String _xsiSchemaLocation =
      'http://www.topografix.com/GPX/1/1 '
      'http://www.topografix.com/GPX/1/1/gpx.xsd';

  static const String _creator = 'Langgeng Sea';

  /// Export a single haul as a GPX track. Useful when sharing one haul
  /// in isolation (e.g. from haul detail).
  String exportHaul(
    Haul haul,
    List<TrackPoint> points, {
    Trip? parentTrip,
  }) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('gpx', nest: () {
      _writeRootAttributes(builder);
      _writeMetadata(
        builder,
        title: haul.displayName(),
        description: parentTrip?.name,
        bounds: _boundsForPoints(points),
      );
      _writeTrack(builder, haul, points);
    });
    return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  /// Export an entire trip as a multi-track GPX, with optional waypoints
  /// for the user's saved markers. This is the format used by the
  /// "Bagikan Sekarang" flow when the user picks "GPX Universal".
  String exportTrip(
    Trip trip,
    List<Haul> hauls,
    Map<String, List<TrackPoint>> pointsByHaul, {
    List<AppMarker> markers = const [],
  }) {
    final allPoints = <TrackPoint>[
      for (final list in pointsByHaul.values) ...list,
    ];
    final markerLatLngs = markers
        .map((m) => _LatLng(m.latitude, m.longitude))
        .toList(growable: false);

    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('gpx', nest: () {
      _writeRootAttributes(builder);
      _writeMetadata(
        builder,
        title: trip.name ?? 'Trip Langgeng Sea',
        description: _tripDescription(trip, hauls),
        bounds: _boundsCombined(
          allPoints.map((p) => _LatLng(p.latitude, p.longitude)),
          markerLatLngs,
        ),
        tripExtensions: () => _writeTripExtensions(builder, trip, hauls),
      );

      // Markers first so they show up at the top of typical GPX
      // viewers. GPX 1.1 schema requires <wpt>* before <rte>* /
      // <trk>*, so this also keeps the document schema-valid.
      for (final marker in markers) {
        _writeWaypoint(builder, marker);
      }

      // One <trk> per haul. Hauls with no points still get a stub so
      // the receiver knows the haul exists, with an `<lsea:note>`
      // explaining why the segment is empty.
      for (final haul in hauls) {
        final points = pointsByHaul[haul.id] ?? const <TrackPoint>[];
        _writeTrack(builder, haul, points);
      }
    });

    return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  // ===========================================================================
  // Builder helpers
  // ===========================================================================

  void _writeRootAttributes(XmlBuilder builder) {
    builder.attribute('version', '1.1');
    builder.attribute('creator', _creator);
    builder.attribute('xmlns', _gpxNs);
    builder.attribute('xmlns:xsi', _xsiNs);
    builder.attribute('xmlns:lsea', _lseaNs);
    builder.attribute('xsi:schemaLocation', _xsiSchemaLocation);
  }

  void _writeMetadata(
    XmlBuilder builder, {
    required String title,
    String? description,
    _Bounds? bounds,
    void Function()? tripExtensions,
  }) {
    builder.element('metadata', nest: () {
      builder.element('name', nest: title);
      if (description != null && description.isNotEmpty) {
        builder.element('desc', nest: description);
      }
      builder.element('author', nest: () {
        builder.element('name', nest: _creator);
        builder.element('link', nest: () {
          builder.attribute('href', 'https://langgengsea.id');
          builder.element('text', nest: 'Langgeng Sea');
        });
      });
      builder.element(
        'time',
        nest: DateTime.now().toUtc().toIso8601String(),
      );
      if (bounds != null) {
        builder.element('bounds', nest: () {
          builder.attribute('minlat', _formatCoord(bounds.minLat));
          builder.attribute('minlon', _formatCoord(bounds.minLon));
          builder.attribute('maxlat', _formatCoord(bounds.maxLat));
          builder.attribute('maxlon', _formatCoord(bounds.maxLon));
        });
      }
      if (tripExtensions != null) {
        builder.element('extensions', nest: tripExtensions);
      }
    });
  }

  void _writeTripExtensions(
    XmlBuilder builder,
    Trip trip,
    List<Haul> hauls,
  ) {
    final totalDistance = hauls.fold<double>(
      0,
      (sum, h) => sum + h.distanceMeters,
    );
    final totalDuration = hauls.fold<int>(
      0,
      (sum, h) => sum + h.durationSeconds,
    );
    final totalSweptArea = hauls.fold<double>(
      0,
      (sum, h) => sum + h.sweptAreaM2,
    );

    builder.element('lsea:trip', nest: () {
      builder.attribute('id', trip.id);
      builder.attribute('status', trip.status.name);
      builder.element(
        'lsea:startedAt',
        nest: trip.startedAt.toUtc().toIso8601String(),
      );
      if (trip.endedAt != null) {
        builder.element(
          'lsea:endedAt',
          nest: trip.endedAt!.toUtc().toIso8601String(),
        );
      }
      builder.element('lsea:haulCount', nest: hauls.length.toString());
      builder.element(
        'lsea:totalDistanceMeters',
        nest: totalDistance.toStringAsFixed(2),
      );
      builder.element(
        'lsea:totalDurationSeconds',
        nest: totalDuration.toString(),
      );
      builder.element(
        'lsea:totalSweptAreaM2',
        nest: totalSweptArea.toStringAsFixed(2),
      );
      if (trip.homePort != null && trip.homePort!.isNotEmpty) {
        builder.element('lsea:homePort', nest: trip.homePort!);
      }
    });
  }

  void _writeWaypoint(XmlBuilder builder, AppMarker marker) {
    builder.element('wpt', nest: () {
      builder.attribute('lat', _formatCoord(marker.latitude));
      builder.attribute('lon', _formatCoord(marker.longitude));
      builder.element(
        'time',
        nest: marker.createdAt.toUtc().toIso8601String(),
      );
      builder.element('name', nest: marker.name);
      if (marker.notes != null && marker.notes!.isNotEmpty) {
        builder.element('desc', nest: marker.notes!);
      }
      builder.element('sym', nest: _symbolForCategory(marker.category));
      builder.element('type', nest: marker.category.displayLabel);
      builder.element('extensions', nest: () {
        builder.element('lsea:marker', nest: () {
          builder.attribute('id', marker.id);
          builder.attribute('category', marker.category.storageKey);
        });
      });
    });
  }

  void _writeTrack(XmlBuilder builder, Haul haul, List<TrackPoint> points) {
    builder.element('trk', nest: () {
      builder.element('name', nest: haul.displayName());
      builder.element(
        'desc',
        nest: 'Tarikan #${haul.orderIndex} '
            '· lebar trawl ${haul.trawlWidthMeters.toStringAsFixed(1)} m',
      );
      builder.element('type', nest: 'fishing-haul');

      builder.element('extensions', nest: () {
        builder.element('lsea:haul', nest: () {
          builder.attribute('id', haul.id);
          builder.attribute('orderIndex', haul.orderIndex.toString());
          builder.attribute('status', haul.status.name);
          builder.element(
            'lsea:startedAt',
            nest: haul.startedAt.toUtc().toIso8601String(),
          );
          if (haul.endedAt != null) {
            builder.element(
              'lsea:endedAt',
              nest: haul.endedAt!.toUtc().toIso8601String(),
            );
          }
          builder.element(
            'lsea:trawlWidthMeters',
            nest: haul.trawlWidthMeters.toStringAsFixed(2),
          );
          builder.element(
            'lsea:distanceMeters',
            nest: haul.distanceMeters.toStringAsFixed(2),
          );
          builder.element(
            'lsea:durationSeconds',
            nest: haul.durationSeconds.toString(),
          );
          if (haul.avgSpeedKnots != null) {
            builder.element(
              'lsea:avgSpeedKnots',
              nest: haul.avgSpeedKnots!.toStringAsFixed(2),
            );
          }
          if (haul.avgHeadingDegrees != null) {
            builder.element(
              'lsea:avgHeadingDegrees',
              nest: haul.avgHeadingDegrees!.toStringAsFixed(1),
            );
          }
          builder.element(
            'lsea:sweptAreaM2',
            nest: haul.sweptAreaM2.toStringAsFixed(2),
          );
        });
      });

      // Always emit a <trkseg>, even when empty, so the document
      // schema stays consistent. Empty <trkseg/> is valid GPX 1.1.
      builder.element('trkseg', nest: () {
        for (final pt in points) {
          builder.element('trkpt', nest: () {
            builder.attribute('lat', _formatCoord(pt.latitude));
            builder.attribute('lon', _formatCoord(pt.longitude));
            if (pt.altitudeMeters != null) {
              builder.element(
                'ele',
                nest: pt.altitudeMeters!.toStringAsFixed(2),
              );
            }
            builder.element(
              'time',
              nest: pt.timestamp.toUtc().toIso8601String(),
            );
            if (pt.speedMps != null) {
              builder.element(
                'speed',
                nest: pt.speedMps!.toStringAsFixed(2),
              );
            }
            // GPX 1.1 doesn't define `<course>` / `<speed>` in the
            // base schema, so we also surface heading + accuracy in
            // an lsea:trkpt extension for round-tripping.
            if (pt.headingDegrees != null || pt.accuracyMeters != null) {
              builder.element('extensions', nest: () {
                builder.element('lsea:trkpt', nest: () {
                  if (pt.headingDegrees != null) {
                    builder.element(
                      'lsea:headingDegrees',
                      nest: pt.headingDegrees!.toStringAsFixed(1),
                    );
                  }
                  if (pt.accuracyMeters != null) {
                    builder.element(
                      'lsea:accuracyMeters',
                      nest: pt.accuracyMeters!.toStringAsFixed(2),
                    );
                  }
                });
              });
            }
          });
        }
      });
    });
  }

  // ===========================================================================
  // Pure helpers
  // ===========================================================================

  String _tripDescription(Trip trip, List<Haul> hauls) {
    final pieces = <String>[];
    pieces.add('${hauls.length} tarikan');
    final totalDistance = hauls.fold<double>(
      0,
      (sum, h) => sum + h.distanceMeters,
    );
    if (totalDistance > 0) {
      pieces.add('${(totalDistance / 1000).toStringAsFixed(2)} km total');
    }
    if (trip.homePort != null && trip.homePort!.isNotEmpty) {
      pieces.add('Pelabuhan: ${trip.homePort!}');
    }
    return pieces.join(' · ');
  }

  String _symbolForCategory(MarkerCategory category) {
    // Names taken from common GPX viewer symbol sets (Garmin compat).
    return switch (category) {
      MarkerCategory.productive => 'Fishing Hot Spot',
      MarkerCategory.hazard => 'Skull and Crossbones',
      MarkerCategory.port => 'Anchor',
      MarkerCategory.other => 'Flag, Blue',
    };
  }

  /// Format a coordinate with up to 7 decimal places (≈1 cm precision)
  /// without trailing zeros, so files stay compact.
  String _formatCoord(double value) {
    final s = value.toStringAsFixed(7);
    // Strip trailing zeros + dangling decimal point.
    var trimmed = s;
    if (trimmed.contains('.')) {
      trimmed = trimmed.replaceFirst(RegExp(r'0+$'), '');
      trimmed = trimmed.replaceFirst(RegExp(r'\.$'), '');
    }
    return trimmed;
  }

  _Bounds? _boundsForPoints(Iterable<TrackPoint> points) {
    return _boundsCombined(
      points.map((p) => _LatLng(p.latitude, p.longitude)),
      const [],
    );
  }

  _Bounds? _boundsCombined(
    Iterable<_LatLng> trackPoints,
    Iterable<_LatLng> waypoints,
  ) {
    double? minLat, minLon, maxLat, maxLon;
    void include(_LatLng pt) {
      minLat = (minLat == null || pt.lat < minLat!) ? pt.lat : minLat;
      maxLat = (maxLat == null || pt.lat > maxLat!) ? pt.lat : maxLat;
      minLon = (minLon == null || pt.lon < minLon!) ? pt.lon : minLon;
      maxLon = (maxLon == null || pt.lon > maxLon!) ? pt.lon : maxLon;
    }

    for (final p in trackPoints) {
      include(p);
    }
    for (final p in waypoints) {
      include(p);
    }
    if (minLat == null) return null;
    return _Bounds(
      minLat: minLat!,
      minLon: minLon!,
      maxLat: maxLat!,
      maxLon: maxLon!,
    );
  }

  // ===========================================================================
  // exportAll(...) — global export with optional category filtering
  // ===========================================================================
  //
  // Used by the global ExportScreen (Settings → Ekspor Data GPX) which lets
  // the user pick "Semua / Jalur / Penanda" via checkboxes. This is a
  // separate entry point from `exportTrip(...)` (per-trip share) — both
  // produce GPX 1.1 with the same root, metadata, and lsea: extensions.
  //
  // Writes to a temp file and returns the [File] for the share sheet.

  Future<File> exportAll({
    required bool includeTracks,
    required bool includeMarkers,
    List<Haul> hauls = const [],
    Map<String, List<TrackPoint>> pointsByHaul = const {},
    List<AppMarker> markers = const [],
  }) async {
    // Filter haul list down to only what the user asked for.
    final List<Haul> effectiveHauls = includeTracks ? hauls : const [];
    final List<AppMarker> effectiveMarkers =
        includeMarkers ? markers : const [];

    final allPoints = <TrackPoint>[
      for (final h in effectiveHauls)
        ...(pointsByHaul[h.id] ?? const <TrackPoint>[]),
    ];
    final markerLatLngs = effectiveMarkers
        .map((m) => _LatLng(m.latitude, m.longitude))
        .toList(growable: false);

    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('gpx', nest: () {
      _writeRootAttributes(builder);
      _writeMetadata(
        builder,
        title: _exportAllTitle(includeTracks, includeMarkers),
        description: _exportAllDescription(
          effectiveHauls.length,
          allPoints.length,
          effectiveMarkers.length,
        ),
        bounds: _boundsCombined(
          allPoints.map((p) => _LatLng(p.latitude, p.longitude)),
          markerLatLngs,
        ),
      );

      for (final marker in effectiveMarkers) {
        _writeWaypoint(builder, marker);
      }

      for (final haul in effectiveHauls) {
        final points = pointsByHaul[haul.id] ?? const <TrackPoint>[];
        // Skip empty hauls in the global export — unlike per-trip
        // export where empty <trk> stubs are useful for showing what
        // hauls existed, the global export targets "everything I want
        // to share" so empty stubs are noise.
        if (points.isEmpty) continue;
        _writeTrack(builder, haul, points);
      }
    });

    final content =
        builder.buildDocument().toXmlString(pretty: true, indent: '  ');

    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/langgeng_sea_$timestamp.gpx');
    await file.writeAsString(content);
    return file;
  }

  String _exportAllTitle(bool includeTracks, bool includeMarkers) {
    if (includeTracks && includeMarkers) return 'Data Langgeng Sea (Lengkap)';
    if (includeTracks) return 'Jalur Tarikan Langgeng Sea';
    if (includeMarkers) return 'Penanda Langgeng Sea';
    return 'Langgeng Sea';
  }

  String _exportAllDescription(int haulCount, int pointCount, int markerCount) {
    final parts = <String>[];
    if (haulCount > 0) parts.add('$haulCount tarikan ($pointCount titik)');
    if (markerCount > 0) parts.add('$markerCount penanda');
    return parts.isEmpty ? 'Tidak ada data' : parts.join(' · ');
  }
}

class _LatLng {
  const _LatLng(this.lat, this.lon);
  final double lat;
  final double lon;
}

class _Bounds {
  const _Bounds({
    required this.minLat,
    required this.minLon,
    required this.maxLat,
    required this.maxLon,
  });

  final double minLat;
  final double minLon;
  final double maxLat;
  final double maxLon;
}


// =============================================================================
// GpxExporterService — global export wrapper used by ExportScreen
// =============================================================================
//
// This is the higher-level entry point used by the Settings → Ekspor Data GPX
// screen. It fetches all completed hauls (plus the currently-recording one,
// so users can export mid-trip) + every track point + every marker, hands
// them to [GpxExporter.exportAll] with the user-selected filter flags, and
// returns an [ExportResult] so the UI can show a "berhasil ekspor: 3 jalur,
// 5 penanda" summary without re-counting.
//
// Per-trip sharing (the "Bagikan Sekarang" sheet on a single trip) still
// goes through [ExportService.exportTrip]; this class is global only.

class GpxExporterService {
  GpxExporterService(this._ref);

  final Ref _ref;
  final GpxExporter _exporter = GpxExporter();

  Future<ExportResult> exportAll({
    required bool includeTracks,
    required bool includeMarkers,
  }) async {
    List<Haul> hauls = [];
    Map<String, List<TrackPoint>> pointsByHaul = {};
    List<AppMarker> markers = [];

    if (includeTracks) {
      // Pulling track points via the DAO directly (rather than through
      // TrackPointRepository) keeps this method self-contained — we
      // don't want to drag the repository's broader API surface into
      // an export-only path.
      final haulRepo = _ref.read(haulRepositoryProvider);
      final db = _ref.read(appDatabaseProvider);

      hauls = await haulRepo.listAllCompleted();
      // Append the currently-recording haul if any, so users can export
      // mid-trip without first having to tap "Angkat Trawl".
      final recording = await haulRepo.getRecording();
      if (recording != null && !hauls.any((h) => h.id == recording.id)) {
        hauls = [...hauls, recording];
      }

      for (final haul in hauls) {
        final rows = await db.trackPointDao.findByHaulId(haul.id);
        pointsByHaul[haul.id] = rows.map(TrackPointMapper.fromRow).toList();
      }

      Logger.instance.info('export.tracks_collected', {
        'haulCount': hauls.length,
        'totalPoints':
            pointsByHaul.values.fold<int>(0, (a, b) => a + b.length),
      });
    }

    if (includeMarkers) {
      markers = await _ref.read(markerRepositoryProvider).getAll();
      Logger.instance.info('export.markers_collected', {
        'count': markers.length,
      });
    }

    final file = await _exporter.exportAll(
      includeTracks: includeTracks,
      includeMarkers: includeMarkers,
      hauls: hauls,
      pointsByHaul: pointsByHaul,
      markers: markers,
    );

    final totalPoints =
        pointsByHaul.values.fold<int>(0, (a, b) => a + b.length);

    return ExportResult(
      file: file,
      // Only count hauls that actually contributed points — empty hauls
      // are filtered out of the GPX output, so the user-visible counter
      // should reflect what was packed, not what was queried.
      haulCount: hauls.where((h) {
        final pts = pointsByHaul[h.id];
        return pts != null && pts.isNotEmpty;
      }).length,
      trackPointCount: totalPoints,
      markerCount: markers.length,
    );
  }
}

/// Summary returned to the UI after exporting so the user can see how many
/// items were actually written to the GPX file.
class ExportResult {
  const ExportResult({
    required this.file,
    required this.haulCount,
    required this.trackPointCount,
    required this.markerCount,
  });

  final File file;
  final int haulCount;
  final int trackPointCount;
  final int markerCount;

  bool get isEmpty =>
      haulCount == 0 && trackPointCount == 0 && markerCount == 0;
}

final gpxExporterProvider = Provider<GpxExporterService>((ref) {
  return GpxExporterService(ref);
});
