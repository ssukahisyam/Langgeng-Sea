// Unit tests untuk [activateAccurateMode] (PR #29 Phase 4).
//
// Pakai fake [PermissionHandler] yang full-scriptable: setiap test
// mengatur urutan return untuk check & request method, lalu memeriksa
// hasil [ActivateAccurateResult] yang dihasilkan.
//
// Tujuan: lock down 7 jalur permission state combination yang
// disebut di design.md §11. Tidak ada platform channel yang dipanggil,
// jadi test full-pure-Dart dan bisa lulus di sandbox tanpa Flutter
// engine.

import 'package:flutter_test/flutter_test.dart';
import 'package:langgeng_sea/features/tracking/application/tracking_mode_activation.dart';
import 'package:langgeng_sea/features/tracking/application/tracking_permission_flow.dart';
import 'package:permission_handler/permission_handler.dart';

class _FakePermissionHandler implements PermissionHandler {
  _FakePermissionHandler({
    required this.sdkInt,
    PermissionStatus notificationsStatus = PermissionStatus.granted,
    PermissionStatus notificationsRequestResult = PermissionStatus.granted,
    PermissionStatus batteryStatus = PermissionStatus.granted,
    PermissionStatus batteryRequestResult = PermissionStatus.granted,
  })  : _notificationsStatus = notificationsStatus,
        _notificationsRequestResult = notificationsRequestResult,
        _batteryStatus = batteryStatus,
        _batteryRequestResult = batteryRequestResult;

  final int sdkInt;
  PermissionStatus _notificationsStatus;
  final PermissionStatus _notificationsRequestResult;
  PermissionStatus _batteryStatus;
  final PermissionStatus _batteryRequestResult;

  int notificationsCheckCount = 0;
  int notificationsRequestCount = 0;
  int batteryCheckCount = 0;
  int batteryRequestCount = 0;
  int sdkIntCount = 0;

  @override
  Future<int> androidSdkInt() async {
    sdkIntCount++;
    return sdkInt;
  }

  @override
  Future<PermissionStatus> checkNotifications() async {
    notificationsCheckCount++;
    return _notificationsStatus;
  }

  @override
  Future<PermissionStatus> requestNotifications() async {
    notificationsRequestCount++;
    _notificationsStatus = _notificationsRequestResult;
    return _notificationsRequestResult;
  }

  @override
  Future<PermissionStatus> checkIgnoreBattery() async {
    batteryCheckCount++;
    return _batteryStatus;
  }

  @override
  Future<PermissionStatus> requestIgnoreBattery() async {
    batteryRequestCount++;
    _batteryStatus = _batteryRequestResult;
    return _batteryRequestResult;
  }

  // Unused di test ini — implementasi minimal supaya interface lengkap.
  @override
  Future<PermissionStatus> checkFineLocation() async => PermissionStatus.granted;

  @override
  Future<PermissionStatus> requestFineLocation() async =>
      PermissionStatus.granted;

  @override
  Future<PermissionStatus> checkBackgroundLocation() async =>
      PermissionStatus.granted;

  @override
  Future<PermissionStatus> requestBackgroundLocation() async =>
      PermissionStatus.granted;
}

