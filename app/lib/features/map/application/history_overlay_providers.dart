import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/latlng_bounds_util.dart';
import '../../../core/utils/polyline_simplifier.dart';
import '../../tracking/data/haul_repository.dart';
import '../../tracking/data/track_point_repository.dart';

/// A single haul's simplified polyline + metadata, ready to feed into
/// PolylineLayer without any further per-frame work.
///
/// Record shape chosen (Dart 3 records) because these values are
/// passed across an isolate boundary via [compute] and records serialise
/// without extra boilerplate.
typedef HaulTrackRender = ({
  String haulId,
  String tripId,
  int orderIndex,
  int? colorValue,
  List<LatLng> points,

  /// Raw user-given name from the haul row. `null` when the user
  /// never named this haul — UI callers fall back to a date-based
  /// label (see `trackDisplayLabel`).
  String? storedName,

  /// Start timestamp of the haul that produced this polyline. Used
  /// by `TrackPopup` / `trackDisplayLabel` to format the default
  /// label and show "Dimulai ..." metadata.
  DateTime startedAt,
});

/// Bundle surfaced to UI: the simplified polylines + pre-computed
/// bounding box so the map can auto-fit without re-walking the points.
class HistoryOverlayRender {
  const HistoryOverlayRender({
    required this.tracks,
    required this.bounds,
    required this.sourceHaulCount,
  });

  final List<HaulTrackRender> tracks;
  final LatLngBounds? bounds;

  /// How many hauls were fed into the overlay (including those whose
  /// trace had <2 points and got dropped during simplification).
  final int sourceHaulCount;

  bool get isEmpty => tracks.isEmpty;
}

// ---------------------------------------------------------------------------
// Simplify payload (top-level so it can cross an isolate boundary).
// ---------------------------------------------------------------------------

typedef _SimplifyInput = ({
  String haulId,
  String tripId,
  int orderIndex,
  int? colorValue,
  List<LatLng> points,
  String? storedName,
  DateTime startedAt,
  double toleranceMeters,
});

