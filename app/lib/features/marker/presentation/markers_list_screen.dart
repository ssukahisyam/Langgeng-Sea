import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../data/marker_repository.dart';
import '../domain/entities/marker.dart';
import 'widgets/add_marker_dialog.dart';

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
                        onTap: () =>
                            setState(() => _selectedCategory = null),
                      ),
                      const SizedBox(width: AppSizes.sp2),
                      _FilterChip(
                        label: 'Produktif',
                        selected:
                            _selectedCategory == MarkerCategory.productive,
                        onTap: () => setState(
                            () => _selectedCategory = MarkerCategory.productive),
                      ),
                      const SizedBox(width: AppSizes.sp2),
                      _FilterChip(
                        label: 'Karang',
                        selected: _selectedCategory == MarkerCategory.hazard,
                        onTap: () => setState(
                            () => _selectedCategory = MarkerCategory.hazard),
                      ),
                      const SizedBox(width: AppSizes.sp2),
                      _FilterChip(
                        label: 'Pelabuhan',
                        selected: _selectedCategory == MarkerCategory.port,
                        onTap: () => setState(
                            () => _selectedCategory = MarkerCategory.port),
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
                      itemBuilder: (context, i) =>
                          _MarkerTile(marker: filtered[i]),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMarkerDialog(context),
        child: const Icon(PhosphorIconsBold.mapPinPlus),
      ),
    );
  }

  Future<void> _showAddMarkerDialog(BuildContext context) async {
    final marker = await showDialog<AppMarker>(
      context: context,
      builder: (_) => const AddMarkerDialog(
        latitude: 0,
        longitude: 0,
      ),
    );
    if (marker != null) {
      await ref.read(markerRepositoryProvider).create(
            name: marker.name,
            category: marker.category,
            latitude: marker.latitude,
            longitude: marker.longitude,
            notes: marker.notes,
          );
    }
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

class _MarkerTile extends StatelessWidget {
  const _MarkerTile({required this.marker});

  final AppMarker marker;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return GlassCard(
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
                Text(
                  marker.name,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
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
        ],
      ),
    );
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
