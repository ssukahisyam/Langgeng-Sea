import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/observability/logger.dart';
import '../../../core/services/gps_reading.dart';
import '../../../core/services/gps_service.dart';
import '../../../core/utils/geo_calculator.dart';
import '../data/background_tracking_service.dart';
import '../data/flutter_background_tracking_service.dart';
import '../data/haul_repository.dart';
import '../data/track_point_repository.dart';
import '../data/trip_repository.dart';
import '../domain/entities/haul.dart';
import '../domain/entities/haul_metrics.dart';
import 'tracking_state.dart';

/// Orchestrates the Mulai Tebar → Angkat Trawl lifecycle.
///
/// Subscribes to [GpsService.watchPosition] while a haul is recording.
/// Every reading is persisted via [TrackPointRepository], and live metrics
/// (distance, duration, current/avg speed & heading, swept area) are
/// recomputed incrementally.
///
/// The incremental math is the point: we do **not** re-sum the entire
/// polyline on every tick — only add the latest leg. That keeps per-tick
/// cost flat even for 12-hour trips (~4k points at 10s interval).
///
/// **PR #40 — pencabutan mode tracking:** controller ini dulunya
/// punya percabangan Normal vs Akurasi (skip vs request battery
/// exemption). Audit pasca rilis menemukan keduanya hampir identik
/// secara operasional dan Mode Normal justru lebih boros baterai
/// karena throttling Doze tanpa exemption. Sekarang start path selalu
/// pakai jalur penuh (foreground service + battery exemption); resume
/// path tetap `skipBatteryPermission: true` supaya dialog OS tidak
/// muncul ulang setelah crash recovery.
class TrackingController extends Notifier<TrackingState> {
  StreamSubscription<GpsReading>? _gpsSub;
  StreamSubscription<BackgroundTrackingStatus>? _bgStatusSub;

  // Running aggregates for the currently-recording haul.
  // Reset on start/stop; rebuilt from DB on crash recovery.
  double _distanceMeters = 0;
  double _sumSin = 0;
  double _sumCos = 0;
  int _headingCount = 0;
  double _sumSpeedMps = 0;
  int _speedCount = 0;
  LatLng? _lastPoint;

  // Exponential retry state (Requirement 1.7).
  int _retryCount = 0;
  static const _maxRetries = 3;
  Timer? _retryTimer;

  @override
  TrackingState build() {
    ref.onDispose(_cancelAll);
    return const TrackingState.idle();
  }

  TripRepository get _trips => ref.read(tripRepositoryProvider);
  HaulRepository get _hauls => ref.read(haulRepositoryProvider);
  TrackPointRepository get _points => ref.read(trackPointRepositoryProvider);
  GpsService get _gps => ref.read(gpsServiceProvider);
  BackgroundTrackingService get _bgService =>
      ref.read(backgroundTrackingServiceProvider);

  // =======================================================================
  // Lifecycle
  // =======================================================================

