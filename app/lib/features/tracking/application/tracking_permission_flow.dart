import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/observability/logger.dart';
import '../../../core/services/gps_service.dart';

/// Result of the tracking permission pre-flight.
///
/// Maps directly to Requirement 1 Acceptance Criteria 1, 1a, 5, and 6:
/// - [Granted]: Both fine-location and (on API 29+) background-location
///   were granted. The caller may start a full Background_Service
///   session. Notification permission is requested on API 33+ but its
///   absence does not downgrade this result.
/// - [GrantedForegroundOnly]: Fine-location is available but
///   background-location was denied. Per AC 6, the Tracking_Controller
///   must show a non-blocking warning and start tracking with
///   foreground-only GPS acquisition (AC 1a).
/// - [Denied]: Fine-location was denied (or OS location services are
///   off). Tracking cannot proceed and the caller must surface a
///   banner directing the user to settings.
sealed class TrackingPermissionResult {
  const TrackingPermissionResult();
}

/// Fine-location + background-location both granted.
final class Granted extends TrackingPermissionResult {
  const Granted();
}

/// Fine-location granted, background-location denied or unavailable.
final class GrantedForegroundOnly extends TrackingPermissionResult {
  const GrantedForegroundOnly();
}

/// Fine-location denied, or OS location services disabled.
final class Denied extends TrackingPermissionResult {
  const Denied();
}

/// Thin abstraction over `permission_handler` + `device_info_plus`.
///
/// Split out so [ensureTrackingPermissions] stays pure and testable
/// (no direct platform channel I/O). Production wiring is provided by
/// [RealPermissionHandler]; tests supply an in-memory fake.
abstract class PermissionHandler {
  /// Current `ACCESS_FINE_LOCATION` status.
  Future<PermissionStatus> checkFineLocation();

  /// Request `ACCESS_FINE_LOCATION`. Returns the resulting status.
  Future<PermissionStatus> requestFineLocation();

  /// Current `ACCESS_BACKGROUND_LOCATION` status.
  ///
  /// On Android 9 and below this is implicitly granted if fine
  /// location is granted; callers should still gate by SDK level via
  /// [androidSdkInt].
  Future<PermissionStatus> checkBackgroundLocation();

  /// Request `ACCESS_BACKGROUND_LOCATION`. The OS on API 30+ routes
  /// this to a settings screen rather than a dialog; [showRationale]
  /// should be invoked beforehand to set expectations.
  Future<PermissionStatus> requestBackgroundLocation();

  /// Current `POST_NOTIFICATIONS` status (Android 13+).
  Future<PermissionStatus> checkNotifications();

  /// Request `POST_NOTIFICATIONS`. Returns the resulting status.
  Future<PermissionStatus> requestNotifications();

  /// Current `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` status. Tracking
  /// dapat berjalan tanpa permission ini, tetapi Android Doze akan
  /// men-throttle GPS saat layar mati. Diintroduksi untuk
  /// `activateAccurateMode` (PR #29).
  Future<PermissionStatus> checkIgnoreBattery();

  /// Request `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. Returns the
  /// resulting status. Best-effort: kalau OEM ROM atau plugin tidak
  /// mendukung, status akhir bisa `denied`.
  Future<PermissionStatus> requestIgnoreBattery();

  /// Android SDK integer (e.g. 29 for Android 10). Returns a negative
  /// value on non-Android platforms so the permission flow can skip
  /// Android-specific branches safely.
  Future<int> androidSdkInt();
}

/// Production [PermissionHandler] backed by `permission_handler` and
/// `device_info_plus`.
class RealPermissionHandler implements PermissionHandler {
  RealPermissionHandler({DeviceInfoPlugin? deviceInfo})
      : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _deviceInfo;

  int? _cachedSdkInt;

  @override
  Future<PermissionStatus> checkFineLocation() => Permission.location.status;

  @override
  Future<PermissionStatus> requestFineLocation() =>
      Permission.location.request();

  @override
  Future<PermissionStatus> checkBackgroundLocation() =>
      Permission.locationAlways.status;

  @override
  Future<PermissionStatus> requestBackgroundLocation() =>
      Permission.locationAlways.request();

  @override
  Future<PermissionStatus> checkNotifications() =>
      Permission.notification.status;

  @override
  Future<PermissionStatus> requestNotifications() =>
      Permission.notification.request();

  @override
  Future<PermissionStatus> checkIgnoreBattery() =>
      Permission.ignoreBatteryOptimizations.status;

  @override
  Future<PermissionStatus> requestIgnoreBattery() =>
      Permission.ignoreBatteryOptimizations.request();

