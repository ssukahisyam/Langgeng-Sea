import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/observability/logger.dart';
import '../../../data/database/app_database.dart';
import '../domain/entities/track_point.dart';
import 'background_tracking_service.dart';
import 'mappers.dart';

/// Notification channel used for the persistent foreground-service
/// notification on Android.
const _kNotificationChannelId = 'langgeng_tracking';
const _kForegroundNotificationId = 888;

/// Key used to pass / receive the active haul id across isolate boundary.
const _kHaulIdKey = 'haulId';

/// Key used for status updates from the background isolate.
const _kStatusKey = 'status';

/// Thrown by [FlutterBackgroundTrackingService.start] ketika
/// `POST_NOTIFICATIONS` (Android 13+) ditolak user atau plugin gagal
/// memeriksa status permission. Tanpa permission ini, panggilan
/// `startForeground()` di sisi Android akan dilempar dengan
/// `CannotPostForegroundServiceNotificationException` ("Bad notification
/// for startForeground") yang meng-crash aplikasi. Lempar exception
/// terdefinisi ini supaya `TrackingController` bisa downgrade ke
/// foreground-only mode + tampilkan banner ke user, daripada crash.
class NotificationPermissionDeniedException implements Exception {
  const NotificationPermissionDeniedException();

  @override
  String toString() =>
      'NotificationPermissionDeniedException: POST_NOTIFICATIONS belum '
      'di-grant. Foreground service tidak bisa start.';
}

/// Thrown ketika `flutter_background_service` gagal memulai service
/// dari sisi Android (mis. PlatformException, channel disabled,
/// OEM restriction). Membungkus exception asli sebagai [cause] supaya
/// caller bisa logging tanpa kehilangan stack trace, sementara tipe
/// yang stabil ini bisa di-catch secara terstruktur.
class BackgroundServiceStartException implements Exception {
  const BackgroundServiceStartException(this.cause);

  final Object cause;

  @override
  String toString() =>
      'BackgroundServiceStartException: gagal memulai foreground '
      'service. Cause: $cause';
}

/// Concrete [BackgroundTrackingService] backed by `flutter_background_service`.
///
/// Starts an Android foreground service with `foregroundServiceType=location`
/// (configured in AndroidManifest.xml). The background isolate runs
/// [onBackgroundStart] which acquires GPS fixes via Geolocator and persists
/// them as TrackPoints through a local (isolate-scoped) database instance.
///
/// _Requirements: 1.1, 1.2, 1.3, 1.7, 1.8, 1.9_
class FlutterBackgroundTrackingService implements BackgroundTrackingService {
  FlutterBackgroundTrackingService() : _service = FlutterBackgroundService();

  final FlutterBackgroundService _service;
  final _statusController =
      StreamController<BackgroundTrackingStatus>.broadcast();

  BackgroundTrackingStatus _lastStatus = BackgroundTrackingStatus.stopped;
  bool _initialised = false;

  /// Must be called once during app initialisation (before any start/stop).
  @override
  Future<void> initialise() async {
    if (_initialised) return;
    _initialised = true;
    // Set up the notification channel for the foreground service.
    final androidConfig = AndroidConfiguration(
      onStart: onBackgroundStart,
      isForegroundMode: true,
      autoStart: false,
      autoStartOnBoot: false,
      foregroundServiceNotificationId: _kForegroundNotificationId,
      initialNotificationTitle: 'Langgeng Sea',
      initialNotificationContent: 'Memulai tracking GPS…',
      foregroundServiceTypes: [AndroidForegroundType.location],
      notificationChannelId: _kNotificationChannelId,
    );

    final iosConfig = IosConfiguration(
      autoStart: false,
      onForeground: _iosOnForeground,
    );

    await _service.configure(
      androidConfiguration: androidConfig,
      iosConfiguration: iosConfig,
    );

    // Listen to status updates from the background isolate.
    _service.on(_kStatusKey).listen((event) {
      if (event == null) return;
      final statusName = event['value'] as String?;
      if (statusName == null) return;
      final status = BackgroundTrackingStatus.values.firstWhere(
        (s) => s.name == statusName,
        orElse: () => BackgroundTrackingStatus.stopped,
      );
      _lastStatus = status;
      _statusController.add(status);
    });
  }

