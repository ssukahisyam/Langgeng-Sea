import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xml/xml.dart';

import '../../../core/observability/logger.dart';
import '../../marker/data/marker_repository.dart';
import '../../marker/domain/entities/marker.dart';
import '../../tracking/data/haul_repository.dart';
import '../../tracking/data/track_point_repository.dart';
import '../../tracking/data/trip_repository.dart';
import 'imported_dataset_repository.dart';

/// Result of parsing a GPX file before persisting it.
///
/// PR #33 overhaul: sekarang membawa metadata exporter dan kategori
/// marker yang sudah di-parse dari extension `<lsea:marker>`,
/// `<lsea:trip>`, `<lsea:haul>`, dan `<lsea:exporter>`. Pemanggil di
/// UI dapat menampilkan preview yang akurat sebelum commit ke DB.
class GpxImportPreview {
  const GpxImportPreview({
    required this.fileName,
    required this.trackCount,
    required this.totalTrackPoints,
    required this.waypointCount,
    required this.waypoints,
    required this.tracks,
    this.exporterName,
    this.vesselName,
    this.homePort,
    this.exportedAt,
  });

  /// Nama file asli dari `FilePicker` — disimpan ke
  /// `imported_datasets.file_name` saat commit.
  final String fileName;

  /// Nama nelayan dari `<lsea:exporter><lsea:ownerName>`. Null kalau
  /// file dari aplikasi GPX lain.
  final String? exporterName;

  /// Nama kapal dari `<lsea:exporter><lsea:vesselName>`.
  final String? vesselName;

  /// Home port dari `<lsea:exporter><lsea:homePort>`.
  final String? homePort;

  /// Timestamp ekspor dari `<lsea:exportedAt>`.
  final DateTime? exportedAt;

  /// Number of `<trk>` elements found.
  final int trackCount;

  /// Total `<trkpt>` across all tracks.
  final int totalTrackPoints;

  /// Number of `<wpt>` elements found.
  final int waypointCount;

  /// Parsed waypoints ready to be inserted as [AppMarker]s.
  final List<PendingWaypoint> waypoints;

  /// Parsed tracks (name + flat point list + optional metadata).
  final List<PendingTrack> tracks;

  /// True bila ada data yang valid untuk diimpor.
  bool get hasAny => trackCount > 0 || waypointCount > 0;

  /// True kalau metadata exporter Styra tersedia (file dari
  /// ekspor PR #27, bukan dari aplikasi GPX lain seperti OsmAnd).
  bool get hasExporterInfo =>
      exporterName != null || vesselName != null || homePort != null;

  /// Breakdown jumlah waypoint per kategori — dipakai oleh UI
  /// preview di ImportScreen untuk tampilkan ringkasan.
  Map<MarkerCategory, int> waypointCountByCategory() {
    final result = <MarkerCategory, int>{};
    for (final wp in waypoints) {
      result[wp.category] = (result[wp.category] ?? 0) + 1;
    }
    return result;
  }
}

