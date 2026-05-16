import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xml/xml.dart';

import '../../marker/data/marker_repository.dart';
import '../../marker/domain/entities/marker.dart';

/// Result of parsing a GPX file before persisting it. Lets the caller
/// preview counts in the UI and then commit.
class GpxImportPreview {
  const GpxImportPreview({
    required this.trackCount,
    required this.totalTrackPoints,
    required this.waypointCount,
    required this.waypoints,
    required this.tracks,
  });

  /// Number of `<trk>` elements found.
  final int trackCount;

  /// Total `<trkpt>` across all tracks.
  final int totalTrackPoints;

  /// Number of `<wpt>` elements found.
  final int waypointCount;

  /// Parsed waypoints ready to be inserted as [AppMarker]s.
  final List<_PendingWaypoint> waypoints;

  /// Parsed tracks (name + flat point list). Persisting these requires
  /// creating Trip + Haul rows; we currently only import waypoints
  /// directly, while tracks are preview-only until that flow is wired.
  final List<_PendingTrack> tracks;

  /// True bila ada data yang valid untuk diimpor.
  bool get hasAny => trackCount > 0 || waypointCount > 0;
}

class _PendingWaypoint {
  const _PendingWaypoint({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.description,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String? description;
}

class _PendingTrack {
  const _PendingTrack({
    required this.name,
    required this.points,
  });

  final String name;
  final List<_PendingTrackPoint> points;
}

class _PendingTrackPoint {
  const _PendingTrackPoint({
    required this.latitude,
    required this.longitude,
    this.timestamp,
    this.elevation,
  });

  final double latitude;
  final double longitude;
  final DateTime? timestamp;
  final double? elevation;
}

/// Parses GPX 1.1 files and persists waypoints into the marker
/// repository.
///
/// This replaces the old placeholder `LseaJsonImporter` flow. Tracks
/// (`<trk>`) are also parsed so the preview can show the counts, but
/// they are not yet inserted because that requires reconstructing
/// Trip/Haul ownership which is non-trivial — see TODO at end of
/// [import].
class GpxImporter {
  const GpxImporter(this._ref);

  final Ref _ref;

  /// Parse the GPX XML string. Throws [FormatException] when the file
  /// is not valid GPX.
  GpxImportPreview parse(String xmlSource) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(xmlSource);
    } catch (e) {
      throw FormatException('File bukan XML yang valid: $e');
    }

    final root = doc.rootElement;
    if (root.localName != 'gpx') {
      throw const FormatException('File bukan GPX (root element bukan <gpx>).');
    }

    // Waypoints (top-level <wpt>).
    final waypoints = <_PendingWaypoint>[];
    for (final wpt in root.findElements('wpt')) {
      final lat = double.tryParse(wpt.getAttribute('lat') ?? '');
      final lon = double.tryParse(wpt.getAttribute('lon') ?? '');
      if (lat == null || lon == null) continue;
      waypoints.add(_PendingWaypoint(
        name: wpt.getElement('name')?.innerText.trim().isNotEmpty == true
            ? wpt.getElement('name')!.innerText.trim()
            : 'Waypoint',
        latitude: lat,
        longitude: lon,
        description: wpt.getElement('desc')?.innerText.trim(),
      ));
    }

    // Tracks (<trk> -> <trkseg> -> <trkpt>).
    final tracks = <_PendingTrack>[];
    for (final trk in root.findElements('trk')) {
      final name = trk.getElement('name')?.innerText.trim() ?? 'Track';
      final points = <_PendingTrackPoint>[];
      for (final seg in trk.findElements('trkseg')) {
        for (final pt in seg.findElements('trkpt')) {
          final lat = double.tryParse(pt.getAttribute('lat') ?? '');
          final lon = double.tryParse(pt.getAttribute('lon') ?? '');
          if (lat == null || lon == null) continue;
          DateTime? ts;
          final timeStr = pt.getElement('time')?.innerText.trim();
          if (timeStr != null && timeStr.isNotEmpty) {
            ts = DateTime.tryParse(timeStr);
          }
          final ele =
              double.tryParse(pt.getElement('ele')?.innerText.trim() ?? '');
          points.add(_PendingTrackPoint(
            latitude: lat,
            longitude: lon,
            timestamp: ts,
            elevation: ele,
          ));
        }
      }
      tracks.add(_PendingTrack(name: name, points: points));
    }

    final totalTrackPoints =
        tracks.fold<int>(0, (acc, t) => acc + t.points.length);

    return GpxImportPreview(
      trackCount: tracks.length,
      totalTrackPoints: totalTrackPoints,
      waypointCount: waypoints.length,
      waypoints: waypoints,
      tracks: tracks,
    );
  }

  /// Persist the parsed preview into the database.
  ///
  /// Currently inserts waypoints as [AppMarker]s (category =
  /// [MarkerCategory.other]). Tracks are not yet imported as Hauls
  /// because that requires creating an "Imported Trip" container
  /// trip — TODO(import-tracks) wire this up after the preview UI is
  /// validated by users.
  ///
  /// Returns the number of items actually inserted.
  Future<int> import(GpxImportPreview preview) async {
    final markerRepo = _ref.read(markerRepositoryProvider);
    var inserted = 0;
    for (final wp in preview.waypoints) {
      await markerRepo.create(
        name: wp.name,
        category: MarkerCategory.other,
        latitude: wp.latitude,
        longitude: wp.longitude,
        notes: wp.description,
      );
      inserted++;
    }
    return inserted;
  }
}

final gpxImporterProvider = Provider<GpxImporter>((ref) {
  return GpxImporter(ref);
});