void main() {
  group('activateAccurateMode — Android 13+', () {
    test('granted notif + granted battery → AccurateActivated', () async {
      final handler = _FakePermissionHandler(
        sdkInt: 34,
        notificationsStatus: PermissionStatus.granted,
        batteryStatus: PermissionStatus.granted,
      );

      final result = await activateAccurateMode(handler: handler);

      expect(result, isA<AccurateActivated>());
      // Sudah granted, jadi request tidak dipanggil.
      expect(handler.notificationsRequestCount, 0);
      expect(handler.batteryRequestCount, 0);
    });

    test('denied notif → request → granted → granted battery → AccurateActivated',
        () async {
      final handler = _FakePermissionHandler(
        sdkInt: 34,
        notificationsStatus: PermissionStatus.denied,
        notificationsRequestResult: PermissionStatus.granted,
        batteryStatus: PermissionStatus.granted,
      );

      final result = await activateAccurateMode(handler: handler);

      expect(result, isA<AccurateActivated>());
      expect(handler.notificationsRequestCount, 1,
          reason: 'must request notif when not granted');
    });

    test('denied notif + request still denied → AccurateDeclined', () async {
      final handler = _FakePermissionHandler(
        sdkInt: 34,
        notificationsStatus: PermissionStatus.denied,
        notificationsRequestResult: PermissionStatus.denied,
      );

      final result = await activateAccurateMode(handler: handler);

      expect(result, isA<AccurateDeclined>());
      // Battery tidak boleh diperiksa kalau notif gagal — fail fast.
      expect(handler.batteryCheckCount, 0);
      expect(handler.batteryRequestCount, 0);
    });

    test('permanently denied notif → AccurateNeedsSystemSettings(notifications)',
        () async {
      final handler = _FakePermissionHandler(
        sdkInt: 34,
        notificationsStatus: PermissionStatus.permanentlyDenied,
      );

      final result = await activateAccurateMode(handler: handler);

      expect(result, isA<AccurateNeedsSystemSettings>());
      expect(
        (result as AccurateNeedsSystemSettings).reason,
        NeedSettingsReason.notifications,
      );
      expect(handler.batteryCheckCount, 0);
    });

    test('granted notif + denied battery → AccurateActivatedWithBatteryWarning',
        () async {
      final handler = _FakePermissionHandler(
        sdkInt: 34,
        notificationsStatus: PermissionStatus.granted,
        batteryStatus: PermissionStatus.denied,
        batteryRequestResult: PermissionStatus.denied,
      );

      final result = await activateAccurateMode(handler: handler);

      expect(result, isA<AccurateActivatedWithBatteryWarning>(),
          reason: 'battery denied is non-blocking — mode tetap pindah Akurasi');
      expect(handler.batteryRequestCount, 1);
    });

    test(
        'granted notif + permanently denied battery → '
        'AccurateNeedsSystemSettings(battery)', () async {
      final handler = _FakePermissionHandler(
        sdkInt: 34,
        notificationsStatus: PermissionStatus.granted,
        batteryStatus: PermissionStatus.permanentlyDenied,
      );

      final result = await activateAccurateMode(handler: handler);

      expect(result, isA<AccurateNeedsSystemSettings>());
      expect(
        (result as AccurateNeedsSystemSettings).reason,
        NeedSettingsReason.battery,
      );
    });
  });

  group('activateAccurateMode — Android < 13', () {
    test('skips notif step entirely (sdkInt 31)', () async {
      // Android 12: POST_NOTIFICATIONS bukan permission runtime, jadi
      // langsung ke battery step.
      final handler = _FakePermissionHandler(
        sdkInt: 31,
        // Notif diset permanently denied — TIDAK boleh berpengaruh
        // karena step itu di-skip total.
        notificationsStatus: PermissionStatus.permanentlyDenied,
        batteryStatus: PermissionStatus.granted,
      );

      final result = await activateAccurateMode(handler: handler);

      expect(result, isA<AccurateActivated>());
      expect(handler.notificationsCheckCount, 0,
          reason: 'sdkInt < 33 must not check notifications');
      expect(handler.notificationsRequestCount, 0);
    });
  });

  group('activateAccurateMode — non-Android', () {
    test('sdkInt < 0 → AccurateUnsupportedPlatform', () async {
      final handler = _FakePermissionHandler(sdkInt: -1);

      final result = await activateAccurateMode(handler: handler);

      expect(result, isA<AccurateUnsupportedPlatform>());
      expect(handler.notificationsCheckCount, 0);
      expect(handler.batteryCheckCount, 0);
    });
  });
}
