import 'package:flutter_test/flutter_test.dart';
import 'package:langgeng_sea/features/export_import/data/gpx_exporter.dart';
import 'package:langgeng_sea/features/tracking/domain/entities/haul.dart';
import 'package:langgeng_sea/features/tracking/domain/entities/track_point.dart';
import 'package:langgeng_sea/features/tracking/domain/entities/trip.dart';

void main() {
  late GpxExporter exporter;

  setUp(() {
    exporter = GpxExporter();
  });

  group('GpxExporter.exportHaul', () {
    test('generates valid GPX 1.1 structure', () {
      final haul = Haul(
        id: 'haul-1',
        tripId: 'trip-1',
        orderIndex: 1,
        name: 'Haul Pagi',
        startedAt: DateTime(2024, 6, 15, 6, 0),
        status: HaulStatus.completed,
        trawlWidthMeters: 20.0,
        endedAt: DateTime(2024, 6, 15, 8, 0),
        distanceMeters: 5000,
        durationSeconds: 7200,
      );

      final points = [
        TrackPoint(
          haulId: 'haul-1',
          latitude: -6.8891,
          longitude: 110.4196,
          timestamp: DateTime.utc(2024, 6, 15, 6, 0),
          speedMps: 2.5,
        ),
        TrackPoint(
          haulId: 'haul-1',
          latitude: -6.8901,
          longitude: 110.4210,
          timestamp: DateTime.utc(2024, 6, 15, 6, 5),
          speedMps: 2.8,
        ),
      ];

      final gpx = exporter.exportHaul(haul, points);

      // Verify XML header
      expect(gpx, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      // Verify GPX root with version and creator
      expect(gpx, contains('version="1.1"'));
      expect(gpx, contains('creator="Langgeng Sea"'));
      // Verify track structure
      expect(gpx, contains('<trk>'));
      expect(gpx, contains('<name>Haul Pagi</name>'));
      expect(gpx, contains('<trkseg>'));
      expect(gpx, contains('</trkseg>'));
      expect(gpx, contains('</trk>'));
      expect(gpx, contains('</gpx>'));
    });

    test('includes correct lat/lon values', () {
      final haul = Haul(
        id: 'haul-1',
        tripId: 'trip-1',
        orderIndex: 1,
        startedAt: DateTime(2024, 6, 15, 6, 0),
        status: HaulStatus.completed,
        trawlWidthMeters: 20.0,
      );

      final points = [
        TrackPoint(
          haulId: 'haul-1',
          latitude: -6.8891,
          longitude: 110.4196,
          timestamp: DateTime.utc(2024, 6, 15, 6, 0),
        ),
      ];

      final gpx = exporter.exportHaul(haul, points);

      expect(gpx, contains('lat="-6.8891"'));
      expect(gpx, contains('lon="110.4196"'));
    });

    test('includes time and speed elements', () {
      final haul = Haul(
        id: 'haul-1',
        tripId: 'trip-1',
        orderIndex: 1,
        startedAt: DateTime(2024, 6, 15, 6, 0),
        status: HaulStatus.completed,
        trawlWidthMeters: 20.0,
      );

      final points = [
        TrackPoint(
          haulId: 'haul-1',
          latitude: -6.8891,
          longitude: 110.4196,
          timestamp: DateTime.utc(2024, 6, 15, 6, 0),
          speedMps: 3.14,
        ),
      ];

      final gpx = exporter.exportHaul(haul, points);

      expect(gpx, contains('<time>2024-06-15T06:00:00.000Z</time>'));
      expect(gpx, contains('<speed>3.14</speed>'));
    });

    test('omits speed element when null', () {
      final haul = Haul(
        id: 'haul-1',
        tripId: 'trip-1',
        orderIndex: 1,
        startedAt: DateTime(2024, 6, 15, 6, 0),
        status: HaulStatus.completed,
        trawlWidthMeters: 20.0,
      );

      final points = [
        TrackPoint(
          haulId: 'haul-1',
          latitude: -6.8891,
          longitude: 110.4196,
          timestamp: DateTime.utc(2024, 6, 15, 6, 0),
        ),
      ];

      final gpx = exporter.exportHaul(haul, points);

      expect(gpx, isNot(contains('<speed>')));
    });

    test('uses displayName fallback when name is null', () {
      final haul = Haul(
        id: 'haul-1',
        tripId: 'trip-1',
        orderIndex: 3,
        startedAt: DateTime(2024, 6, 15, 6, 0),
        status: HaulStatus.completed,
        trawlWidthMeters: 20.0,
      );

      final gpx = exporter.exportHaul(haul, []);

      expect(gpx, contains('<name>Haul #3</name>'));
    });

    test('escapes XML special characters in track name', () {
      final haul = Haul(
        id: 'haul-1',
        tripId: 'trip-1',
        orderIndex: 1,
        name: 'Haul <utara> & "selatan"',
        startedAt: DateTime(2024, 6, 15, 6, 0),
        status: HaulStatus.completed,
        trawlWidthMeters: 20.0,
      );

      final gpx = exporter.exportHaul(haul, []);

      expect(
        gpx,
        contains(
          '<name>Haul &lt;utara&gt; &amp; &quot;selatan&quot;</name>',
        ),
      );
    });
  });

  group('GpxExporter.exportTrip', () {
    test('generates multiple tracks for multiple hauls', () {
      final trip = Trip(
        id: 'trip-1',
        startedAt: DateTime(2024, 6, 15),
        status: TripStatus.completed,
        name: 'Trip Siang',
      );

      final hauls = [
        Haul(
          id: 'h1',
          tripId: 'trip-1',
          orderIndex: 1,
          name: 'Haul 1',
          startedAt: DateTime(2024, 6, 15, 6, 0),
          status: HaulStatus.completed,
          trawlWidthMeters: 20.0,
        ),
        Haul(
          id: 'h2',
          tripId: 'trip-1',
          orderIndex: 2,
          name: 'Haul 2',
          startedAt: DateTime(2024, 6, 15, 10, 0),
          status: HaulStatus.completed,
          trawlWidthMeters: 20.0,
        ),
      ];

      final pointsByHaul = <String, List<TrackPoint>>{
        'h1': [
          TrackPoint(
            haulId: 'h1',
            latitude: -6.88,
            longitude: 110.41,
            timestamp: DateTime.utc(2024, 6, 15, 6, 0),
          ),
        ],
        'h2': [
          TrackPoint(
            haulId: 'h2',
            latitude: -6.89,
            longitude: 110.42,
            timestamp: DateTime.utc(2024, 6, 15, 10, 0),
          ),
        ],
      };

      final gpx = exporter.exportTrip(trip, hauls, pointsByHaul);

      // Should contain two trk elements
      expect('<trk>'.allMatches(gpx).length, equals(2));
      expect(gpx, contains('<name>Haul 1</name>'));
      expect(gpx, contains('<name>Haul 2</name>'));
    });
  });
}
