import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../tracking/data/haul_repository.dart';
import '../../tracking/data/track_point_repository.dart';
import '../../tracking/domain/entities/haul.dart';
import '../../tracking/domain/entities/track_point.dart';
import 'widgets/delete_confirm_dialog.dart';
import 'widgets/item_options_sheet.dart';
import 'widgets/multi_haul_map.dart';
import 'widgets/rename_dialog.dart';

/// Detail view of a single haul. Focused layout: the map shows only this
/// haul's polyline, the 5 metric tiles mirror the summary sheet, and
/// there's a placeholder card for the future log book (M5).
class HaulDetailScreen extends ConsumerWidget {
  const HaulDetailScreen({super.key, required this.haulId});

  final String haulId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final haulAsync = ref.watch(haulByIdProvider(haulId));
    final pointsAsync = ref.watch(trackPointsByHaulProvider(haulId));

    return AmbientBackground(
      showBlobs: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(context, ref, haulAsync.valueOrNull),
        body: haulAsync.when(
          loading: () => const _CenteredSpinner(),
          error: (e, _) => _ErrorState(message: '$e'),
          data: (haul) {
            if (haul == null) return const _NotFoundState();
            return _Body(haul: haul, pointsAsync: pointsAsync);
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    Haul? haul,
  ) {
    final text = context.text;
    return AppBar(
      leading: IconButton(
        onPressed: () => _pop(context),
        icon: const Icon(PhosphorIconsRegular.arrowLeft),
      ),
      title: Text(
        'Haul Detail',
        style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          onPressed: haul == null
              ? null
              : () => _onOptionsPressed(context, ref, haul),
          tooltip: 'Opsi',
          icon: const Icon(PhosphorIconsRegular.dotsThree),
        ),
      ],
    );
  }

  Future<void> _onOptionsPressed(
    BuildContext context,
    WidgetRef ref,
    Haul haul,
  ) async {
    // Don't let the user rename/delete a haul that is still recording —
    // the tracking controller owns its lifecycle.
    if (haul.isRecording) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Selesaikan haul terlebih dulu (tekan "Angkat Trawl").'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final result = await ItemOptionsSheet.show(
      context,
      title: haul.displayName(),
      subtitle: '${Formatters.sectionDate(haul.startedAt)} · '
          '${Formatters.wallClock(haul.startedAt)}',
    );
    if (!context.mounted) return;

    switch (result) {
      case ItemOption.rename:
        final newName = await RenameDialog.show(
          context,
          title: 'Ubah Nama Haul',
          initial: haul.name ?? '',
          hint: 'Contoh: Spot Utara Pagi',
        );
        if (newName == null || !context.mounted) return;
        await ref
            .read(haulRepositoryProvider)
            .rename(haul.id, newName.isEmpty ? null : newName);
      case ItemOption.delete:
        final confirmed = await DeleteConfirmDialog.show(
          context,
          title: 'Hapus Haul?',
          body: 'Semua titik GPS dan catatan yang terkait haul ini '
              'akan ikut terhapus. Tindakan ini tidak dapat dibatalkan.',
        );
        if (!confirmed || !context.mounted) return;
        await ref.read(haulRepositoryProvider).deleteHaul(haul.id);
        if (!context.mounted) return;
        _pop(context);
      case ItemOption.dismissed:
        break;
    }
  }

  void _pop(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.history);
    }
  }
}

// ===========================================================================
// Body
// ===========================================================================

class _Body extends StatelessWidget {
  const _Body({required this.haul, required this.pointsAsync});

  final Haul haul;
  final AsyncValue<List<TrackPoint>> pointsAsync;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.sp5,
        AppSizes.sp2,
        AppSizes.sp5,
        AppSizes.sp8,
      ),
      children: [
        _Hero(haul: haul),
        const SizedBox(height: AppSizes.sp3),
        pointsAsync.when(
          loading: () => const _MapSkeleton(),
          error: (_, __) => const _MapError(),
          data: (points) => MultiHaulMap(
            hauls: [haul],
            pointsByHaulId: {haul.id: points},
          ),
        ),
        const SizedBox(height: AppSizes.sp4),
        _MetricGrid(haul: haul),
        const SizedBox(height: AppSizes.sp4),
        _CatchPlaceholder(),
      ],
    );
  }
}

// ===========================================================================
// Hero
// ===========================================================================

class _Hero extends StatelessWidget {
  const _Hero({required this.haul});
  final Haul haul;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    final startClock = Formatters.wallClock(haul.startedAt);
    final endClock = haul.endedAt != null
        ? Formatters.wallClock(haul.endedAt!)
        : '…';

