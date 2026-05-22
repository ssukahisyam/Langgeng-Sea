import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../export_import/data/imported_dataset_repository.dart';
import '../../../offline_map/data/offline_region_repository.dart';
import '../../application/all_history_visible_provider.dart';
import '../../application/markers_overlay_provider.dart';
import 'map_action_button.dart';
import 'offline_regions_layer.dart' show offlineRegionsOverlayProvider;

/// Tombol expandable yang membungkus semua toggle layer/overlay map.
///
/// PR #40 — sebelumnya 4 toggle terpisah memenuhi kolom kanan
/// (markers, all history, offline regions, dataset filter). Itu
/// bikin kolom kanan terlalu padat dan ukuran tidak konsisten dengan
/// tombol lain. Sekarang semua toggle dijahit ke satu tombol
/// `stack` yang expand vertikal saat ditap.
///
/// Behavior:
/// - Collapsed: satu [MapActionButton] 44×44 dengan ikon [stack].
///   Kalau ada toggle aktif, tombol menampilkan dot indicator
///   ([MapActionButton.active]).
/// - Expanded: list vertikal entries dengan animasi 200ms slide-down
///   + fade. Tap di luar (Barrier) atau tap trigger lagi = collapse.
/// - Self-hide entries: dataset filter & offline regions otomatis
///   sembunyi kalau provider data-nya kosong (sama seperti behavior
///   lama). Markers + AllHistory selalu tampil.
///
/// Tap pada entry tidak otomatis menutup expandable — supaya user
/// bisa toggle beberapa overlay sekaligus tanpa expand-close-expand.
/// User explicitly tap trigger atau area lain untuk collapse.
class MapLayersExpandable extends ConsumerStatefulWidget {
  const MapLayersExpandable({
    super.key,
    required this.onOpenDatasetFilter,
  });

  /// Callback saat user tap entry "Filter dataset". Caller buka
  /// modal sheet untuk pilih dataset mana yang visible. Tetap
  /// di-handle di [MapScreen] supaya logic resolusi `BuildContext`
  /// + `_showModalBottomSheet` tetap kohesif dengan widget lain.
  final VoidCallback onOpenDatasetFilter;

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
                      onDatasetFilterTap: widget.onOpenDatasetFilter,
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;

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
          Text(
            'Layer Peta',
            style: text.labelSmall?.copyWith(
              color: tokens.textTertiary,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 0.6,
            ),
          ),
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
        ],
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
  });

  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;
  final String? trailingText;
  final bool showTrailingArrow;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    final colors = context.colors;
    final iconColor = on ? colors.primary : tokens.textSecondary;
    final labelColor = on ? colors.primary : tokens.textSecondary;

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
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
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
              if (showTrailingArrow) ...[
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
