import 'package:flutter_test/flutter_test.dart';

import 'package:styra/features/marker/domain/entities/marker.dart';

void main() {
  final testMarkers = [
    AppMarker(
      id: '1',
      name: 'Spot Udang',
      category: MarkerCategory.productive,
      latitude: -6.0,
      longitude: 106.0,
      createdAt: DateTime(2024, 1, 1),
    ),
    AppMarker(
      id: '2',
      name: 'Karang Berbahaya',
      category: MarkerCategory.hazard,
      latitude: -6.1,
      longitude: 106.1,
      createdAt: DateTime(2024, 1, 2),
    ),
    AppMarker(
      id: '3',
      name: 'Pelabuhan Muara',
      category: MarkerCategory.port,
      latitude: -6.2,
      longitude: 106.2,
      createdAt: DateTime(2024, 1, 3),
    ),
    AppMarker(
      id: '4',
      name: 'Titik Refuel',
      category: MarkerCategory.other,
      latitude: -6.3,
      longitude: 106.3,
      createdAt: DateTime(2024, 1, 4),
    ),
    AppMarker(
      id: '5',
      name: 'Spot Tenggiri',
      category: MarkerCategory.productive,
      latitude: -6.4,
      longitude: 106.4,
      createdAt: DateTime(2024, 1, 5),
    ),
  ];

  group('filterMarkersByCategory', () {
    test('returns all markers when category is null', () {
      final result = filterMarkersByCategory(testMarkers, null);
      expect(result.length, 5);
      expect(result, testMarkers);
    });

    test('filters productive markers', () {
      final result =
          filterMarkersByCategory(testMarkers, MarkerCategory.productive);
      expect(result.length, 2);
      expect(result.every((m) => m.category == MarkerCategory.productive),
          isTrue,);
      expect(result[0].name, 'Spot Udang');
      expect(result[1].name, 'Spot Tenggiri');
    });

    test('filters hazard markers', () {
      final result =
          filterMarkersByCategory(testMarkers, MarkerCategory.hazard);
      expect(result.length, 1);
      expect(result.first.name, 'Karang Berbahaya');
    });

    test('filters port markers', () {
      final result =
          filterMarkersByCategory(testMarkers, MarkerCategory.port);
      expect(result.length, 1);
      expect(result.first.name, 'Pelabuhan Muara');
    });

    test('filters other markers', () {
      final result =
          filterMarkersByCategory(testMarkers, MarkerCategory.other);
      expect(result.length, 1);
      expect(result.first.name, 'Titik Refuel');
    });

    test('returns empty list if no markers match', () {
      final onlyProductive = [testMarkers[0]];
      final result =
          filterMarkersByCategory(onlyProductive, MarkerCategory.hazard);
      expect(result, isEmpty);
    });

    test('returns empty list for empty input', () {
      final result =
          filterMarkersByCategory([], MarkerCategory.productive);
      expect(result, isEmpty);
    });
  });

  group('MarkerCategory', () {
    test('storageKey matches enum name', () {
      expect(MarkerCategory.productive.storageKey, 'productive');
      expect(MarkerCategory.hazard.storageKey, 'hazard');
      expect(MarkerCategory.port.storageKey, 'port');
      expect(MarkerCategory.other.storageKey, 'other');
    });

    test('displayLabel returns Indonesian labels', () {
      expect(MarkerCategory.productive.displayLabel, 'Produktif');
      expect(MarkerCategory.hazard.displayLabel, 'Karang/Bahaya');
      expect(MarkerCategory.port.displayLabel, 'Pelabuhan');
      expect(MarkerCategory.other.displayLabel, 'Lainnya');
    });

    test('fromStorageKey parses correctly', () {
      expect(
          MarkerCategory.fromStorageKey('productive'), MarkerCategory.productive,);
      expect(MarkerCategory.fromStorageKey('hazard'), MarkerCategory.hazard);
      expect(MarkerCategory.fromStorageKey('port'), MarkerCategory.port);
      expect(MarkerCategory.fromStorageKey('other'), MarkerCategory.other);
    });

    test('fromStorageKey defaults to other for unknown keys', () {
      expect(MarkerCategory.fromStorageKey('unknown'), MarkerCategory.other);
      expect(MarkerCategory.fromStorageKey(''), MarkerCategory.other);
    });
  });

  group('AppMarker', () {
    test('latLng getter returns correct LatLng', () {
      final marker = testMarkers[0];
      expect(marker.latLng.latitude, -6.0);
      expect(marker.latLng.longitude, 106.0);
    });
  });
}
