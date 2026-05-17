/// Contextual state of `Map_Screen` that governs which adaptive UI
/// controls are visible at any moment.
///
/// Map_Mode has exactly five values and is derived deterministically
/// from four independent input booleans:
///
/// - `tracking` — whether `Tracking_Controller` currently has an
///   active Trip/Haul recording session.
/// - `navigating` — whether `Navigation_Service` currently has an
///   active `GotoTarget` or `FollowTrackTarget`.
/// - `markerPickActive` — whether user has entered the marker pick
///   mode via long-press of the Add Marker FAB or from the Markers
///   list (PR #32).
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

  /// User entered marker-picking mode (PR #32) via long-press of the
  /// Add Marker FAB or the Markers list "+" button. The map shows a
  /// crosshair fixed at the viewport center and a bottom sheet with
  /// live coordinates plus [Tandai di Sini] / [Batal] buttons. User
  /// pans the map to center the crosshair on the desired location,
  /// then taps confirm to open `AddMarkerDialog` with that coord.
  ///
  /// Lower priority than `tracking` and `navigating`: if either becomes
  /// active concurrently (race), pick mode auto-cancels and the higher
  /// priority UI takes over. Entry points (long-press FAB, list "+")
  /// guard against this anyway, but the derive priority is the safety
  /// net.
  pickMarkerLocation,
}

/// Pure derivation of [MapMode] from the four independent input
/// booleans.
///
/// The priority order is fixed and deterministic:
///
/// ```text
///   navigating > tracking > pickMarkerLocation > viewingHistory > idle
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
/// - Marker pick mode is an explicit user action mid-flow, but lower
///   than tracking/navigation. If user somehow enters pick mode while
///   tracking starts (race), tracking wins and pick auto-cancels.
/// - History overlay only wins when nothing else is going on.
///
/// This function is intentionally a top-level pure function (no side
/// effects, no Flutter/Riverpod dependencies) so it can be exhaustively
/// property-tested over all 2⁴ = 16 boolean combinations
/// (see Requirement 4 "mutual exclusion + priority" invariant).
MapMode deriveMapMode({
  required bool tracking,
  required bool navigating,
  required bool historyOverlayActive,
  bool markerPickActive = false,
}) {
  if (navigating) return MapMode.navigating;
  if (tracking) return MapMode.tracking;
  if (markerPickActive) return MapMode.pickMarkerLocation;
  if (historyOverlayActive) return MapMode.viewingHistory;
  return MapMode.idle;
}
