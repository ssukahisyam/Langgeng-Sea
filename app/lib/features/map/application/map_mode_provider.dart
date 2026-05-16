import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/application/navigation_controller.dart';
import '../../navigation/application/navigation_state.dart';
import '../../tracking/application/tracking_controller.dart';
import 'all_history_visible_provider.dart';
import 'map_mode.dart';

/// Derives the contextual [MapMode] for `Map_Screen` by joining three
/// independent sources of truth:
///
/// - [trackingControllerProvider] — exposes a [TrackingState] whose
///   [TrackingState.isRecording] is true iff a Haul is currently being
///   recorded by `Tracking_Controller`.
/// - [navigationControllerProvider] — exposes a sealed
///   [NavigationState]; an active session is represented by the
///   [NavigationActive] subclass (idle is [NavigationIdle]).
/// - [allHistoryVisibleProvider] — the `StateProvider<bool>` backing
///   the "Tampilkan semua riwayat" (footprints) toggle.
///
/// The actual mode is computed by the pure [deriveMapMode] helper, so
/// the priority rule (`navigating > tracking > viewingHistory > idle`)
/// lives in one place and is fully property-testable independently
/// from Riverpod.
///
/// NOT `autoDispose` on purpose: the three watched sources are all
/// long-lived app-scoped providers (a Haul can survive tab switches,
/// the history toggle is persistent, navigation is likewise
/// long-lived), so we keep `mapModeProvider` alive for the same
/// lifetime. That lets any widget — not just `Map_Screen` — cheaply
/// read the current map mode without re-deriving the join every
/// frame.
///
/// Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.12.
final mapModeProvider = Provider<MapMode>((ref) {
  final tracking = ref.watch(trackingControllerProvider).isRecording;
  final navigating =
      ref.watch(navigationControllerProvider) is NavigationActive;
  // NOTE: `allHistoryVisibleProvider` is intentionally NOT used to derive
  // the mode any more. The "Tampilkan Jejak" footprints toggle on the
  // right column is a passive layer toggle — it must NOT replace the
  // action panel at the bottom (otherwise the Mulai/Berhenti tracking
  // button disappears, breaking the user's primary workflow). Reading
  // it here is preserved only to keep the provider warm; a future
  // pinned-overlay flow may re-introduce a `viewingHistory` mode.
  ref.watch(allHistoryVisibleProvider);
  return deriveMapMode(
    tracking: tracking,
    navigating: navigating,
    historyOverlayActive: false,
  );
});
