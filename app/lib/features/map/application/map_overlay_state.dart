import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which history overlay is currently active on top of the live map.
///
/// The pattern: when the user opens a trip or haul detail and taps the
/// "expand to main map" icon, we navigate back to the map tab and set
/// this state. The map screen listens and renders the matching overlay
/// + an "unpin" chip. The state must survive tab switches (Peta ↔
/// Riwayat ↔ Dashboard) so we intentionally do NOT use autoDispose.
sealed class MapOverlayMode {
  const MapOverlayMode();
}

/// No overlay — the map shows only the live haul (if recording).
class MapOverlayNone extends MapOverlayMode {
  const MapOverlayNone();
}

/// Show every completed haul across every trip.
class MapOverlayAllHistory extends MapOverlayMode {
  const MapOverlayAllHistory();
}

/// Spotlight a single trip (every haul belonging to it).
class MapOverlaySingleTrip extends MapOverlayMode {
  const MapOverlaySingleTrip(this.tripId);
  final String tripId;
}

/// Spotlight a single haul.
class MapOverlaySingleHaul extends MapOverlayMode {
  const MapOverlaySingleHaul(this.haulId);
  final String haulId;
}

/// Notifier that owns the current map overlay mode.
///
/// Stays alive for the lifetime of the app (no autoDispose) so the user
/// can jump from Peta → Riwayat → Peta and the highlighted trip/haul is
/// still pinned. Users clear it manually via the X on the context chip
/// or the footprints toggle.
class MapOverlayController extends Notifier<MapOverlayMode> {
  @override
  MapOverlayMode build() => const MapOverlayNone();

  /// Clear any active overlay and return to the "just the live map" view.
  void clear() {
    state = const MapOverlayNone();
  }

  /// Toggle the "show every completed haul" overlay.
  void toggleAllHistory() {
    state = state is MapOverlayAllHistory
        ? const MapOverlayNone()
        : const MapOverlayAllHistory();
  }

  /// Highlight a single trip on the main map.
  void showTrip(String tripId) {
    state = MapOverlaySingleTrip(tripId);
  }

  /// Highlight a single haul on the main map.
  void showHaul(String haulId) {
    state = MapOverlaySingleHaul(haulId);
  }
}

/// App-scoped provider — NOT autoDispose on purpose (see class doc).
final mapOverlayControllerProvider =
    NotifierProvider<MapOverlayController, MapOverlayMode>(
  MapOverlayController.new,
);
