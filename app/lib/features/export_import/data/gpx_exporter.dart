import 'package:xml/xml.dart';

import 'package:xml/xml.dart';

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/observability/logger.dart';
import '../../../data/database/app_database.dart';
import '../../marker/data/marker_repository.dart';
import '../../marker/domain/entities/marker.dart';
import '../../onboarding/domain/entities/user_profile.dart';
import '../../tracking/data/haul_repository.dart';
import '../../tracking/data/mappers.dart';
import '../../tracking/domain/entities/haul.dart';
import '../../tracking/domain/entities/track_point.dart';
import '../../tracking/domain/entities/trip.dart';
import '../domain/entities/export_filter.dart';

/// Generates GPX 1.1 XML from haul/trip track data.
///
/// Implementation uses the `xml` package (already in pubspec) so the
/// output is always well-formed and properly escaped, regardless of
/// edge cases (empty hauls, empty trip, special characters in names,
/// etc).
///
/// PR #25/26 fixed the "self-closing root" bug — the file always emits
/// at least a `<metadata>` block so it makes sense to humans even when
/// no track data is available.
///
/// PR #27 (R4) extends this with:
/// - `<author><name>` + `<lsea:exporter>` block carrying nelayan name,
///   vessel name, home port, exported-at timestamp, and a
///   human-readable filter description.
/// - `<lsea:summary>` block with rolled-up totals across all
///   included trips/hauls/markers — useful for receivers who want a
///   quick glance without parsing every `<trk>`.
/// - `<lsea:trip>` extension on every `<trk>` so receivers know which
///   parent trip a haul belongs to (previously only haul stats were
///   carried).
/// - `<lsea:haul colorValue colorHex>` so the user-picked polyline
///   colour round-trips through GPX.
/// - `<lsea:filterDescription>` so the receiver knows whether the file
///   is a slice (e.g. "7 hari terakhir") or full data.
///
/// GPX namespace + Styra custom extensions (`xmlns:styra`) make
/// it possible to round-trip extra fields without breaking
/// compatibility with generic GPX consumers like Google Earth, Garmin
/// BaseCamp, or QGIS — they just ignore the unknown extension
/// namespace.
class GpxExporter {
  static const String _gpxNs = 'http://www.topografix.com/GPX/1/1';
  static const String _xsiNs = 'http://www.w3.org/2001/XMLSchema-instance';

  /// PR #44 (rebrand): namespace + prefix berubah dari `lsea:` ke
  /// `styra:` seiring rebrand Styra → Styra. GPX importer
  /// menerima both prefix supaya file lama dari versi pre-rebrand
  /// tetap bisa di-import.
  static const String _styraNs = 'https://styra.app/gpx/extensions/v1';
  static const String _xsiSchemaLocation =
      'http://www.topografix.com/GPX/1/1 '
      'http://www.topografix.com/GPX/1/1/gpx.xsd';

