import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langgeng_sea/features/offline_map/domain/offline_tile_math.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('OfflineTileMath.lonToTileX', () {
    test('-180° maps to tile 0 at every zoom', () {
      for (var z = 0; z <= 18; z++) {
        expect(OfflineTileMath.lonToTileX(-180, z), 0);
      }
    });

    test('0° at zoom N maps to half the horizontal tile count', () {
      // At zoom z there are 2^z columns; 0° should fall on column 2^(z-1).
      expect(OfflineTileMath.lonToTileX(0, 3), 4);
      expect(OfflineTileMath.lonToTileX(0, 10), 512);
    });

    test('monotonically increases with longitude', () {
      final a = OfflineTileMath.lonToTileX(100, 10);
      final b = OfflineTileMath.lonToTileX(113, 10);
      expect(b, greaterThanOrEqualTo(a));
    });
  });

  group('OfflineTileMath.latToTileY', () {
    test('equator maps to half the tile count', () {
      expect(OfflineTileMath.latToTileY(0, 3), 4);
      expect(OfflineTileMath.latToTileY(0, 10), 512);
    });

    test('clamps polar latitudes to the Mercator limit', () {
      final northPole = OfflineTileMath.latToTileY(90, 10);
      final southPole = OfflineTileMath.latToTileY(-90, 10);
      expect(northPole, greaterThanOrEqualTo(0));
      expect(southPole, lessThanOrEqualTo((1 << 10) - 1));
    });
  });

  group('OfflineTileMath.tilesForLevel', () {
    test('bounds inside a single tile counts as 1', () {
      // A sub-tile-sized bounds near Selat Madura at zoom 10.
      final bounds = LatLngBounds(
        const LatLng(-7.20, 113.40),
        const LatLng(-7.205, 113.405),
      );
      expect(OfflineTileMath.tilesForLevel(bounds, 10), greaterThanOrEqualTo(1));
      expect(OfflineTileMath.tilesForLevel(bounds, 10), lessThanOrEqualTo(4));
    });

    test('quadruples-ish per zoom level step', () {
      final bounds = LatLngBounds(
        const LatLng(-7.0, 113.0),
        const LatLng(-7.5, 113.5),
      );
      final z10 = OfflineTileMath.tilesForLevel(bounds, 10);
      final z11 = OfflineTileMath.tilesForLevel(bounds, 11);
      // Each zoom increment doubles linear tile count, so area quadruples.
      // Floor/ceil effects keep this loose — verify the factor is in (2, 5).
      expect(z11 / z10, greaterThan(2));
      expect(z11 / z10, lessThan(5));
    });
  });

  group('OfflineTileMath.totalTiles', () {
    test('returns 0 when min > max', () {
      final bounds = LatLngBounds(
        const LatLng(-7, 113),
        const LatLng(-8, 114),
      );
      expect(OfflineTileMath.totalTiles(bounds, 10, 5), 0);
    });

    test('is the sum of tilesForLevel over the range', () {
      final bounds = LatLngBounds(
        const LatLng(-7, 113),
        const LatLng(-7.5, 113.5),
      );
      final expected = OfflineTileMath.tilesForLevel(bounds, 8) +
          OfflineTileMath.tilesForLevel(bounds, 9) +
          OfflineTileMath.tilesForLevel(bounds, 10);
      expect(OfflineTileMath.totalTiles(bounds, 8, 10), expected);
    });

    test('monotonically increases with the zoom range', () {
      final bounds = LatLngBounds(
        const LatLng(-7, 113),
        const LatLng(-7.5, 113.5),
      );
      final narrow = OfflineTileMath.totalTiles(bounds, 10, 10);
      final wide = OfflineTileMath.totalTiles(bounds, 8, 12);
      expect(wide, greaterThan(narrow));
    });
  });

  group('OfflineTileMath.estimatedBytes', () {
    test('returns 0 for non-positive tile counts', () {
      expect(OfflineTileMath.estimatedBytes(0), 0);
      expect(OfflineTileMath.estimatedBytes(-1), 0);
    });

    test('scales linearly with tile count', () {
      final a = OfflineTileMath.estimatedBytes(100);
      final b = OfflineTileMath.estimatedBytes(200);
      expect(b, 2 * a);
    });

    test('respects a custom average byte size', () {
      expect(
        OfflineTileMath.estimatedBytes(100, avgTileBytes: 10000),
        1000000,
      );
    });
  });
}