/// Waypoint yang akan di-import sebagai [AppMarker].
class PendingWaypoint {
  const PendingWaypoint({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.category,
    this.description,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String? description;

  /// Sudah di-resolve dari `<lsea:marker category>` atau fallback
  /// `MarkerCategory.other` kalau tidak ada extension.
  final MarkerCategory category;
}

/// Track yang akan di-import sebagai Haul + TrackPoint rows.
///
/// Field `tripId` / `tripName` / `tripColorValue` digunakan untuk
/// group beberapa `<trk>` ke 1 Trip row saat import. File dari
/// ekspor PR #27 memberi `tripId` yang stabil; file dari aplikasi
/// lain biasanya tidak punya — kita group dengan fallback nama
/// "Impor: {filename}".
class PendingTrack {
  const PendingTrack({
    required this.name,
    required this.points,
    this.tripId,
    this.tripName,
    this.tripColorValue,
    this.haulId,
    this.haulName,
    this.haulColorValue,
    this.haulOrderIndex,
    this.haulStartedAt,
    this.haulEndedAt,
    this.haulTrawlWidthMeters,
    this.haulDistanceMeters,
    this.haulDurationSeconds,
    this.haulSweptAreaM2,
    this.haulAvgSpeedKnots,
    this.haulAvgHeadingDegrees,
  });

  final String name;
  final List<PendingTrackPoint> points;

  // Trip-level metadata dari `<lsea:trip>` extension.
  final String? tripId;
  final String? tripName;
  final int? tripColorValue;

  // Haul-level metadata dari `<lsea:haul>` extension.
  final String? haulId;
  final String? haulName;
  final int? haulColorValue;
  final int? haulOrderIndex;
  final DateTime? haulStartedAt;
  final DateTime? haulEndedAt;
  final double? haulTrawlWidthMeters;
  final double? haulDistanceMeters;
  final int? haulDurationSeconds;
  final double? haulSweptAreaM2;
  final double? haulAvgSpeedKnots;
  final double? haulAvgHeadingDegrees;
}

class PendingTrackPoint {
  const PendingTrackPoint({
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

/// Parses GPX 1.1 files (with optional Styra `lsea`
/// extensions) and persists the data into `imported_datasets` plus
/// child rows.
///
/// PR #33 overhaul:
/// - Marker `<wpt>` di-parse dengan kategori dari `<lsea:marker>`
/// - Track `<trk>` di-parse jadi Trip + Haul + TrackPoint dengan
///   `dataset_id` FK
/// - Metadata exporter di-simpan ke `imported_datasets` row
/// - File dari aplikasi GPX lain (tanpa `lsea` extension) tetap
///   bisa di-import dengan fallback values
class GpxImporter {
  const GpxImporter(this._ref);

  final Ref _ref;

  /// Parse the GPX XML string. Throws [FormatException] when the file
  /// is not valid GPX.
  ///
  /// [fileName] dipakai sebagai metadata `imported_datasets.file_name`
  /// dan fallback Trip name kalau file tidak punya `<lsea:trip>`.
  GpxImportPreview parse(String xmlSource, {required String fileName}) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(xmlSource);
    } catch (e) {
      throw FormatException('File bukan XML yang valid: $e');
    }

    final root = doc.rootElement;
    if (root.localName != 'gpx') {
      throw const FormatException(
        'File bukan GPX (root element bukan <gpx>).',
      );
    }

    // ---- Metadata exporter ---------------------------------------
    String? exporterName;
    String? vesselName;
    String? homePort;
    DateTime? exportedAt;
    final metadata = root.getElement('metadata');
    if (metadata != null) {
      // exportedAt bisa di metadata.time ATAU di metadata extensions
      final timeStr = metadata.getElement('time')?.innerText.trim();
      if (timeStr != null && timeStr.isNotEmpty) {
        exportedAt = DateTime.tryParse(timeStr);
      }
      final extensions = metadata.getElement('extensions');
      if (extensions != null) {
        final exporterEl = _findExtensionElement(extensions, 'exporter');
        if (exporterEl != null) {
          vesselName = _extensionText(exporterEl, 'vesselName');
          exporterName = _extensionText(exporterEl, 'ownerName');
          homePort = _extensionText(exporterEl, 'homePort');
        }
        final exportedAtStr =
            _findExtensionElement(extensions, 'exportedAt')?.innerText.trim();
        if (exportedAtStr != null && exportedAtStr.isNotEmpty) {
          exportedAt = DateTime.tryParse(exportedAtStr) ?? exportedAt;
        }
      }
    }

    // ---- Waypoints (top-level <wpt>) -----------------------------
    final waypoints = <PendingWaypoint>[];
    for (final wpt in root.findElements('wpt')) {
      final lat = double.tryParse(wpt.getAttribute('lat') ?? '');
      final lon = double.tryParse(wpt.getAttribute('lon') ?? '');
      if (lat == null || lon == null) continue;
      final name = wpt.getElement('name')?.innerText.trim();
      final description = wpt.getElement('desc')?.innerText.trim();
      // Cari `<extensions><lsea:marker category=...>`
      MarkerCategory category = MarkerCategory.other;
      final extensions = wpt.getElement('extensions');
      if (extensions != null) {
        final markerEl = _findExtensionElement(extensions, 'marker');
        if (markerEl != null) {
          final raw = markerEl.getAttribute('category');
          category = MarkerCategory.fromGpxValue(raw);
        }
      }
      // Fallback: kalau ada `<sym>` atau `<type>` yang berisi nama
      // kategori, coba parse dari situ juga (untuk file dari
      // aplikasi lain yang pakai konvensi serupa).
      if (category == MarkerCategory.other) {
        final symText = wpt.getElement('sym')?.innerText.trim();
        final typeText = wpt.getElement('type')?.innerText.trim();
        final fromSym = MarkerCategory.fromGpxValue(symText);
        final fromType = MarkerCategory.fromGpxValue(typeText);
        category = fromSym != MarkerCategory.other ? fromSym : fromType;
      }
      waypoints.add(PendingWaypoint(
        name: (name != null && name.isNotEmpty) ? name : 'Waypoint',
        latitude: lat,
        longitude: lon,
        description:
            (description != null && description.isNotEmpty) ? description : null,
        category: category,
      ));
    }

    // ---- Tracks (<trk> -> <trkseg> -> <trkpt>) -------------------
    final tracks = <PendingTrack>[];
    for (final trk in root.findElements('trk')) {
      final name = trk.getElement('name')?.innerText.trim();
      final points = <PendingTrackPoint>[];
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
          final ele = double.tryParse(
              pt.getElement('ele')?.innerText.trim() ?? '');
          points.add(PendingTrackPoint(
            latitude: lat,
            longitude: lon,
            timestamp: ts,
            elevation: ele,
          ));
        }
      }
      // Parse `<lsea:trip>` dan `<lsea:haul>` extensions kalau ada.
      String? tripId;
      String? tripName;
      int? tripColorValue;
      String? haulId;
      String? haulName;
      int? haulColorValue;
      int? haulOrderIndex;
      DateTime? haulStartedAt;
      DateTime? haulEndedAt;
      double? haulTrawlWidthMeters;
      double? haulDistanceMeters;
      int? haulDurationSeconds;
      double? haulSweptAreaM2;
      double? haulAvgSpeedKnots;
      double? haulAvgHeadingDegrees;
      final extensions = trk.getElement('extensions');
      if (extensions != null) {
        final tripEl = _findExtensionElement(extensions, 'trip');
        if (tripEl != null) {
          tripId = tripEl.getAttribute('id');
          tripName = tripEl.getAttribute('name');
          tripColorValue =
              _parseHexInt(tripEl.getAttribute('colorValue'));
        }
        final haulEl = _findExtensionElement(extensions, 'haul');
        if (haulEl != null) {
          haulId = haulEl.getAttribute('id');
          haulName = name;
          haulColorValue =
              _parseHexInt(haulEl.getAttribute('colorValue'));
          haulOrderIndex =
              int.tryParse(haulEl.getAttribute('orderIndex') ?? '');
          final startedAtStr = haulEl.getAttribute('startedAt');
          if (startedAtStr != null) {
            haulStartedAt = DateTime.tryParse(startedAtStr);
          }
          final endedAtStr = haulEl.getAttribute('endedAt');
          if (endedAtStr != null) {
            haulEndedAt = DateTime.tryParse(endedAtStr);
          }
          haulTrawlWidthMeters = double.tryParse(
              haulEl.getAttribute('trawlWidthMeters') ?? '');
          haulDistanceMeters = double.tryParse(
              haulEl.getAttribute('distanceMeters') ?? '');
          haulDurationSeconds = int.tryParse(
              haulEl.getAttribute('durationSeconds') ?? '');
          haulSweptAreaM2 = double.tryParse(
              haulEl.getAttribute('sweptAreaM2') ?? '');
          haulAvgSpeedKnots = double.tryParse(
              haulEl.getAttribute('avgSpeedKnots') ?? '');
          haulAvgHeadingDegrees = double.tryParse(
              haulEl.getAttribute('avgHeadingDegrees') ?? '');
        }
      }
      tracks.add(PendingTrack(
        name: (name != null && name.isNotEmpty) ? name : 'Track',
        points: points,
        tripId: tripId,
        tripName: tripName,
        tripColorValue: tripColorValue,
        haulId: haulId,
        haulName: haulName,
        haulColorValue: haulColorValue,
        haulOrderIndex: haulOrderIndex,
        haulStartedAt: haulStartedAt,
        haulEndedAt: haulEndedAt,
        haulTrawlWidthMeters: haulTrawlWidthMeters,
        haulDistanceMeters: haulDistanceMeters,
        haulDurationSeconds: haulDurationSeconds,
        haulSweptAreaM2: haulSweptAreaM2,
        haulAvgSpeedKnots: haulAvgSpeedKnots,
        haulAvgHeadingDegrees: haulAvgHeadingDegrees,
      ));
    }

    final totalTrackPoints =
        tracks.fold<int>(0, (acc, t) => acc + t.points.length);

    return GpxImportPreview(
      fileName: fileName,
      exporterName: exporterName,
      vesselName: vesselName,
      homePort: homePort,
      exportedAt: exportedAt,
      trackCount: tracks.length,
      totalTrackPoints: totalTrackPoints,
      waypointCount: waypoints.length,
      waypoints: waypoints,
      tracks: tracks,
    );
  }

  /// Persist the parsed preview into the database (PR #33).
  ///
  /// Flow:
  /// 1. Buat 1 row `imported_datasets` dengan metadata exporter
  /// 2. Insert markers dengan `dataset_id`
  /// 3. Group tracks by `tripId` (atau `tripName`, atau fallback
  ///    "Impor: {filename}") -> buat Trip rows
  /// 4. Per track: buat Haul row + insert TrackPoints
  /// 5. Recount denormalized counters di dataset row
  ///
  /// Returns total inserted (marker count + total track point count).
  Future<int> import(GpxImportPreview preview) async {
    final datasetRepo = _ref.read(importedDatasetRepositoryProvider);
    final markerRepo = _ref.read(markerRepositoryProvider);
    final tripRepo = _ref.read(tripRepositoryProvider);
    final haulRepo = _ref.read(haulRepositoryProvider);
    final pointRepo = _ref.read(trackPointRepositoryProvider);

    // 1. Buat dataset row
    final dataset = await datasetRepo.create(
      fileName: preview.fileName,
      exporterName: preview.exporterName,
      vesselName: preview.vesselName,
      exportedAt: preview.exportedAt,
    );
    Logger.instance.info('import.start', {
      'datasetId': dataset.id,
      'fileName': preview.fileName,
      'waypointCount': preview.waypointCount,
      'trackCount': preview.trackCount,
    });

    var inserted = 0;

    // 2. Insert markers
    for (final wp in preview.waypoints) {
      await markerRepo.createForDataset(
        datasetId: dataset.id,
        name: wp.name,
        category: wp.category,
        latitude: wp.latitude,
        longitude: wp.longitude,
        notes: wp.description,
      );
      inserted++;
    }

    // 3. Group tracks by tripId (atau fallback)
    if (preview.tracks.isNotEmpty) {
      // Map<groupKey, _TripGroup> dimana groupKey = tripId atau tripName
      // atau '_default' kalau tidak ada metadata trip.
      final groups = <String, _TripGroup>{};
      for (final track in preview.tracks) {
        final key = track.tripId ?? track.tripName ?? '_default';
        final existing = groups[key];
        if (existing == null) {
          groups[key] = _TripGroup(
            name: track.tripName ?? 'Impor: ${preview.fileName}',
            colorValue: track.tripColorValue,
            tracks: [track],
          );
        } else {
          existing.tracks.add(track);
        }
      }

      for (final group in groups.values) {
        // Hitung start/end timestamp dari trkpt
        final allPoints = group.tracks
            .expand((t) => t.points)
            .where((p) => p.timestamp != null)
            .toList();
        DateTime tripStart;
        DateTime tripEnd;
        if (allPoints.isNotEmpty) {
          tripStart = allPoints
              .map((p) => p.timestamp!)
              .reduce((a, b) => a.isBefore(b) ? a : b);
          tripEnd = allPoints
              .map((p) => p.timestamp!)
              .reduce((a, b) => a.isAfter(b) ? a : b);
        } else {
          tripStart = preview.exportedAt ?? DateTime.now();
          tripEnd = tripStart;
        }

        final trip = await tripRepo.createForDataset(
          datasetId: dataset.id,
          name: group.name,
          startedAt: tripStart,
          endedAt: tripEnd,
          colorValue: group.colorValue,
          homePort: preview.homePort,
        );

        // Per track in this group → buat Haul + TrackPoints
        var orderIndex = 1;
        for (final track in group.tracks) {
          final pointsWithTime = track.points
              .where((p) => p.timestamp != null)
              .toList();
          DateTime haulStart;
          DateTime haulEnd;
          if (track.haulStartedAt != null && track.haulEndedAt != null) {
            haulStart = track.haulStartedAt!;
            haulEnd = track.haulEndedAt!;
          } else if (pointsWithTime.isNotEmpty) {
            haulStart = pointsWithTime
                .map((p) => p.timestamp!)
                .reduce((a, b) => a.isBefore(b) ? a : b);
            haulEnd = pointsWithTime
                .map((p) => p.timestamp!)
                .reduce((a, b) => a.isAfter(b) ? a : b);
          } else {
            haulStart = tripStart;
            haulEnd = tripEnd;
          }

          // Stats: prefer dari extension. Kalau tidak ada,
          // recompute (rough) — distance dari haversine, swept
          // area dari distance × trawlWidth, durasi dari
          // start/end.
          final trawlWidth = track.haulTrawlWidthMeters ?? 20.0;
          final duration = track.haulDurationSeconds ??
              haulEnd.difference(haulStart).inSeconds;
          final distance = track.haulDistanceMeters ??
              _approxDistanceMeters(track.points);
          final sweptArea =
              track.haulSweptAreaM2 ?? (distance * trawlWidth);

          final haul = await haulRepo.createForDataset(
            datasetId: dataset.id,
            tripId: trip.id,
            orderIndex: track.haulOrderIndex ?? orderIndex,
            startedAt: haulStart,
            endedAt: haulEnd,
            trawlWidthMeters: trawlWidth,
            distanceMeters: distance,
            durationSeconds: duration,
            sweptAreaM2: sweptArea,
            name: track.haulName ?? track.name,
            avgSpeedKnots: track.haulAvgSpeedKnots,
            avgHeadingDegrees: track.haulAvgHeadingDegrees,
            colorValue: track.haulColorValue,
          );

          for (final pt in track.points) {
            await pointRepo.appendImportedPoint(
              haulId: haul.id,
              latitude: pt.latitude,
              longitude: pt.longitude,
              timestamp: pt.timestamp ?? haulStart,
              altitudeMeters: pt.elevation,
            );
            inserted++;
          }
          orderIndex++;
        }
      }
    }

    // 5. Recount denormalized counters
    await datasetRepo.recountChildren(dataset.id);
    Logger.instance.info('import.done', {
      'datasetId': dataset.id,
      'inserted': inserted,
    });

    return inserted;
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  /// Cari child element dengan `localName == name` tanpa peduli
  /// namespace prefix. Pakai walk manual karena `findElements` di
  /// xml package match by `name`, bukan localName.
  ///
  /// PR #44 (rebrand): pendekatan localName ini secara otomatis
  /// menerima both prefix `lsea:` (legacy Styra pre-rebrand)
  /// dan `styra:` (Styra rebrand+). File GPX dari versi app lama
  /// tetap bisa di-import tanpa perubahan apapun di sini.
  XmlElement? _findExtensionElement(XmlElement parent, String name) {
    for (final child in parent.children.whereType<XmlElement>()) {
      if (child.localName == name) return child;
    }
    return null;
  }

  /// Read text content dari child element dengan `localName == name`,
  /// trim, return null kalau kosong / absent.
  String? _extensionText(XmlElement parent, String name) {
    final el = _findExtensionElement(parent, name);
    if (el == null) return null;
    final text = el.innerText.trim();
    return text.isEmpty ? null : text;
  }

  /// Parse string '0xAARRGGBB' atau '#RRGGBB' ke int. Kalau gagal,
  /// return null.
  int? _parseHexInt(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    var clean = raw.trim();
    if (clean.startsWith('#')) {
      clean = clean.substring(1);
      // Tanpa alpha — tambahkan FF di depan.
      if (clean.length == 6) clean = 'FF$clean';
    } else if (clean.startsWith('0x') || clean.startsWith('0X')) {
      clean = clean.substring(2);
    }
    return int.tryParse(clean, radix: 16);
  }

  /// Estimate distance dalam meter dari list trackpoint via
  /// haversine. Dipakai sebagai fallback kalau `<lsea:haul
  /// distanceMeters>` tidak tersedia di file.
  double _approxDistanceMeters(List<PendingTrackPoint> points) {
    if (points.length < 2) return 0;
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += _haversineMeters(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return total;
  }

  double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // earth radius in meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.asin(math.sqrt(a));
    return r * c;
  }

  double _toRadians(double deg) => deg * math.pi / 180.0;
}

/// Internal grouping helper untuk merge multiple `<trk>` ke 1 Trip.
class _TripGroup {
  _TripGroup({
    required this.name,
    required this.colorValue,
    required this.tracks,
  });

  final String name;
  final int? colorValue;
  final List<PendingTrack> tracks;
}

final gpxImporterProvider = Provider<GpxImporter>((ref) {
  return GpxImporter(ref);
});
