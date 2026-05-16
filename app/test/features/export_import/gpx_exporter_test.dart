import 'package:flutter_test/flutter_test.dart';
import 'package:langgeng_sea/features/export_import/data/gpx_exporter.dart';
import 'package:langgeng_sea/features/marker/domain/entities/marker.dart';
import 'package:langgeng_sea/features/tracking/domain/entities/haul.dart';
import 'package:langgeng_sea/features/tracking/domain/entities/track_point.dart';
import 'package:langgeng_sea/features/tracking/domain/entities/trip.dart';
import 'package:xml/xml.dart';

void main() {
  late GpxExporter exporter;

  setUp(() {
    exporter = GpxExporter();
  });

  Trip trip({String? name}) => Trip(
        id: 'trip-1',
        startedAt: DateTime.utc(2024, 6, 15, 5),
        status: TripStatus.completed,
        name: name,
        endedAt: DateTime.utc(2024, 6, 15, 12),
      );

  Haul haul({
    String id = 'haul-1',
    String? name,
    int orderIndex = 1,
    HaulStatus status = HaulStatus.completed,
    double distanceMeters = 0,
    int durationSeconds = 0,
    double sweptAreaM2 = 0,
  }) =>
      Haul(
        id: id,
        tripId: 'trip-1',
        orderIndex: orderIndex,
        name: name,
        startedAt: DateTime.utc(2024, 6, 15, 6),
        endedAt: DateTime.utc(2024, 6, 15, 8),
        status: status,
        trawlWidthMeters: 20.0,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        sweptAreaM2: sweptAreaM2,
      );

  TrackPoint pt({
    double lat = -6.8891,
    double lon = 110.4196,
    DateTime? ts,
    double? speed,
  }) =>
      TrackPoint(
        haulId: 'haul-1',
        latitude: lat,
        longitude: lon,
        timestamp: ts ?? DateTime.utc(2024, 6, 15, 6),
        speedMps: speed,
      );

  group('GpxExporter.exportHaul', () {
    test('produces valid GPX 1.1 with required namespaces and metadata', () {
      final h = haul(name: 'Spot Pagi');
      final gpx = exporter.exportHaul(h, [pt(speed: 2.5)]);

      // Document must be parseable XML.
      final doc = XmlDocument.parse(gpx);
      final root = doc.rootElement;

      expect(root.name.local, 'gpx');
      expect(root.getAttribute('version'), '1.1');
      expect(root.getAttribute('creator'), 'Langgeng Sea');
      expect(
        root.getAttribute('xmlns'),
        'http://www.topografix.com/GPX/1/1',
      );
      expect(
        root.getAttribute('xmlns:lsea'),
        startsWith('https://langgengsea.id/gpx/extensions'),
      );

      // Always present even when output is otherwise minimal.
      expect(root.findElements('metadata').single, isNotNull);
      expect(root.findAllElements('trk'), isNotEmpty);
      expect(root.findAllElements('trkpt'), hasLength(1));
    });

    test('encodes coordinates and timestamps from the track point', () {
      final h = haul(name: 'Spot Pagi');
      final gpx = exporter.exportHaul(h, [pt(speed: 3.14)]);

      expect(gpx, contains('lat="-6.8891"'));
      expect(gpx, contains('lon="110.4196"'));
      expect(gpx, contains('<time>2024-06-15T06:00:00.000Z</time>'));
      expect(gpx, contains('<speed>3.14</speed>'));
    });

    test('omits speed element when point has no speed', () {
      final gpx = exporter.exportHaul(haul(name: 'X'), [pt()]);
      expect(gpx, isNot(contains('<speed>')));
    });

    test('falls back to displayName when haul has no user-given name', () {
      final gpx = exporter.exportHaul(haul(orderIndex: 3), const []);
      expect(gpx, contains('<name>Tarikan #3</name>'));
    });

    test('escapes XML special characters in track name', () {
      final h = haul(name: 'Spot <utara> & "selatan"');
      final gpx = exporter.exportHaul(h, const []);
      // The xml package escapes properly; just round-trip parse + read.
      final doc = XmlDocument.parse(gpx);
      final trkName = doc
          .findAllElements('trk')
          .single
          .findElements('name')
          .single
          .innerText;
      expect(trkName, 'Spot <utara> & "selatan"');
    });
  });

  group('GpxExporter.exportTrip', () {
    test('emits one <trk> per haul, even when haul has no points', () {
      final t = trip(name: 'Trip Siang');
      final hauls = [
        haul(id: 'h1', name: 'Haul 1', orderIndex: 1),
        haul(id: 'h2', name: 'Haul 2', orderIndex: 2),
      ];
      final pts = {
        'h1': [pt(lat: -6.88, lon: 110.41)],
        'h2': const <TrackPoint>[],
      };

      final gpx = exporter.exportTrip(t, hauls, pts);
      final doc = XmlDocument.parse(gpx);

      final tracks = doc.findAllElements('trk').toList();
      expect(tracks, hasLength(2));
      // Empty haul still has a trkseg (possibly self-closing) so the
      // schema stays valid.
      final track2 = tracks[1];
      expect(track2.findElements('trkseg'), hasLength(1));
      expect(track2.findElements('name').single.innerText, 'Haul 2');
    });

    test('produces a complete GPX even when trip has zero hauls', () {
      // PR #25 regression guard: empty data must NOT produce
      // self-closing root.
      final t = trip(name: 'Trip Kosong');
      final gpx = exporter.exportTrip(t, const [], const {});

      final doc = XmlDocument.parse(gpx);
      final root = doc.rootElement;
      expect(root.findElements('metadata'), hasLength(1));
      final metadata = root.findElements('metadata').single;
      // Metadata title is now a generic content-aware label, not the
      // trip name (since exportTrip is a shim around exportFiltered
      // and the filter only mentions 'jalur saja' content). Trip
      // name still surfaces on each <trk>'s lsea:trip extension.
      expect(metadata.findElements('time'), hasLength(1));

      // No tracks because there are no hauls — but root is NOT
      // self-closing (it has child elements).
      expect(root.findAllElements('trk'), isEmpty);
      expect(gpx, isNot(matches(RegExp(r'<gpx[^>]*/>'))));
      expect(gpx, contains('</gpx>'));
    });

    test('writes markers as <wpt> waypoints with category metadata', () {
      final t = trip(name: 'Trip Tengah');
      final marker = AppMarker(
        id: 'm-1',
        name: 'Karang Hiu',
        category: MarkerCategory.hazard,
        latitude: -6.9,
        longitude: 110.5,
        notes: 'Hindari saat air pasang',
        createdAt: DateTime.utc(2024, 6, 1),
      );

      final gpx = exporter.exportTrip(
        t,
        const [],
        const {},
        markers: [marker],
      );
      final doc = XmlDocument.parse(gpx);
      final wpt = doc.findAllElements('wpt').single;

      expect(wpt.getAttribute('lat'), '-6.9');
      expect(wpt.getAttribute('lon'), '110.5');
      expect(wpt.findElements('name').single.innerText, 'Karang Hiu');
      expect(
        wpt.findElements('desc').single.innerText,
        'Hindari saat air pasang',
      );
      // lsea extension preserves category for round-tripping.
      final ext = wpt.findElements('extensions').single;
      final lseaMarker = ext.findElements('lsea:marker').single;
      expect(lseaMarker.getAttribute('category'), 'hazard');
      expect(lseaMarker.getAttribute('categoryLabel'), 'Karang/Bahaya');
    });

    test('parent <lsea:trip> extension appears on every track', () {
      final t = trip(name: 'Trip Stats');
      final hauls = [
        haul(
          id: 'h1',
          name: 'A',
          distanceMeters: 1000,
          durationSeconds: 3600,
          sweptAreaM2: 20000,
        ),
        haul(
          id: 'h2',
          name: 'B',
          orderIndex: 2,
          distanceMeters: 500,
          durationSeconds: 1800,
          sweptAreaM2: 10000,
        ),
      ];
      final gpx = exporter.exportTrip(
        t,
        hauls,
        const {'h1': [], 'h2': []},
      );
      final doc = XmlDocument.parse(gpx);

      final tracks = doc.findAllElements('trk').toList();
      for (final track in tracks) {
        final ext = track.findElements('extensions').single;
        final lseaTrip = ext.findElements('lsea:trip').single;
        expect(lseaTrip.getAttribute('id'), 'trip-1');
        expect(lseaTrip.getAttribute('name'), 'Trip Stats');
      }
    });

    test('embeds aggregated lsea:summary in metadata extensions', () {
      final t = trip(name: 'Trip Stats');
      final hauls = [
        haul(
          id: 'h1',
          name: 'A',
          distanceMeters: 1000,
          durationSeconds: 3600,
          sweptAreaM2: 20000,
        ),
        haul(
          id: 'h2',
          name: 'B',
          orderIndex: 2,
          distanceMeters: 500,
          durationSeconds: 1800,
          sweptAreaM2: 10000,
        ),
      ];
      final gpx = exporter.exportTrip(
        t,
        hauls,
        const {'h1': [], 'h2': []},
      );
      final doc = XmlDocument.parse(gpx);
      final metaExt = doc
          .findAllElements('metadata')
          .single
          .findElements('extensions')
          .single;
      final summary = metaExt.findElements('lsea:summary').single;
      expect(summary.getAttribute('tripCount'), '1');
      expect(summary.getAttribute('haulCount'), '2');
      expect(summary.getAttribute('totalDistanceMeters'), '1500.00');
      expect(summary.getAttribute('totalDurationSeconds'), '5400');
    });

    test('computes <bounds> from track points and waypoints', () {
      final t = trip(name: 'Bounds');
      final hauls = [haul(id: 'h1')];
      final pts = {
        'h1': [
          pt(lat: -7.0, lon: 110.0),
          pt(lat: -6.5, lon: 111.0),
        ],
      };
      final gpx = exporter.exportTrip(t, hauls, pts);
      final doc = XmlDocument.parse(gpx);
      final bounds =
          doc.findAllElements('metadata').single.findElements('bounds').single;
      expect(bounds.getAttribute('minlat'), '-7');
      expect(bounds.getAttribute('maxlat'), '-6.5');
      expect(bounds.getAttribute('minlon'), '110');
      expect(bounds.getAttribute('maxlon'), '111');
    });
  });
}
