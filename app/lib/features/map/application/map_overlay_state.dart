import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which history overlay is currently "pinned" on top of the live map.
///
/// The pattern: when the user opens a trip or haul detail and taps the
/// "expand to main map" icon, we navigate back to the map tab and set
/// this state. The map screen listens and renders the matching overlay
/// + an "unpin" chip. The state must survive tab switches (Peta ↔
/// Riwayat ↔ Dashboard) so we intentionally do NOT use autoDispose.
///
/// This is SINGLE-SLOT state: SingleTrip, SingleHaul and None are
/// mutually exclusive because each one answers "what specific thing
/// is the user drilling into?". The separate
/// [allHistoryVisibleProvider] flag is what controls the "show every
/// completed haul behind everything else" toggle — the two are
/// independent so a user can pin a trip AND still see all-history
/// footprints behind it.
sealed class MapOverlayMode {
  const MapOverlayMode();
}

/// No overlay pinned — the map shows only the live haul (if recording)
/// plus optionally the all-history footprints layer.
class MapOverlayNone extends MapOverlayMode {
  const MapOverlayNone();
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
/// Stays alive for the lifetime of the app (no autoDispose) so the
/// user can jump from Peta → Riwayat → Peta and the highlighted
/// trip/haul is still pinned. Users clear it manually via the X on
/// the context chip.
class MapOverlayController extends Notifier<MapOverlayMode> {
  @override
  MapOverlayMode build() => const MapOverlayNone();

  /// Clear any active overlay and return to the "just the live map" view.
  void clear() {
    state = const MapOverlayNone();
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