  /// Start a new haul. Creates (or reuses) the active trip.
  ///
  /// [trawlWidthMeters] is captured into the haul row so later profile
  /// edits don't rewrite history. UI typically reads from user profile.
  ///
  /// Now also starts the [BackgroundTrackingService] so GPS persists
  /// even when the app is backgrounded (Requirement 1.1).
  Future<Haul> startHaul({required double trawlWidthMeters}) async {
    if (state.isRecording) {
      // Already recording — idempotent return.
      return state.haul!;
    }

    final trip = await _trips.getOrStartActiveTrip();
    final haul = await _hauls.startHaul(
      tripId: trip.id,
      trawlWidthMeters: trawlWidthMeters,
    );

    _resetAggregates();
    _retryCount = 0;

    state = TrackingState(
      activeTrip: trip,
      haul: haul,
      metrics: HaulMetrics.empty,
      livePoints: const [],
      backgroundStatus: BackgroundTrackingStatus.starting,
    );

    // Start the foreground GPS stream for live metrics.
    _gpsSub = _gps.watchPosition().listen(
      _onReading,
      onError: (_) {
        // Silently drop — the error banner surfaces GPS issues.
      },
    );

    // PR #40: pencabutan mode tracking. Sebelumnya cabang ini pilih
    // skipBatteryPermission berdasarkan TrackingMode (Normal = true,
    // Akurasi = false). Sekarang selalu false — request exemption
    // baterai supaya tracking jalan stabil saat layar mati.
    Logger.instance.info(
      'tracking.start',
      {'haulId': haul.id},
    );

    try {
      await _bgService.start(
        haulId: haul.id,
        notificationTitle: 'Langgeng Sea — Merekam',
        notificationBody: '${haul.displayName()} sedang direkam',
        skipBatteryPermission: false,
      );
      _subscribeBgStatus();
    } on NotificationPermissionDeniedException catch (e) {
      // POST_NOTIFICATIONS ditolak. Tanpa permission ini, foreground
      // service akan crash dengan CannotPostForegroundServiceNotificationException.
      // Degrade ke foreground-only GPS — user melihat banner
      // "tracking degraded" via backgroundDegraded di TrackingState.
      Logger.instance.warn(
        'tracking.bg_start_blocked_notification_denied',
        {'reason': e.toString()},
      );
      _markBackgroundFailed();
    } on NotificationChannelDisabledException catch (e) {
      // PR #31: channel-level disabled meskipun app-level granted.
      Logger.instance.warn(
        'tracking.bg_start_blocked_channel_disabled',
        {'reason': e.toString()},
      );
      _markBackgroundFailed();
    } on BackgroundServiceStartException catch (e) {
      // Plugin / OEM lempar PlatformException saat startService().
      Logger.instance.warn(
        'tracking.bg_start_failed',
        {'error': e.toString()},
      );
      _markBackgroundFailed();
    } catch (e) {
      // Background service failed to start — continue with foreground
      // GPS only (AC 1a graceful degradation).
      Logger.instance.warn(
        'tracking.bg_start_failed',
        {'error': e.toString()},
      );
      _markBackgroundFailed();
    }

    return haul;
  }

  /// Stop the current haul, finalize its metrics, and persist them.
  ///
  /// Returns a [HaulCompletion] (or null if nothing was recording) so the
  /// UI can pop a summary sheet. Does **not** end the trip — the user may
  /// chain more hauls before tapping "Akhiri Trip".
  Future<HaulCompletion?> stopHaul() async {
    final haul = state.haul;
    if (haul == null) return null;

    await _cancelAll();

    // Stop background service.
    try {
      await _bgService.stop();
    } catch (e) {
      Logger.instance.warn(
        'tracking.bg_stop_failed',
        {'error': e.toString()},
      );
    }

    final endedAt = DateTime.now();
    final durationSeconds =
        endedAt.difference(haul.startedAt).inSeconds.clamp(0, 1 << 30);

    final finalized = haul.copyWith(
      status: HaulStatus.completed,
      endedAt: endedAt,
      distanceMeters: _distanceMeters,
      durationSeconds: durationSeconds,
      avgSpeedKnots: _averageSpeedKnots(),
      avgHeadingDegrees: _circularMeanFromSums(),
      sweptAreaM2: GeoCalculator.sweptAreaM2(
        distanceMeters: _distanceMeters,
        trawlWidthMeters: haul.trawlWidthMeters,
      ),
    );

    await _hauls.finalizeHaul(finalized);
    final pointCount = await _points.countForHaul(haul.id);

    state = state.copyWith(
      clearHaul: true,
      metrics: HaulMetrics.empty,
      livePoints: const [],
      backgroundStatus: BackgroundTrackingStatus.stopped,
    );
    _resetAggregates();

    return HaulCompletion(haul: finalized, pointCount: pointCount);
  }

