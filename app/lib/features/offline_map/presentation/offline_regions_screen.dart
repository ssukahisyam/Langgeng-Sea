import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show RetinaMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../history/presentation/widgets/delete_confirm_dialog.dart';
import '../application/offline_download_controller.dart';
import '../data/offline_region_repository.dart';
import '../domain/entities/offline_region.dart';
import 'widgets/region_tile.dart';

/// "Peta Offline" tab screen reached from Settings. Lists every saved
/// region and hosts the entry-point to the picker flow.
class OfflineRegionsScreen extends ConsumerWidget {
  const OfflineRegionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.text;
    final regionsAsync = ref.watch(offlineRegionsProvider);
    final downloadState = ref.watch(offlineDownloadControllerProvider);

    return AmbientBackground(
      showBlobs: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => _pop(context),
            icon: const Icon(PhosphorIconsRegular.arrowLeft),
          ),
          title: Text(
            'Peta Offline',
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(AppRoutes.offlineMapPicker),
          icon: const Icon(PhosphorIconsFill.plusCircle, size: 20),
          label: const Text('Tambah Area'),
        ),
        body: regionsAsync.when(
          loading: () => const _Loading(),
          error: (e, _) => _ErrorState(message: '$e'),
          data: (regions) {
            if (regions.isEmpty) return const _EmptyState();
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.sp5,
                AppSizes.sp3,
                AppSizes.sp5,
                100,
              ),
              itemCount: regions.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSizes.sp3 - 2),
              itemBuilder: (_, i) {
                final region = regions[i];
                final isRunning = downloadState.region?.id == region.id;
                return RegionTile(
                  region: region,
                  progressFraction:
                      isRunning ? downloadState.progress?.fraction : null,
                  onTap: () => _showRegionInfo(context, ref, region),
                  onDelete: () => _onDeletePressed(context, ref, region),
                  onRetry: region.status == OfflineRegionStatus.failed &&
                          !downloadState.isActive
                      ? () => ref
                          .read(offlineDownloadControllerProvider.notifier)
                          .retry(
                            region,
                            retina: RetinaMode.isHighDensity(context),
                            downloadSeamark: true,
                          )
                      : null,
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _pop(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.settings);
    }
  }

  Future<void> _onDeletePressed(
    BuildContext context,
    WidgetRef ref,
    OfflineRegion region,
  ) async {
    // Don't let the user nuke the region currently mid-download.
    if (ref.read(offlineDownloadControllerProvider).region?.id == region.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Batalkan unduhan dulu sebelum menghapus'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final confirmed = await DeleteConfirmDialog.show(
      context,
      title: 'Hapus Area?',
      body: 'Area "${region.name}" akan dihapus dari daftar. '
          'Tile yang sudah diunduh tetap ada di cache sampai Anda '
          'menghapus semua data di Pengaturan.',
    );
    if (!confirmed || !context.mounted) return;
    await ref
        .read(offlineDownloadControllerProvider.notifier)
        .deleteRegion(region);
  }

  void _showRegionInfo(
    BuildContext context,
    WidgetRef ref,
    OfflineRegion region,
  ) {
    // Keep this simple for MVP: info snackbar. Full detail screen is
    // a future polish item.
    final bounds = region.bounds;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${region.name} · zoom ${region.minZoom}-${region.maxZoom} · '
          '${region.actualTileCount} tile · '
          '(${bounds.south.toStringAsFixed(3)}, '
          '${bounds.west.toStringAsFixed(3)}) to '
          '(${bounds.north.toStringAsFixed(3)}, '
          '${bounds.east.toStringAsFixed(3)})',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ===========================================================================
// States
// ===========================================================================

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(context.colors.primary),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIconsFill.warning, size: 48, color: tokens.danger),
            const SizedBox(height: AppSizes.sp3),
            Text('Gagal memuat daftar', style: text.titleMedium),
            const SizedBox(height: AppSizes.sp2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: tokens.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.sp8),
        child: GlassCard(
          level: GlassLevel.level2,
          padding: const EdgeInsets.all(AppSizes.sp6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: tokens.primarySoft,
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                ),
                child: Icon(
                  PhosphorIconsRegular.downloadSimple,
                  size: 32,
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(height: AppSizes.sp4),
              Text('Belum Ada Peta Offline', style: text.titleLarge),
              const SizedBox(height: AppSizes.sp2),
              Text(
                'Unduh area laut favorit Anda saat terhubung wifi '
                'supaya peta tetap tampil di tengah laut tanpa sinyal.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
