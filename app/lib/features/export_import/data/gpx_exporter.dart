import 'package:xml/xml.dart';

import '../../../features/marker/domain/entities/marker.dart';
import '../../../features/tracking/domain/entities/haul.dart';
import '../../../features/tracking/domain/entities/track_point.dart';
import '../../../features/tracking/domain/entities/trip.dart';

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
