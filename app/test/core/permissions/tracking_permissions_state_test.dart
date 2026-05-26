// PR #41 — tests untuk TrackingPermissionsState helper getters.
//
// Provider sendiri butuh platform channel mocking yang ribet untuk
// permission_handler. Kita tes saja state object-nya supaya logic
// allRequired / allOptimal benar.

import 'package:flutter_test/flutter_test.dart';
import 'package:styra/core/permissions/tracking_permissions_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  TrackingPermissionsState build({
    PermissionStatus location = PermissionStatus.denied,
    PermissionStatus notification = PermissionStatus.denied,
    PermissionStatus battery = PermissionStatus.denied,
  }) =>
      TrackingPermissionsState(
        location: location,
        notification: notification,
        battery: battery,
      );

  group('TrackingPermissionsState.allRequired', () {
    test('false saat lokasi denied', () {
      expect(
        build(
          location: PermissionStatus.denied,
          notification: PermissionStatus.granted,
        ).allRequired,
        isFalse,
      );
    });

    test('false saat notifikasi denied', () {
      expect(
        build(
          location: PermissionStatus.granted,
          notification: PermissionStatus.denied,
        ).allRequired,
        isFalse,
      );
    });

    test('true saat lokasi + notifikasi granted (battery boleh denied)', () {
      expect(
        build(
          location: PermissionStatus.granted,
          notification: PermissionStatus.granted,
          battery: PermissionStatus.denied,
        ).allRequired,
        isTrue,
      );
    });

    test('true juga saat semua granted', () {
      expect(
        build(
          location: PermissionStatus.granted,
          notification: PermissionStatus.granted,
          battery: PermissionStatus.granted,
        ).allRequired,
        isTrue,
      );
    });
  });

  group('TrackingPermissionsState.allOptimal', () {
    test('false kalau battery denied meski wajib granted', () {
      expect(
        build(
          location: PermissionStatus.granted,
          notification: PermissionStatus.granted,
          battery: PermissionStatus.denied,
        ).allOptimal,
        isFalse,
      );
    });

    test('true hanya saat semua granted', () {
      expect(
        build(
          location: PermissionStatus.granted,
          notification: PermissionStatus.granted,
          battery: PermissionStatus.granted,
        ).allOptimal,
        isTrue,
      );
    });

    test('false saat lokasi denied (independen dari battery)', () {
      expect(
        build(
          location: PermissionStatus.denied,
          notification: PermissionStatus.granted,
          battery: PermissionStatus.granted,
        ).allOptimal,
        isFalse,
      );
    });
  });

  group('TrackingPermissionsState.copyWith', () {
    test('partial update tidak mengubah field lain', () {
      final base = build(
        location: PermissionStatus.granted,
        notification: PermissionStatus.granted,
        battery: PermissionStatus.denied,
      );
      final updated = base.copyWith(battery: PermissionStatus.granted);
      expect(updated.location, PermissionStatus.granted);
      expect(updated.notification, PermissionStatus.granted);
      expect(updated.battery, PermissionStatus.granted);
    });
  });

  test('loading sentinel: semua denied', () {
    final loading = TrackingPermissionsState.loading;
    expect(loading.location, PermissionStatus.denied);
    expect(loading.notification, PermissionStatus.denied);
    expect(loading.battery, PermissionStatus.denied);
    expect(loading.allRequired, isFalse);
    expect(loading.allOptimal, isFalse);
  });
}
