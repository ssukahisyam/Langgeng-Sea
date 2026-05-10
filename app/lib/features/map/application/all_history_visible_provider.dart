import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the "Tampilkan semua riwayat" (footprints) overlay is
/// currently turned on.
///
/// Separate from [mapOverlayControllerProvider] on purpose:
///
/// - `MapOverlayMode` is SINGLE-slot state — SingleTrip, SingleHaul,
///   and None are mutually exclusive because each one answers the
///   question "which specific thing is the user drilling into right
///   now?". Pinning a trip while already pinning a haul would be
///   incoherent UX.
///
/// - The footprints toggle asks a SEPARATE question: "should the rest
///   of my history be painted underneath, regardless of what (if
///   anything) is currently pinned?". When the user taps a haul on
///   the history list the app opens a single-haul overlay, but the
///   user may still want the full historical sea of polylines behind
///   it as context.
///
/// Modelling these as two independent providers lets both coexist:
/// the map_screen's build merges polylines from the active overlay
/// AND from the all-history render when this flag is true.
///
/// Explicitly NOT `autoDispose` — the toggle state must persist while
/// the user jumps between Peta ↔ Riwayat ↔ Dashboard so they don't
/// have to re-enable it after every tab switch. Same policy as
/// [mapOverlayControllerProvider] and [markersOverlayEnabledProvider].
final allHistoryVisibleProvider = StateProvider<bool>((ref) => false);
