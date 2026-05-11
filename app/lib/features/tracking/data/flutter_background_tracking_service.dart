import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/observability/logger.dart';
import '../../../core/services/gps_reading.dart';
import '../../../data/database/app_database.dart';
import 'background_tracking_service.dart';
import 'mappers.dart';
import '../domain/entities/track_point.dart';

/// Notification channel used for the persistent foreground-service
/// notification on Android.
const _kNotificationChannelId = 'langgeng_tracking';
const _kNotificationChannelName = 'Tracking GPS';
const _kForegroundNotificationId = 888;

/// Key used to pass / receive the active haul id across isolate boundary.
const _kHaulIdKey = 'haulId';

/// Key used for status updates from the background isolate.
const _kStatusKey = 'status';

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

  /// Must be called once during app initialisation (before any start/stop).
  Future<void> initialise() async {
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
  }) async {
    _lastStatus = BackgroundTrackingStatus.starting;
    _statusController.add(BackgroundTrackingStatus.starting);

    await _service.startService();

    // Send the haul id to the background isolate so it knows which
    // haul to append points to.
    _service.invoke('start', {_kHaulIdKey: haulId});
  }

  @override
  Future<void> stop() async {
    _service.invoke('stop');
    _lastStatus = BackgroundTrackingStatus.stopped;
    _statusController.add(BackgroundTrackingStatus.stopped);
  }

  @override
  Stream<BackgroundTrackingStatus> watchStatus() async* {
    yield _lastStatus;
    yield* _statusController.stream;
  }
}

/// Provider for the concrete background tracking service.
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

  service.on('start').listen((event) async {
    final haulId = event?[_kHaulIdKey] as String?;
    if (haulId == null) return;

    try {
      // Initialise an isolate-local database.
      db = AppDatabase();
      final dao = db!.trackPointDao;

      sendStatus(BackgroundTrackingStatus.running);

      // Subscribe to GPS position stream.
      gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 2,
        ),
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
            speedMps:
                position.speed.isFinite && position.speed >= 0
                    ? position.speed
                    : null,
            headingDegrees:
                position.heading.isFinite && position.heading != 0.0
                    ? position.heading
                    : null,
            accuracyMeters:
                position.accuracy.isFinite && position.accuracy > 0
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
            service.setForegroundNotificationInfo(
              title: 'Langgeng Sea — Merekam',
              content: 'GPS aktif untuk ${haulId.substring(0, 8)}…',
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
