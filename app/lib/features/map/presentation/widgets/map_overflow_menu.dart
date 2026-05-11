import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/router/app_router.dart';
import '../../application/all_history_visible_provider.dart';
import '../../application/map_mode.dart';
import '../../application/map_mode_provider.dart';

/// Three-dot overflow menu for `Map_Screen`.
///
/// Hosts controls that the adaptive UI hides from the primary toolbar
/// depending on the current [MapMode] — without itself changing the
/// mode. Pulled out of `Map_Screen` as a standalone widget so its
/// visibility rules (see Requirement 4.10) stay testable in isolation.
///
/// Minimum contents mandated by Requirement 4.10:
///   (a) Toggle History_Overlay when it is active but its toolbar
///       control is hidden (Tracking / Navigating modes).
///   (b) "Tambah penanda di sini" — quick marker creation at the
///       current map center. The caller owns the "current center"
///       resolution and passes a ready-to-fire [onAddMarkerHere].
///   (c) Quick access to [MarkersListScreen] via the shared router.
///
/// An additional "Paskan semua" item surfaces whenever [onFitAll] is
/// provided and [MapMode] is not [MapMode.viewingHistory] — the
/// viewing-history mode already exposes that button in its dedicated
/// controls widget, so duplicating it there would clutter the menu.
///
/// The menu intentionally does NOT consume tracking / navigation
/// controllers; toggling `allHistoryVisibleProvider` stays a pure
/// data mutation, the mode priority rule (`mapModeProvider`) re-reads
/// it on the next frame. That keeps the menu side-effect-free with
/// respect to [MapMode].
class MapOverflowMenu extends ConsumerWidget {
  const MapOverflowMenu({
    super.key,
    this.onAddMarkerHere,
    this.onFitAll,
  });

  /// Fired when the user taps "Tambah penanda di sini".
  ///
  /// The caller is responsible for resolving the target location
  /// (typically `MapController.camera.center`) and opening whatever
  /// marker-creation flow is appropriate. If null, the entry is
  /// rendered disabled so the surface stays discoverable.
  final VoidCallback? onAddMarkerHere;

  /// Fired when the user taps "Paskan semua". Only surfaces when the
  /// current mode is not [MapMode.viewingHistory] (history mode has
  /// its own dedicated "Paskan semua" button in `HistoryOverlayControls`).
  /// If null, the entry is omitted.
  final VoidCallback? onFitAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(mapModeProvider);
    final historyOn = ref.watch(allHistoryVisibleProvider);
    final showFitAll =
        onFitAll != null && mode != MapMode.viewingHistory;

    return PopupMenuButton<_MenuAction>(
      tooltip: 'Menu peta',
      icon: const Icon(PhosphorIconsRegular.dotsThreeVertical),
      position: PopupMenuPosition.under,
      onSelected: (action) => _handle(context, ref, action),
      itemBuilder: (context) => <PopupMenuEntry<_MenuAction>>[
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.toggleHistory,
          child: _MenuRow(
            icon: historyOn
                ? PhosphorIconsRegular.footprints
                : PhosphorIconsBold.footprints,
            label: historyOn
                ? 'Nonaktifkan riwayat'
                : 'Aktifkan riwayat',
          ),
        ),
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.addMarkerHere,
          enabled: onAddMarkerHere != null,
          child: const _MenuRow(
            icon: PhosphorIconsBold.mapPinPlus,
            label: 'Tambah penanda di sini',
          ),
        ),
        const PopupMenuItem<_MenuAction>(
          value: _MenuAction.manageMarkers,
          child: _MenuRow(
            icon: PhosphorIconsBold.mapPin,
            label: 'Kelola penanda',
          ),
        ),
        if (showFitAll)
          const PopupMenuItem<_MenuAction>(
            value: _MenuAction.fitAll,
            child: _MenuRow(
              icon: PhosphorIconsBold.frameCorners,
              label: 'Paskan semua',
            ),
          ),
      ],
    );
  }

  void _handle(BuildContext context, WidgetRef ref, _MenuAction action) {
    switch (action) {
      case _MenuAction.toggleHistory:
        final notifier = ref.read(allHistoryVisibleProvider.notifier);
        notifier.state = !notifier.state;
      case _MenuAction.addMarkerHere:
        onAddMarkerHere?.call();
      case _MenuAction.manageMarkers:
        context.push(AppRoutes.markerList);
      case _MenuAction.fitAll:
        onFitAll?.call();
    }
  }
}

/// Intent identifiers for [MapOverflowMenu] entries. Kept as a private
/// enum so the public API is a typed callback surface, not a string
/// soup.
enum _MenuAction {
  toggleHistory,
  addMarkerHere,
  manageMarkers,
  fitAll,
}

/// Shared layout for menu rows — small icon, label, consistent spacing.
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}
