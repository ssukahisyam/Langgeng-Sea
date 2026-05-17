import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../export_import/data/imported_dataset_repository.dart';
import '../../map/application/map_mode_provider.dart';
import '../data/marker_repository.dart';
import '../domain/entities/marker.dart';
import 'widgets/edit_marker_category_sheet.dart';

/// Layar daftar marker kustom dengan filter kategori.
class MarkersListScreen extends ConsumerStatefulWidget {
  const MarkersListScreen({super.key});

  @override
  ConsumerState<MarkersListScreen> createState() => _MarkersListScreenState();
}

class _MarkersListScreenState extends ConsumerState<MarkersListScreen> {
  MarkerCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final markersAsync = ref.watch(allMarkersProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Penanda Saya'),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // --- Category filter chips ---
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.sp4,
                  vertical: AppSizes.sp3,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Semua',
                        selected: _selectedCategory == null,
                        onTap: () => setState(() => _selectedCategory = null),
                      ),
                      const SizedBox(width: AppSizes.sp2),
                      _FilterChip(
                        label: 'Produktif',
                        selected:
                            _selectedCategory == MarkerCategory.productive,
                        onTap: () => setState(
                          () => _selectedCategory = MarkerCategory.productive,
                        ),
                      ),
                      const SizedBox(width: AppSizes.sp2),
                      _FilterChip(
                        label: 'Karang',
                        selected: _selectedCategory == MarkerCategory.hazard,
                        onTap: () => setState(
                          () => _selectedCategory = MarkerCategory.hazard,
                        ),
                      ),
                      const SizedBox(width: AppSizes.sp2),
                      _FilterChip(
                        label: 'Pelabuhan',
                        selected: _selectedCategory == MarkerCategory.port,
                        onTap: () => setState(
                          () => _selectedCategory = MarkerCategory.port,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- Marker list ---
              Expanded(
                child: markersAsync.when(
                  data: (markers) {
                    final filtered =
                        filterMarkersByCategory(markers, _selectedCategory);
                    if (filtered.isEmpty) {
                      return _EmptyState(hasFilter: _selectedCategory != null);
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(AppSizes.sp4),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSizes.sp3),
                      itemBuilder: (context, i) => _MarkerTile(
                        marker: filtered[i],
                        onTap: () => _jumpToMarker(context, filtered[i]),
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startPickFlow(context),
        icon: const Icon(PhosphorIconsBold.mapPinPlus),
        label: const Text('Tambah'),
      ),
    );
  }

  /// PR #32: pindah ke MapScreen dan masuk
  /// `MapMode.pickMarkerLocation`. Penggantian dari flow lama yang
  /// pakai `AddMarkerDialog(latitude: 0, longitude: 0)` placeholder
  /// — itu bug yang membuat marker masuk ke koordinat (0, 0) di
  /// laut Atlantik kalau user submit dialog tanpa edit lat/lon.
  /// Sekarang user wajib pilih koordinat di peta sebelum dialog
  /// muncul.
  void _startPickFlow(BuildContext context) {
    // Set mode dulu, baru navigate. Order ini supaya ketika MapScreen
    // build pertama kali, provider sudah aktif → switch case di
    // _buildModeControls langsung render PickLocationOverlay tanpa
    // kedip ke idle controls.
    ref.read(markerPickActiveProvider.notifier).state = true;
    GoRouter.of(context).go(AppRoutes.map);
  }

  /// Jump to map and focus on this marker without starting navigation automatically.
  void _jumpToMarker(BuildContext context, AppMarker marker) {
    GoRouter.of(context).go('${AppRoutes.map}?focusMarkerId=${marker.id}');
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sp4,
          vertical: AppSizes.sp2,
        ),
        decoration: BoxDecoration(
          color: selected ? context.colors.secondary : tokens.surface2,
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          border: Border.all(
            color: selected ? context.colors.secondary : tokens.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : context.colors.onSurface,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _MarkerTile extends ConsumerWidget {
  const _MarkerTile({required this.marker, this.onTap});

  final AppMarker marker;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _categoryColor(marker.category).withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Icon(
              _categoryIcon(marker.category),
              color: _categoryColor(marker.category),
              size: 20,
            ),
          ),
          const SizedBox(width: AppSizes.sp4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        marker.name,
                        style: Theme.of(context).textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (marker.isImported) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.accentSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Impor',
                          style: TextStyle(
                            fontSize: 9,
                            color: context.colors.secondary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${marker.latitude.toStringAsFixed(5)}, ${marker.longitude.toStringAsFixed(5)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.sp2,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: _categoryColor(marker.category).withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Text(
              marker.category.displayLabel,
              style: TextStyle(
                fontSize: 11,
                color: _categoryColor(marker.category),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Three-dot menu for marker actions (Task 13.5)
          PopupMenuButton<_MarkerAction>(
            tooltip: 'Opsi penanda',
            icon: Icon(
              PhosphorIconsRegular.dotsThreeVertical,
              size: 18,
              color: tokens.textTertiary,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            position: PopupMenuPosition.under,
            onSelected: (action) => _handleAction(context, ref, action),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _MarkerAction.editCategory,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIconsRegular.tag, size: 18),
                    SizedBox(width: 12),
                    Text('Ubah kategori'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: _MarkerAction.delete,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIconsRegular.trash, size: 18),
                    SizedBox(width: 12),
                    Text('Hapus'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _MarkerAction action,
  ) async {
    switch (action) {
      case _MarkerAction.editCategory:
        // PR #33: marker imported tidak boleh di-rename / di-edit kategori.
        if (marker.isImported) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Penanda dari data impor tidak bisa diedit. Hapus dataset utuh dari Kelola Data Impor.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
          break;
        }
        final newCategory = await EditMarkerCategorySheet.show(
          context,
          currentCategory: marker.category,
          markerName: marker.name,
        );
        if (newCategory != null && newCategory != marker.category) {
          await ref
              .read(markerRepositoryProvider)
              .updateCategory(marker.id, newCategory);
        }
      case _MarkerAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hapus Penanda?'),
            content: Text('Penanda "${marker.name}" akan dihapus.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Hapus'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          // PR #33: simpan datasetId sebelum delete untuk auto-cleanup.
          final datasetId = marker.datasetId;
          await ref.read(markerRepositoryProvider).delete(marker.id);
          if (datasetId != null) {
            await ref
                .read(importedDatasetRepositoryProvider)
                .autoCleanupIfEmpty(datasetId);
          }
        }
    }
  }

  Color _categoryColor(MarkerCategory cat) => switch (cat) {
        MarkerCategory.productive => Colors.green,
        MarkerCategory.hazard => Colors.red,
        MarkerCategory.port => Colors.blue,
        MarkerCategory.other => Colors.grey,
      };

  IconData _categoryIcon(MarkerCategory cat) => switch (cat) {
        MarkerCategory.productive => PhosphorIconsBold.fishSimple,
        MarkerCategory.hazard => PhosphorIconsBold.warning,
        MarkerCategory.port => PhosphorIconsBold.anchor,
        MarkerCategory.other => PhosphorIconsBold.mapPin,
      };
}

enum _MarkerAction { editCategory, delete }

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter});

  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIconsBold.mapPinLine,
            size: 64,
            color: tokens.textSecondary.withOpacity(0.4),
          ),
          const SizedBox(height: AppSizes.sp4),
          Text(
            hasFilter
                ? 'Tidak ada penanda untuk kategori ini'
                : 'Belum ada penanda',
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 15,
            ),
          ),
          if (!hasFilter) ...[
            const SizedBox(height: AppSizes.sp2),
            Text(
              'Tekan + untuk menambahkan penanda baru',
              style: TextStyle(
                color: tokens.textSecondary.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
