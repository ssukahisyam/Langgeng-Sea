import 'package:latlong2/latlong.dart';

import '../domain/entities/haul.dart';
import '../domain/entities/haul_metrics.dart';
import '../domain/entities/trip.dart';

/// Snapshot of the tracking subsystem exposed to the UI.
///
/// When idle the UI shows "Mulai Tebar". When recording the UI switches to
/// live stats + "Angkat Trawl". Keep this a single value so the Map screen
/// can switch its layout with one `ref.watch`.
class TrackingState {
  const TrackingState({
    required this.activeTrip,
    required this.haul,
    required this.metrics,
    required this.livePoints,
  });

  const TrackingState.idle()
      : activeTrip = null,
        haul = null,
        metrics = HaulMetrics.empty,
        livePoints = const [];

  /// Non-null while user has started a trip. A trip may exist without an
  /// active haul (between tebar/angkat cycles).
  final Trip? activeTrip;

  /// Non-null while a haul is currently recording.
  final Haul? haul;

  /// Live metrics for the recording haul; [HaulMetrics.empty] otherwise.
  final HaulMetrics metrics;

  /// Points of the recording haul, in order. Used to draw the live
  /// polyline without re-querying the DB on every rebuild.
  final List<LatLng> livePoints;

  bool get isRecording => haul != null;
  bool get hasTrip => activeTrip != null;

  TrackingState copyWith({
    Trip? activeTrip,
    Haul? haul,
    HaulMetrics? metrics,
    List<LatLng>? livePoints,
    bool clearHaul = false,
    bool clearTrip = false,
  }) {
    return TrackingState(
      activeTrip: clearTrip ? null : (activeTrip ?? this.activeTrip),
      haul: clearHaul ? null : (haul ?? this.haul),
      metrics: metrics ?? this.metrics,
      livePoints: livePoints ?? this.livePoints,
    );
  }
}

/// Result returned to the UI when a haul finishes. Lets the Map screen
/// pop a summary bottom sheet without re-querying.
class HaulCompletion {
  const HaulCompletion({required this.haul, required this.pointCount});
  final Haul haul;
  final int pointCount;
}
