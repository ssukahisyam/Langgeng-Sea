import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langgeng_sea/features/offline_map/domain/entities/offline_region.dart';
import 'package:latlong2/latlong.dart';

OfflineRegion _region({
  OfflineRegionStatus status = OfflineRegionStatus.completed,
  int sizeBytes = 0,
}) =>
    OfflineRegion(
      id: 'r1',
      name: 'Selat Madura',
      bounds: LatLngBounds(
        const LatLng(-7.5, 113.0),
        const LatLng(-7.0, 113.5),
      ),
      minZoom: 8,
      maxZoom: 14,
      status: status,
      createdAt: DateTime(2026, 5, 8),
      sizeBytes: sizeBytes,
    );

void main() {
  group('OfflineRegion.humanReadableSize', () {
    test('returns dash placeholder when size is 0', () {
      expect(_region().humanReadableSize(), '— MB');
    });

    test('uses bytes under 1 KiB', () {
      expect(_region(sizeBytes: 512).humanReadableSize(), '512 B');
    });

    test('uses KB between 1 KiB and 1 MiB', () {
      expect(_region(sizeBytes: 1024).humanReadableSize(), '1.0 KB');
      expect(_region(sizeBytes: 750 * 1024).humanReadableSize(), '750.0 KB');
    });

    test('uses MB between 1 MiB and 1 GiB', () {
      expect(
        _region(sizeBytes: 248 * 1024 * 1024).humanReadableSize(),
        '248.0 MB',
      );
    });

    test('uses GB above 1 GiB', () {
      expect(
        _region(sizeBytes: 3 * 1024 * 1024 * 1024).humanReadableSize(),
        '3.00 GB',
      );
    });
  });

  group('OfflineRegion flags', () {
    test('isReady only true when completed', () {
      expect(_region(status: OfflineRegionStatus.completed).isReady, isTrue);
      expect(_region(status: OfflineRegionStatus.downloading).isReady, isFalse);
      expect(_region(status: OfflineRegionStatus.pending).isReady, isFalse);
      expect(_region(status: OfflineRegionStatus.failed).isReady, isFalse);
    });

    test('isInProgress only true while downloading', () {
      expect(
        _region(status: OfflineRegionStatus.downloading).isInProgress,
        isTrue,
      );
      expect(
        _region(status: OfflineRegionStatus.completed).isInProgress,
        isFalse,
      );
    });
  });

  group('OfflineRegion.center', () {
    test('returns the midpoint of the bounds', () {
      final c = _region().center;
      expect(c.latitude, closeTo(-7.25, 1e-9));
      expect(c.longitude, closeTo(113.25, 1e-9));
    });
  });

  group('OfflineRegion.copyWith', () {
    test('preserves unchanged fields', () {
      final original = _region();
      final updated = original.copyWith(
        status: OfflineRegionStatus.downloading,
        sizeBytes: 1000,
      );
      expect(updated.id, original.id);
      expect(updated.name, original.name);
      expect(updated.status, OfflineRegionStatus.downloading);
      expect(updated.sizeBytes, 1000);
      expect(updated.bounds.north, original.bounds.north);
    });
  });
}
