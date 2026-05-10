// Extra coverage for the polyline / cross-track helpers of
// GeoCalculator beyond what [geo_calculator_bearing_test.dart] already
// exercises. This file focuses on the follow-track specific
// scenarios:
//   * cross-track sanity on rectangular legs (not just equator)
//   * nearestPointOnPolyline picking the correct seg when the query
//     is beyond the polyline endpoints (should clamp)
//   * percentAlongPolyline on a multi-leg polyline, checking the
//     hint param threading against the autodetect result
//   * polylineLengthMeters for multi-leg paths
//
// Pure Dart -- no Flutter bindings required.

import 'package:flutter_test/flutter_test.dart';
import 'package:langgeng_sea/core/utils/geo_calculator.dart';
import 'package:latlong2/latlong.dart';

void main() {
  // ---------------------------------------------------------------------------
  // cross-track on non-equator legs
  // ---------------------------------------------------------------------------

  group('crossTrackDistanceMeters - realistic follow-track segments', () {
    test('north-south leg at mid-latitude, perpendicular offset ~70m', () {
      // Mid-Java latitude, 0.001° ~ 111 m of latitude (lat-indep).
      // Line from (-7.25, 113.4) -> (-7.24, 113.4). Point 0.00063°
      // east of the line midpoint is ~70 m (cos(-7.25°) ≈ 0.992).
      const segStart = LatLng(-7.25, 113.4);
      const segEnd = LatLng(-7.24, 113.4);
      const offset = LatLng(-7.245, 113.40063);
      final d = GeoCalculator.crossTrackDistanceMeters(
        offset,
        segStart,
        segEnd,
      );
      expect(d, closeTo(70, 8));
    });

    test('diagonal leg, offset 0 m on line returns ~0', () {
      // Line from (0, 0) to (0.1, 0.1). Midpoint (0.05, 0.05) sits
      // exactly on the line.
      const segStart = LatLng(0, 0);
      const segEnd = LatLng(0.1, 0.1);
      const onLine = LatLng(0.05, 0.05);
      final d = GeoCalculator.crossTrackDistanceMeters(
        onLine,
        segStart,
        segEnd,
      );
      expect(d, lessThan(50)); // looser tolerance, this is a diagonal
    });

    test('off-route threshold scenario: ~30 m perpendicular at equator', () {
      // Line along the equator from (0, 0) to (0, 0.1). Point offset
      // 30 m to the north.
      const segStart = LatLng(0, 0);
      const segEnd = LatLng(0, 0.1);
      // 30 / 111000 ≈ 0.0002703 deg of latitude at equator.
      const offset = LatLng(0.0002703, 0.05);
      final d = GeoCalculator.crossTrackDistanceMeters(
        offset,
        segStart,
        segEnd,
      );
      expect(d, closeTo(30, 1));
    });
  });

  // ---------------------------------------------------------------------------
  // nearestPointOnPolyline for follow-track-like paths
  // ---------------------------------------------------------------------------

  group('nearestPointOnPolyline - multi-leg follow paths', () {
    test('L-shaped polyline picks the correct leg for each quadrant', () {
      // Polyline: (0,0) -> (0, 0.1) -> (0.1, 0.1). Two legs:
      //   seg 0: east along equator
      //   seg 1: north from (0, 0.1)
      const poly = <LatLng>[
        LatLng(0, 0),
        LatLng(0, 0.1),
        LatLng(0.1, 0.1),
      ];

      // Point north of seg 0's midpoint should pick seg 0.
      final east = GeoCalculator.nearestPointOnPolyline(
        const LatLng(0.0002, 0.05),
        poly,
      );
      expect(east.nearestSegmentIndex, 0);

      // Point east of seg 1's midpoint should pick seg 1.
      final north = GeoCalculator.nearestPointOnPolyline(
        const LatLng(0.05, 0.1002),
        poly,
      );
      expect(north.nearestSegmentIndex, 1);
    });

    test('query past polyline end clamps distance to endpoint haversine',
        () {
      const poly = <LatLng>[
        LatLng(0, 0),
        LatLng(0, 0.1),
      ];
      const farPast = LatLng(0, 0.5);
      final r = GeoCalculator.nearestPointOnPolyline(farPast, poly);
      final endDist =
          GeoCalculator.haversineMeters(farPast, const LatLng(0, 0.1));
      expect(r.distanceMeters, closeTo(endDist, 0.5));
    });

    test('query before polyline start clamps distance to startpoint', () {
      const poly = <LatLng>[
        LatLng(0, 0),
        LatLng(0, 0.1),
      ];
      const farBefore = LatLng(0, -0.5);
      final r = GeoCalculator.nearestPointOnPolyline(farBefore, poly);
      final startDist =
          GeoCalculator.haversineMeters(farBefore, const LatLng(0, 0));
      expect(r.distanceMeters, closeTo(startDist, 0.5));
    });
  });

  // ---------------------------------------------------------------------------
  // percentAlongPolyline - multi-leg
  // ---------------------------------------------------------------------------

  group('percentAlongPolyline - multi-leg paths', () {
    test('L-shaped polyline, midpoint of first leg ~25%', () {
      // Two equal-length legs (each 0.1° along axis). Midpoint of
      // first leg should be at 25% of total polyline.
      const poly = <LatLng>[
        LatLng(0, 0),
        LatLng(0, 0.1),
        LatLng(0.1, 0.1),
      ];
      final pct = GeoCalculator.percentAlongPolyline(
        const LatLng(0, 0.05),
        poly,
      );
      expect(pct, closeTo(0.25, 0.03));
    });

    test('L-shaped polyline, corner is at 50%', () {
      const poly = <LatLng>[
        LatLng(0, 0),
        LatLng(0, 0.1),
        LatLng(0.1, 0.1),
      ];
      final pct = GeoCalculator.percentAlongPolyline(
        const LatLng(0, 0.1),
        poly,
      );
      expect(pct, closeTo(0.5, 0.02));
    });

    test('hint matches autodetect output on a picked leg', () {
      const poly = <LatLng>[
        LatLng(0, 0),
        LatLng(0, 0.1),
        LatLng(0.1, 0.1),
      ];
      const q = LatLng(0, 0.075); // on first leg, 75% of the way
      final auto = GeoCalculator.percentAlongPolyline(q, poly);
      final hinted = GeoCalculator.percentAlongPolyline(
        q,
        poly,
        nearestSegmentIndex: 0,
      );
      expect(hinted, closeTo(auto, 0.01));
    });

    test('point orthogonal to middle leg still produces 0..1 result', () {
      const poly = <LatLng>[
        LatLng(0, 0),
        LatLng(0, 0.1),
        LatLng(0.1, 0.1),
        LatLng(0.1, 0.2),
      ];
      // Point offset north-east of the middle leg (0,0.1) -> (0.1, 0.1).
      final pct = GeoCalculator.percentAlongPolyline(
        const LatLng(0.05, 0.105),
        poly,
      );
      expect(pct, greaterThan(0.0));
      expect(pct, lessThan(1.0));
    });
  });

  // ---------------------------------------------------------------------------
  // polylineLengthMeters
  // ---------------------------------------------------------------------------

  group('polylineLengthMeters', () {
    test('sum of 3-leg equator polyline ≈ 3 × 111 m per 0.001°', () {
      // Three legs of 0.001° each along the equator ≈ 111 m each,
      // total ≈ 333 m.
      const poly = <LatLng>[
        LatLng(0, 0),
        LatLng(0, 0.001),
        LatLng(0, 0.002),
        LatLng(0, 0.003),
      ];
      expect(
        GeoCalculator.polylineLengthMeters(poly),
        closeTo(333, 3),
      );
    });

    test('degenerate polyline returns 0', () {
      expect(
        GeoCalculator.polylineLengthMeters(const [LatLng(0, 0)]),
        0,
      );
      expect(
        GeoCalculator.polylineLengthMeters(const <LatLng>[]),
        0,
      );
    });
  });
}
