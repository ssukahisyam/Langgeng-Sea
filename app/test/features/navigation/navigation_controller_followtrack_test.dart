// Unit tests for NavigationController -- follow-track branch (M11b).
//
// Mirrors navigation_controller_goto_test.dart's setup (fake alert
// service + overridden currentReadingProvider stream + fakeAsync for
// deterministic debounce). Exercises the hysteresis machine:
//
//   Idle -> startFollowTrack -> Active(normal)
//   Active(normal) + crossTrack > 30m  -> offRouteCountdown
//   offRouteCountdown + 5s             -> offRoute + "keluar jalur"
//   offRoute + crossTrack <= 30m       -> returnCountdown
//   returnCountdown + 5s               -> normal + back-on-route haptic
//   Any countdown + threshold flip     -> cancel + revert (no alarm)
//
// Also sanity-checks progress math: crossTrack, percentAlongPath,
// distanceToTargetMeters all derive correctly from the reference
// polyline for a running follow-track.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langgeng_sea/core/services/gps_reading.dart';
import 'package:langgeng_sea/core/services/gps_service.dart';
import 'package:langgeng_sea/core/settings/application/app_settings_provider.dart';
import 'package:langgeng_sea/data/database/app_database.dart';
import 'package:langgeng_sea/features/map/application/current_reading_provider.dart';
import 'package:langgeng_sea/features/navigation/application/navigation_controller.dart';
import 'package:langgeng_sea/features/navigation/application/navigation_state.dart';
import 'package:langgeng_sea/features/navigation/data/navigation_alert_service.dart';
import 'package:langgeng_sea/features/navigation/domain/entities/navigation_target.dart';
import 'package:latlong2/latlong.dart';

import '../../helpers/fake_gps_service.dart';
import '../../helpers/fake_navigation_alert_service.dart';

/// Reference polyline used across tests: simple east-bound leg along
/// the equator from (0,0) to (0, 0.001) -- ~111 m long. "On-line"
/// points have latitude 0; "off-route" points have latitude offsets
/// in degrees converted from meters (≈ 1/111000 per m).
const _path = <LatLng>[LatLng(0, 0), LatLng(0, 0.001)];

GpsReading _reading(LatLng pos, {double? speed}) => GpsReading(
      latitude: pos.latitude,
      longitude: pos.longitude,
      timestamp: DateTime(2026, 5, 10, 12),
      accuracyMeters: 5,
      speedMps: speed,
    );

