import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../export_import/data/imported_dataset_repository.dart';
import '../../../offline_map/data/offline_region_repository.dart';
import '../../application/all_history_visible_provider.dart';
import '../../application/markers_overlay_provider.dart';
import 'map_action_button.dart';
import 'offline_regions_layer.dart' show offlineRegionsOverlayProvider;

/// Tombol expandable yang membungkus toggle layer + action map.
///
/// PR #41 — sebelumnya kolom kanan punya dua popup terpisah:
/// `MapLayersExpandable` (4 toggle layer) dan `MapOverflowMenu`
/// (titik tiga dengan 4 action). User komplain redundant + ada
/// duplikat (toggle "Riwayat" muncul di dua tempat). Sekarang
/// digabung jadi satu popup dengan dua section:
///
/// - **Layer Peta** (toggle) — Penanda, Riwayat tarikan,
///   Area peta offline, Filter data impor.
/// - **Aksi** (action) — Tambah penanda di sini, Kelola penanda,
///   Kalibrasi kompas.
///
/// Behavior:
/// - Collapsed: satu [MapActionButton] 44×44 dengan ikon `stack`.
///   Kalau ada toggle aktif, tombol menampilkan dot indicator.
/// - Expanded: panel vertikal dengan animasi 200ms slide-down +
///   fade. Tap trigger lagi = collapse.
/// - Toggle entry: tap tidak menutup expandable (multi-select).
/// - Action entry: tap auto-collapse setelah action dijalankan
///   (push route / open sheet / tambah marker).
class MapLayersExpandable extends ConsumerStatefulWidget {
  const MapLayersExpandable({
    super.key,
    required this.onOpenDatasetFilter,
    required this.onAddMarkerHere,
  });

  /// Callback saat user tap entry "Filter data impor". Caller buka
  /// modal sheet untuk pilih dataset mana yang visible. Tetap
  /// di-handle di [MapScreen] supaya logic resolusi `BuildContext`
  /// + `_showModalBottomSheet` tetap kohesif dengan widget lain.
  final VoidCallback onOpenDatasetFilter;

  /// Callback saat user tap entry "Tambah penanda di sini". Caller
  /// resolve current GPS reading (atau map center) dan buka dialog
  /// add marker. Sebelumnya entry ini ada di MapOverflowMenu.
  final VoidCallback onAddMarkerHere;

  @override
  ConsumerState<MapLayersExpandable> createState() =>
      _MapLayersExpandableState();
}

class _MapLayersExpandableState extends ConsumerState<MapLayersExpandable>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
  }

  /// Action entries collapse panel setelah dijalankan supaya user
  /// langsung kembali ke peta. Toggle entries TIDAK panggil ini —
  /// user mungkin mau hidup-matikan beberapa overlay sekaligus.
  void _runActionAndCollapse(VoidCallback action) {
    action();
    if (_expanded) setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final markersOn = ref.watch(markersOverlayEnabledProvider);
    final allHistoryOn = ref.watch(allHistoryVisibleProvider);
    final overlayOn = ref.watch(offlineRegionsOverlayProvider);
    final regions = ref.watch(offlineRegionsProvider).asData?.value ?? const [];
    final hasOfflineRegions = regions.any((r) => r.isReady);
    final datasets = ref.watch(importedDatasetsProvider).asData?.value;
    final hasDatasets = datasets != null && datasets.isNotEmpty;
    final visibleCount =
        hasDatasets ? datasets.where((d) => d.visible).length : 0;
    final totalCount = hasDatasets ? datasets.length : 0;

    final anyActive = markersOn ||
        allHistoryOn ||
        (hasOfflineRegions && overlayOn) ||
        (hasDatasets && visibleCount < totalCount);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Expanded panel — di-render di atas trigger (sebelum
        // trigger di Column normal-direction). Saat parent pakai
        // verticalDirection: up, panel ini akan muncul di bawah
        // trigger di layar.
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.bottomCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SizeTransition(
                sizeFactor: anim,
                axisAlignment: 1.0,
                child: child,
              ),
            ),
            child: !_expanded
                ? const SizedBox.shrink(key: ValueKey('collapsed'))
                : Padding(
                    key: const ValueKey('expanded'),
                    padding: const EdgeInsets.only(bottom: AppSizes.sp2),
                    child: _LayersPanel(
                      markersOn: markersOn,
                      onMarkersTap: () {
                        ref.read(markersOverlayEnabledProvider.notifier).state =
                            !markersOn;
                      },
                      allHistoryOn: allHistoryOn,
                      onAllHistoryTap: () {
                        ref.read(allHistoryVisibleProvider.notifier).state =
                            !allHistoryOn;
                      },
                      hasOfflineRegions: hasOfflineRegions,
                      offlineRegionsOn: overlayOn,
                      onOfflineRegionsTap: () {
                        ref.read(offlineRegionsOverlayProvider.notifier).state =
                            !overlayOn;
                      },
                      hasDatasets: hasDatasets,
                      datasetVisibleCount: visibleCount,
                      datasetTotalCount: totalCount,
                      onDatasetFilterTap: () => _runActionAndCollapse(
                        widget.onOpenDatasetFilter,
                      ),
                      onAddMarkerHere: () => _runActionAndCollapse(
                        widget.onAddMarkerHere,
                      ),
                      onManageMarkers: () => _runActionAndCollapse(
                        () => context.push(AppRoutes.markerList),
                      ),
                      onCalibrateCompass: () => _runActionAndCollapse(
                        () => context.push(AppRoutes.compass),
                      ),
                    ),
                  ),
          ),
        ),
        MapActionButton(
          icon: PhosphorIconsBold.stack,
          tooltip: _expanded ? 'Tutup layer' : 'Layer & overlay',
          onTap: _toggleExpanded,
          active: anyActive || _expanded,
        ),
      ],
    );
  }
}

