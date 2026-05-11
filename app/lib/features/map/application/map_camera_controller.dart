import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Encapsulates the `flutter_map` [MapController] and the two latches
/// that together implement the "single initial fit, then free pan/zoom"
/// behaviour of the `History_Overlay` (Requirement 2).
///
/// This replaces the ad-hoc `_fittedOverlayKey` + `_followingUser`
/// booleans that previously lived inside `_MapScreenState`. Keeping the
/// camera logic behind an explicit API lets us property-test the
/// latch behaviour in isolation (no widget tree required) and prevents
/// the "snap-back while zooming" bug reported in the field.
///
/// ## Latch model
///
/// For each activation cycle (one "History_Overlay ON" session):
///
/// - `_initialFitDone` is `false` until [maybeInitialFit] succeeds.
///   Flips to `true` the first time we actually call `fitCamera` on
///   non-degenerate bounds, OR when we recenter on a degenerate bounds
///   (single point / all-identical points) — both count as "the initial
///   fit has happened" per AC 2.8.
/// - `_userLatched` is `false` until the user touches the map.
///   `onUserGesture()` flips it to `true` permanently for that cycle,
///   which short-circuits every subsequent [maybeInitialFit] call so
///   the overlay never yanks the user's view back when fresh data
///   emits.
/// - Both latches reset on [activate] (new cycle) and [deactivate]
///   (cycle ended).
///
/// ## Explicit fit
///
/// [fitCameraExplicit] is the escape hatch for the "Paskan semua"
/// button (AC 2.5). It always fits the camera, but deliberately does
/// NOT change `_userLatched` — tapping "Paskan semua" once should not
/// cause a later data emission to auto-fit again.
///
/// ## Degenerate bounds (AC 2.8)
///
/// `LatLngBounds` can, in theory, describe a single point (north ==
/// south AND east == west) when a Track contains one point or all
/// identical points. `MapController.fitCamera` on such bounds would
/// either jump to infinite zoom or throw inside `flutter_map`. We
/// detect that degenerate case via [_isDegenerate] and fall back to
/// [MapController.move] centered on the single point at a minimum
/// zoom of 15. The initial-fit latch is still flipped so later data
/// updates don't retrigger the fallback every frame.
///
/// ## Contract
///
/// Callers MUST pass a non-null [LatLngBounds] into [maybeInitialFit]
/// and [fitCameraExplicit]. Handling of empty overlay data (no Marker
/// and no Track -> null bounds) is the caller's responsibility, per
/// AC 2.7 ("do not fit, preserve current viewport").
class MapCameraController {
  MapCameraController(this._mapController);

  final MapController _mapController;

  /// Identifies the current activation cycle. Null when the overlay
  /// is inactive; non-null opaque token when active. We only compare
  /// for null/non-null inside this class — the token itself is owned
  /// by the caller and can be any stable object for a single cycle.
  Object? _activeOverlayKey;
  bool _initialFitDone = false;
  bool _userLatched = false;

  /// Padding applied to [CameraFit.bounds] when fitting the camera.
  /// Matches the previous `_fitOverlayBounds` / `_fitAllHistoryBounds`
  /// helpers in `map_screen.dart` (both used `EdgeInsets.all(64)`) so
  /// the visual behaviour before and after this refactor is identical.
  static const _defaultPadding = EdgeInsets.all(64);

  /// Minimum zoom used when recentering on degenerate bounds (AC 2.8).
  /// Chosen high enough that a single-point Track is still visible as
  /// a recognisable area, not a global view.
  static const _degenerateFallbackZoom = 15.0;

  /// Whether an activation cycle is currently in progress. Useful for
  /// widget tests and the future `HistoryOverlayControls` "Paskan
  /// semua" button (which should be enabled only while active).
  bool get isActive => _activeOverlayKey != null;

  /// Whether the user has touched the map at least once since the
  /// current cycle started. After this flips to true, auto-fit is
  /// permanently suppressed for the rest of the cycle (AC 2.3).
  bool get userHasPanned => _userLatched;

