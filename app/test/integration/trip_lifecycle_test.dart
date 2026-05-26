// End-to-end integration test for a full trip lifecycle.
//
// Drives the tracking subsystem as the UI does: startHaul → feed GPS →
// stopHaul → startHaul again → endTrip. Verifies both the in-memory
// state (TrackingController / TrackingState) and the on-disk state
// (Drift rows, TripSummary aggregates) stay consistent.
//
// Runs entirely in-memory (NativeDatabase.memory()) and uses the
// existing FakeGpsService helper so no platform plugins are needed.
// This test is shaped to run under `flutter test` — it does NOT need
// an Android emulator.

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:styra/core/services/gps_reading.dart';
import 'package:styra/core/services/gps_service.dart';
import 'package:styra/data/database/app_database.dart';
import 'package:styra/features/onboarding/data/user_profile_repository.dart';
import 'package:styra/features/tracking/application/tracking_controller.dart';
import 'package:styra/features/tracking/data/trip_repository.dart';
import 'package:styra/features/tracking/domain/entities/trip.dart';

import '../helpers/fake_gps_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Trip lifecycle — full end-to-end', () {
    late AppDatabase db;
    late FakeGpsService fakeGps;
    late ProviderContainer container;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      fakeGps = FakeGpsService();

      container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        gpsServiceProvider.overrideWithValue(fakeGps),
      ],);

      // Seed a user profile so the real app flow would be satisfied.
      // Not strictly required by the tracking controller (trawl width is
      // passed explicitly), but mirrors production call-sites.
      await container.read(userProfileRepositoryProvider).saveProfile(
            name: 'Pak Hasan',
            vesselName: 'KM Harapan Jaya',
            trawlWidthMeters: 20,
            homePort: 'Brondong',
          );
    });

    tearDown(() async {
      container.dispose();
      fakeGps.dispose();
      await db.close();
    });

    test(
      'Mulai Tebar → 10 GPS points → Angkat → second Haul → endTrip '
      'persists correct rows and aggregates',
      () async {
        final controller = container.read(trackingControllerProvider.notifier);
        final tripRepo = container.read(tripRepositoryProvider);

        // Sanity: no trip or haul yet.
        expect(await tripRepo.getActiveTrip(), isNull);
        expect(await db.haulDao.findRecording(), isNull);

        // ================================================================
        // Haul #1
        // ================================================================
        final haul1 = await controller.startHaul(trawlWidthMeters: 20);

        final tripRow = await db.tripDao.findActive();
        expect(tripRow, isNotNull,
            reason: 'startHaul should create the active trip',);
        expect(tripRow!.status, 'active');

        final haul1Row = await db.haulDao.findById(haul1.id);
        expect(haul1Row, isNotNull);
        expect(haul1Row!.status, 'recording');
        expect(haul1Row.orderIndex, 1);
        expect(haul1Row.tripId, tripRow.id);

        // Push 10 synthetic GPS readings along a straight NE line.
        // ~0.0003° per step ≈ 33 m, so total ~300 m over 10 points.
        final baseTime = DateTime.now();
        for (var i = 0; i < 10; i++) {
          fakeGps.emit(GpsReading(
            latitude: -7.2000 + i * 0.0003,
            longitude: 113.4000 + i * 0.0003,
            timestamp: baseTime.add(Duration(seconds: i * 10)),
            accuracyMeters: 6,
            speedMps: 2.5,
            headingDegrees: 45,
          ),);
          // Give the stream microtask a chance to land.
          await Future<void>.delayed(Duration.zero);
        }

        // All 10 points should have been persisted.
        expect(await db.trackPointDao.countForHaul(haul1.id), 10);

        // ================================================================
        // Angkat Trawl (stop haul #1)
        // ================================================================
        final completion1 = await controller.stopHaul();
        expect(completion1, isNotNull);
        expect(completion1!.pointCount, 10);

        final haul1Final = await db.haulDao.findById(haul1.id);
        expect(haul1Final!.status, 'completed');
        expect(haul1Final.distanceMeters, greaterThan(0),
            reason: 'pairwise haversine should produce a positive distance',);
        expect(haul1Final.durationSeconds, greaterThan(0));
        expect(haul1Final.sweptAreaM2, greaterThan(0));
        expect(haul1Final.avgSpeedKnots, isNotNull);

        // Trip should still be active — user may do another haul.
        final tripAfter1 = await tripRepo.getActiveTrip();
        expect(tripAfter1, isNotNull);
        expect(tripAfter1!.status, TripStatus.active);

        // ================================================================
        // Haul #2 in the same trip
        // ================================================================
        final haul2 = await controller.startHaul(trawlWidthMeters: 20);
        expect(haul2.tripId, tripAfter1.id,
            reason: 'a second haul must reuse the still-active trip',);
        expect(haul2.orderIndex, 2,
            reason: 'order_index should auto-increment within the trip',);

        // A few points for haul #2 too so it has non-zero metrics.
        for (var i = 0; i < 5; i++) {
          fakeGps.emit(GpsReading(
            latitude: -7.2100 + i * 0.0002,
            longitude: 113.4100 + i * 0.0002,
            timestamp: baseTime.add(Duration(minutes: 5, seconds: i * 10)),
            accuracyMeters: 8,
            speedMps: 2.0,
            headingDegrees: 50,
          ),);
          await Future<void>.delayed(Duration.zero);
        }

        await controller.stopHaul();
        final haul2Final = await db.haulDao.findById(haul2.id);
        expect(haul2Final!.status, 'completed');

        // ================================================================
        // Akhiri Trip
        // ================================================================
        await controller.endTrip();

        final finalTrip = await db.tripDao.findById(tripAfter1.id);
        expect(finalTrip!.status, 'completed',
            reason: 'endTrip should close the trip row',);
        expect(await tripRepo.getActiveTrip(), isNull,
            reason: 'no trip should be active after endTrip',);

        // ================================================================
        // TripSummary aggregate check
        // ================================================================
        final summaries = await tripRepo.listSummaries();
        expect(summaries, hasLength(1));

        final summary = summaries.single;
        expect(summary.trip.id, tripAfter1.id);
        expect(summary.haulCount, 2,
            reason: 'both hauls should contribute to the summary',);
        expect(
          summary.totalDistanceMeters,
          closeTo(
            haul1Final.distanceMeters + haul2Final.distanceMeters,
            0.01,
          ),
        );
        expect(
          summary.totalDurationSeconds,
          haul1Final.durationSeconds + haul2Final.durationSeconds,
        );
        expect(
          summary.totalSweptAreaM2,
          closeTo(
            haul1Final.sweptAreaM2 + haul2Final.sweptAreaM2,
            0.01,
          ),
        );
      },
    );

    test('endTrip mid-recording also stops the current haul', () async {
      final controller = container.read(trackingControllerProvider.notifier);

      final haul = await controller.startHaul(trawlWidthMeters: 18);
      fakeGps.emit(GpsReading(
        latitude: -7.2,
        longitude: 113.4,
        timestamp: DateTime.now(),
        accuracyMeters: 5,
        speedMps: 2.2,
        headingDegrees: 90,
      ),);
      await Future<void>.delayed(Duration.zero);

      // Don't call stopHaul first — endTrip should do it.
      await controller.endTrip();

      final haulRow = await db.haulDao.findById(haul.id);
      expect(haulRow!.status, 'completed',
          reason: 'endTrip should cascade-stop an active haul',);

      final tripRow = await db.tripDao.findById(haul.tripId);
      expect(tripRow!.status, 'completed');
    });
  });
}
