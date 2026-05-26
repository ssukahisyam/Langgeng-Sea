import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:styra/features/export_import/data/lsea_json_exporter.dart';
import 'package:styra/features/export_import/data/lsea_json_importer.dart';
import 'package:styra/features/logbook/domain/entities/catch_item.dart';
import 'package:styra/features/logbook/domain/entities/log_book_entry.dart';
import 'package:styra/features/tracking/domain/entities/haul.dart';
import 'package:styra/features/tracking/domain/entities/track_point.dart';
import 'package:styra/features/tracking/domain/entities/trip.dart';

void main() {
  group('LseaJsonExporter', () {
    late LseaJsonExporter exporter;

    setUp(() {
      exporter = LseaJsonExporter();
    });

    test('exported JSON has correct format field', () {
      final trip = Trip(
        id: 'trip-1',
        startedAt: DateTime(2024, 6, 15),
        status: TripStatus.completed,
      );

      final result = exporter.exportTrip(
        trip: trip,
        hauls: [],
        pointsByHaul: {},
        logBookByHaul: {},
        userName: 'Pak Ahmad',
        vesselName: 'KM Sejahtera',
      );

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['format'], equals('langgeng-sea-v1'));
    });

    test('exported JSON has correct exportedBy fields', () {
      final trip = Trip(
        id: 'trip-1',
        startedAt: DateTime(2024, 6, 15),
        status: TripStatus.completed,
      );

      final result = exporter.exportTrip(
        trip: trip,
        hauls: [],
        pointsByHaul: {},
        logBookByHaul: {},
        userName: 'Pak Ahmad',
        vesselName: 'KM Sejahtera',
      );

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      final exportedBy = decoded['exportedBy'] as Map<String, dynamic>;
      expect(exportedBy['name'], equals('Pak Ahmad'));
      expect(exportedBy['vessel'], equals('KM Sejahtera'));
    });

    test('exported JSON contains trip with hauls structure', () {
      final trip = Trip(
        id: 'trip-1',
        name: 'Trip Utara',
        startedAt: DateTime(2024, 6, 15),
        status: TripStatus.completed,
      );

      final hauls = [
        Haul(
          id: 'h1',
          tripId: 'trip-1',
          orderIndex: 1,
          startedAt: DateTime(2024, 6, 15, 6, 0),
          status: HaulStatus.completed,
          trawlWidthMeters: 20.0,
          distanceMeters: 3000,
          durationSeconds: 3600,
        ),
      ];

      final pointsByHaul = <String, List<TrackPoint>>{
        'h1': [
          TrackPoint(
            haulId: 'h1',
            latitude: -6.88,
            longitude: 110.41,
            timestamp: DateTime.utc(2024, 6, 15, 6, 0),
            speedMps: 2.5,
          ),
        ],
      };

      final result = exporter.exportTrip(
        trip: trip,
        hauls: hauls,
        pointsByHaul: pointsByHaul,
        logBookByHaul: {},
        userName: 'Pak Ahmad',
        vesselName: 'KM Sejahtera',
      );

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      final tripData = decoded['trip'] as Map<String, dynamic>;
      expect(tripData['id'], equals('trip-1'));
      expect(tripData['name'], equals('Trip Utara'));

      final haulsData = tripData['hauls'] as List;
      expect(haulsData.length, equals(1));

      final haulData = haulsData[0] as Map<String, dynamic>;
      expect(haulData['distanceMeters'], equals(3000));
      expect(haulData['durationSeconds'], equals(3600));

      final trackPoints = haulData['trackPoints'] as List;
      expect(trackPoints.length, equals(1));
      expect(trackPoints[0]['lat'], equals(-6.88));
      expect(trackPoints[0]['lon'], equals(110.41));
    });

    test('exported JSON includes logbook with catches', () {
      final trip = Trip(
        id: 'trip-1',
        startedAt: DateTime(2024, 6, 15),
        status: TripStatus.completed,
      );

      final hauls = [
        Haul(
          id: 'h1',
          tripId: 'trip-1',
          orderIndex: 1,
          startedAt: DateTime(2024, 6, 15, 6, 0),
          status: HaulStatus.completed,
          trawlWidthMeters: 20.0,
        ),
      ];

      final logBookByHaul = <String, LogBookEntry>{
        'h1': LogBookEntry(
          id: 'lb-1',
          scope: LogBookScope.haul,
          haulId: 'h1',
          weather: Weather.cerah,
          catches: [
            const CatchItem(id: 'c1', species: 'Kakap', weightKg: 15.5),
            const CatchItem(id: 'c2', species: 'Tongkol', weightKg: 8.0),
          ],
          createdAt: DateTime(2024, 6, 15),
          updatedAt: DateTime(2024, 6, 15),
        ),
      };

      final result = exporter.exportTrip(
        trip: trip,
        hauls: hauls,
        pointsByHaul: {'h1': []},
        logBookByHaul: logBookByHaul,
        userName: 'Budi',
        vesselName: 'Kapal Maju',
      );

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      final tripData = decoded['trip'] as Map<String, dynamic>;
      final haulData = (tripData['hauls'] as List)[0] as Map<String, dynamic>;
      final logBook = haulData['logBook'] as Map<String, dynamic>;

      expect(logBook['weather'], equals('cerah'));
      final catches = logBook['catches'] as List;
      expect(catches.length, equals(2));
      expect(catches[0]['species'], equals('Kakap'));
      expect(catches[0]['weightKg'], equals(15.5));
    });

    test('exported JSON has exportedAt timestamp', () {
      final trip = Trip(
        id: 'trip-1',
        startedAt: DateTime(2024, 6, 15),
        status: TripStatus.completed,
      );

      final result = exporter.exportTrip(
        trip: trip,
        hauls: [],
        pointsByHaul: {},
        logBookByHaul: {},
        userName: 'Test',
        vesselName: 'Test Vessel',
      );

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['exportedAt'], isNotNull);
      // Should be a valid ISO 8601 date
      expect(DateTime.tryParse(decoded['exportedAt'] as String), isNotNull);
    });

    test('exported JSON has markers array (empty for now)', () {
      final trip = Trip(
        id: 'trip-1',
        startedAt: DateTime(2024, 6, 15),
        status: TripStatus.completed,
      );

      final result = exporter.exportTrip(
        trip: trip,
        hauls: [],
        pointsByHaul: {},
        logBookByHaul: {},
        userName: 'Test',
        vesselName: 'Test',
      );

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['markers'], isA<List>());
      expect((decoded['markers'] as List).isEmpty, isTrue);
    });
  });

  group('LseaJsonImporter', () {
    late LseaJsonImporter importer;

    setUp(() {
      importer = LseaJsonImporter();
    });

    test('parses valid .lsea.json and returns correct preview', () {
      final json = jsonEncode({
        'format': 'langgeng-sea-v1',
        'exportedAt': '2024-06-15T10:00:00.000Z',
        'exportedBy': {
          'name': 'Pak Ahmad',
          'vessel': 'KM Sejahtera',
        },
        'trip': {
          'id': 'trip-1',
          'name': 'Trip Utara',
          'startedAt': '2024-06-15T06:00:00.000Z',
          'status': 'completed',
          'hauls': [
            {
              'id': 'h1',
              'distanceMeters': 3000.0,
              'durationSeconds': 3600,
            },
            {
              'id': 'h2',
              'distanceMeters': 2500.0,
              'durationSeconds': 2700,
            },
          ],
        },
        'markers': [],
      });

      final preview = importer.parse(json);

      expect(preview.senderName, equals('Pak Ahmad'));
      expect(preview.vesselName, equals('KM Sejahtera'));
      expect(preview.haulCount, equals(2));
      expect(preview.totalDistanceMeters, equals(5500.0));
      expect(preview.tripName, equals('Trip Utara'));
      expect(preview.exportedAt.year, equals(2024));
      expect(preview.exportedAt.month, equals(6));
      expect(preview.exportedAt.day, equals(15));
    });

    test('throws FormatException for invalid JSON', () {
      expect(
        () => importer.parse('not json at all'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for wrong format version', () {
      final json = jsonEncode({
        'format': 'unknown-v99',
        'exportedBy': {'name': 'Test', 'vessel': 'Test'},
        'trip': {'hauls': []},
      });

      expect(
        () => importer.parse(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('tidak didukung'),
          ),
        ),
      );
    });

    test('throws FormatException when trip field is missing', () {
      final json = jsonEncode({
        'format': 'langgeng-sea-v1',
        'exportedAt': '2024-06-15T10:00:00.000Z',
        'exportedBy': {'name': 'Test', 'vessel': 'Test'},
      });

      expect(
        () => importer.parse(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('handles missing exportedBy gracefully', () {
      final json = jsonEncode({
        'format': 'langgeng-sea-v1',
        'exportedAt': '2024-06-15T10:00:00.000Z',
        'trip': {'hauls': []},
      });

      expect(
        () => importer.parse(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('round-trip: export then import returns matching preview', () {
      // Export
      final exporter = LseaJsonExporter();
      final trip = Trip(
        id: 'trip-1',
        name: 'Trip Malam',
        startedAt: DateTime(2024, 7, 20),
        status: TripStatus.completed,
      );

      final hauls = [
        Haul(
          id: 'h1',
          tripId: 'trip-1',
          orderIndex: 1,
          startedAt: DateTime(2024, 7, 20, 18, 0),
          status: HaulStatus.completed,
          trawlWidthMeters: 20.0,
          distanceMeters: 4200,
        ),
        Haul(
          id: 'h2',
          tripId: 'trip-1',
          orderIndex: 2,
          startedAt: DateTime(2024, 7, 20, 21, 0),
          status: HaulStatus.completed,
          trawlWidthMeters: 20.0,
          distanceMeters: 3100,
        ),
      ];

      final exported = exporter.exportTrip(
        trip: trip,
        hauls: hauls,
        pointsByHaul: {'h1': [], 'h2': []},
        logBookByHaul: {},
        userName: 'Rudi',
        vesselName: 'KM Bahari',
      );

      // Import
      final preview = importer.parse(exported);

      expect(preview.senderName, equals('Rudi'));
      expect(preview.vesselName, equals('KM Bahari'));
      expect(preview.haulCount, equals(2));
      expect(preview.totalDistanceMeters, equals(7300.0));
      expect(preview.tripName, equals('Trip Malam'));
    });
  });
}
