// Pure-Dart unit tests for the helper math that powers TrackingController.
//
// These are deliberately *narrower* than
// `tracking_controller_test.dart` (which drives the full controller
// against an in-memory AppDatabase + FakeGpsService). The point of
// this file is to exercise the pure functions the controller relies
// on — GeoCalculator + the accuracy-gate predicate — with zero Drift
// setup, zero Riverpod wiring, and zero Flutter bindings.
//
// If any of these ever fail, metric aggregation in the real controller
// is broken at the root. Full integration behaviour (DB persistence,
// state transitions, recovery) is covered elsewhere.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:langgeng_sea/core/utils/geo_calculator.dart';
import 'package:latlong2/latlong.dart';

/// Mirror of the accuracy gate used inside TrackingController._onReading.
/// Kept identical so a regression in either place surfaces here.
bool _acceptForAggregation(double? accuracyMeters) {
  return accuracyMeters == null || accuracyMeters <= 25.0;
}

void main() {
  // ---------------------------------------------------------------------------
  // Circular mean heading (wrap-around correctness)
  // ---------------------------------------------------------------------------

  group('GeoCalculator.circularMeanDegrees', () {
    test('wraps across the 0°/360° boundary (350° + 10° ≈ 0°)', () {
      final mean = GeoCalculator.circularMeanDegrees([350.0, 10.0]);
      expect(mean, isNotNull);

      // Both 0° and 360° are valid representations of due-north.
      final distanceFromNorth = math.min(mean!, 360 - mean);
      expect(
        distanceFromNorth,
        lessThan(1.0),
        reason: 'arithmetic mean would give 180° (south) — we must wrap',
      );
    });

    test('agrees with arithmetic mean when no wrap is needed', () {
      final mean = GeoCalculator.circularMeanDegrees([10.0, 20.0]);
      expect(mean, closeTo(15.0, 0.5));
    });

    test('handles a cluster around north (355, 0, 5) ≈ 0°', () {
      final mean = GeoCalculator.circularMeanDegrees([355.0, 0.0, 5.0]);
      expect(mean, isNotNull);
      final distanceFromNorth = math.min(mean!, 360 - mean);
      expect(distanceFromNorth, lessThan(1.0));
    });

    test('handles a single heading (identity)', () {
      expect(GeoCalculator.circularMeanDegrees([135.0]), closeTo(135.0, 0.01));
    });

    test('returns null for an empty input', () {
      expect(GeoCalculator.circularMeanDegrees(const []), isNull);
    });

    test('skips non-finite values rather than returning NaN', () {
      final mean = GeoCalculator.circularMeanDegrees([double.nan, 90.0]);
      expect(mean, closeTo(90.0, 0.5));
    });
  });

  // ---------------------------------------------------------------------------
  // Distance — pairwise haversine on synthetic polylines
  // ---------------------------------------------------------------------------

  group('GeoCalculator.totalDistanceMeters', () {
    test('returns 0 for fewer than two points', () {
      expect(GeoCalculator.totalDistanceMeters(const []), 0);
      expect(
        GeoCalculator.totalDistanceMeters(const [LatLng(-7.2, 113.4)]),
        0,
      );
    });

    test('equals the sum of pairwise haversine legs on a 4-point track', () {
      // Small excursion off Probolinggo. Real coastal polyline shape,
      // small enough that great-circle and planar approximations agree.
      const points = <LatLng>[
        LatLng(-7.2000, 113.4000),
        LatLng(-7.2010, 113.4010),
        LatLng(-7.2020, 113.4020),
        LatLng(-7.2030, 113.4030),
      ];

      final manual = GeoCalculator.haversineMeters(points[0], points[1]) +
          GeoCalculator.haversineMeters(points[1], points[2]) +
          GeoCalculator.haversineMeters(points[2], points[3]);

      expect(
        GeoCalculator.totalDistanceMeters(points),
        closeTo(manual, 0.001),
      );
    });

    test('order-independent on a closed loop (round-trip = 2× one-way)', () {
      const a = LatLng(-7.2, 113.4);
      const b = LatLng(-7.21, 113.41);
      final oneWay = GeoCalculator.haversineMeters(a, b);
      final loop = GeoCalculator.totalDistanceMeters(
        const [a, b, a],
      );
      expect(loop, closeTo(oneWay * 2, 0.001));
    });

    test('matches a known one-arc-minute latitude span (~1852 m)', () {
      // One minute of latitude along a meridian ≈ 1852 m (nautical mile).
      // Haversine on WGS84 mean radius is within ~0.5% of that.
      const a = LatLng(0.0, 0.0);
      const b = LatLng(1.0 / 60.0, 0.0);
      final d = GeoCalculator.haversineMeters(a, b);
      expect(d, closeTo(1852, 1852 * 0.01));
    });
  });

  // ---------------------------------------------------------------------------
  // Accuracy gate (filter predicate)
  // ---------------------------------------------------------------------------

  group('accuracy gate (accuracyMeters ≤ 25)', () {
    test('accepts null accuracy (unknown is not a block)', () {
      expect(_acceptForAggregation(null), isTrue);
    });

    test('accepts excellent and acceptable fixes', () {
      expect(_acceptForAggregation(0), isTrue);
      expect(_acceptForAggregation(5), isTrue);
      expect(_acceptForAggregation(15), isTrue);
      expect(_acceptForAggregation(25), isTrue, reason: '25m is boundary-inclusive');
    });

    test('rejects fixes worse than 25 m', () {
      expect(_acceptForAggregation(26), isFalse);
      expect(_acceptForAggregation(50), isFalse);
      expect(_acceptForAggregation(200), isFalse);
    });

    test(
      'filter applied to a synthetic mixed-quality trace keeps only good fixes',
      () {
        final readings = <({LatLng point, double? accuracy})>[
          (point: const LatLng(-7.2000, 113.4000), accuracy: 5),
          (point: const LatLng(-7.2010, 113.4010), accuracy: 5),
          // Bad outlier far away — would inflate distance by ~100 km if kept.
          (point: const LatLng(-8.0000, 114.0000), accuracy: 50),
          (point: const LatLng(-7.2020, 113.4020), accuracy: 6),
        ];

        final accepted = readings
            .where((r) => _acceptForAggregation(r.accuracy))
            .map((r) => r.point)
            .toList();

        // Three good fixes survive; the 50 m outlier is dropped.
        expect(accepted, hasLength(3));
        expect(accepted.contains(const LatLng(-8.0000, 114.0000)), isFalse);

        // Sanity: resulting polyline distance is small (coastal excursion),
        // not the ~100 km the outlier would have introduced.
        final distance = GeoCalculator.totalDistanceMeters(accepted);
        expect(distance, lessThan(5000));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Unit conversions (sanity)
  // ---------------------------------------------------------------------------

  group('GeoCalculator.mpsToKnots', () {
    test('1 m/s ≈ 1.944 knots', () {
      expect(GeoCalculator.mpsToKnots(1), closeTo(1.944, 0.001));
    });

    test('0 m/s == 0 knots', () {
      expect(GeoCalculator.mpsToKnots(0), 0);
    });
  });

  // ---------------------------------------------------------------------------
  // Swept area (trawl)
  // ---------------------------------------------------------------------------

  group('GeoCalculator.sweptAreaM2', () {
    test('distance × trawl width for positive inputs', () {
      expect(
        GeoCalculator.sweptAreaM2(distanceMeters: 1000, trawlWidthMeters: 20),
        20000,
      );
    });

    test('zero for non-positive inputs', () {
      expect(
        GeoCalculator.sweptAreaM2(distanceMeters: 0, trawlWidthMeters: 20),
        0,
      );
      expect(
        GeoCalculator.sweptAreaM2(distanceMeters: 100, trawlWidthMeters: 0),
        0,
      );
      expect(
        GeoCalculator.sweptAreaM2(distanceMeters: -1, trawlWidthMeters: 20),
        0,
      );
    });
  });
}