  static const String _creator = 'Styra';

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
      _writeTrack(builder, haul, points, parentTrip: parentTrip);
    });
    return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  /// Export an entire trip as a multi-track GPX, with optional
  /// waypoints for the user's saved markers.
  ///
  /// Backward-compat shim — internally builds an [ExportFilter] that
  /// targets just this trip, then delegates to [exportFiltered]. New
  /// callers should pass an explicit [exporter] / [filter] for full
  /// metadata coverage.
  String exportTrip(
    Trip trip,
    List<Haul> hauls,
    Map<String, List<TrackPoint>> pointsByHaul, {
    List<AppMarker> markers = const [],
    UserProfile? exporter,
  }) {
    return exportFiltered(
      filter: ExportFilter(
        includeTracks: true,
        includeMarkers: markers.isNotEmpty,
        tripIds: {trip.id},
      ),
      exporter: exporter,
      trips: [trip],
      haulsByTripId: {trip.id: hauls},
      pointsByHaulId: pointsByHaul,
      markers: markers,
    );
  }

  /// Export semua data yang lewat filter (PR #27 R4).
  ///
  /// Kontrak input:
  /// - [trips]: SEMUA trip yang sudah lolos `filter.matchesTrip`.
  ///   Caller boleh juga menyodorkan superset — exporter akan re-filter
  ///   secara defensif.
  /// - [haulsByTripId]: untuk setiap trip yang masuk, list haul-nya.
  ///   Hanya haul completed yang punya entry di sini biasanya;
  ///   haul `recording` yang masih hidup tidak ikut diekspor.
  /// - [pointsByHaulId]: untuk setiap haul, list track point. Boleh
  ///   kosong (haul tanpa fix) — kita tetap emit `<trk>` stub supaya
  ///   penerima tahu haul itu ada.
  /// - [markers]: SEMUA marker yang sudah lolos `filter.matchesMarker`.
  ///   Re-filter defensif dilakukan.
  /// - [exporter]: profil pengekspor (nelayan + kapal). `null` = tidak
  ///   tulis blok `<lsea:exporter>`, `<author><name>` fallback ke
  ///   "Styra".
  ///
  /// Selalu menghasilkan dokumen yang well-formed — minimal
  /// `<gpx><metadata/></gpx>` walau filter menghasilkan 0 trip / 0
  /// marker.
  String exportFiltered({
    required ExportFilter filter,
    required List<Trip> trips,
    required Map<String, List<Haul>> haulsByTripId,
    required Map<String, List<TrackPoint>> pointsByHaulId,
    required List<AppMarker> markers,
    UserProfile? exporter,
    DateTime? exportedAt,
  }) {
    final now = exportedAt ?? DateTime.now();

    // Defensive re-filter — caller mungkin sudah filter, tapi kita
    // tidak bisa percaya begitu saja. ExportFilter punya semantics
    // yang halus (tripIds override dateRange) jadi jalankan ulang di
    // sini sebagai safety net.
    final filteredTrips = trips.where(filter.matchesTrip).toList();
    final filteredMarkers =
        filter.includeMarkers ? markers.where(filter.matchesMarker).toList() : <AppMarker>[];

    // Flatten haul list dari trip yang lolos filter, hanya kalau user
    // include tracks. Urutan dipertahankan: outer trip-startedAt,
    // inner haul-orderIndex.
    final filteredHauls = <_HaulWithTrip>[];
    if (filter.includeTracks) {
      for (final trip in filteredTrips) {
        final haulsOfTrip = haulsByTripId[trip.id] ?? const <Haul>[];
        for (final haul in haulsOfTrip) {
          filteredHauls.add(_HaulWithTrip(haul: haul, trip: trip));
        }
      }
    }

    // Hitung total — dipakai di metadata & `<lsea:summary>`.
    final totalDistance =
        filteredHauls.fold<double>(0, (s, hw) => s + hw.haul.distanceMeters);
    final totalDuration =
        filteredHauls.fold<int>(0, (s, hw) => s + hw.haul.durationSeconds);
    final totalSweptArea =
        filteredHauls.fold<double>(0, (s, hw) => s + hw.haul.sweptAreaM2);

    final allPoints = <TrackPoint>[
      for (final hw in filteredHauls)
        ...?pointsByHaulId[hw.haul.id],
    ];
    final markerLatLngs = filteredMarkers
        .map((m) => _LatLng(m.latitude, m.longitude))
        .toList(growable: false);

    final summary = _ExportSummary(
      tripCount: filteredTrips.length,
      haulCount: filteredHauls.length,
      markerCount: filteredMarkers.length,
      totalDistanceMeters: totalDistance,
      totalDurationSeconds: totalDuration,
      totalSweptAreaM2: totalSweptArea,
    );

    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('gpx', nest: () {
      _writeRootAttributes(builder);
      _writeMetadata(
        builder,
        title: _titleForFilter(filter),
        description: _descriptionForSummary(summary),
        bounds: _boundsCombined(
          allPoints.map((p) => _LatLng(p.latitude, p.longitude)),
          markerLatLngs,
        ),
        exportedAt: now,
        exporter: exporter,
        filter: filter,
        summary: summary,
      );

      // Markers first (GPX 1.1 schema requires `<wpt>*` before
      // `<trk>*`).
      for (final marker in filteredMarkers) {
        _writeWaypoint(builder, marker);
      }

      for (final hw in filteredHauls) {
        final points = pointsByHaulId[hw.haul.id] ?? const <TrackPoint>[];
        _writeTrack(builder, hw.haul, points, parentTrip: hw.trip);
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
    builder.attribute('xmlns:styra', _styraNs);
    builder.attribute('xsi:schemaLocation', _xsiSchemaLocation);
  }

  void _writeMetadata(
    XmlBuilder builder, {
    required String title,
    String? description,
    _Bounds? bounds,
    DateTime? exportedAt,
    UserProfile? exporter,
    ExportFilter? filter,
    _ExportSummary? summary,
  }) {
    final exportTimestamp = (exportedAt ?? DateTime.now()).toUtc();
    final authorName = exporter?.name ?? _creator;

    builder.element('metadata', nest: () {
      builder.element('name', nest: title);
      if (description != null && description.isNotEmpty) {
        builder.element('desc', nest: description);
      }
      builder.element('author', nest: () {
        builder.element('name', nest: authorName);
        builder.element('link', nest: () {
          builder.attribute('href', 'https://styra.app');
          builder.element('text', nest: 'Styra');
        });
      });
      builder.element('time', nest: exportTimestamp.toIso8601String());
      if (bounds != null) {
        builder.element('bounds', nest: () {
          builder.attribute('minlat', _formatCoord(bounds.minLat));
          builder.attribute('minlon', _formatCoord(bounds.minLon));
          builder.attribute('maxlat', _formatCoord(bounds.maxLat));
          builder.attribute('maxlon', _formatCoord(bounds.maxLon));
        });
      }

      // Always emit extensions block when we have exporter / filter /
      // summary to surface — keeps the structural shape predictable
      // for receivers regardless of how rich the data is.
      final hasExtensionContent =
          exporter != null || filter != null || summary != null;
      if (hasExtensionContent) {
        builder.element('extensions', nest: () {
          if (exporter != null) {
            _writeExporterBlock(
              builder,
              exporter: exporter,
              filter: filter,
              exportedAt: exportTimestamp,
            );
          } else if (filter != null) {
            // Even tanpa user profile, kita tetap surface
            // filterDescription standalone supaya penerima tahu.
            builder.element('styra:exporter', nest: () {
              builder.attribute('hasUserProfile', 'false');
              builder.element(
                'styra:exportedAt',
                nest: exportTimestamp.toIso8601String(),
              );
              builder.element(
                'styra:filterDescription',
                nest: filter.describe(),
              );
            });
          }
          if (summary != null) {
            _writeSummaryBlock(builder, summary);
          }
        });
      }
    });
  }

  void _writeExporterBlock(
    XmlBuilder builder, {
    required UserProfile exporter,
    required DateTime exportedAt,
    ExportFilter? filter,
  }) {
    builder.element('styra:exporter', nest: () {
      builder.element('styra:vesselName', nest: exporter.vesselName);
      builder.element('styra:ownerName', nest: exporter.name);
      if (exporter.homePortOptional != null &&
          exporter.homePortOptional!.isNotEmpty) {
        builder.element('styra:homePort', nest: exporter.homePortOptional!);
      }
      if (exporter.vesselGtOptional != null) {
        builder.element(
          'styra:vesselGt',
          nest: exporter.vesselGtOptional!.toStringAsFixed(2),
        );
      }
      builder.element(
        'styra:trawlWidthMeters',
        nest: exporter.trawlWidthMeters.toStringAsFixed(2),
      );
      builder.element(
        'styra:exportedAt',
        nest: exportedAt.toIso8601String(),
      );
      if (filter != null) {
        builder.element('styra:filterDescription', nest: filter.describe());
      }
    });
  }

  void _writeSummaryBlock(XmlBuilder builder, _ExportSummary summary) {
    builder.element('styra:summary', nest: () {
      builder.attribute('tripCount', summary.tripCount.toString());
      builder.attribute('haulCount', summary.haulCount.toString());
      builder.attribute('markerCount', summary.markerCount.toString());
      builder.attribute(
        'totalDistanceMeters',
        summary.totalDistanceMeters.toStringAsFixed(2),
      );
      builder.attribute(
        'totalDurationSeconds',
        summary.totalDurationSeconds.toString(),
      );
      builder.attribute(
        'totalSweptAreaM2',
        summary.totalSweptAreaM2.toStringAsFixed(2),
      );
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
        builder.element('styra:marker', nest: () {
          builder.attribute('id', marker.id);
          builder.attribute('category', marker.category.storageKey);
          builder.attribute(
            'categoryLabel',
            marker.category.displayLabel,
          );
        });
      });
    });
  }

  void _writeTrack(
    XmlBuilder builder,
    Haul haul,
    List<TrackPoint> points, {
    Trip? parentTrip,
  }) {
    builder.element('trk', nest: () {
      builder.element('name', nest: haul.displayName());
      builder.element('desc', nest: _haulDescription(haul));
      builder.element('type', nest: 'fishing-haul');

      builder.element('extensions', nest: () {
        // Parent trip extension — receiver bisa rekonstruksi
        // grouping trip → haul tanpa harus parsing nama.
        if (parentTrip != null) {
          _writeTripExtensionAttrs(builder, parentTrip);
        }
        _writeHaulExtensionAttrs(builder, haul);
      });

      // Always emit a `<trkseg>`, even when empty, so the document
      // schema stays consistent. Empty `<trkseg/>` is valid GPX 1.1.
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
                builder.element('styra:trkpt', nest: () {
                  if (pt.headingDegrees != null) {
                    builder.element(
                      'styra:headingDegrees',
                      nest: pt.headingDegrees!.toStringAsFixed(1),
                    );
                  }
                  if (pt.accuracyMeters != null) {
                    builder.element(
                      'styra:accuracyMeters',
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

  void _writeTripExtensionAttrs(XmlBuilder builder, Trip trip) {
    builder.element('styra:trip', nest: () {
      builder.attribute('id', trip.id);
      if (trip.name != null && trip.name!.isNotEmpty) {
        builder.attribute('name', trip.name!);
      }
      builder.attribute('status', trip.status.name);
      builder.attribute(
        'startedAt',
        trip.startedAt.toUtc().toIso8601String(),
      );
      if (trip.endedAt != null) {
        builder.attribute(
          'endedAt',
          trip.endedAt!.toUtc().toIso8601String(),
        );
      }
      if (trip.homePort != null && trip.homePort!.isNotEmpty) {
        builder.attribute('homePort', trip.homePort!);
      }
      if (trip.colorValue != null) {
        builder.attribute('colorValue', '0x${_argbHex(trip.colorValue!)}');
        builder.attribute('colorHex', '#${_rgbHex(trip.colorValue!)}');
      }
    });
  }

  void _writeHaulExtensionAttrs(XmlBuilder builder, Haul haul) {
    builder.element('styra:haul', nest: () {
      builder.attribute('id', haul.id);
      builder.attribute('orderIndex', haul.orderIndex.toString());
      builder.attribute('status', haul.status.name);
      builder.attribute(
        'startedAt',
        haul.startedAt.toUtc().toIso8601String(),
      );
      if (haul.endedAt != null) {
        builder.attribute(
          'endedAt',
          haul.endedAt!.toUtc().toIso8601String(),
        );
      }
      builder.attribute(
        'trawlWidthMeters',
        haul.trawlWidthMeters.toStringAsFixed(2),
      );
      builder.attribute(
        'distanceMeters',
        haul.distanceMeters.toStringAsFixed(2),
      );
      builder.attribute(
        'durationSeconds',
        haul.durationSeconds.toString(),
      );
      if (haul.avgSpeedKnots != null) {
        builder.attribute(
          'avgSpeedKnots',
          haul.avgSpeedKnots!.toStringAsFixed(2),
        );
      }
      if (haul.avgHeadingDegrees != null) {
        builder.attribute(
          'avgHeadingDegrees',
          haul.avgHeadingDegrees!.toStringAsFixed(1),
        );
      }
      builder.attribute(
        'sweptAreaM2',
        haul.sweptAreaM2.toStringAsFixed(2),
      );
      if (haul.colorValue != null) {
        builder.attribute('colorValue', '0x${_argbHex(haul.colorValue!)}');
        builder.attribute('colorHex', '#${_rgbHex(haul.colorValue!)}');
      }
    });
  }

  // ===========================================================================
  // Pure helpers
  // ===========================================================================

  String _titleForFilter(ExportFilter filter) {
    if (filter.includeTracks && filter.includeMarkers) {
      return 'Data Styra (Lengkap)';
    }
    if (filter.includeTracks) {
      return 'Jalur Tarikan Styra';
    }
    if (filter.includeMarkers) {
      return 'Penanda Styra';
    }
    return 'Data Styra';
  }

  String _descriptionForSummary(_ExportSummary s) {
    final pieces = <String>[];
    if (s.tripCount > 0) pieces.add('${s.tripCount} trip');
    if (s.haulCount > 0) pieces.add('${s.haulCount} tarikan');
    if (s.totalDistanceMeters > 0) {
      pieces.add('${(s.totalDistanceMeters / 1000).toStringAsFixed(2)} km');
    }
    if (s.markerCount > 0) pieces.add('${s.markerCount} penanda');
    if (pieces.isEmpty) return 'Tidak ada data yang cocok';
    return pieces.join(' · ');
  }

  String _haulDescription(Haul haul) {
    final pieces = <String>[
      'Tarikan #${haul.orderIndex}',
      'lebar trawl ${haul.trawlWidthMeters.toStringAsFixed(1)} m',
    ];
    if (haul.distanceMeters > 0) {
      pieces.add('${(haul.distanceMeters / 1000).toStringAsFixed(2)} km');
    }
    if (haul.durationSeconds > 0) {
      final m = (haul.durationSeconds / 60).round();
      pieces.add('$m menit');
    }
    if (haul.avgSpeedKnots != null) {
      pieces.add('${haul.avgSpeedKnots!.toStringAsFixed(1)} knot');
    }
    if (haul.avgHeadingDegrees != null) {
      pieces.add(
        '${haul.avgHeadingDegrees!.toStringAsFixed(0)}°',
      );
    }
    if (haul.sweptAreaM2 > 0) {
      pieces.add('${(haul.sweptAreaM2 / 10000).toStringAsFixed(2)} ha');
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
    var trimmed = s;
    if (trimmed.contains('.')) {
      trimmed = trimmed.replaceFirst(RegExp(r'0+$'), '');
      trimmed = trimmed.replaceFirst(RegExp(r'\.$'), '');
    }
    return trimmed;
  }

  String _argbHex(int argb) {
    return argb.toUnsigned(32).toRadixString(16).padLeft(8, '0').toUpperCase();
  }

  String _rgbHex(int argb) {
    final rgb = argb.toUnsigned(32) & 0xFFFFFF;
    return rgb.toRadixString(16).padLeft(6, '0').toUpperCase();
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
    final file = File('${dir.path}/styra_$timestamp.gpx');
    await file.writeAsString(content);
    return file;
  }

  String _exportAllTitle(bool includeTracks, bool includeMarkers) {
    if (includeTracks && includeMarkers) return 'Data Styra (Lengkap)';
    if (includeTracks) return 'Jalur Tarikan Styra';
    if (includeMarkers) return 'Penanda Styra';
    return 'Styra';
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

class _ExportSummary {
  const _ExportSummary({
    required this.tripCount,
    required this.haulCount,
    required this.markerCount,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.totalSweptAreaM2,
  });

  final int tripCount;
  final int haulCount;
  final int markerCount;
  final double totalDistanceMeters;
  final int totalDurationSeconds;
  final double totalSweptAreaM2;
}

class _HaulWithTrip {
  const _HaulWithTrip({required this.haul, required this.trip});
  final Haul haul;
  final Trip trip;
}
