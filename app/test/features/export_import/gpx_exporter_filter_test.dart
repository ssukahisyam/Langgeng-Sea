// Tests untuk GpxExporter.exportFiltered (PR #27 R4 + R5).
//
// Memverifikasi:
// - <lsea:exporter> block muncul / hilang sesuai user profile
// - <lsea:summary> rolled-up totals akurat
// - Filter date range / tripIds / markerCategories memotong output
// - filterDescription string cocok dengan ExportFilter.describe()
// - colorValue di-encode sebagai colorHex pada <lsea:haul>
// - Output kosong (filter zero-result) tetap valid XML, bukan
//   self-closing root.

import 'package:flutter_test/flutter_test.dart';
import 'package:styra/features/export_import/data/gpx_exporter.dart';
import 'package:styra/features/export_import/domain/entities/date_range.dart';
import 'package:styra/features/export_import/domain/entities/export_filter.dart';
import 'package:styra/features/marker/domain/entities/marker.dart';
import 'package:styra/features/onboarding/domain/entities/user_profile.dart';
import 'package:styra/features/tracking/domain/entities/haul.dart';
import 'package:styra/features/tracking/domain/entities/track_point.dart';
import 'package:styra/features/tracking/domain/entities/trip.dart';
import 'package:xml/xml.dart';