  /// Finalize the parent trip. Any recording haul is stopped first.
  ///
  /// Normally we resolve the trip from `state.activeTrip`. But this is
  /// called from the summary sheet's "Akhiri Trip" path, which runs
  /// AFTER `stopHaul()` has already reset state to idle — plus there
  /// are real observed races where `activeTrip` reads null before the
  /// handler runs (Flutter frame boundary between pop-sheet and
  /// endTrip-call). In those cases the trip stayed `active` in the DB
  /// even though the user clearly asked to end it.
  ///
  /// [forceTripId] lets the caller pass the trip id directly (from the
  /// completed haul) so the finalize goes through no matter the state.
  Future<void> endTrip({String? forceTripId}) async {
    if (state.isRecording) {
      await stopHaul();
    }
    final tripId = forceTripId ?? state.activeTrip?.id;
    if (tripId == null) return;
    await _trips.endTrip(tripId);
    state = const TrackingState.idle();
  }

  // =======================================================================
  // Crash recovery
  // =======================================================================

  /// Called once at app start. If a haul was left in 'recording' status
  /// (app killed mid-tracking) return it so the UI can prompt the user.
  Future<Haul?> detectRecoverableHaul() => _hauls.getRecording();

  /// Resume writing points to an already-recording haul. Rebuilds
  /// aggregates from existing DB points so metrics stay correct.
  ///
  /// Returns `null` jika resume berhasil (haul masih recording), atau
  /// [HaulCompletion] jika parent trip sudah dihapus dari DB sehingga
  /// haul-nya orphan dan tidak bisa di-resume secara meaningful — dalam
  /// kasus itu kita finalize haul tersebut dengan data yang ada
  /// (PR #27 R2: "Trip lookup di resumeHaul HARUS tahan kalau trip
  /// parent sudah dihapus").
  Future<HaulCompletion?> resumeHaul(Haul haul) async {
    if (state.isRecording) return null;

    final trip = await _trips.getById(haul.tripId);

    // Edge case (PR #27 R2): parent trip sudah hilang dari DB.
    // Sebelumnya kode lanjut ke `state.activeTrip = trip` (null) dan
    // beberapa caller di-`!`-bang downstream → crash. Sekarang kita
    // finalize orphan haul-nya supaya tidak ada baris stale dengan
    // status `recording` yang akan trigger crash recovery dialog di
    // setiap restart aplikasi.
    if (trip == null) {
      Logger.instance.warn(
        'tracking.resume_orphan_haul_finalizing',
        {'haulId': haul.id, 'tripId': haul.tripId},
      );
      return finalizeRecoveredHaul(haul);
    }

    final existing = await _points.getByHaul(haul.id);

    _resetAggregates();
    final latLngs = existing.map((p) => p.latLng).toList();
    _distanceMeters = GeoCalculator.totalDistanceMeters(latLngs);
    _lastPoint = latLngs.isNotEmpty ? latLngs.last : null;
    _replayHeadingSpeed(
      existing.map(
        (p) => (
          p.headingDegrees,
          p.speedMps,
        ),
      ),
    );

    _retryCount = 0;

    state = TrackingState(
      activeTrip: trip,
      haul: haul,
      metrics: _currentMetrics(DateTime.now().difference(haul.startedAt)),
      livePoints: latLngs,
      backgroundStatus: BackgroundTrackingStatus.starting,
    );

    _gpsSub = _gps.watchPosition().listen(_onReading, onError: (_) {});

    // PR #40: resume path selalu start foreground service.
    // skipBatteryPermission=true di sini supaya dialog OS tidak muncul
    // ulang setelah crash recovery — user sudah pernah merespons di
    // sesi sebelumnya. Mencegah race dengan Android 14+ foreground
    // service rule.
    try {
      await _bgService.start(
        haulId: haul.id,
        notificationTitle: 'Langgeng Sea — Merekam',
        notificationBody: '${haul.displayName()} — dilanjutkan',
        skipBatteryPermission: true,
      );
      _subscribeBgStatus();
    } catch (e) {
      Logger.instance.warn(
        'tracking.bg_resume_failed',
        {'error': e.toString()},
      );
      state = state.copyWith(
        backgroundStatus: BackgroundTrackingStatus.failed,
      );
    }

    return null;
  }