/// Runs inside [compute] — must be a top-level function.
List<HaulTrackRender> _simplifyBatch(List<_SimplifyInput> inputs) {
  final out = <HaulTrackRender>[];
  for (final input in inputs) {
    if (input.points.length < 2) continue;
    final simplified = PolylineSimplifier.simplify(
      input.points,
      toleranceMeters: 1.0, // 1 meter tolerance for high accuracy
    );
    if (simplified.length < 2) continue;
    out.add(
      (
        haulId: input.haulId,
        tripId: input.tripId,
        orderIndex: input.orderIndex,
        colorValue: input.colorValue,
        points: simplified,
        storedName: input.storedName,
        startedAt: input.startedAt,
      ),
    );
  }
  return out;
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// All-history overlay. Loads every completed haul, their points, and
/// simplifies them on a background isolate.
///
/// Auto-disposes when the overlay chip is off and the map screen isn't
/// listening — saves memory for users with hundreds of trips.
final allHistoryRenderProvider =
    FutureProvider.autoDispose<HistoryOverlayRender>((ref) async {
  final haulRepo = ref.watch(haulRepositoryProvider);
  final pointsRepo = ref.watch(trackPointRepositoryProvider);

  final hauls = await haulRepo.listAllCompleted();
  if (hauls.isEmpty) {
    return const HistoryOverlayRender(
      tracks: [],
      bounds: null,
      sourceHaulCount: 0,
    );
  }

  // Fetch points in parallel — O(hauls) queries but each is a cheap
  // time-series lookup and Future.wait keeps latency bounded.
  final pointBatches = await Future.wait(
    hauls.map((h) async {
      final points = await pointsRepo.getByHaul(h.id);
      return (haul: h, points: points);
    }),
  );

  final inputs = <_SimplifyInput>[
    for (final b in pointBatches)
      (
        haulId: b.haul.id,
        tripId: b.haul.tripId,
        orderIndex: b.haul.orderIndex,
        colorValue: b.haul.colorValue,
        points: [for (final p in b.points) p.latLng],
        storedName: b.haul.name,
        startedAt: b.haul.startedAt,
        // 1 m tolerance preserves short-distance detail (e.g. 21 m test
        // tracks that previously got flattened to a straight line).
        toleranceMeters: 1.0,
      ),
  ];

  final tracks = await compute<List<_SimplifyInput>, List<HaulTrackRender>>(
    _simplifyBatch,
    inputs,
  );

  final allPoints = tracks.expand((t) => t.points);
  final bounds = LatLngBoundsUtil.fromPoints(allPoints);

  return HistoryOverlayRender(
    tracks: tracks,
    bounds: bounds,
    sourceHaulCount: hauls.length,
  );
});

/// Render bundle for a single trip. Used when the user taps the
/// "expand to main map" icon on trip_detail_screen.
final tripRenderProvider = FutureProvider.autoDispose
    .family<HistoryOverlayRender, String>((ref, tripId) async {
  final haulRepo = ref.watch(haulRepositoryProvider);
  final pointsRepo = ref.watch(trackPointRepositoryProvider);

  final hauls = await haulRepo.listByTrip(tripId);
  if (hauls.isEmpty) {
    return const HistoryOverlayRender(
      tracks: [],
      bounds: null,
      sourceHaulCount: 0,
    );
  }

  final tracks = <HaulTrackRender>[];
  final allBoundsSource = <LatLng>[];
  for (final h in hauls) {
    final points = await pointsRepo.getByHaul(h.id);
    if (points.length < 2) continue;
    // Keep a very low tolerance (1 m) so even short tracks show their
    // curves faithfully.
    final simplified = PolylineSimplifier.simplify(
      [for (final p in points) p.latLng],
      toleranceMeters: 1.0,
    );
    if (simplified.length < 2) continue;
    allBoundsSource.addAll(simplified);
    tracks.add(
      (
        haulId: h.id,
        tripId: h.tripId,
        orderIndex: h.orderIndex,
        colorValue: h.colorValue,
        points: simplified,
        storedName: h.name,
        startedAt: h.startedAt,
      ),
    );
  }

  return HistoryOverlayRender(
    tracks: tracks,
    bounds: LatLngBoundsUtil.fromPoints(allBoundsSource),
    sourceHaulCount: hauls.length,
  );
});

/// Render bundle for a single haul.
final haulRenderProvider = FutureProvider.autoDispose
    .family<HistoryOverlayRender, String>((ref, haulId) async {
  final haulRepo = ref.watch(haulRepositoryProvider);
  final pointsRepo = ref.watch(trackPointRepositoryProvider);

  final haul = await haulRepo.getById(haulId);
  if (haul == null) {
    return const HistoryOverlayRender(
      tracks: [],
      bounds: null,
      sourceHaulCount: 0,
    );
  }
  final points = await pointsRepo.getByHaul(haulId);
  if (points.length < 2) {
    return const HistoryOverlayRender(
      tracks: [],
      bounds: null,
      sourceHaulCount: 1,
    );
  }
  final simplified = PolylineSimplifier.simplify(
    [for (final p in points) p.latLng],
    toleranceMeters: 0.5,
  );
  if (simplified.length < 2) {
    return const HistoryOverlayRender(
      tracks: [],
      bounds: null,
      sourceHaulCount: 1,
    );
  }
  return HistoryOverlayRender(
    tracks: [
      (
        haulId: haul.id,
        tripId: haul.tripId,
        orderIndex: haul.orderIndex,
        colorValue: haul.colorValue,
        points: simplified,
        storedName: haul.name,
        startedAt: haul.startedAt,
      ),
    ],
    bounds: LatLngBoundsUtil.fromPoints(simplified),
    sourceHaulCount: 1,
  );
});