  @override
  Future<int> androidSdkInt() async {
    final cached = _cachedSdkInt;
    if (cached != null) return cached;
    try {
      final info = await _deviceInfo.androidInfo;
      return _cachedSdkInt = info.version.sdkInt;
    } catch (_) {
      // Not on Android (or platform channel missing). Treat as a
      // sentinel so the flow skips Android-only branches.
      return _cachedSdkInt = -1;
    }
  }
}

/// Ensures the permissions needed to start a tracking session.
///
/// Algorithm (Requirement 1 AC 5, 6; derived from design.md §
/// "PermissionFlow"):
///
/// 1. If OS location services are off (via [GpsService.isLocationServiceEnabled]),
///    invoke `showRationale('gps_off')` and return [Denied]. Requesting
///    permission while the radio is off is pointless — the user must
///    turn it on in settings first.
/// 2. Check `ACCESS_FINE_LOCATION`. If not granted, call
///    [PermissionHandler.requestFineLocation]. If the result is still
///    not granted, return [Denied].
/// 3. On Android 10+ (SDK 29+), check `ACCESS_BACKGROUND_LOCATION`. If
///    not granted, call `showRationale('background_location')` before
///    [PermissionHandler.requestBackgroundLocation]. If the result is
///    still not granted, return [GrantedForegroundOnly].
/// 4. On Android 13+ (SDK 33+), check `POST_NOTIFICATIONS`. If not
///    granted, call [PermissionHandler.requestNotifications]. Lack of
///    notification permission does NOT downgrade the result — the
///    foreground service can still run; a `Logger.warn` entry is
///    emitted so the user-facing UI can decide whether to prompt a
///    follow-up dialog.
/// 5. Return [Granted].
///
/// [showRationale] receives a stable explanation id:
/// - `'gps_off'`: OS location services are disabled.
/// - `'background_location'`: Background location is about to be
///   requested; on API 30+ the OS redirects to a settings screen, so
///   the rationale is the only chance to explain why.
///
/// The function performs no UI work directly — [showRationale] is the
/// sole UI hook and is expected to be synchronous from the caller's
/// perspective (return value is ignored). This keeps the function
/// property-testable against Property 5 ("Permission flow menghasilkan
/// result deterministik").
Future<TrackingPermissionResult> ensureTrackingPermissions({
  required GpsService gps,
  required PermissionHandler handler,
  required void Function(String explanationId) showRationale,
}) async {
  // Step 1 — GPS radio pre-flight. A granted permission is useless if
  // the user has the GPS switch turned off.
  final serviceOn = await gps.isLocationServiceEnabled();
  if (!serviceOn) {
    showRationale('gps_off');
    return const Denied();
  }

  // Step 2 — ACCESS_FINE_LOCATION (Requirement 1 AC 5).
  var fine = await handler.checkFineLocation();
  if (!fine.isGranted) {
    fine = await handler.requestFineLocation();
  }
  if (!fine.isGranted) {
    return const Denied();
  }

  // Determine SDK level once for the remaining Android-specific gates.
  final sdkInt = await handler.androidSdkInt();

  // Step 3 — ACCESS_BACKGROUND_LOCATION on Android 10+ (API 29+).
  // Android 9 and below treat fine-location as implicitly covering
  // background access, so we leave the result as Granted on those
  // versions.
  if (sdkInt >= 29) {
    var background = await handler.checkBackgroundLocation();
    if (!background.isGranted) {
      // Rationale MUST precede the request — on API 30+ the OS opens a
      // settings screen and the user needs context (AC 5).
      showRationale('background_location');
      background = await handler.requestBackgroundLocation();
    }
    if (!background.isGranted) {
      // AC 6: caller will surface the non-blocking warning and only
      // start tracking on the next explicit tap.
      return const GrantedForegroundOnly();
    }
  }

  // Step 4 — POST_NOTIFICATIONS on Android 13+ (API 33+). The
  // foreground service on API 34 requires a persistent notification;
  // if the user denies this we still let tracking start so that the
  // data-path isn't gated by a notification-only permission, but we
  // log a warning so the caller can prompt a follow-up nudge.
  if (sdkInt >= 33) {
    var notifications = await handler.checkNotifications();
    if (!notifications.isGranted) {
      notifications = await handler.requestNotifications();
    }
    if (!notifications.isGranted) {
      Logger.instance.warn(
        'tracking.permission.notifications_denied',
        {'sdkInt': sdkInt, 'status': notifications.name},
      );
    }
  }

  return const Granted();
}
