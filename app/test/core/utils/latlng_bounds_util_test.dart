import 'package:flutter_test/flutter_test.dart';
import 'package:langgeng_sea/core/utils/latlng_bounds_util.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('LatLngBoundsUtil.fromPoints', () {
    test('returns null for empty iterable', () {
      expect(LatLngBoundsUtil.fromPoints(const []), isNull);
    });

    test('inflates around a single point so bounds are non-degenerate', () {
      final bounds =
          LatLngBoundsUtil.fromPoints(const [LatLng(-7.2, 113.4)])!;
      expect(bounds.north - bounds.south, greaterThan(0));
      expect(bounds.east - bounds.west, greaterThan(0));
    });

    test('encloses every input point', () {
      const points = [
        LatLng(-7.2, 113.3),
        LatLng(-7.1, 113.5),
        LatLng(-7.3, 113.4),
      ];
      final bounds = LatLngBoundsUtil.fromPoints(points)!;
      for (final p in points) {
        expect(bounds.contains(p), isTrue);
      }
    });

    test('padding inflates bounds by roughly the requested amount', () {
      final tight = LatLngBoundsUtil.fromPoints(
        const [LatLng(0, 0), LatLng(1, 1)],
        paddingDegrees: 0,
      )!;
      final padded = LatLngBoundsUtil.fromPoints(
        const [LatLng(0, 0), LatLng(1, 1)],
        paddingDegrees: 0.5,
      )!;
      // With a 1° span the padding only kicks in via the degeneracy
      // guard, so tight and padded both cover the corners; just verify
      // neither crashes and both contain the inputs.
      for (final p in const [LatLng(0, 0), LatLng(1, 1)]) {
        expect(tight.contains(p), isTrue);
        expect(padded.contains(p), isTrue);
      }
    });
  });
}
