import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../data/imported_dataset_repository.dart';
import '../domain/entities/imported_dataset.dart';

/// Layar Kelola Data Impor (PR #33).
///
/// Menampilkan list semua dataset yang user impor — satu card per file
/// dengan checkbox visibility + tombol hapus. Pakai pattern reactive
/// stream via `importedDatasetsProvider` supaya update toggle dari
/// MapScreen overlay langsung tercermin di sini juga.
class ImportedDatasetsScreen extends ConsumerWidget {
  const ImportedDatasetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final text = context.text;
    final asyncDatasets = ref.watch(importedDatasetsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Kelola Data Impor'),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: asyncDatasets.when(
            data: (datasets) {
              if (datasets.isEmpty) {
                return _EmptyState();
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.sp4,
                  AppSizes.sp3,
                  AppSizes.sp4,
                  AppSizes.sp4,
                ),
                itemCount: datasets.length + 1,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSizes.sp3),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppSizes.sp1,
                        left: AppSizes.sp1,
                      ),
                      child: Text(
                        '${datasets.length} dataset diimpor. '
                        'Toggle untuk sembunyikan, hapus untuk hilangkan permanen.',
                        style: text.bodySmall?.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                    );
                  }
                  final ds = datasets[i - 1];
                  return _DatasetCard(dataset: ds);
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.sp4),
                child: Text(
                  'Gagal memuat daftar dataset: $e',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: tokens.danger),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: tokens.accentSoft,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                PhosphorIconsRegular.folderOpen,
                size: 36,
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.sp4),
            Text(
              'Belum ada data impor',
              style: text.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.sp2),
            Text(
              'Tap "Impor Data" di Pengaturan untuk memuat file GPX '
              'dari nelayan lain.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatasetCard extends ConsumerStatefulWidget {
  const _DatasetCard({required this.dataset});

  final ImportedDataset dataset;

  @override
  ConsumerState<_DatasetCard> createState() => _DatasetCardState();
}

class _DatasetCardState extends ConsumerState<_DatasetCard> {
  bool _busy = false;

  static final _dateFormat = DateFormat('d MMM yyyy, HH:mm', 'id_ID');
  static final _exportedFormat = DateFormat('d MMM yyyy', 'id_ID');

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    final colors = context.colors;
    final ds = widget.dataset;

    return GlassCard(
      level: GlassLevel.level2,
      padding: const EdgeInsets.all(AppSizes.sp1),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.sp3,
          AppSizes.sp3,
          AppSizes.sp3,
          AppSizes.sp3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ds.visible
                        ? tokens.primarySoft
                        : tokens.accentSoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    ds.visible
                        ? PhosphorIconsFill.folder
                        : PhosphorIconsRegular.folder,
                    size: 18,
                    color: ds.visible
                        ? colors.primary
                        : tokens.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSizes.sp3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ds.fileName,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (ds.vesselName != null ||
                          ds.exporterName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (ds.vesselName != null) ds.vesselName!,
                            if (ds.exporterName != null) ds.exporterName!,
                            if (ds.exportedAt != null)
                              _exportedFormat.format(ds.exportedAt!.toLocal()),
                          ].join(' · '),
                          style: text.bodySmall?.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Switch(
                  value: ds.visible,
                  onChanged: _busy ? null : _toggleVisible,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sp3),
            // Counter row
            Wrap(
              spacing: AppSizes.sp2,
              runSpacing: AppSizes.sp1,
              children: [
                _CounterChip(
                  icon: PhosphorIconsFill.mapPin,
                  label: '${ds.markerCount} penanda',
                  emphasised: ds.markerCount > 0,
                ),
                _CounterChip(
                  icon: PhosphorIconsFill.path,
                  label: '${ds.tripCount} trip',
                  emphasised: ds.tripCount > 0,
                ),
                _CounterChip(
                  icon: PhosphorIconsFill.lineSegments,
                  label: '${ds.haulCount} tarikan',
                  emphasised: ds.haulCount > 0,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sp3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Diimpor ${_dateFormat.format(ds.importedAt.toLocal())}',
                    style: text.bodySmall?.copyWith(
                      color: tokens.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _confirmDelete,
                  icon: Icon(
                    PhosphorIconsBold.trash,
                    size: 16,
                    color: tokens.danger,
                  ),
                  label: Text(
                    'Hapus',
                    style: text.labelMedium?.copyWith(
                      color: tokens.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleVisible(bool value) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(importedDatasetRepositoryProvider)
          .setVisible(widget.dataset.id, value);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final ds = widget.dataset;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus dataset?'),
        content: Text(
          'Akan menghapus ${ds.markerCount} penanda, '
          '${ds.tripCount} trip, dan ${ds.haulCount} tarikan dari '
          'aplikasi.\n\nFile asli di perangkat Anda tidak terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: context.tokens.danger.withValues(alpha: 0.15),
              foregroundColor: context.tokens.danger,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(importedDatasetRepositoryProvider).delete(ds.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dataset "${ds.fileName}" dihapus.'),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _CounterChip extends StatelessWidget {
  const _CounterChip({
    required this.icon,
    required this.label,
    required this.emphasised,
  });

  final IconData icon;
  final String label;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sp2,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: emphasised ? tokens.primarySoft : tokens.surface3,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: emphasised ? colors.primary : tokens.textTertiary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: text.labelSmall?.copyWith(
              color: emphasised ? colors.primary : tokens.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