  /// Abandon an orphan recording haul (user picked "Akhiri sekarang" in
  /// the recovery dialog). Finalizes metrics from whatever points exist.
  Future<HaulCompletion?> finalizeRecoveredHaul(Haul haul) async {
    final points = await _points.getByHaul(haul.id);
    _resetAggregates();
    _distanceMeters =
        GeoCalculator.totalDistanceMeters(points.map((p) => p.latLng).toList());
    _replayHeadingSpeed(points.map((p) => (p.headingDegrees, p.speedMps)));

    final endedAt = points.isNotEmpty
        ? points.last.timestamp
        : haul.startedAt.add(const Duration(seconds: 1));

    final finalized = haul.copyWith(
      status: HaulStatus.completed,
      endedAt: endedAt,
      distanceMeters: _distanceMeters,
      durationSeconds: endedAt.difference(haul.startedAt).inSeconds,
      avgSpeedKnots: _averageSpeedKnots(),
      avgHeadingDegrees: _circularMeanFromSums(),
      sweptAreaM2: GeoCalculator.sweptAreaM2(
        distanceMeters: _distanceMeters,
        trawlWidthMeters: haul.trawlWidthMeters,
      ),
    );

    await _hauls.finalizeHaul(finalized);
    _resetAggregates();

    return HaulCompletion(haul: finalized, pointCount: points.length);
  }

  // =======================================================================
  // GPS stream handler
  // =======================================================================

  Future<void> _onReading(GpsReading reading) async {
    final haul = state.haul;
    if (haul == null) return;

    // Drop low-quality fixes from metric aggregation (still persisted so
    // the raw trace is preserved for later review). The 50m threshold
    // matches real-world performance on a Redmi Note 10 Pro: on land
    // a calibrated GNSS typically reports 5-15m, at sea 10-30m, and
    // only truly degraded fixes (indoor startup, canopy occlusion)
    // come back >50m. A tighter gate (25m) discarded perfectly usable
    // offshore fixes and made the live metrics freeze.
    final acc = reading.accuracyMeters;
    final accept = acc == null || acc <= 50.0;

    await _points.appendReading(haulId: haul.id, reading: reading);

    final newPoint = reading.latLng;

    if (accept) {
      if (_lastPoint != null) {
        _distanceMeters += GeoCalculator.haversineMeters(_lastPoint!, newPoint);
      }
      _lastPoint = newPoint;

      final h = reading.headingDegrees;
      final v = reading.speedMps;
      if (h != null && (v ?? 0) > 0.5) {
        final r = h * math.pi / 180.0;
        _sumSin += math.sin(r);
        _sumCos += math.cos(r);
        _headingCount++;
      }
      if (v != null && v >= 0 && v < 30) {
        _sumSpeedMps += v;
        _speedCount++;
      }
    }

    final duration = DateTime.now().difference(haul.startedAt);

    state = state.copyWith(
      livePoints: [...state.livePoints, newPoint],
      metrics: _currentMetrics(duration, latest: reading),
    );
  }

  // =======================================================================
  // Helpers
  // =======================================================================

  HaulMetrics _currentMetrics(Duration duration, {GpsReading? latest}) {
    return HaulMetrics(
      distanceMeters: _distanceMeters,
      duration: duration,
      avgSpeedKnots: _averageSpeedKnots(),
      currentSpeedKnots: latest?.speedMps != null
          ? GeoCalculator.mpsToKnots(latest!.speedMps!)
          : state.metrics.currentSpeedKnots,
      avgHeadingDegrees: _circularMeanFromSums(),
      currentHeadingDegrees:
          latest?.headingDegrees ?? state.metrics.currentHeadingDegrees,
      sweptAreaM2: GeoCalculator.sweptAreaM2(
        distanceMeters: _distanceMeters,
        trawlWidthMeters: state.haul?.trawlWidthMeters ?? 20.0,
      ),
      pointCount: state.livePoints.length + 1,
    );
  }

  double? _averageSpeedKnots() {
    if (_speedCount == 0) return null;
    return GeoCalculator.mpsToKnots(_sumSpeedMps / _speedCount);
  }

