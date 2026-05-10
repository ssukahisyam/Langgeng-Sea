import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the user-placed markers layer is currently visible on the
/// live map.
///
/// Explicitly NOT `autoDispose` — the toggle state should persist while
/// the user switches between the Map, Riwayat, and Dashboard tabs so
/// they don't have to re-enable it after every navigation. Same policy
/// as [mapOverlayControllerProvider] for the history overlay.
final markersOverlayEnabledProvider = StateProvider<bool>((ref) => false);