  @override
  Future<void> start({
    required String haulId,
    required String notificationTitle,
    required String notificationBody,
    bool skipBatteryPermission = false,
  }) async {
    // Defensive: if the caller forgot to invoke initialise() during
    // bootstrap, do it now. initialise() is idempotent.
    await initialise();

    _lastStatus = BackgroundTrackingStatus.starting;
    _statusController.add(BackgroundTrackingStatus.starting);

    // Idempotent guard (PR #27 R2): kalau service sebelumnya masih
    // running (mis. sisa dari sesi yang crash) — stop dulu, beri
    // jeda singkat supaya Android sempat menerima `stopForeground`,
    // baru start ulang. Tanpa ini, `startService()` kedua kali
    // bisa menabrak `IllegalStateException` di Android 14+.
    try {
      final alreadyRunning = await _service.isRunning();
      if (alreadyRunning) {
        Logger.instance.info(
          'tracking.bg_service_already_running_stopping',
          {'haulId': haulId},
        );
        _service.invoke('stop');
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      // `isRunning()` belum tentu reliable di semua versi plugin /
      // OEM ROM. Kalau cek itu sendiri throw, kita tetap lanjut —
      // worst case `startService()` di bawah throw yang kita catch
      // ke `BackgroundTrackingStatus.failed` di caller.
      Logger.instance.warn(
        'tracking.bg_isrunning_check_failed',
        {'error': e.toString()},
      );
    }

    // Acquire CPU wakelock so Android Doze mode doesn't throttle the
    // background isolate's GPS stream when the screen turns off.
    // Without this, position events stop firing within ~30s of lock
    // and the user sees a straight line between lock and unlock.
    //
    // Catatan PR #27 R1: battery-optimisation permission SENGAJA
    // tidak di-request di sini lagi — dipindah ke fire-and-forget
    // SETELAH `startService()` agar tidak race dengan rule
    // "foreground service notification ≤ 5 detik" di Android 14+.
    try {
      await WakelockPlus.enable();
    } catch (e) {
      Logger.instance.warn('tracking.wakelock_enable_failed', {
        'error': e.toString(),
      });
    }

    // POST_NOTIFICATIONS gate (PR #27 R1 follow-up):
    // Android 13+ (API 33) menjadikan POST_NOTIFICATIONS sebagai
    // permission runtime. Foreground service yang panggil
    // `startForeground()` tanpa permission ini akan dilempar
    // `RemoteServiceException$CannotPostForegroundServiceNotificationException`
    // — crash yang dilaporkan user di Redmi Note 10 Pro / PixelOS
    // ("Bad notification for startForeground").
    //
    // Strategi:
    // - Cek + request permission DI SINI (sebelum startService).
    // - Wrap dengan timeout supaya dialog yang stuck tidak menggantung.
    // - Kalau hasil akhir bukan granted, BAIL OUT lewat exception —
    //   caller (TrackingController) akan menangkap dan downgrade ke
    //   foreground-only GPS lewat `BackgroundTrackingStatus.failed`.
    //   LEBIH BAIK gagal start dengan banner daripada crash app.
    if (Platform.isAndroid) {
      try {
        var status = await Permission.notification.status;
        if (!status.isGranted) {
          status = await Permission.notification.request().timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  Logger.instance.warn(
                    'tracking.notification_permission_timeout',
                    const {'timeoutSeconds': 10},
                  );
                  return PermissionStatus.denied;
                },
              );
        }
        if (!status.isGranted) {
          Logger.instance.warn(
            'tracking.notification_permission_denied',
            {'status': status.name},
          );
          _lastStatus = BackgroundTrackingStatus.failed;
          _statusController.add(BackgroundTrackingStatus.failed);
          throw const NotificationPermissionDeniedException();
        }
      } on NotificationPermissionDeniedException {
        rethrow;
      } catch (e, stack) {
        // Plugin error / detached activity / channel missing — log
        // tapi JANGAN lanjut startService() karena kemungkinan besar
        // berakhir crash juga. Caller akan tampilkan banner.
        Logger.instance.warn(
          'tracking.notification_permission_check_failed',
          {'error': e.toString()},
          e,
          stack,
        );
        _lastStatus = BackgroundTrackingStatus.failed;
        _statusController.add(BackgroundTrackingStatus.failed);
        throw const NotificationPermissionDeniedException();
      }
    }

