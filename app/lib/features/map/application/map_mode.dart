/// Contextual state of `Map_Screen` that governs which adaptive UI
/// controls are visible at any moment.
///
/// Map_Mode has exactly four values and is derived deterministically
/// from three independent input booleans:
///
/// - `tracking` — whether `Tracking_Controller` currently has an
///   active Trip/Haul recording session.
/// - `navigating` — whether `Navigation_Service` currently has an
///   active `GotoTarget` or `FollowTrackTarget`.
/// - `historyOverlayActive` — whether the `History_Overlay` toggle is
///   turned on (the "footprints" button).
///
/// See [deriveMapMode] for the pure derivation rule.
///
/// Kept intentionally free of Flutter imports so it can be unit- and
/// property-tested under `flutter test` without any widget bindings
/// (Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.12).
enum MapMode {
  /// Default viewing state: no active tracking, no active navigation,
  /// no history overlay. `Map_Screen` shows the "Mulai tracking" FAB,
  /// the history toggle, and the standard map controls.
  idle,

  /// A Trip/Haul is currently being recorded via `Tracking_Controller`
  /// and no navigation is active. `Map_Screen` swaps the FAB for the
  /// tracking bottom sheet with live stats + "Berhenti tracking".
  tracking,

  /// `Navigation_Service` is active (either `GotoTarget` or
  /// `FollowTrackTarget`). Takes priority over every other mode — when
  /// tracking and navigating happen concurrently, `Map_Screen` renders
  /// the concurrent layout described in Requirement 4.12a.
  navigating,

  /// User opened the "Tampilkan semua riwayat" overlay while no
  /// tracking or navigation is active. `Map_Screen` shows the history
  /// overlay controls (filter, "Paskan semua").
  viewingHistory,
}

/// Pure derivation of [MapMode] from the three independent input
/// booleans.
///
/// The priority order is fixed and deterministic:
///
/// ```text
///   navigating > tracking > viewingHistory > idle
/// ```
///
/// Rationale:
///
/// - Navigation is the most actionable, safety-sensitive context (the
///   user is actively heading somewhere), so its UI must not be
///   overridden by anything else.
/// - A live tracking session is more important than a passive history
///   view because losing visibility of "Berhenti tracking" risks
///   leaving the recorder running by accident.
/// - History overlay only wins when nothing else is going on.
///
/// This function is intentionally a top-level pure function (no side
/// effects, no Flutter/Riverpod dependencies) so it can be exhaustively
/// property-tested over all 2³ = 8 boolean combinations
/// (see Requirement 4 "mutual exclusion + priority" invariant).
MapMode deriveMapMode({
  required bool tracking,
  required bool navigating,
  required bool historyOverlayActive,
}) {
  if (navigating) return MapMode.navigating;
  if (tracking) return MapMode.tracking;
  if (historyOverlayActive) return MapMode.viewingHistory;
  return MapMode.idle;
}
