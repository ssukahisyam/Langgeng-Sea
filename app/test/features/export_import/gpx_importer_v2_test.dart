// Roundtrip integration test untuk PR #33 Phase 4: ekspor PR #27
// dihasilkan oleh GpxExporter.exportFiltered, lalu di-import ulang
// oleh GpxImporter, harus menghasilkan dataset + marker + trip + haul
// + trackpoint dengan field utama match.
//
// Strategy: pakai in-memory AppDatabase (Drift), bypass repository
// FK kompleks dengan langsung verify count + kategori marker.

// PR #40: drift exports `isNull`/`isNotNull` matchers for SQL builder
// expressions yang clash dengan flutter_test matchers di test ini.
// Hide drift's matchers supaya `expect(..., isNull)` tetap pakai
// matcher version dari flutter_test.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:styra/data/database/app_database.dart';
import 'package:styra/features/export_import/data/gpx_importer.dart';
import 'package:styra/features/export_import/data/imported_dataset_repository.dart';
import 'package:styra/features/marker/domain/entities/marker.dart';

const _gpxWithLseaExtensions = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Langgeng Sea"
     xmlns="http://www.topografix.com/GPX/1/1"
     xmlns:lsea="http://langgeng-sea.app/gpx/extensions/v1">
  <metadata>
    <name>Data Langgeng Sea (Lengkap)</name>
    <time>2026-05-25T12:00:00.000Z</time>
    <author><name>Pak Hasan</name></author>
    <extensions>
      <lsea:exporter>
        <lsea:vesselName>KM Sumber Rejeki</lsea:vesselName>
        <lsea:ownerName>Pak Hasan</lsea:ownerName>
        <lsea:homePort>Paciran</lsea:homePort>
      </lsea:exporter>
      <lsea:exportedAt>2026-05-25T12:00:00.000Z</lsea:exportedAt>
    </extensions>
  </metadata>
  <wpt lat="-7.20000" lon="113.40000">
    <time>2026-05-25T08:00:00.000Z</time>
    <name>Spot Produktif 1</name>
    <desc>Tongkol</desc>
    <sym>diamond</sym>
    <type>Produktif</type>
    <extensions>
      <lsea:marker id="m1" category="produktif" categoryLabel="Produktif"/>
    </extensions>
  </wpt>
  <wpt lat="-7.21000" lon="113.41000">
    <name>Pelabuhan Brondong</name>
    <extensions>
      <lsea:marker id="m2" category="pelabuhan"/>
    </extensions>
  </wpt>
  <wpt lat="-7.22000" lon="113.42000">
    <name>Karang Bahaya</name>
    <extensions>
      <lsea:marker id="m3" category="bahaya"/>
    </extensions>
  </wpt>
  <trk>
    <name>Tarikan #1: Subuh</name>
    <desc>3.2 km, 1h 15m</desc>
    <type>fishing-haul</type>
    <extensions>
      <lsea:trip id="trip-a" name="Trip 25 Mei" status="completed"
                 startedAt="2026-05-25T05:00:00.000Z"
                 endedAt="2026-05-25T11:00:00.000Z"
                 colorValue="0xFFAABBCC"
                 colorHex="#AABBCC"/>
      <lsea:haul id="haul-1" orderIndex="1" status="completed"
                 startedAt="2026-05-25T05:30:00.000Z"
                 endedAt="2026-05-25T06:45:00.000Z"
                 trawlWidthMeters="20.00"
                 distanceMeters="3200.00"
                 durationSeconds="4500"
                 sweptAreaM2="64000.00"
                 colorValue="0xFFFF0000"
                 colorHex="#FF0000"/>
    </extensions>
    <trkseg>
      <trkpt lat="-7.20000" lon="113.40000">
        <time>2026-05-25T05:30:00.000Z</time>
      </trkpt>
      <trkpt lat="-7.20100" lon="113.40100">
        <time>2026-05-25T05:31:00.000Z</time>
      </trkpt>
      <trkpt lat="-7.20200" lon="113.40200">
        <time>2026-05-25T05:32:00.000Z</time>
      </trkpt>
    </trkseg>
  </trk>
  <trk>
    <name>Tarikan #2: Pagi</name>
    <type>fishing-haul</type>
    <extensions>
      <lsea:trip id="trip-a" name="Trip 25 Mei" status="completed"
                 startedAt="2026-05-25T05:00:00.000Z"
                 endedAt="2026-05-25T11:00:00.000Z"/>
      <lsea:haul id="haul-2" orderIndex="2" status="completed"
                 startedAt="2026-05-25T07:00:00.000Z"
                 endedAt="2026-05-25T08:30:00.000Z"
                 trawlWidthMeters="20.00"
                 distanceMeters="2800.00"
                 durationSeconds="5400"
                 sweptAreaM2="56000.00"/>
    </extensions>
    <trkseg>
      <trkpt lat="-7.21000" lon="113.41000">
        <time>2026-05-25T07:00:00.000Z</time>
      </trkpt>
      <trkpt lat="-7.21100" lon="113.41100">
        <time>2026-05-25T07:01:00.000Z</time>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';

