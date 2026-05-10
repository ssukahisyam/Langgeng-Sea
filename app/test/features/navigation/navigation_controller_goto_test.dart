// Unit tests for NavigationController -- go-to branch (M11a).
//
// Exercises the state machine:
//   Idle -> startGoto() -> Active(normal)
//   Active(normal) + GPS tick in arrival radius -> arrivingCountdown
//   arrivingCountdown + 3s elapsed -> arrived + alert dispatched
//   arrivingCountdown + GPS tick outside radius -> normal (no alert)
//   arrived is sticky until stop()
//
// Uses FakeAsync to drive the 3-second debounce deterministically.

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

GpsReading _reading(LatLng pos, {double? speed}) => GpsReading(
      latitude: pos.latitude,
      longitude: pos.longitude,
      timestamp: DateTime(2026, 5, 10, 12),
      accuracyMeters: 5,
      speedMps: speed,
    );

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
      navigationAlertServiceProvider
          .overrideWithValue(fakeAlerts),
      // Collapse the permission + OS dance into "always ready"
      // so currentReadingProvider below emits immediately.
      currentReadingProvider
          .overrideWith((ref) => gpsStream.stream),
    ]);

    // Prime appSettings so the alarm dispatch reads a non-null value.
    container.read(appSettingsProvider);
  });

  tearDown(() async {
    container.dispose();
    await gpsStream.close();
    fakeGps.dispose();
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Basic lifecycle
  // ---------------------------------------------------------------------------

  group('lifecycle', () {
    test('defaults to NavigationIdle', () {
      expect(container.read(navigationControllerProvider),
          isA<NavigationIdle>());
    });

    test('startGoto transitions to NavigationActive', () {
      container.read(navigationControllerProvider.notifier).startGoto(
            const GotoTarget(
              position: LatLng(-7.2, 113.4),
              label: 'Spot Udang',
            ),
          );
      final state = container.read(navigationControllerProvider);
      expect(state, isA<NavigationActive>());
      final active = state as NavigationActive;
      expect(active.target, isA<GotoTarget>());
      expect(active.alarmState, NavigationAlarmState.normal);
    });

    test('stop() resets to Idle', () {
      final ctrl = container.read(navigationControllerProvider.notifier);
      ctrl.startGoto(const GotoTarget(
        position: LatLng(-7.2, 113.4),
        label: 'X',
      ));
      ctrl.stop();
      expect(container.read(navigationControllerProvider),
          isA<NavigationIdle>());
    });
  });

  // ---------------------------------------------------------------------------
  // Progress recomputation
  // ---------------------------------------------------------------------------

  group('progress', () {
    test('updates on each GPS reading', () async {
      final ctrl = container.read(navigationControllerProvider.notifier);
      ctrl.startGoto(const GotoTarget(
        position: LatLng(0, 0.001),
        label: 'Target',
      ));

      gpsStream.add(_reading(const LatLng(0, 0), speed: 2.0));
      // Riverpod delivers stream events on microtasks.
      await Future<void>.delayed(Duration.zero);

      final state =
          container.read(navigationControllerProvider) as NavigationActive;
      // ~111 m at equator for 0.001 deg longitude.
      expect(state.progress.distanceToTargetMeters, closeTo(111, 5));
      expect(state.progress.bearingDegrees, closeTo(90, 1));
      // Non-null ETA because speed > 0.25 m/s.
      expect(state.progress.etaSeconds, isNotNull);
    });

    test('suppresses ETA when speed is below threshold', () async {
      final ctrl = container.read(navigationControllerProvider.notifier);
      ctrl.startGoto(const GotoTarget(
        position: LatLng(0, 0.001),
        label: 'Target',
      ));

      gpsStream.add(_reading(const LatLng(0, 0), speed: 0.05));
      await Future<void>.delayed(Duration.zero);

      final state =
          container.read(navigationControllerProvider) as NavigationActive;
      expect(state.progress.etaSeconds, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Arrival state machine (3 s debounce)
  // ---------------------------------------------------------------------------

  test(
    'close GPS fix -> arrivingCountdown -> after 3s -> arrived + alert fired',
    () {
      fakeAsync((async) {
        // Inside fakeAsync so the 3-second debounce timer is driven by
        // async.elapse() rather than real time.
        final ctrl = container.read(navigationControllerProvider.notifier);
        ctrl.startGoto(const GotoTarget(
          position: LatLng(0, 0),
          label: 'Dermaga',
        ));

        // Emit a fix within 5 metres of the target.
        gpsStream.add(_reading(
          const LatLng(0, 0.000045), // ~5 m east of (0,0)
          speed: 1.5,
        ));
        async.flushMicrotasks();

        expect(
          (container.read(navigationControllerProvider) as NavigationActive)
              .alarmState,
          NavigationAlarmState.arrivingCountdown,
        );
        // Alarm has NOT fired yet.
        expect(fakeAlerts.countOf('arrived'), 0);

        // Advance past the 3-second debounce window.
        async.elapse(const Duration(seconds: 4));
        async.flushMicrotasks();

        expect(
          (container.read(navigationControllerProvider) as NavigationActive)
              .alarmState,
          NavigationAlarmState.arrived,
        );
        expect(fakeAlerts.countOf('arrived'), 1);
        final last = fakeAlerts.lastOf('arrived')!;
        expect(last.label, 'Dermaga');
      });
    },
  );

  test(
    'user walks out of radius during countdown -> back to normal, no alarm',
    () {
      fakeAsync((async) {
        final ctrl = container.read(navigationControllerProvider.notifier);
        ctrl.startGoto(const GotoTarget(
          position: LatLng(0, 0),
          label: 'X',
        ));

        // Enter radius.
        gpsStream.add(_reading(const LatLng(0, 0.00004), speed: 1.5));
        async.flushMicrotasks();
        expect(
          (container.read(navigationControllerProvider) as NavigationActive)
              .alarmState,
          NavigationAlarmState.arrivingCountdown,
        );

        // 1 second into countdown, move back OUT of radius.
        async.elapse(const Duration(seconds: 1));
        gpsStream.add(_reading(const LatLng(0, 0.001), speed: 1.5));
        async.flushMicrotasks();
        expect(
          (container.read(navigationControllerProvider) as NavigationActive)
              .alarmState,
          NavigationAlarmState.normal,
        );

        // Advance past the original 3-second mark -- no alarm should fire.
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(fakeAlerts.countOf('arrived'), 0);
      });
    },
  );

  test('arrived is sticky -- subsequent GPS ticks do not refire alarm', () {
    fakeAsync((async) {
      final ctrl = container.read(navigationControllerProvider.notifier);
      ctrl.startGoto(const GotoTarget(
        position: LatLng(0, 0),
        label: 'X',
      ));

      gpsStream.add(_reading(const LatLng(0, 0.00003), speed: 1.5));
      async.elapse(const Duration(seconds: 4));
      async.flushMicrotasks();
      expect(fakeAlerts.countOf('arrived'), 1);

      // Subsequent readings should not retrigger the alarm.
      for (var i = 0; i < 5; i++) {
        gpsStream.add(_reading(const LatLng(0, 0.00002), speed: 1.5));
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
      }
      expect(fakeAlerts.countOf('arrived'), 1);
    });
  });

  test('stop() during arrivingCountdown cancels the pending alarm', () {
    fakeAsync((async) {
      final ctrl = container.read(navigationControllerProvider.notifier);
      ctrl.startGoto(const GotoTarget(
        position: LatLng(0, 0),
        label: 'X',
      ));

      gpsStream.add(_reading(const LatLng(0, 0.00003), speed: 1.5));
      async.flushMicrotasks();
      ctrl.stop();
      async.elapse(const Duration(seconds: 5));
      async.flushMicrotasks();

      expect(container.read(navigationControllerProvider),
          isA<NavigationIdle>());
      expect(fakeAlerts.countOf('arrived'), 0);
    });
  });
}
