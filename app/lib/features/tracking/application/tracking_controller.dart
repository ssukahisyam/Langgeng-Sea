import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/gps_reading.dart';
import '../../../core/services/gps_service.dart';
import '../../../core/utils/geo_calculator.dart';
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
class TrackingController extends Notifier<TrackingState> {
  StreamSubscription<GpsReading>? _gpsSub;

  // Running aggregates for the currently-recording haul.
  // Reset on start/stop; rebuilt from DB on crash recovery.
  double _distanceMeters = 0;
  double _sumSin = 0;
  double _sumCos = 0;
  int _headingCount = 0;
  double _sumSpeedMps = 0;
  int _speedCount = 0;
  LatLng? _lastPoint;

  @override
  TrackingState build() {
    ref.onDispose(_cancelSub);
    return const TrackingState.idle();
  }

  TripRepository get _trips => ref.read(tripRepositoryProvider);
  HaulRepository get _hauls => ref.read(haulRepositoryProvider);
  TrackPointRepository get _points => ref.read(trackPointRepositoryProvider);
  GpsService get _gps => ref.read(gpsServiceProvider);

  // =======================================================================
  // Lifecycle
  // =======================================================================

  /// Start a new haul. Creates (or reuses) the active trip.
  ///
  /// [trawlWidthMeters] is captured into the haul row so later profile
  /// edits don't rewrite history. UI typically reads from user profile.
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

    state = TrackingState(
      activeTrip: trip,
      haul: haul,
      metrics: HaulMetrics.empty,
      livePoints: const [],
    );

    _gpsSub = _gps.watchPosition().listen(
      _onReading,
      onError: (_) {
        // Silently drop — the error banner surfaces GPS issues.
      },
    );

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

    await _cancelSub();

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
    );
    _resetAggregates();

    return HaulCompletion(haul: finalized, pointCount: pointCount);
  }

  /// Finalize the parent trip. Any recording haul is stopped first.
  Future<void> endTrip() async {
    if (state.isRecording) {
      await stopHaul();
    }
    final trip = state.activeTrip;
    if (trip == null) return;
    await _trips.endTrip(trip.id);
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
  Future<void> resumeHaul(Haul haul) async {
    if (state.isRecording) return;

    final trip = await _trips.getById(haul.tripId);
    final existing = await _points.getByHaul(haul.id);

    _resetAggregates();
    final latLngs = existing.map((p) => p.latLng).toList();
    _distanceMeters = GeoCalculator.totalDistanceMeters(latLngs);
    _lastPoint = latLngs.isNotEmpty ? latLngs.last : null;
    _replayHeadingSpeed(existing.map((p) => (
          p.headingDegrees,
          p.speedMps,
        )));

    state = TrackingState(
      activeTrip: trip,
      haul: haul,
      metrics: _currentMetrics(DateTime.now().difference(haul.startedAt)),
      livePoints: latLngs,
    );

    _gpsSub = _gps.watchPosition().listen(_onReading, onError: (_) {});
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
    // the raw trace is preserved for later review).
    //
    // Gate relaxed from 25m → 50m in this revision. Reason: `high`
    // accuracy mode (Fused Location Provider) reports ~30-40m indoors
    // and near shore, which was getting ALL fixes dropped under the
    // old 25m gate — polyline stayed empty when user walked around
    // the village. 50m is still tight enough that real fixes di laut
    // lepas (3-8m) selalu lolos, sementara indoor/pinggir-darat fixes
    // (30-40m) juga masuk — akurasi berkurang ~1-2% di track total,
    // acceptable trade-off.
    final acc = reading.accuracyMeters;
    final accept = acc == null || acc <= 50.0;

    await _points.appendReading(haulId: haul.id, reading: reading);

    final newPoint = reading.latLng;

    if (accept) {
      if (_lastPoint != null) {
        _distanceMeters +=
            GeoCalculator.haversineMeters(_lastPoint!, newPoint);
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

  Future<void> _cancelSub() async {
    await _gpsSub?.cancel();
    _gpsSub = null;
  }
}

final trackingControllerProvider =
    NotifierProvider<TrackingController, TrackingState>(
  TrackingController.new,
);
