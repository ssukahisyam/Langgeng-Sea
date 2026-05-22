import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../application/all_history_visible_provider.dart';
import '../../application/map_mode.dart';
import '../../application/map_mode_provider.dart';

/// Three-dot overflow menu for `MapScreen`.
///
/// Hosts secondary controls supaya kolom kanan tidak sesak. Sejak
/// PR #40 entry "Kalibrasi kompas" di-pindah ke sini dari kolom
/// utama (sebelumnya selalu mengambil slot di [MapControls]).
///
/// Isi default:
///   - Kalibrasi kompas → push ke `AppRoutes.compass`
///   - Toggle History_Overlay (mempertahankan label dinamis)
///   - "Tambah penanda di sini" — dijalankan via [onAddMarkerHere]
///   - "Kelola penanda" → push ke `AppRoutes.markerList`
///   - "Paskan semua" — kondisional via [onFitAll], hanya muncul
///     saat mode bukan [MapMode.viewingHistory] (mode itu sudah
///     punya tombol Paskan sendiri di `HistoryOverlayControls`).
///
/// Trigger: pakai [MapActionButton] supaya seragam dengan tombol
/// floating lain (44×44, GlassCard level2). Sebelumnya pakai
/// [PopupMenuButton] default yang lebih besar dan tidak match style.
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
    final showFitAll = onFitAll != null && mode != MapMode.viewingHistory;

    return PopupMenuButton<_MenuAction>(
      tooltip: 'Menu peta',
      position: PopupMenuPosition.under,
      onSelected: (action) => _handle(context, ref, action),
      child: const _OverflowTriggerButton(),
      itemBuilder: (context) => <PopupMenuEntry<_MenuAction>>[
        const PopupMenuItem<_MenuAction>(
          value: _MenuAction.compassCalibration,
          child: _MenuRow(
            icon: PhosphorIconsBold.compass,
            label: 'Kalibrasi kompas',
          ),
        ),
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.toggleHistory,
          child: _MenuRow(
            icon: historyOn
                ? PhosphorIconsRegular.footprints
                : PhosphorIconsBold.footprints,
            label: historyOn ? 'Nonaktifkan riwayat' : 'Aktifkan riwayat',
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
      case _MenuAction.compassCalibration:
        context.push(AppRoutes.compass);
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

/// Trigger visual untuk PopupMenuButton supaya ukurannya seragam
/// dengan tombol floating lain (44×44, GlassCard level2).
///
/// Tidak pakai [MapActionButton] sebagai child PopupMenuButton karena
/// MapActionButton punya InkWell sendiri yang akan menelan tap event
/// — PopupMenuButton ber-rely pada GestureDetector internal yang tap
/// child-nya. Jadi kita re-render visual MapActionButton tanpa
/// InkWell di sini, dan biarkan PopupMenuButton handle tap.
class _OverflowTriggerButton extends StatelessWidget {
  const _OverflowTriggerButton();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return GlassCard(
      level: GlassLevel.level2,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(
          PhosphorIconsRegular.dotsThreeVertical,
          color: tokens.textSecondary,
          size: 22,
        ),
      ),
    );
  }
}

/// Intent identifiers for [MapOverflowMenu] entries. Kept as a private
/// enum so the public API is a typed callback surface, not a string
/// soup.
enum _MenuAction {
  compassCalibration,
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