  double? _circularMeanFromSums() {
    if (_headingCount == 0) return null;
    final avg = math.atan2(
      _sumSin / _headingCount,
      _sumCos / _headingCount,
    );
    return (avg * 180.0 / math.pi + 360.0) % 360.0;
  }

  void _resetAggregates() {
    _distanceMeters = 0;
    _sumSin = 0;
    _sumCos = 0;
    _headingCount = 0;
    _sumSpeedMps = 0;
    _speedCount = 0;
    _lastPoint = null;
  }

  void _replayHeadingSpeed(Iterable<(double?, double?)> pairs) {
    for (final pair in pairs) {
      final h = pair.$1;
      final v = pair.$2;
      if (h != null && (v ?? 0) > 0.5) {
        final r = h * math.pi / 180.0;
        _sumSin += math.sin(r);
        _sumCos += math.cos(r);
        _headingCount++;
      }
      if (v != null && v >= 0 && v < 30) {
        _sumSpeedMps += v;
        _speedCount++;
      }
    }
  }

  Future<void> _cancelAll() async {
    await _gpsSub?.cancel();
    _gpsSub = null;
    await _bgStatusSub?.cancel();
    _bgStatusSub = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// PR #40: tandai background gagal start tanpa downgrade mode.
  /// Sebelumnya `_autoFallbackToNormal` menulis Mode Normal ke DB
  /// supaya start berikutnya tidak coba foreground service. Sekarang
  /// tidak ada konsep mode lagi — kalau gagal sekali, foreground GPS
  /// tetap jalan (banner "tracking degraded" muncul lewat
  /// backgroundDegraded di TrackingState) dan retry exponential di
  /// [_attemptRetry] tetap akan mencoba.
  void _markBackgroundFailed() {
    state = state.copyWith(
      backgroundStatus: BackgroundTrackingStatus.failed,
    );
  }

  // =======================================================================
  // Background service monitoring (Requirement 1.7)
  // =======================================================================

  /// Subscribe to background service status updates for retry logic.
  void _subscribeBgStatus() {
    _bgStatusSub?.cancel();
    _bgStatusSub = _bgService.watchStatus().listen((status) {
      if (!state.isRecording) return;

      state = state.copyWith(backgroundStatus: status);

      if (status == BackgroundTrackingStatus.stopped && state.isRecording) {
        // Service was killed by OS — attempt exponential retry.
        _attemptRetry();
      } else if (status == BackgroundTrackingStatus.running) {
        // Service recovered — reset retry counter.
        _retryCount = 0;
      }
    });
  }

  /// Exponential backoff retry: 1s, 2s, 4s — then give up (Requirement 1.7).
  void _attemptRetry() {
    if (_retryCount >= _maxRetries) {
      state = state.copyWith(
        backgroundStatus: BackgroundTrackingStatus.failed,
      );
      Logger.instance.warn(
        'tracking.bg_retry_exhausted',
        {'retries': _retryCount},
      );
      return;
    }

    state = state.copyWith(
      backgroundStatus: BackgroundTrackingStatus.restarting,
    );

    final delay = Duration(seconds: math.pow(2, _retryCount).toInt());
    _retryCount++;

    Logger.instance.info(
      'tracking.bg_retry',
      {'attempt': _retryCount, 'delaySeconds': delay.inSeconds},
    );

    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () async {
      final haul = state.haul;
      if (haul == null || !state.isRecording) return;

      try {
        await _bgService.start(
          haulId: haul.id,
          notificationTitle: 'Langgeng Sea — Merekam',
          notificationBody: '${haul.displayName()} — restart',
        );
      } catch (e) {
        Logger.instance.warn(
          'tracking.bg_retry_failed',
          {'attempt': _retryCount, 'error': e.toString()},
        );
        // Will be picked up by the next watchStatus emission.
      }
    });
  }
}

final trackingControllerProvider =
    NotifierProvider<TrackingController, TrackingState>(
  TrackingController.new,
);