void main() {
  late GpxExporter exporter;

  setUp(() {
    exporter = GpxExporter();
  });

  // ---------------------------------------------------------------------------
  // Fixtures
  // ---------------------------------------------------------------------------

  Trip mkTrip(
    String id, {
    String? name,
    DateTime? startedAt,
  }) =>
      Trip(
        id: id,
        name: name,
        startedAt: startedAt ?? DateTime.utc(2026, 5, 1),
        status: TripStatus.completed,
      );

  Haul mkHaul(
    String id, {
    required String tripId,
    int orderIndex = 1,
    double distanceMeters = 1000,
    int durationSeconds = 3600,
    double sweptAreaM2 = 20000,
    int? colorValue,
  }) =>
      Haul(
        id: id,
        tripId: tripId,
        orderIndex: orderIndex,
        startedAt: DateTime.utc(2026, 5, 1, 6),
        endedAt: DateTime.utc(2026, 5, 1, 7),
        status: HaulStatus.completed,
        trawlWidthMeters: 20,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        sweptAreaM2: sweptAreaM2,
        colorValue: colorValue,
      );

  AppMarker mkMarker(
    String id,
    MarkerCategory cat, {
    double lat = -6.9,
    double lon = 110.5,
  }) =>
      AppMarker(
        id: id,
        name: 'm-$id',
        category: cat,
        latitude: lat,
        longitude: lon,
        createdAt: DateTime.utc(2026, 5, 1),
      );

  UserProfile mkProfile() => UserProfile(
        name: 'Pak Budi',
        vesselName: 'KM Bahari',
        vesselGtOptional: 12.5,
        homePortOptional: 'Pelabuhan Tanjung',
        trawlWidthMeters: 22.5,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 5, 1),
      );

  TrackPoint mkPt(
    String haulId,
    double lat,
    double lon, [
    DateTime? ts,
  ]) =>
      TrackPoint(
        haulId: haulId,
        latitude: lat,
        longitude: lon,
        timestamp: ts ?? DateTime.utc(2026, 5, 1, 6, 30),
      );

  // ---------------------------------------------------------------------------
  // <lsea:exporter> presence
  // ---------------------------------------------------------------------------

  group('<lsea:exporter> block', () {
    test('present with full user profile data when exporter non-null', () {
      final gpx = exporter.exportFiltered(
        filter: ExportFilter.allData,
        exporter: mkProfile(),
        trips: const [],
        haulsByTripId: const {},
        pointsByHaulId: const {},
        markers: const [],
      );

      final doc = XmlDocument.parse(gpx);
      final exporterEl = doc
          .findAllElements('metadata')
          .single
          .findElements('extensions')
          .single
          .findElements('lsea:exporter')
          .single;

      expect(
        exporterEl.findElements('lsea:vesselName').single.innerText,
        'KM Bahari',
      );
      expect(
        exporterEl.findElements('lsea:ownerName').single.innerText,
        'Pak Budi',
      );
      expect(
        exporterEl.findElements('lsea:homePort').single.innerText,
        'Pelabuhan Tanjung',
      );
      expect(
        exporterEl.findElements('lsea:vesselGt').single.innerText,
        '12.50',
      );
      expect(
        exporterEl.findElements('lsea:trawlWidthMeters').single.innerText,
        '22.50',
      );
      expect(
        exporterEl.findElements('lsea:exportedAt').single.innerText,
        endsWith('Z'),
      );
      expect(
        exporterEl.findElements('lsea:filterDescription').single.innerText,
        contains('Jalur + Penanda'),
      );
    });

    test('omitted (placeholder only) when exporter is null', () {
      final gpx = exporter.exportFiltered(
        filter: ExportFilter.allData,
        exporter: null,
        trips: const [],
        haulsByTripId: const {},
        pointsByHaulId: const {},
        markers: const [],
      );
      final doc = XmlDocument.parse(gpx);

      // <author><name> falls back to "Styra".
      final authorName = doc
          .findAllElements('metadata')
          .single
          .findElements('author')
          .single
          .findElements('name')
          .single
          .innerText;
      expect(authorName, 'Styra');

      // Placeholder lsea:exporter block exists but with hasUserProfile=false.
      final placeholder = doc
          .findAllElements('metadata')
          .single
          .findElements('extensions')
          .single
          .findElements('lsea:exporter')
          .singleOrNull;
      expect(placeholder, isNotNull);
      expect(placeholder!.getAttribute('hasUserProfile'), 'false');
      expect(
        placeholder.findElements('lsea:vesselName'),
        isEmpty,
        reason: 'placeholder must NOT carry vessel data',
      );
    });

    test('exportedAt timestamp is honoured when supplied', () {
      final fixedNow = DateTime.utc(2026, 5, 16, 10, 30);
      final gpx = exporter.exportFiltered(
        filter: ExportFilter.allData,
        exporter: mkProfile(),
        exportedAt: fixedNow,
        trips: const [],
        haulsByTripId: const {},
        pointsByHaulId: const {},
        markers: const [],
      );
      expect(gpx, contains('2026-05-16T10:30:00.000Z'));
    });
  });

  // ---------------------------------------------------------------------------
  // <lsea:summary>
  // ---------------------------------------------------------------------------

  group('<lsea:summary>', () {
    test('rolled-up totals across multiple trips & hauls', () {
      final t1 = mkTrip('t1', startedAt: DateTime.utc(2026, 5, 1));
      final t2 = mkTrip('t2', startedAt: DateTime.utc(2026, 5, 5));
      final hauls = {
        't1': [
          mkHaul('h1',
              tripId: 't1',
              orderIndex: 1,
              distanceMeters: 1000,
              durationSeconds: 3600,
              sweptAreaM2: 20000,),
          mkHaul('h2',
              tripId: 't1',
              orderIndex: 2,
              distanceMeters: 500,
              durationSeconds: 1800,
              sweptAreaM2: 10000,),
        ],
        't2': [
          mkHaul('h3',
              tripId: 't2',
              orderIndex: 1,
              distanceMeters: 2000,
              durationSeconds: 7200,
              sweptAreaM2: 40000,),
        ],
      };
      final markers = [
        mkMarker('m1', MarkerCategory.productive),
        mkMarker('m2', MarkerCategory.hazard),
        mkMarker('m3', MarkerCategory.port),
      ];

      final gpx = exporter.exportFiltered(
        filter: ExportFilter.allData,
        exporter: mkProfile(),
        trips: [t1, t2],
        haulsByTripId: hauls,
        pointsByHaulId: const {},
        markers: markers,
      );

      final doc = XmlDocument.parse(gpx);
      final summary = doc
          .findAllElements('metadata')
          .single
          .findElements('extensions')
          .single
          .findElements('lsea:summary')
          .single;

      expect(summary.getAttribute('tripCount'), '2');
      expect(summary.getAttribute('haulCount'), '3');
      expect(summary.getAttribute('markerCount'), '3');
      expect(summary.getAttribute('totalDistanceMeters'), '3500.00');
      expect(summary.getAttribute('totalDurationSeconds'), '12600');
      expect(summary.getAttribute('totalSweptAreaM2'), '70000.00');
    });

    test('reflects filter — hauls outside dateRange are not summed', () {
      final inRange = mkTrip('in', startedAt: DateTime.utc(2026, 5, 5));
      final outRange = mkTrip('out', startedAt: DateTime.utc(2026, 1, 1));
      final hauls = {
        'in': [mkHaul('h1', tripId: 'in', distanceMeters: 1000)],
        'out': [mkHaul('h9', tripId: 'out', distanceMeters: 9999)],
      };

      final filter = ExportFilter(
        includeTracks: true,
        includeMarkers: false,
        dateRange: DateRange.fromDates(
          from: DateTime(2026, 5, 1),
          to: DateTime(2026, 5, 7),
        ),
      );

      final gpx = exporter.exportFiltered(
        filter: filter,
        exporter: mkProfile(),
        trips: [inRange, outRange],
        haulsByTripId: hauls,
        pointsByHaulId: const {},
        markers: const [],
      );
      final doc = XmlDocument.parse(gpx);
      final summary = doc.findAllElements('lsea:summary').single;
      expect(summary.getAttribute('tripCount'), '1');
      expect(summary.getAttribute('haulCount'), '1');
      expect(summary.getAttribute('totalDistanceMeters'), '1000.00');
    });
  });

  // ---------------------------------------------------------------------------
  // Filter behaviour
  // ---------------------------------------------------------------------------

  group('filter behaviour', () {
    test('includeTracks=false produces no <trk>', () {
      final t = mkTrip('t1');
      final filter = ExportFilter(
        includeTracks: false,
        includeMarkers: true,
      );
      final gpx = exporter.exportFiltered(
        filter: filter,
        exporter: mkProfile(),
        trips: [t],
        haulsByTripId: {
          't1': [mkHaul('h1', tripId: 't1')],
        },
        pointsByHaulId: const {},
        markers: [mkMarker('m1', MarkerCategory.productive)],
      );
      final doc = XmlDocument.parse(gpx);
      expect(doc.findAllElements('trk'), isEmpty);
      expect(doc.findAllElements('wpt'), hasLength(1));
    });

    test('includeMarkers=false produces no <wpt>', () {
      final t = mkTrip('t1');
      final filter = ExportFilter(
        includeTracks: true,
        includeMarkers: false,
      );
      final gpx = exporter.exportFiltered(
        filter: filter,
        exporter: mkProfile(),
        trips: [t],
        haulsByTripId: {
          't1': [mkHaul('h1', tripId: 't1')],
        },
        pointsByHaulId: const {},
        markers: [mkMarker('m1', MarkerCategory.productive)],
      );
      final doc = XmlDocument.parse(gpx);
      expect(doc.findAllElements('wpt'), isEmpty);
      expect(doc.findAllElements('trk'), hasLength(1));
    });

    test('tripIds subset emits tracks only for matching trips', () {
      final t1 = mkTrip('t1');
      final t2 = mkTrip('t2', startedAt: DateTime.utc(2026, 5, 5));
      final filter = ExportFilter(
        includeTracks: true,
        includeMarkers: false,
        tripIds: {'t1'},
      );
      final gpx = exporter.exportFiltered(
        filter: filter,
        exporter: mkProfile(),
        trips: [t1, t2],
        haulsByTripId: {
          't1': [mkHaul('h1', tripId: 't1')],
          't2': [mkHaul('h2', tripId: 't2')],
        },
        pointsByHaulId: const {},
        markers: const [],
      );
      final doc = XmlDocument.parse(gpx);
      final tracks = doc.findAllElements('trk').toList();
      expect(tracks, hasLength(1));
      // Track must reference parent trip 't1'.
      final lseaTripId = tracks.single
          .findElements('extensions')
          .single
          .findElements('lsea:trip')
          .single
          .getAttribute('id');
      expect(lseaTripId, 't1');
    });

    test('markerCategories subset filters waypoints', () {
      final t = mkTrip('t1');
      final filter = ExportFilter(
        includeTracks: false,
        includeMarkers: true,
        markerCategories: {MarkerCategory.hazard},
      );
      final gpx = exporter.exportFiltered(
        filter: filter,
        exporter: mkProfile(),
        trips: [t],
        haulsByTripId: const {},
        pointsByHaulId: const {},
        markers: [
          mkMarker('m1', MarkerCategory.productive),
          mkMarker('m2', MarkerCategory.hazard),
          mkMarker('m3', MarkerCategory.port),
        ],
      );
      final doc = XmlDocument.parse(gpx);
      final wpts = doc.findAllElements('wpt').toList();
      expect(wpts, hasLength(1));
      final lseaMarker = wpts.single
          .findElements('extensions')
          .single
          .findElements('lsea:marker')
          .single;
      expect(lseaMarker.getAttribute('category'), 'hazard');
    });

    test('zero-result filter still produces well-formed GPX (not self-closing)',
        () {
      final filter = ExportFilter(
        includeTracks: true,
        includeMarkers: true,
        tripIds: const {}, // explicit empty → zero trips
        markerCategories: const {}, // explicit empty → zero markers
      );
      final gpx = exporter.exportFiltered(
        filter: filter,
        exporter: mkProfile(),
        trips: [mkTrip('t1')],
        haulsByTripId: {
          't1': [mkHaul('h1', tripId: 't1')],
        },
        pointsByHaulId: const {},
        markers: [mkMarker('m1', MarkerCategory.hazard)],
      );

      final doc = XmlDocument.parse(gpx);
      final root = doc.rootElement;
      expect(root.findAllElements('trk'), isEmpty);
      expect(root.findAllElements('wpt'), isEmpty);
      // metadata still present + exporter block + summary.
      expect(root.findElements('metadata'), hasLength(1));
      expect(gpx, isNot(matches(RegExp(r'<gpx[^>]*/>'))));
      expect(gpx, contains('</gpx>'));
    });
  });

  // ---------------------------------------------------------------------------
  // Color encoding
  // ---------------------------------------------------------------------------

  group('color encoding', () {
    test('colorValue surfaces as both ARGB hex and #RGB hex on <lsea:haul>',
        () {
      // 0xFF4FC3F7 = solid sky blue
      const argb = 0xFF4FC3F7;
      final t = mkTrip('t1');
      final h = mkHaul('h1', tripId: 't1', colorValue: argb);
      final gpx = exporter.exportFiltered(
        filter: ExportFilter.allData,
        exporter: mkProfile(),
        trips: [t],
        haulsByTripId: {'t1': [h]},
        pointsByHaulId: const {},
        markers: const [],
      );
      final doc = XmlDocument.parse(gpx);
      final lseaHaul = doc
          .findAllElements('trk')
          .single
          .findElements('extensions')
          .single
          .findElements('lsea:haul')
          .single;
      expect(lseaHaul.getAttribute('colorValue'), '0xFF4FC3F7');
      expect(lseaHaul.getAttribute('colorHex'), '#4FC3F7');
    });

    test('null colorValue emits no color attributes', () {
      final t = mkTrip('t1');
      final h = mkHaul('h1', tripId: 't1', colorValue: null);
      final gpx = exporter.exportFiltered(
        filter: ExportFilter.allData,
        exporter: mkProfile(),
        trips: [t],
        haulsByTripId: {'t1': [h]},
        pointsByHaulId: const {},
        markers: const [],
      );
      final doc = XmlDocument.parse(gpx);
      final lseaHaul = doc.findAllElements('lsea:haul').single;
      expect(lseaHaul.getAttribute('colorValue'), isNull);
      expect(lseaHaul.getAttribute('colorHex'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // filterDescription cocok dengan ExportFilter.describe()
  // ---------------------------------------------------------------------------

  group('filterDescription consistency', () {
    test('matches ExportFilter.describe() output verbatim', () {
      final filter = ExportFilter(
        includeTracks: true,
        includeMarkers: true,
        markerCategories: {MarkerCategory.productive, MarkerCategory.hazard},
      );
      final gpx = exporter.exportFiltered(
        filter: filter,
        exporter: mkProfile(),
        trips: const [],
        haulsByTripId: const {},
        pointsByHaulId: const {},
        markers: const [],
      );
      final doc = XmlDocument.parse(gpx);
      final desc = doc
          .findAllElements('lsea:filterDescription')
          .single
          .innerText;
      expect(desc, filter.describe());
    });
  });

  // ---------------------------------------------------------------------------
  // Track points tetap muncul di output kalau tracks include
  // ---------------------------------------------------------------------------

  group('track points round-trip', () {
    test('points masuk ke trkseg', () {
      final t = mkTrip('t1');
      final h = mkHaul('h1', tripId: 't1');
      final gpx = exporter.exportFiltered(
        filter: ExportFilter.allData,
        exporter: mkProfile(),
        trips: [t],
        haulsByTripId: {'t1': [h]},
        pointsByHaulId: {
          'h1': [
            mkPt('h1', -7.0, 110.0),
            mkPt('h1', -7.001, 110.001),
          ],
        },
        markers: const [],
      );
      final doc = XmlDocument.parse(gpx);
      final trkpts = doc.findAllElements('trkpt').toList();
      expect(trkpts, hasLength(2));
      expect(trkpts.first.getAttribute('lat'), '-7');
      expect(trkpts.first.getAttribute('lon'), '110');
    });
  });
}