class _LayersPanel extends StatelessWidget {
  const _LayersPanel({
    required this.markersOn,
    required this.onMarkersTap,
    required this.allHistoryOn,
    required this.onAllHistoryTap,
    required this.hasOfflineRegions,
    required this.offlineRegionsOn,
    required this.onOfflineRegionsTap,
    required this.hasDatasets,
    required this.datasetVisibleCount,
    required this.datasetTotalCount,
    required this.onDatasetFilterTap,
    required this.onAddMarkerHere,
    required this.onManageMarkers,
    required this.onCalibrateCompass,
  });

  final bool markersOn;
  final VoidCallback onMarkersTap;
  final bool allHistoryOn;
  final VoidCallback onAllHistoryTap;
  final bool hasOfflineRegions;
  final bool offlineRegionsOn;
  final VoidCallback onOfflineRegionsTap;
  final bool hasDatasets;
  final int datasetVisibleCount;
  final int datasetTotalCount;
  final VoidCallback onDatasetFilterTap;
  final VoidCallback onAddMarkerHere;
  final VoidCallback onManageMarkers;
  final VoidCallback onCalibrateCompass;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return GlassCard(
      level: GlassLevel.level2,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sp3,
        vertical: AppSizes.sp2,
      ),
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(label: 'Layer Peta'),
          const SizedBox(height: AppSizes.sp2),
          _LayerEntry(
            icon:
                markersOn ? PhosphorIconsFill.mapPin : PhosphorIconsBold.mapPin,
            label: 'Penanda',
            on: markersOn,
            onTap: onMarkersTap,
          ),
          _LayerEntry(
            icon: allHistoryOn
                ? PhosphorIconsFill.footprints
                : PhosphorIconsBold.footprints,
            label: 'Riwayat tarikan',
            on: allHistoryOn,
            onTap: onAllHistoryTap,
          ),
          if (hasOfflineRegions)
            _LayerEntry(
              icon: offlineRegionsOn
                  ? PhosphorIconsFill.downloadSimple
                  : PhosphorIconsBold.downloadSimple,
              label: 'Area peta offline',
              on: offlineRegionsOn,
              onTap: onOfflineRegionsTap,
            ),
          if (hasDatasets)
            _LayerEntry(
              icon: PhosphorIconsBold.folderOpen,
              label: 'Filter data impor',
              trailingText: '$datasetVisibleCount/$datasetTotalCount',
              on: datasetVisibleCount > 0,
              onTap: onDatasetFilterTap,
              showTrailingArrow: true,
            ),
          // Divider antara group toggle dan group action.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.sp1),
            child: Divider(height: 1, color: tokens.border),
          ),
          const _SectionHeading(label: 'Aksi'),
          const SizedBox(height: AppSizes.sp2),
          _LayerEntry(
            icon: PhosphorIconsBold.mapPinPlus,
            label: 'Tambah penanda di sini',
            on: false,
            onTap: onAddMarkerHere,
            isAction: true,
          ),
          _LayerEntry(
            icon: PhosphorIconsBold.mapPin,
            label: 'Kelola penanda',
            on: false,
            onTap: onManageMarkers,
            isAction: true,
          ),
          _LayerEntry(
            icon: PhosphorIconsBold.compass,
            label: 'Kalibrasi kompas',
            on: false,
            onTap: onCalibrateCompass,
            isAction: true,
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    return Text(
      label,
      style: text.labelSmall?.copyWith(
        color: tokens.textTertiary,
        fontWeight: FontWeight.w700,
        fontSize: 10,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _LayerEntry extends StatelessWidget {
  const _LayerEntry({
    required this.icon,
    required this.label,
    required this.on,
    required this.onTap,
    this.trailingText,
    this.showTrailingArrow = false,
    this.isAction = false,
  });

  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;
  final String? trailingText;
  final bool showTrailingArrow;

  /// PR #41: tandai entry sebagai action (bukan toggle). Saat true,
  /// state [on] diabaikan untuk styling — entry selalu di-render
  /// dengan warna textSecondary, plus caretRight trailing arrow
  /// supaya user paham ini akan trigger sesuatu (push route / buka
  /// sheet / dialog).
  final bool isAction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    final colors = context.colors;
    final iconColor = isAction
        ? tokens.textSecondary
        : (on ? colors.primary : tokens.textSecondary);
    final labelColor = isAction
        ? tokens.textSecondary
        : (on ? colors.primary : tokens.textSecondary);
    final labelWeight =
        isAction ? FontWeight.w500 : (on ? FontWeight.w700 : FontWeight.w500);
    final showCaret = showTrailingArrow || isAction;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.sp2,
            vertical: AppSizes.sp2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: AppSizes.sp2),
              Text(
                label,
                style: text.labelMedium?.copyWith(
                  color: labelColor,
                  fontWeight: labelWeight,
                ),
              ),
              if (trailingText != null) ...[
                const SizedBox(width: AppSizes.sp3),
                Text(
                  trailingText!,
                  style: text.labelSmall?.copyWith(
                    color: tokens.textTertiary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
              if (showCaret) ...[
                const SizedBox(width: AppSizes.sp1),
                Icon(
                  PhosphorIconsRegular.caretRight,
                  size: 12,
                  color: tokens.textTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