/// Build a LatLng offset `metersNorth` meters from [along] (positive
/// = north). At / near the equator, 1° of latitude is ~111 km, so
/// offset in degrees is meters / 111000.
LatLng _offsetNorth(LatLng along, double metersNorth) {
  return LatLng(along.latitude + metersNorth / 111000.0, along.longitude);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeGpsService fakeGps;
  late FakeNavigationAlertService fakeAlerts;
  late StreamController<GpsReading> gpsStream;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    fakeGps = FakeGpsService();
    fakeAlerts = FakeNavigationAlertService();
    gpsStream = StreamController<GpsReading>.broadcast();

    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      gpsServiceProvider.overrideWithValue(fakeGps),
      navigationAlertServiceProvider.overrideWithValue(fakeAlerts),
      currentReadingProvider.overrideWith((ref) => gpsStream.stream),
    ],);

    // Prime app settings so alarm dispatch reads a non-null value.
    container.read(appSettingsProvider);
  });

  tearDown(() async {
    container.dispose();
    await gpsStream.close();
    fakeGps.dispose();
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  group('lifecycle', () {
    test('startFollowTrack transitions Idle -> Active(normal)', () {
      container
          .read(navigationControllerProvider.notifier)
          .startFollowTrack(const FollowTrackTarget(
            pathPoints: _path,
            label: 'Haul Test',
            sourceType: FollowTrackSource.haul,
            sourceId: 'h-1',
          ),);
      final state = container.read(navigationControllerProvider);
      expect(state, isA<NavigationActive>());
      final active = state as NavigationActive;
      expect(active.target, isA<FollowTrackTarget>());
      expect(active.alarmState, NavigationAlarmState.normal);
    });

    test('stop() during an off-route countdown cancels the alarm', () {
      fakeAsync((async) {
        final ctrl = container.read(navigationControllerProvider.notifier);
        ctrl.startFollowTrack(const FollowTrackTarget(
          pathPoints: _path,
          label: 'H',
          sourceType: FollowTrackSource.haul,
          sourceId: 'h-1',
        ),);
        // Emit a reading 50m off the line -> enters offRouteCountdown.
        gpsStream.add(_reading(_offsetNorth(const LatLng(0, 0.0005), 50)));
        async.flushMicrotasks();
        expect(
          (container.read(navigationControllerProvider) as NavigationActive)
              .alarmState,
          NavigationAlarmState.offRouteCountdown,
        );

        // User stops nav before the 5s lapses. Alarm must not fire.
        ctrl.stop();
        async.elapse(const Duration(seconds: 7));
        async.flushMicrotasks();

        expect(container.read(navigationControllerProvider),
            isA<NavigationIdle>(),);
        expect(fakeAlerts.countOf('offRoute'), 0);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // Progress recomputation
  // ---------------------------------------------------------------------------

  group('progress', () {
    test('on-line reading -> crossTrack ~0, percentAlong rises', () async {
      final ctrl = container.read(navigationControllerProvider.notifier);
      ctrl.startFollowTrack(const FollowTrackTarget(
        pathPoints: _path,
        label: 'H',
        sourceType: FollowTrackSource.haul,
        sourceId: 'h-1',
      ),);

      // Quarter of the way along the leg, on the line.
      gpsStream.add(_reading(const LatLng(0, 0.00025), speed: 2.0));
      await Future<void>.delayed(Duration.zero);

      final state =
          container.read(navigationControllerProvider) as NavigationActive;
      expect(state.progress.crossTrackMeters, lessThan(5));
      expect(state.progress.percentAlongPath, closeTo(0.25, 0.05));
      // distanceToTarget measured to the end of the polyline, ~83 m
      // remaining at this point.
      expect(state.progress.distanceToTargetMeters, closeTo(83, 10));
      // ETA non-null because speed > threshold.
      expect(state.progress.etaSeconds, isNotNull);
    });

    test('off-line reading populates crossTrack ≈ offset meters', () async {
      final ctrl = container.read(navigationControllerProvider.notifier);
      ctrl.startFollowTrack(const FollowTrackTarget(
        pathPoints: _path,
        label: 'H',
        sourceType: FollowTrackSource.haul,
        sourceId: 'h-1',
      ),);

      // 40 m north of the mid-leg point.
      gpsStream.add(_reading(
        _offsetNorth(const LatLng(0, 0.0005), 40),
        speed: 2.0,
      ),);
      await Future<void>.delayed(Duration.zero);

      final state =
          container.read(navigationControllerProvider) as NavigationActive;
      expect(state.progress.crossTrackMeters, closeTo(40, 3));
    });
  });

  // ---------------------------------------------------------------------------
  // Off-route state machine (5 s debounce)
  // ---------------------------------------------------------------------------

  test(
    'crossTrack > 30m -> offRouteCountdown -> after 5s -> offRoute + alarm',
    () {
      fakeAsync((async) {
        final ctrl = container.read(navigationControllerProvider.notifier);
        ctrl.startFollowTrack(const FollowTrackTarget(
          pathPoints: _path,
          label: 'Haul X',
          sourceType: FollowTrackSource.haul,
          sourceId: 'h-1',
        ),);

        // First reading on-line -> stay normal.
        gpsStream.add(_reading(const LatLng(0, 0.00025), speed: 1.5));
        async.flushMicrotasks();
        expect(
          (container.read(navigationControllerProvider) as NavigationActive)
              .alarmState,
          NavigationAlarmState.normal,
        );

        // Drift 50 m north -> enter countdown.
        gpsStream.add(_reading(
          _offsetNorth(const LatLng(0, 0.0005), 50),
          speed: 1.5,
        ),);
        async.flushMicrotasks();
        expect(
          (container.read(navigationControllerProvider) as NavigationActive)
              .alarmState,
          NavigationAlarmState.offRouteCountdown,
        );
        expect(fakeAlerts.countOf('offRoute'), 0);

        // Past the 5 s debounce -> commit to offRoute, alarm fires.
        async.elapse(const Duration(seconds: 6));
        async.flushMicrotasks();
        expect(
          (container.read(navigationControllerProvider) as NavigationActive)
              .alarmState,
          NavigationAlarmState.offRoute,
        );
        expect(fakeAlerts.countOf('offRoute'), 1);
        expect(fakeAlerts.lastOf('offRoute')!.distance, closeTo(50, 5));
      });
    },
  );

  test(
    'returning to route during countdown cancels the off-route alarm',
    () {
      fakeAsync((async) {
        final ctrl = container.read(navigationControllerProvider.notifier);
        ctrl.startFollowTrack(const FollowTrackTarget(
          pathPoints: _path,
          label: 'H',
          sourceType: FollowTrackSource.haul,
          sourceId: 'h-1',
        ),);

        // Drift 50 m off-route -> countdown.
        gpsStream.add(_reading(
          _offsetNorth(const LatLng(0, 0.0005), 50),
          speed: 1.5,
        ),);
        async.flushMicrotasks();
        expect(
          (container.read(navigationControllerProvider) as NavigationActive)
              .alarmState,
          NavigationAlarmState.offRouteCountdown,
        );

        // 2 s in, return to within 30 m -> cancel back to normal.
        async.elapse(const Duration(seconds: 2));
        gpsStream.add(_reading(const LatLng(0, 0.0005), speed: 1.5));
        async.flushMicrotasks();
        expect(
          (container.read(navigationControllerProvider) as NavigationActive)
              .alarmState,
          NavigationAlarmState.normal,
        );

        // Advance past the original 5 s mark. Alarm must stay silent.
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(fakeAlerts.countOf('offRoute'), 0);
      });
    },
  );

  test(
    'offRoute -> back-on-route fires haptic-only notifyBackOnRoute',
    () {
      fakeAsync((async) {
        final ctrl = container.read(navigationControllerProvider.notifier);
        ctrl.startFollowTrack(const FollowTrackTarget(
          pathPoints: _path,
          label: 'H',
          sourceType: FollowTrackSource.haul,
          sourceId: 'h-1',
        ),);

        // Commit to off-route first.
        gpsStream.add(_reading(
          _offsetNorth(const LatLng(0, 0.0005), 50),
          speed: 1.5,
        ),);
        async.elapse(const Duration(seconds: 6));
        async.flushMicrotasks();
        expect(fakeAlerts.countOf('offRoute'), 1);

        // Return to route: first tick transitions to returnCountdown,
        // then 5 s later fire back-on-route.
        gpsStream.add(_reading(const LatLng(0, 0.0005), speed: 1.5));
        async.flushMicrotasks();
        expect(
          (container.read(navigationControllerProvider) as NavigationActive)
              .alarmState,
          NavigationAlarmState.returnCountdown,
        );
        expect(fakeAlerts.countOf('backOnRoute'), 0);

        async.elapse(const Duration(seconds: 6));
        async.flushMicrotasks();
        expect(
          (container.read(navigationControllerProvider) as NavigationActive)
              .alarmState,
          NavigationAlarmState.normal,
        );
        expect(fakeAlerts.countOf('backOnRoute'), 1);
        // Off-route alarm did NOT re-fire on the way back.
        expect(fakeAlerts.countOf('offRoute'), 1);
      });
    },
  );

  test(
    'drift-out during returnCountdown reverts to offRoute silently',
    () {
      fakeAsync((async) {
        final ctrl = container.read(navigationControllerProvider.notifier);
        ctrl.startFollowTrack(const FollowTrackTarget(
          pathPoints: _path,
          label: 'H',
          sourceType: FollowTrackSource.haul,
          sourceId: 'h-1',
        ),);

        // Commit offRoute.
        gpsStream.add(_reading(
          _offsetNorth(const LatLng(0, 0.0005), 50),
          speed: 1.5,
        ),);
        async.elapse(const Duration(seconds: 6));
        async.flushMicrotasks();

        // Step into returnCountdown.
        gpsStream.add(_reading(const LatLng(0, 0.0005), speed: 1.5));
        async.flushMicrotasks();
        expect(
          (container.read(navigationControllerProvider) as NavigationActive)
              .alarmState,
          NavigationAlarmState.returnCountdown,
        );

        // Drift out again mid-return. Should collapse back to
        // offRoute without a second "keluar jalur" alarm.
        async.elapse(const Duration(seconds: 2));
        gpsStream.add(_reading(
          _offsetNorth(const LatLng(0, 0.0005), 50),
          speed: 1.5,
        ),);
        async.flushMicrotasks();
        expect(
          (container.read(navigationControllerProvider) as NavigationActive)
              .alarmState,
          NavigationAlarmState.offRoute,
        );

        // Nothing new dispatched on either side.
        async.elapse(const Duration(seconds: 4));
        async.flushMicrotasks();
        expect(fakeAlerts.countOf('offRoute'), 1);
        expect(fakeAlerts.countOf('backOnRoute'), 0);
      });
    },
  );
}
