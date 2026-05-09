import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:langgeng_sea/core/utils/geo_calculator.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('GeoCalculator.haversineMeters', () {
    test('returns 0 for identical points', () {
      const p = LatLng(-7.2, 113.4);
      expect(GeoCalculator.haversineMeters(p, p), 0);
    });

    test('matches known reference value within 0.5%', () {
      // Jakarta → Surabaya ~ 660.5 km (great-circle)
      const jakarta = LatLng(-6.2088, 106.8456);
      const surabaya = LatLng(-7.2575, 112.7521);
      final d = GeoCalculator.haversineMeters(jakarta, surabaya);
      expect(d, closeTo(660500, 3500));
    });

    test('is symmetric', () {
      const a = LatLng(-7.1, 113.3);
      const b = LatLng(-7.2, 113.5);
      final ab = GeoCalculator.haversineMeters(a, b);
      final ba = GeoCalculator.haversineMeters(b, a);
      expect(ab, closeTo(ba, 0.001));
    });

    test('handles antipodal-ish pairs without NaN', () {
      const a = LatLng(0, 0);
      const b = LatLng(0, 180);
      final d = GeoCalculator.haversineMeters(a, b);
      expect(d.isFinite, isTrue);
      // Half the Earth's circumference (~20 015 km) ± 1%.
      expect(d, closeTo(20015000, 200000));
    });
  });

  group('GeoCalculator.totalDistanceMeters', () {
    test('returns 0 for empty list', () {
      expect(GeoCalculator.totalDistanceMeters([]), 0);
    });

    test('returns 0 for single point', () {
      expect(
        GeoCalculator.totalDistanceMeters(const [LatLng(-7, 113)]),
        0,
      );
    });

    test('equals pairwise sum for polyline', () {
      const a = LatLng(-7.1, 113.3);
      const b = LatLng(-7.11, 113.31);
      const c = LatLng(-7.12, 113.32);
      final expected = GeoCalculator.haversineMeters(a, b) +
          GeoCalculator.haversineMeters(b, c);
      expect(
        GeoCalculator.totalDistanceMeters([a, b, c]),
        closeTo(expected, 0.01),
      );
    });
  });

  group('GeoCalculator.circularMeanDegrees', () {
    test('returns null for empty input', () {
      expect(GeoCalculator.circularMeanDegrees([]), isNull);
    });

    test('returns the single bearing unchanged', () {
      expect(GeoCalculator.circularMeanDegrees([45]), closeTo(45, 0.001));
    });

    test('averages bearings across the 0°/360° seam without bias', () {
      // 350° + 10° → should be 0°, not 180° (which arithmetic mean gives)
      final mean = GeoCalculator.circularMeanDegrees([350, 10])!;
      expect(mean, closeTo(0, 0.5));
    });

    test('averages symmetrically around any angle', () {
      // 85° and 95° → 90°
      final mean = GeoCalculator.circularMeanDegrees([85, 95])!;
      expect(mean, closeTo(90, 0.001));
    });

    test('ignores non-finite bearings', () {
      final mean = GeoCalculator.circularMeanDegrees([90, double.nan, 90])!;
      expect(mean, closeTo(90, 0.001));
    });

    test('output is always in [0, 360)', () {
      final mean = GeoCalculator.circularMeanDegrees([359, 1])!;
      expect(mean, greaterThanOrEqualTo(0));
      expect(mean, lessThan(360));
    });
  });

  group('GeoCalculator.sweptAreaM2', () {
    test('returns 0 for zero distance', () {
      expect(
        GeoCalculator.sweptAreaM2(distanceMeters: 0, trawlWidthMeters: 20),
        0,
      );
    });

    test('returns 0 for zero or negative width', () {
      expect(
        GeoCalculator.sweptAreaM2(distanceMeters: 1000, trawlWidthMeters: 0),
        0,
      );
      expect(
        GeoCalculator.sweptAreaM2(distanceMeters: 1000, trawlWidthMeters: -5),
        0,
      );
    });

    test('is distance × width', () {
      expect(
        GeoCalculator.sweptAreaM2(
          distanceMeters: 2400,
          trawlWidthMeters: 20,
        ),
        48000,
      );
    });
  });

  group('GeoCalculator.mpsToKnots', () {
    test('zero maps to zero', () {
      expect(GeoCalculator.mpsToKnots(0), 0);
    });

    test('matches standard conversion factor', () {
      // 1 m/s = 1.943844 knots
      expect(GeoCalculator.mpsToKnots(1), closeTo(1.943844, 0.00001));
    });

    test('is linear', () {
      final single = GeoCalculator.mpsToKnots(3.2);
      final scaled = GeoCalculator.mpsToKnots(3.2 * 10);
      expect(scaled, closeTo(single * 10, 0.0001));
    });
  });

  // Sanity-check: the algorithm choices don't silently regress by
  // a large margin for a realistic 1 km straight-line haul.
  group('realistic haul example', () {
    test('1 km due east at lat 0 has expected distance & bearing', () {
      // 1 degree longitude at equator ≈ 111.32 km.
      // So 0.009° ≈ 1.002 km.
      const start = LatLng(0, 113.0);
      const end = LatLng(0, 113.009);
      expect(
        GeoCalculator.haversineMeters(start, end),
        closeTo(1001.6, 2),
      );

      // Compute bearing by differentiation — not in our API but useful
      // to prove our circular mean helper is trustworthy.
      final dLon = (end.longitude - start.longitude) * math.pi / 180.0;
      final y = math.sin(dLon) * math.cos(end.latitude * math.pi / 180.0);
      final x = math.cos(start.latitude * math.pi / 180.0) *
              math.sin(end.latitude * math.pi / 180.0) -
          math.sin(start.latitude * math.pi / 180.0) *
              math.cos(end.latitude * math.pi / 180.0) *
              math.cos(dLon);
      final bearing =
          ((math.atan2(y, x) * 180.0 / math.pi) + 360.0) % 360.0;

      expect(bearing, closeTo(90, 0.5));
      expect(
        GeoCalculator.circularMeanDegrees([bearing, bearing])!,
        closeTo(90, 0.5),
      );
    });
  });
}