const _gpxOsmAndStyle = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="OsmAnd"
     xmlns="http://www.topografix.com/GPX/1/1">
  <wpt lat="-7.30000" lon="113.50000">
    <name>Random Spot</name>
    <desc>From OsmAnd</desc>
  </wpt>
  <trk>
    <name>OsmAnd Track</name>
    <trkseg>
      <trkpt lat="-7.30000" lon="113.50000">
        <time>2026-05-26T05:00:00.000Z</time>
      </trkpt>
      <trkpt lat="-7.30100" lon="113.50100">
        <time>2026-05-26T05:01:00.000Z</time>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('GpxImporter.parse — file dengan lsea extensions', () {
    test('parse exporter metadata', () {
      final importer = container.read(gpxImporterProvider);
      final preview = importer.parse(
        _gpxWithLseaExtensions,
        fileName: 'trip-25-mei.gpx',
      );

      expect(preview.fileName, 'trip-25-mei.gpx');
      expect(preview.exporterName, 'Pak Hasan');
      expect(preview.vesselName, 'KM Sumber Rejeki');
      expect(preview.homePort, 'Paciran');
      expect(preview.exportedAt, isNotNull);
      expect(preview.hasExporterInfo, isTrue);
    });

    test('parse waypoints dengan kategori dari lsea:marker', () {
      final importer = container.read(gpxImporterProvider);
      final preview = importer.parse(
        _gpxWithLseaExtensions,
        fileName: 'trip-25-mei.gpx',
      );

      expect(preview.waypointCount, 3);
      // Kategori match dari extension (Bahasa Indonesia value)
      final byCategory = preview.waypointCountByCategory();
      expect(byCategory[MarkerCategory.productive], 1);
      expect(byCategory[MarkerCategory.port], 1);
      expect(byCategory[MarkerCategory.hazard], 1);
      expect(byCategory[MarkerCategory.other], isNull);

      final productive = preview.waypoints
          .firstWhere((w) => w.category == MarkerCategory.productive);
      expect(productive.name, 'Spot Produktif 1');
      expect(productive.description, 'Tongkol');
      expect(productive.latitude, closeTo(-7.20000, 0.00001));
      expect(productive.longitude, closeTo(113.40000, 0.00001));
    });

    test('parse tracks dengan lsea:trip + lsea:haul', () {
      final importer = container.read(gpxImporterProvider);
      final preview = importer.parse(
        _gpxWithLseaExtensions,
        fileName: 'trip-25-mei.gpx',
      );

      expect(preview.trackCount, 2);
      expect(preview.totalTrackPoints, 5); // 3 + 2

      // Trip metadata
      final t1 = preview.tracks.first;
      expect(t1.tripId, 'trip-a');
      expect(t1.tripName, 'Trip 25 Mei');
      expect(t1.tripColorValue, 0xFFAABBCC);

      // Haul metadata
      expect(t1.haulId, 'haul-1');
      expect(t1.haulColorValue, 0xFFFF0000);
      expect(t1.haulOrderIndex, 1);
      expect(t1.haulDistanceMeters, closeTo(3200.0, 0.01));
      expect(t1.haulDurationSeconds, 4500);
      expect(t1.haulSweptAreaM2, closeTo(64000.0, 0.01));
      expect(t1.haulTrawlWidthMeters, closeTo(20.0, 0.01));
    });
  });

  group('GpxImporter.parse — file dari aplikasi lain (no extensions)', () {
    test('parse waypoints dengan fallback kategori other', () {
      final importer = container.read(gpxImporterProvider);
      final preview = importer.parse(
        _gpxOsmAndStyle,
        fileName: 'osmand.gpx',
      );

      expect(preview.exporterName, isNull);
      expect(preview.vesselName, isNull);
      expect(preview.hasExporterInfo, isFalse);
      expect(preview.waypointCount, 1);
      expect(preview.waypoints.first.category, MarkerCategory.other);
    });

    test('parse tracks tanpa metadata trip/haul', () {
      final importer = container.read(gpxImporterProvider);
      final preview = importer.parse(
        _gpxOsmAndStyle,
        fileName: 'osmand.gpx',
      );

      expect(preview.trackCount, 1);
      expect(preview.tracks.first.tripId, isNull);
      expect(preview.tracks.first.tripName, isNull);
      expect(preview.tracks.first.haulId, isNull);
      expect(preview.tracks.first.haulColorValue, isNull);
    });
  });

  group('GpxImporter.import — persist to DB', () {
    test('PR #27 file → dataset + 3 markers + 1 trip + 2 hauls + 5 points',
        () async {
      final importer = container.read(gpxImporterProvider);
      final preview = importer.parse(
        _gpxWithLseaExtensions,
        fileName: 'trip-25-mei.gpx',
      );
      final inserted = await importer.import(preview);

      // 3 markers + 5 trkpt = 8
      expect(inserted, 8);

      // Verify dataset row
      final datasetRepo = container.read(importedDatasetRepositoryProvider);
      final datasets = await datasetRepo.getAll();
      expect(datasets, hasLength(1));
      final ds = datasets.single;
      expect(ds.fileName, 'trip-25-mei.gpx');
      expect(ds.exporterName, 'Pak Hasan');
      expect(ds.vesselName, 'KM Sumber Rejeki');
      expect(ds.markerCount, 3);
      expect(ds.tripCount, 1, reason: 'kedua track punya tripId yang sama');
      expect(ds.haulCount, 2);
      expect(ds.visible, isTrue);

      // Verify markers di-insert dengan dataset_id
      final markerRows = await db
          .customSelect(
            'SELECT id, name, category, dataset_id FROM markers',
          )
          .get();
      expect(markerRows, hasLength(3));
      for (final r in markerRows) {
        expect(r.data['dataset_id'], ds.id);
      }
      final categories =
          markerRows.map((r) => r.data['category'] as String).toSet();
      expect(categories, {'productive', 'port', 'hazard'});

      // Verify trips
      final tripRows = await db
          .customSelect(
            'SELECT id, name, dataset_id, color_value FROM trips',
          )
          .get();
      expect(tripRows, hasLength(1));
      expect(tripRows.single.data['name'], 'Trip 25 Mei');
      expect(tripRows.single.data['dataset_id'], ds.id);
      expect(tripRows.single.data['color_value'], 0xFFAABBCC);

      // Verify hauls
      final haulRows = await db
          .customSelect(
            'SELECT id, name, dataset_id, color_value, '
            'distance_meters, swept_area_m2 FROM hauls ORDER BY order_index',
          )
          .get();
      expect(haulRows, hasLength(2));
      expect(haulRows.first.data['dataset_id'], ds.id);
      expect(haulRows.first.data['color_value'], 0xFFFF0000);
      expect(
        (haulRows.first.data['distance_meters'] as num).toDouble(),
        closeTo(3200.0, 0.01),
      );

      // Verify trackpoints
      final pointCount = await db
          .customSelect('SELECT COUNT(*) AS c FROM track_points')
          .getSingle();
      expect(pointCount.data['c'], 5);
    });

    test('OsmAnd file → fallback Trip "Impor: filename"', () async {
      final importer = container.read(gpxImporterProvider);
      final preview = importer.parse(
        _gpxOsmAndStyle,
        fileName: 'osmand.gpx',
      );
      await importer.import(preview);

      final tripRows = await db.customSelect('SELECT name FROM trips').get();
      expect(tripRows, hasLength(1));
      // Tanpa <lsea:trip> extension, tripName = null. Group key
      // jadi '_default' → fallback name "Impor: {filename}".
      expect(tripRows.single.data['name'], 'Impor: osmand.gpx');

      final markerRows =
          await db.customSelect("SELECT category FROM markers").get();
      expect(markerRows, hasLength(1));
      expect(markerRows.single.data['category'], 'other');
    });
  });
}