    // Defensive try-catch wrapper di sekitar startService():
    // di samping POST_NOTIFICATIONS yang sudah dijaga di atas, sisi
    // Android masih bisa lempar PlatformException untuk skenario
    // lain yang sulit diprediksi (channel di-disable user manual,
    // OEM ROM yang membatasi FG service, dsb). Lempar sebagai
    // BackgroundServiceStartException supaya caller tetap bisa
    // tampilkan banner — bukan crash app.
    try {
      await _service.startService();
    } catch (e, stack) {
      Logger.instance.error(
        'tracking.bg_start_service_failed',
        {'error': e.toString()},
        e,
        stack,
      );
      _lastStatus = BackgroundTrackingStatus.failed;
      _statusController.add(BackgroundTrackingStatus.failed);
      throw BackgroundServiceStartException(e);
    }

    // Send the haul id to the background isolate so it knows which
    // haul to append points to.
    _service.invoke('start', {_kHaulIdKey: haulId});

    // Battery-optimisation exemption (PR #27 R1):
    // PENTING — request ini SENGAJA dipindah ke fire-and-forget
    // SETELAH `startService()` sukses. Sebelumnya call ini ada di
    // hot-path tracking dan menyebabkan crash di Android 14+:
    // dialog OS membuka activity result yang race dengan rule
    // "foreground service notification harus muncul ≤ 5 detik" →
    // SIGABRT. Dengan pattern di bawah, service sudah hidup duluan
    // (notifikasi tampil), sehingga apa pun yang user pilih di
    // dialog tidak menggagalkan tracking.
    //
    // Path crash-recovery (`resumeHaul`) men-set
    // [skipBatteryPermission] = true supaya user tidak ditanya
    // ulang di sesi pertama setelah crash.
    if (!skipBatteryPermission && Platform.isAndroid) {
      unawaited(
        Future<void>.delayed(
          const Duration(seconds: 2),
          _maybeRequestBatteryOpt,
        ),
      );
    }
  }

  /// Best-effort request untuk
  /// `Permission.ignoreBatteryOptimizations`.
  ///
  /// Fungsi ini WAJIB tahan banting:
  /// - Idempotent: kalau status sudah `granted`, return early.
  /// - Tidak boleh propagate exception ke caller — semua error
  ///   (PlatformException, MissingPluginException, timeout,
  ///   activity-detached) di-log lalu di-swallow.
  /// - Pakai timeout 10 detik supaya kalau dialog stuck atau ROM
  ///   tertentu tidak pernah return, fire-and-forget tidak
  ///   menggantung selamanya.
  Future<void> _maybeRequestBatteryOpt() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (status.isGranted) {
        return;
      }
      final result = await Permission.ignoreBatteryOptimizations
          .request()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          Logger.instance.warn(
            'tracking.battery_opt_request_timeout',
            const {'timeoutSeconds': 10},
          );
          return PermissionStatus.denied;
        },
      );
      Logger.instance.info(
        'tracking.battery_opt_request_result',
        {'status': result.name},
      );
    } catch (e, stack) {
      Logger.instance.warn(
        'tracking.battery_opt_request_failed',
        {'error': e.toString()},
        e,
        stack,
      );
    }
  }

  @override
  Future<void> stop() async {
    _service.invoke('stop');
    _lastStatus = BackgroundTrackingStatus.stopped;
    _statusController.add(BackgroundTrackingStatus.stopped);

    // Release wakelock so the device can sleep normally again.
    try {
      await WakelockPlus.disable();
    } catch (e) {
      Logger.instance.warn('tracking.wakelock_disable_failed', {
        'error': e.toString(),
      });
    }
  }

  @override
  Stream<BackgroundTrackingStatus> watchStatus() async* {
    yield _lastStatus;
    yield* _statusController.stream;
  }
}

/// Provider for the concrete background tracking service.
///
/// Cached as a singleton in the Riverpod container so that the
/// instance created during bootstrap (`initialise()` in main.dart)
/// is the same one reached by [TrackingController.startHaul]. A new
/// `FlutterBackgroundService` per call would silently duplicate the
/// status stream and leak listeners.
final backgroundTrackingServiceProvider =
    Provider<BackgroundTrackingService>((ref) {
  return FlutterBackgroundTrackingService();
});

