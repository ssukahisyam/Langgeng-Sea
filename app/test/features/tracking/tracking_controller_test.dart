// Unit tests for TrackingController focused on metric aggregation logic.
//
// These tests exercise the controller against an in-memory AppDatabase and
// the FakeGpsService helper. They're deliberately narrower than the
// integration test — each test verifies *one* behaviour of the
// aggregation math: trip reuse, pairwise haversine distance, circular
// mean heading, accuracy gating, and crash-recovery rebuild.

import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langgeng_sea/core/services/gps_reading.dart';
import 'package:langgeng_sea/core/services/gps_service.dart';
import 'package:langgeng_sea/core/utils/geo_calculator.dart';
import 'package:langgeng_sea/data/database/app_database.dart';
import 'package:langgeng_sea/features/tracking/application/tracking_controller.dart';
import 'package:langgeng_sea/features/tracking/data/haul_repository.dart';
import 'package:langgeng_sea/features/tracking/data/track_point_repository.dart';
import 'package:langgeng_sea/features/tracking/data/trip_repository.dart';
import 'package:langgeng_sea/features/tracking/domain/entities/haul.dart';
import 'package:latlong2/latlong.dart';

import '../../helpers/fake_gps_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeGpsService fakeGps;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    fakeGps = FakeGpsService();
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      gpsServiceProvider.overrideWithValue(fakeGps),
    ],);
  });

  tearDown(() async {
    container.dispose();
    fakeGps.dispose();
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Trip lifecycle
  // ---------------------------------------------------------------------------

  group('startHaul', () {
    test('creates a new trip when no trip is active', () async {
      final controller = container.read(trackingControllerProvider.notifier);
      final tripRepo = container.read(tripRepositoryProvider);

      expect(await tripRepo.getActiveTrip(), isNull);

      final haul = await controller.startHaul(trawlWidthMeters: 20);

      final trip = await tripRepo.getActiveTrip();
      expect(trip, isNotNull);
      expect(haul.tripId, trip!.id);
      expect(haul.orderIndex, 1);
      expect(haul.status, HaulStatus.recording);
    });

    test('reuses the currently active trip for a subsequent haul', () async {
      final controller = container.read(trackingControllerProvider.notifier);
      final tripRepo = container.read(tripRepositoryProvider);

      final first = await controller.startHaul(trawlWidthMeters: 20);
      await controller.stopHaul();

      final second = await controller.startHaul(trawlWidthMeters: 20);
      expect(second.tripId, first.tripId,
          reason: 'second haul should reuse the active trip',);
      expect(second.orderIndex, 2);

      // Only one trip ever existed.
      final allTrips = await tripRepo.listSummaries();
      expect(allTrips, hasLength(1));
    });
  });

  // ---------------------------------------------------------------------------
  // Distance aggregation
  // ---------------------------------------------------------------------------

  group('stopHaul distance', () {
    test('computes distance as pairwise haversine sum of emitted points',
        () async {
      final controller = container.read(trackingControllerProvider.notifier);

      final haul = await controller.startHaul(trawlWidthMeters: 20);

      // Build a known polyline — 3 segments with known great-circle lengths.
      final points = <LatLng>[
        const LatLng(-7.2000, 113.4000),
        const LatLng(-7.2010, 113.4010),
        const LatLng(-7.2020, 113.4020),
        const LatLng(-7.2030, 113.4030),
      ];
      final baseTime = DateTime(2025, 1, 1, 6);
      for (var i = 0; i < points.length; i++) {
        fakeGps.emit(GpsReading(
          latitude: points[i].latitude,
          longitude: points[i].longitude,
          timestamp: baseTime.add(Duration(seconds: i * 10)),
          accuracyMeters: 5,
          speedMps: 2.0,
          headingDegrees: 135,
        ),);
        await Future<void>.delayed(Duration.zero);
      }

      final completion = await controller.stopHaul();
      expect(completion, isNotNull);

      final expected = GeoCalculator.totalDistanceMeters(points);
      final haulRow = await db.haulDao.findById(haul.id);
      expect(
        haulRow!.distanceMeters,
        closeTo(expected, 0.5),
        reason: 'stored distance should equal pairwise haversine sum',
      );
      expect(haulRow.sweptAreaM2,
          closeTo(expected * haul.trawlWidthMeters, 0.5),);
    });
  });

  // ---------------------------------------------------------------------------
  // Circular mean heading
  // ---------------------------------------------------------------------------

  group('avgHeadingDegrees', () {
    test('350° and 10° average to ~0° (not the arithmetic 180°)', () async {
      final controller = container.read(trackingControllerProvider.notifier);
      final haul = await controller.startHaul(trawlWidthMeters: 20);

      final baseTime = DateTime(2025, 1, 1, 6);
      // Need speed > 0.5 m/s for heading to count (see controller).
      for (final h in [350.0, 10.0]) {
        fakeGps.emit(GpsReading(
          latitude: -7.2,
          longitude: 113.4,
          timestamp: baseTime.add(Duration(seconds: h.toInt())),
          accuracyMeters: 5,
          speedMps: 2.0,
          headingDegrees: h,
        ),);
        await Future<void>.delayed(Duration.zero);
      }

      await controller.stopHaul();

      final row = await db.haulDao.findById(haul.id);
      final heading = row!.avgHeadingDegrees;
      expect(heading, isNotNull);

      // Acceptable: 0° ± 1° OR 360° ± 1° (implementation-dependent, both
      // are correct representations of due-north).
      final distanceFromNorth = math.min(heading!, 360 - heading);
      expect(
        distanceFromNorth,
        lessThan(1.0),
        reason: 'circular mean of 350° & 10° should wrap to ~0°, got $heading',
      );
    });

    test('10° and 20° average to ~15°', () async {
      final controller = container.read(trackingControllerProvider.notifier);
      final haul = await controller.startHaul(trawlWidthMeters: 20);

      final baseTime = DateTime(2025, 1, 1, 6);
      for (final h in [10.0, 20.0]) {
        fakeGps.emit(GpsReading(
          latitude: -7.2,
          longitude: 113.4,
          timestamp: baseTime.add(Duration(seconds: h.toInt())),
          accuracyMeters: 5,
          speedMps: 2.0,
          headingDegrees: h,
        ),);
        await Future<void>.delayed(Duration.zero);
      }
      await controller.stopHaul();

      final row = await db.haulDao.findById(haul.id);
      expect(row!.avgHeadingDegrees, closeTo(15, 0.5));
    });
  });

  // ---------------------------------------------------------------------------
  // Accuracy gate
  // ---------------------------------------------------------------------------

  group('accuracy gate', () {
    test(
      'points with accuracyMeters > 25 are stored but excluded from metrics',
      () async {
        final controller = container.read(trackingControllerProvider.notifier);
        final haul = await controller.startHaul(trawlWidthMeters: 20);

        final baseTime = DateTime(2025, 1, 1, 6);

        // Good points — should contribute to distance.
        fakeGps.emit(GpsReading(
          latitude: -7.2000,
          longitude: 113.4000,
          timestamp: baseTime,
          accuracyMeters: 5,
          speedMps: 2,
          headingDegrees: 90,
        ),);
        await Future<void>.delayed(Duration.zero);
        fakeGps.emit(GpsReading(
          latitude: -7.2000,
          longitude: 113.4010,
          timestamp: baseTime.add(const Duration(seconds: 10)),
          accuracyMeters: 5,
          speedMps: 2,
          headingDegrees: 90,
        ),);
        await Future<void>.delayed(Duration.zero);

        // Bad point — far away but accuracy > 25m. Should be stored but
        // NOT add distance / not update _lastPoint.
        fakeGps.emit(GpsReading(
          latitude: -8.0000,
          longitude: 114.0000,
          timestamp: baseTime.add(const Duration(seconds: 20)),
          accuracyMeters: 50,
          speedMps: 2,
          headingDegrees: 90,
        ),);
        await Future<void>.delayed(Duration.zero);

        // Another good point — distance should resume from the 2nd good point.
        fakeGps.emit(GpsReading(
          latitude: -7.2000,
          longitude: 113.4020,
          timestamp: baseTime.add(const Duration(seconds: 30)),
          accuracyMeters: 6,
          speedMps: 2,
          headingDegrees: 90,
        ),);
        await Future<void>.delayed(Duration.zero);

        await controller.stopHaul();

        // Storage: all 4 raw points persisted so the raw trace is kept.
        expect(await db.trackPointDao.countForHaul(haul.id), 4);

        // Metrics: distance should be ~2× leg-distance (two accepted legs
        // between consecutive good points), nowhere near the ~100 km that
        // the bad point would imply.
        final row = await db.haulDao.findById(haul.id);
        final goodLegDistance = GeoCalculator.haversineMeters(
          const LatLng(-7.2000, 113.4000),
          const LatLng(-7.2000, 113.4010),
        );
        final expected = goodLegDistance * 2;
        expect(
          row!.distanceMeters,
          closeTo(expected, 1.0),
          reason: 'bad fix must be excluded from distance aggregation',
        );
        // And definitely not anywhere near the distance to Bali.
        expect(row.distanceMeters, lessThan(5000));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Resume after crash
  // ---------------------------------------------------------------------------

  group('resumeHaul', () {
    test(
      'rebuilds distance aggregates from existing DB points',
      () async {
        // Simulate the app being killed mid-haul: write some points and a
        // 'recording' haul directly into the DB, then call resumeHaul.
        final controller = container.read(trackingControllerProvider.notifier);

        // Use the real repos to create a trip + haul in-progress.
        final haulRepo = container.read(haulRepositoryProvider);
        final tripRepo = container.read(tripRepositoryProvider);
        final trip = await tripRepo.getOrStartActiveTrip();
        final haul = await haulRepo.startHaul(
          tripId: trip.id,
          trawlWidthMeters: 20,
          startedAt: DateTime(2025, 1, 1, 6),
        );

        // Write points directly via the DAO (imitating a previous session).
        final points = <LatLng>[
          const LatLng(-7.2000, 113.4000),
          const LatLng(-7.2005, 113.4005),
          const LatLng(-7.2010, 113.4010),
        ];
        for (var i = 0; i < points.length; i++) {
          await container.read(trackPointRepositoryProvider).appendReading(
                haulId: haul.id,
                reading: GpsReading(
                  latitude: points[i].latitude,
                  longitude: points[i].longitude,
                  timestamp: DateTime(2025, 1, 1, 6, 0, i * 10),
                  accuracyMeters: 6,
                  speedMps: 2,
                  headingDegrees: 135,
                ),
              );
        }

        // Resume.
        await controller.resumeHaul(haul);

        // Emit one more reading to confirm distance keeps accumulating
        // from the resumed baseline.
        const extra = LatLng(-7.2015, 113.4015);
        fakeGps.emit(GpsReading(
          latitude: extra.latitude,
          longitude: extra.longitude,
          timestamp: DateTime(2025, 1, 1, 6, 1, 0),
          accuracyMeters: 6,
          speedMps: 2,
          headingDegrees: 135,
        ),);
        await Future<void>.delayed(Duration.zero);

        await controller.stopHaul();

        final stored = await db.haulDao.findById(haul.id);
        final expected = GeoCalculator.totalDistanceMeters([...points, extra]);
        expect(
          stored!.distanceMeters,
          closeTo(expected, 1.0),
          reason:
              'resume should rebuild aggregates then add the new leg, '
              'not double-count or start from zero',
        );
      },
    );
  });
}