  /// Begin a new activation cycle keyed by [overlayKey]. Resets both
  /// latches so the next [maybeInitialFit] call performs the single
  /// auto-fit for this cycle.
  ///
  /// Idempotent with respect to re-activation: if called while already
  /// active (e.g. rapid toggle off→on within a single frame before
  /// any data emission, AC 2.6), the latest call wins and the latches
  /// are re-reset so the fit will run against the next data emission.
  void activate(Object overlayKey) {
    _activeOverlayKey = overlayKey;
    _initialFitDone = false;
    _userLatched = false;
  }

  /// End the current activation cycle. Clears the active key and
  /// resets both latches so a future [activate] starts a fresh cycle
  /// where the initial fit will run again (AC 2.6 round-trip).
  void deactivate() {
    _activeOverlayKey = null;
    _initialFitDone = false;
    _userLatched = false;
  }

  /// Perform the one-shot initial fit for the current cycle.
  ///
  /// No-ops when:
  /// - the controller is not active (no cycle in progress),
  /// - the initial fit has already been done for this cycle, OR
  /// - the user has already interacted with the map (latched).
  ///
  /// When [bounds] is degenerate (a single point / all identical
  /// points) we call [MapController.move] instead of
  /// [MapController.fitCamera] to avoid the invalid-bounds hazard
  /// (AC 2.8). The latch is still set so subsequent data emissions
  /// don't repeat the fallback.
  void maybeInitialFit(LatLngBounds bounds) {
    if (_activeOverlayKey == null) return;
    if (_initialFitDone) return;
    if (_userLatched) return;

    if (_isDegenerate(bounds)) {
      _moveToDegenerateCenter(bounds);
    } else {
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: _defaultPadding),
      );
    }
    _initialFitDone = true;
  }

  /// Explicit "Paskan semua" handler. Always fits to [bounds]
  /// regardless of latch state (AC 2.5), and deliberately does NOT
  /// flip `_userLatched` — tapping the button once must not cause
  /// later data emissions to auto-fit again.
  ///
  /// Degenerate bounds are handled the same way as in
  /// [maybeInitialFit] (fall back to a zoomed-in recenter) to keep
  /// the two fit paths visually consistent.
  void fitCameraExplicit(LatLngBounds bounds) {
    if (_isDegenerate(bounds)) {
      _moveToDegenerateCenter(bounds);
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: _defaultPadding),
    );
  }

  /// Must be called from
  /// `MapOptions.onPositionChanged(position, hasGesture)` whenever
  /// `hasGesture == true`. Once invoked, this cycle's auto-fit is
  /// suppressed for the rest of the cycle (AC 2.3).
  void onUserGesture() {
    _userLatched = true;
  }

  /// Detect "degenerate" bounds where the north-east and south-west
  /// corners coincide (or sit within floating-point slop). A handful
  /// of sources produce such bounds legitimately:
  ///
  /// - A Track with a single Track_Point.
  /// - A Track whose points are all identical (boat sitting still).
  ///
  /// `flutter_map` treats these cases inconsistently across versions:
  /// some throw, some clamp to `maxZoom`, some land on the hardcoded
  /// world bounds. Detecting up front and falling back to
  /// [MapController.move] keeps behaviour predictable.
  ///
  /// The epsilon is ~1e-9 degrees ≈ 0.11 mm on the equator, well
  /// below any real GPS accuracy so this won't false-positive on
  /// genuine bounds.
  bool _isDegenerate(LatLngBounds b) {
    const epsilon = 1e-9;
    return (b.north - b.south).abs() < epsilon &&
        (b.east - b.west).abs() < epsilon;
  }

  /// Recenter the camera on a degenerate bounds' corner at a zoom
  /// that's at least [_degenerateFallbackZoom]. Preserves the user's
  /// current zoom if they were already zoomed in further.
  void _moveToDegenerateCenter(LatLngBounds bounds) {
    final center = LatLng(
      (bounds.north + bounds.south) / 2,
      (bounds.east + bounds.west) / 2,
    );
    final currentZoom = _mapController.camera.zoom;
    final targetZoom = math.max(currentZoom, _degenerateFallbackZoom);
    _mapController.move(center, targetZoom);
  }
}
