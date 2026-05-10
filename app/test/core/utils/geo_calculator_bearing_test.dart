// Unit tests for the M11 navigation math helpers that extend
// GeoCalculator: bearing, cross-track, nearest-point-on-polyline, and
// percent-along-polyline.
//
// Pure Dart — no Flutter bindings, no Drift. If any of these fail,
// the go-to / follow-track overlays render junk in the UI.

import 'package:flutter_test/flutter_test.dart';
import 'package:langgeng_sea/core/utils/geo_calculator.dart';
import 'package:latlong2/latlong.dart';

void main() {
  // ---------------------------------------------------------------------------
  // bearingDegrees — cardinal directions + seam
  // ---------------------------------------------------------------------------

  group('GeoCalculator.bearingDegrees', () {
    test('due north from equator → 0 deg', () {
      const from = LatLng(0, 0);
      const to = LatLng(0.1, 0);
      expect(GeoCalculator.bearingDegrees(from, to), closeTo(0, 0.5));
    });

    test('due east from equator → 90 deg', () {
      const from = LatLng(0, 0);
      const to = LatLng(0, 0.1);
      expect(GeoCalculator.bearingDegrees(from, to), closeTo(90, 0.5));
    });

    test('due south from equator → 180 deg', () {
      const from = LatLng(0, 0);
      const to = LatLng(-0.1, 0);
      expect(GeoCalculator.bearingDegrees(from, to), closeTo(180, 0.5));
    });

    test('due west from equator → 270 deg', () {
      const from = LatLng(0, 0);
      const to = LatLng(0, -0.1);
      expect(GeoCalculator.bearingDegrees(from, to), closeTo(270, 0.5));
    });

    test('output is always wrapped into [0, 360)', () {
      // Any combination should yield a non-negative <360 value.
      for (final pair in <(LatLng, LatLng)>[
        (const LatLng(-7.2, 113.4), const LatLng(-7.1, 113.5)),
        (const LatLng(-7.2, 113.4), const LatLng(-7.3, 113.3)),
        (const LatLng(0, 179), const LatLng(0, -179)),
      ]) {
        final b = GeoCalculator.bearingDegrees(pair.$1, pair.$2);
        expect(b, greaterThanOrEqualTo(0));
        expect(b, lessThan(360));
      }
    });

    test('near 0°/360° seam does not collapse to 180', () {
      // From just west of the prime meridian going slightly north-east
      // should be around 45°, NOT 225° (arithmetic-wrap failure mode).
      const from = LatLng(0, -0.01);
      const to = LatLng(0.1, 0.1);
      final b = GeoCalculator.bearingDegrees(from, to);
      expect(b, lessThan(90));
      expect(b, greaterThan(0));
    });
  });

  // ---------------------------------------------------------------------------
  // crossTrackDistanceMeters
  // ---------------------------------------------------------------------------

  group('GeoCalculator.crossTrackDistanceMeters', () {
    test('point exactly on the line has ~0 cross-track distance', () {
      const segStart = LatLng(0, 0);
      const segEnd = LatLng(0, 0.2);
      // Point at (0, 0.1) sits exactly on the equator line.
      const onLine = LatLng(0, 0.1);
      expect(
        GeoCalculator.crossTrackDistanceMeters(onLine, segStart, segEnd),
        lessThan(1.0),
      );
    });

    test('perpendicular offset at equator ≈ great-circle offset', () {
      // Line along the equator from (0,0) -> (0, 0.2).
      // Point offset 0.001° north at longitude 0.1.
      // 0.001° of latitude ≈ 111 m.
      const segStart = LatLng(0, 0);
      const segEnd = LatLng(0, 0.2);
      const offset = LatLng(0.001, 0.1);
      final d = GeoCalculator.crossTrackDistanceMeters(offset, segStart, segEnd);
      expect(d, closeTo(111, 5));
    });

    test('collapsed segment falls back to haversine', () {
      const p = LatLng(0, 0.1);
      const seg = LatLng(0, 0);
      // With start == end, cross-track should equal haversine(p, seg).
      final expected = GeoCalculator.haversineMeters(p, seg);
      expect(
        GeoCalculator.crossTrackDistanceMeters(p, seg, seg),
        closeTo(expected, 0.5),
      );
    });

    test('returns absolute (non-negative) distance', () {
      const segStart = LatLng(0, 0);
      const segEnd = LatLng(0, 0.2);
      const leftOfLine = LatLng(-0.001, 0.1); // South of equator line.
      const rightOfLine = LatLng(0.001, 0.1); // North of equator line.
      final l = GeoCalculator.crossTrackDistanceMeters(
          leftOfLine, segStart, segEnd);
      final r = GeoCalculator.crossTrackDistanceMeters(
          rightOfLine, segStart, segEnd);
      expect(l, greaterThanOrEqualTo(0));
      expect(r, greaterThanOrEqualTo(0));
      // By symmetry of the equator they should be roughly equal.
      expect(l, closeTo(r, 1));
    });
  });

  // ---------------------------------------------------------------------------
  // nearestPointOnPolyline
  // ---------------------------------------------------------------------------

  group('GeoCalculator.nearestPointOnPolyline', () {
    test('picks the segment closest to the query point', () {
      // Three-segment polyline: (0,0) -> (0,0.1) -> (0.1,0.1) -> (0.1,0.2).
      const polyline = <LatLng>[
        LatLng(0, 0),
        LatLng(0, 0.1),
        LatLng(0.1, 0.1),
        LatLng(0.1, 0.2),
      ];
      // Query point near the middle (vertical) segment.
      const q = LatLng(0.05, 0.101);
      final r = GeoCalculator.nearestPointOnPolyline(q, polyline);
      expect(r.nearestSegmentIndex, 1);
      // Should be ~0.001° x ~111km = ~111m from the vertical segment.
      expect(r.distanceMeters, lessThan(200));
    });

    test('returns (0, 0) for empty polyline', () {
      final r = GeoCalculator.nearestPointOnPolyline(
        const LatLng(0, 0),
        const <LatLng>[],
      );
      expect(r.distanceMeters, 0);
      expect(r.nearestSegmentIndex, 0);
    });

    test('single-point polyline returns haversine to that point', () {
      const point = LatLng(0, 0);
      final r = GeoCalculator.nearestPointOnPolyline(
        const LatLng(0, 0.001),
        [point],
      );
      expect(r.nearestSegmentIndex, 0);
      expect(r.distanceMeters, closeTo(111, 5));
    });

    test('point near endpoint uses endpoint haversine, not perpendicular', () {
      // Segment (0,0) -> (0, 0.1). Query "way past" segEnd.
      const polyline = <LatLng>[LatLng(0, 0), LatLng(0, 0.1)];
      const q = LatLng(0, 0.2);
      final r = GeoCalculator.nearestPointOnPolyline(q, polyline);
      final expected = GeoCalculator.haversineMeters(q, const LatLng(0, 0.1));
      expect(r.distanceMeters, closeTo(expected, 1));
    });
  });

  // ---------------------------------------------------------------------------
  // percentAlongPolyline
  // ---------------------------------------------------------------------------

  group('GeoCalculator.percentAlongPolyline', () {
    test('0 at the start of a linear polyline', () {
      const polyline = <LatLng>[
        LatLng(0, 0),
        LatLng(0, 0.1),
        LatLng(0, 0.2),
      ];
      final r = GeoCalculator.percentAlongPolyline(polyline.first, polyline);
      expect(r, closeTo(0, 0.01));
    });

    test('~0.5 at the midpoint of a straight polyline', () {
      const polyline = <LatLng>[
        LatLng(0, 0),
        LatLng(0, 0.1),
        LatLng(0, 0.2),
      ];
      const midpoint = LatLng(0, 0.1);
      final r = GeoCalculator.percentAlongPolyline(midpoint, polyline);
      expect(r, closeTo(0.5, 0.02));
    });

    test('~1.0 at the end of a polyline', () {
      const polyline = <LatLng>[
        LatLng(0, 0),
        LatLng(0, 0.1),
        LatLng(0, 0.2),
      ];
      final r = GeoCalculator.percentAlongPolyline(polyline.last, polyline);
      expect(r, closeTo(1.0, 0.02));
    });

    test('returns 0 for degenerate polylines', () {
      expect(
        GeoCalculator.percentAlongPolyline(
          const LatLng(0, 0),
          const <LatLng>[],
        ),
        0,
      );
      expect(
        GeoCalculator.percentAlongPolyline(
          const LatLng(0, 0),
          const [LatLng(0, 0)],
        ),
        0,
      );
    });

    test('result is always clamped to [0, 1]', () {
      const polyline = <LatLng>[LatLng(0, 0), LatLng(0, 0.1)];
      // Query point is way before segment start.
      const before = LatLng(0, -10);
      const after = LatLng(0, 10);
      final pBefore =
          GeoCalculator.percentAlongPolyline(before, polyline);
      final pAfter = GeoCalculator.percentAlongPolyline(after, polyline);
      expect(pBefore, greaterThanOrEqualTo(0));
      expect(pBefore, lessThanOrEqualTo(1));
      expect(pAfter, greaterThanOrEqualTo(0));
      expect(pAfter, lessThanOrEqualTo(1));
    });

    test('respects a supplied nearestSegmentIndex hint', () {
      const polyline = <LatLng>[
        LatLng(0, 0),
        LatLng(0, 0.1),
        LatLng(0, 0.2),
        LatLng(0, 0.3),
      ];
      // Query point at polyline[2]. percentAlong should be ~0.666.
      const q = LatLng(0, 0.2);
      final autodetected =
          GeoCalculator.percentAlongPolyline(q, polyline);
      final withHint = GeoCalculator.percentAlongPolyline(
        q,
        polyline,
        nearestSegmentIndex: 1,
      );
      // Hint should yield similar or equal result — we deliberately
      // allow a wider tolerance since the hint tells it to skip the
      // auto-detect step.
      expect(withHint, closeTo(autodetected, 0.1));
    });
  });

  // ---------------------------------------------------------------------------
  // polylineLengthMeters (alias of totalDistanceMeters)
  // ---------------------------------------------------------------------------

  group('GeoCalculator.polylineLengthMeters', () {
    test('matches totalDistanceMeters', () {
      const polyline = <LatLng>[
        LatLng(-7.2, 113.4),
        LatLng(-7.21, 113.41),
        LatLng(-7.22, 113.42),
      ];
      expect(
        GeoCalculator.polylineLengthMeters(polyline),
        closeTo(GeoCalculator.totalDistanceMeters(polyline), 0.001),
      );
    });
  });
}