    return GlassCard(
      level: GlassLevel.level2,
      padding: const EdgeInsets.all(AppSizes.sp4 + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HAUL #${haul.orderIndex} · '
            '${Formatters.sectionDate(haul.startedAt).toUpperCase()} · '
            '$startClock - $endClock',
            style: text.labelSmall?.copyWith(
              color: tokens.textTertiary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            haul.displayName(),
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (haul.status == HaulStatus.recording) ...[
            const SizedBox(height: AppSizes.sp2),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sp3,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: tokens.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.radiusPill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIconsFill.record,
                      size: 10, color: tokens.danger),
                  const SizedBox(width: 5),
                  Text(
                    'MASIH MEREKAM',
                    style: text.labelSmall?.copyWith(
                      color: tokens.danger,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// 5 metric tiles (matches HaulSummarySheet layout)
// ===========================================================================

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.haul});
  final Haul haul;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      children: [
        Row(children: [
          Expanded(
            child: _Tile(
              icon: PhosphorIconsBold.ruler,
              iconBg: tokens.primarySoft,
              iconColor: context.colors.primary,
              value: Formatters.distance(haul.distanceMeters),
              label: 'Jarak Tarik',
            ),
          ),
          const SizedBox(width: AppSizes.sp2),
          Expanded(
            child: _Tile(
              icon: PhosphorIconsBold.timer,
              iconBg: tokens.accentSoft,
              iconColor: context.colors.secondary,
              value: Formatters.duration(haul.duration),
              label: 'Durasi',
            ),
          ),
        ]),
        const SizedBox(height: AppSizes.sp2),
        Row(children: [
          Expanded(
            child: _Tile(
              icon: PhosphorIconsBold.speedometer,
              iconBg: tokens.primarySoft,
              iconColor: context.colors.primary,
              value: Formatters.knots(haul.avgSpeedKnots),
              label: 'Kecepatan rata-rata',
            ),
          ),
          const SizedBox(width: AppSizes.sp2),
          Expanded(
            child: _Tile(
              icon: PhosphorIconsBold.compass,
              iconBg: tokens.accentSoft,
              iconColor: context.colors.secondary,
              value: Formatters.heading(haul.avgHeadingDegrees),
              label: 'Arah dominan',
            ),
          ),
        ]),
        const SizedBox(height: AppSizes.sp2),
        _Tile(
          icon: PhosphorIconsBold.frameCorners,
          iconBg: tokens.primarySoft,
          iconColor: context.colors.primary,
          value: _formatArea(haul.sweptAreaM2),
          label: 'Luas area sapuan · lebar ${haul.trawlWidthMeters.round()} m',
        ),
      ],
    );
  }

  String _formatArea(double m2) {
    if (m2 <= 0) return '0 m²';
    if (m2 < 10000) return '${m2.round()} m²';
    final ha = m2 / 10000.0;
    return '${ha.toStringAsFixed(ha < 10 ? 2 : 1)} ha';
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    return GlassCard(
      level: GlassLevel.level1,
      padding: const EdgeInsets.all(AppSizes.sp3 + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: AppSizes.sp2),
          Text(
            value,
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(
              color: tokens.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Catch placeholder (M5)
// ===========================================================================

class _CatchPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    return GlassCard(
      level: GlassLevel.level1,
      padding: const EdgeInsets.all(AppSizes.sp4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tokens.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              PhosphorIconsRegular.fish,
              size: 18,
              color: context.colors.secondary,
            ),
          ),
          const SizedBox(width: AppSizes.sp3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Hasil Tangkap', style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Jenis ikan & berat (kg) — tersedia di M5',
                  style: text.bodySmall?.copyWith(
                    color: tokens.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// States
// ===========================================================================

class _CenteredSpinner extends StatelessWidget {
  const _CenteredSpinner();
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
            Text('Gagal memuat haul', style: text.titleMedium),
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

class _NotFoundState extends StatelessWidget {
  const _NotFoundState();
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
            Icon(
              PhosphorIconsFill.magnifyingGlassMinus,
              size: 48,
              color: tokens.textTertiary,
            ),
            const SizedBox(height: AppSizes.sp3),
            Text('Haul tidak ditemukan', style: text.titleMedium),
            const SizedBox(height: AppSizes.sp2),
            Text(
              'Haul ini mungkin sudah dihapus.',
              style: text.bodySmall?.copyWith(color: tokens.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapSkeleton extends StatelessWidget {
  const _MapSkeleton();
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: Container(
        height: 180,
        color: tokens.surface1,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor:
                  AlwaysStoppedAnimation<Color>(context.colors.primary),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapError extends StatelessWidget {
  const _MapError();
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: Container(
        height: 180,
        color: tokens.surface1,
        child: Center(
          child: Text(
            'Gagal memuat peta',
            style: text.bodySmall?.copyWith(color: tokens.textTertiary),
          ),
        ),
      ),
    );
  }
}