// ============================================================================
// Background isolate entrypoint
// ============================================================================

/// Top-level function invoked by `flutter_background_service` on Android.
///
/// Runs in a separate isolate. Instantiates its own database, GPS, and
/// repository instances (they cannot be shared across isolate boundary).
///
/// _Requirements: 1.1, 1.2, 1.3, 1.9_
@pragma('vm:entry-point')
Future<void> onBackgroundStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  StreamSubscription<Position>? gpsSub;
  AppDatabase? db;

  // Send status update to the foreground isolate.
  void sendStatus(BackgroundTrackingStatus status) {
    service.invoke(_kStatusKey, {'value': status.name});
  }

  sendStatus(BackgroundTrackingStatus.starting);

  // Ensure the service runs as Android foreground service so Doze /
  // background restrictions don't kill us when the screen is off.
  // (Has no effect on iOS.)
  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
  }

  service.on('start').listen((event) async {
    final haulId = event?[_kHaulIdKey] as String?;
    if (haulId == null) return;

    try {
      // Initialise an isolate-local database.
      db = AppDatabase();
      final dao = db!.trackPointDao;

      sendStatus(BackgroundTrackingStatus.running);

      // Subscribe to GPS position stream.
      //
      // Background-friendly settings:
      //   - `distanceFilter: 0` so EVERY fix is emitted (we filter
      //     duplicates ourselves via accuracy gate). Setting >0 makes
      //     Android suppress slow-walking emissions during Doze.
      //   - `intervalDuration: 2s` keeps the GPS receiver active at a
      //     steady cadence even when the screen is off, which is the
      //     core fix for the "straight-line between lock & unlock" bug.
      //   - `forceLocationManager: false` uses Fused Location which is
      //     more battery-efficient AND more accurate at sea than the
      //     raw LocationManager fallback.
      //   - `foregroundNotificationConfig` is intentionally omitted —
      //     flutter_background_service already supplies the foreground
      //     notification; adding another would duplicate it.
      final settings = Platform.isAndroid
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 0,
              intervalDuration: const Duration(seconds: 2),
              forceLocationManager: false,
              useMSLAltitude: true,
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 0,
            );
      gpsSub = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        (position) async {
          // Accuracy gate: drop low-quality fixes from persistence.
          final acc = position.accuracy;
          if (acc.isFinite && acc > 50.0) return;

          final point = TrackPoint(
            haulId: haulId,
            latitude: position.latitude,
            longitude: position.longitude,
            timestamp: position.timestamp,
            speedMps: position.speed.isFinite && position.speed >= 0
                ? position.speed
                : null,
            headingDegrees: position.heading.isFinite && position.heading != 0.0
                ? position.heading
                : null,
            accuracyMeters: position.accuracy.isFinite && position.accuracy > 0
                ? position.accuracy
                : null,
            altitudeMeters:
                position.altitude.isFinite ? position.altitude : null,
          );

          try {
            await dao.insertPoint(TrackPointMapper.toInsertCompanion(point));
          } catch (e) {
            // Log but don't crash the service.
            Logger.instance.warn(
              'background.insert_failed',
              {'error': e.toString()},
            );
          }

          // Update notification text with point count for user feedback.
          if (service is AndroidServiceInstance) {
            final shortHaul = haulId.length > 8
                ? '${haulId.substring(0, 8)}…'
                : haulId;
            service.setForegroundNotificationInfo(
              title: 'Langgeng Sea — Merekam',
              content: 'GPS aktif untuk $shortHaul',
            );
          }
        },
        onError: (error) {
          Logger.instance.warn(
            'background.gps_error',
            {'error': error.toString()},
          );
        },
      );
    } catch (e) {
      sendStatus(BackgroundTrackingStatus.failed);
      Logger.instance.error(
        'background.start_failed',
        {'error': e.toString()},
      );
    }
  });

  service.on('stop').listen((_) async {
    await gpsSub?.cancel();
    gpsSub = null;
    await db?.close();
    db = null;
    sendStatus(BackgroundTrackingStatus.stopped);
    await service.stopSelf();
  });
}

// iOS no-op handler (background location not supported on iOS for this app).
@pragma('vm:entry-point')
Future<bool> _iosOnForeground(ServiceInstance service) async {
  return true;
}
