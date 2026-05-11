
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
import '../../logbook/data/log_book_repository.dart';
import '../../logbook/domain/entities/log_book_entry.dart';
import '../../map/application/map_overlay_state.dart';
import '../../navigation/application/navigation_controller.dart';
import '../../navigation/domain/entities/navigation_target.dart';
import '../../tracking/data/haul_repository.dart';
import '../../tracking/data/track_point_repository.dart';
import '../../tracking/domain/entities/haul.dart';
import '../../tracking/domain/entities/track_point.dart';
import '../../tracking/presentation/widgets/color_picker_sheet.dart';
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
            return _Body(
              haul: haul,
              pointsAsync: pointsAsync,
              onExpandMap: () {
                ref
                    .read(mapOverlayControllerProvider.notifier)
                    .showHaul(haul.id);
                context.go(AppRoutes.map);
              },
            );
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
        'Detail Tarikan',
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
              'Selesaikan tarikan terlebih dulu (tekan "Berhenti").',),
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
          title: 'Ubah Nama Tarikan',
          initial: haul.name ?? '',
          hint: 'Contoh: Spot Utara Pagi',
        );
        if (newName == null || !context.mounted) return;
        await ref
            .read(haulRepositoryProvider)
            .rename(haul.id, newName.isEmpty ? null : newName);
      case ItemOption.changeColor:
        final color = await ColorPickerSheet.show(
          context,
          currentColorValue: haul.colorValue,
        );
        if (!context.mounted) return;
        // color == null means "reset to auto", an int means a picked ARGB value.
        await ref.read(haulRepositoryProvider).setColor(haul.id, color);
      case ItemOption.delete:
        final confirmed = await DeleteConfirmDialog.show(
          context,
          title: 'Hapus Tarikan?',
          body: 'Semua titik GPS dan catatan yang terkait tarikan ini '
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
  const _Body({
    required this.haul,
    required this.pointsAsync,
    required this.onExpandMap,
  });

  final Haul haul;
  final AsyncValue<List<TrackPoint>> pointsAsync;
  final VoidCallback onExpandMap;

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
            onExpandTap: onExpandMap,
          ),
        ),
        const SizedBox(height: AppSizes.sp4),
        _MetricGrid(haul: haul),
        const SizedBox(height: AppSizes.sp4),
        _NavigationCtaRow(haul: haul, pointsAsync: pointsAsync),
        const SizedBox(height: AppSizes.sp4),
        _HaulLogBookCard(haulId: haul.id),
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
            'TARIKAN #${haul.orderIndex} · '
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
                      size: 10, color: tokens.danger,),
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
        ],),
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
        ],),
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
// Log book card (live from DB)
// ===========================================================================

class _HaulLogBookCard extends ConsumerWidget {
  const _HaulLogBookCard({required this.haulId});

  final String haulId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(logBookByHaulProvider(haulId));

    return async.when(
      loading: () => const _LogBookCardShell(
        title: 'Log Book Tarikan',
        subtitle: 'Memuat…',
        trailing: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        onTap: null,
      ),
      error: (_, __) => _LogBookCardShell(
        title: 'Log Book Tarikan',
        subtitle: 'Gagal memuat log',
        onTap: () => context.push(AppRoutes.logBookForHaul(haulId)),
        ctaIcon: PhosphorIconsBold.arrowRight,
      ),
      data: (entry) {
        if (entry == null) {
          return _LogBookCardShell(
            title: 'Log Book Tarikan',
            subtitle: 'Belum ada catatan — isi hasil tangkap & kondisi',
            onTap: () => context.push(AppRoutes.logBookForHaul(haulId)),
            ctaLabel: 'Isi Log Book',
            ctaIcon: PhosphorIconsBold.plus,
          );
        }
        return _LogBookCardShell(
          title: 'Log Book Tarikan',
          subtitle: _summarize(entry),
          onTap: () => context.push(AppRoutes.logBookForHaul(haulId)),
          ctaLabel: 'Edit Log Book',
          ctaIcon: PhosphorIconsBold.pencilSimple,
          saved: true,
        );
      },
    );
  }

  String _summarize(LogBookEntry entry) {
    final parts = <String>[];
    if (entry.totalCatchKg > 0) {
      parts.add('${entry.totalCatchKg.toStringAsFixed(1)} kg tangkap');
    } else if (entry.catches.isNotEmpty) {
      parts.add('${entry.catches.length} jenis ikan');
    }
    if (entry.weather != null) {
      parts.add('Cuaca ${entry.weather!.name}');
    }
    if (entry.wave != null) {
      parts.add('Gelombang ${entry.wave!.name}');
    }
    if (parts.isEmpty && entry.notes != null && entry.notes!.isNotEmpty) {
      parts.add('Catatan tersimpan');
    }
    return parts.isEmpty ? 'Log tersimpan' : parts.join(' · ');
  }
}

class _LogBookCardShell extends StatelessWidget {
  const _LogBookCardShell({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.ctaLabel,
    this.ctaIcon,
    this.trailing,
    this.saved = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? ctaLabel;
  final IconData? ctaIcon;
  final Widget? trailing;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    final accent = saved ? tokens.success : context.colors.primary;
    final iconBg = saved ? tokens.success.withValues(alpha: 0.14) : tokens.primarySoft;

    return GlassCard(
      level: GlassLevel.level1,
      padding: const EdgeInsets.all(AppSizes.sp4),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              saved
                  ? PhosphorIconsFill.notebook
                  : PhosphorIconsRegular.notebook,
              size: 20,
              color: accent,
            ),
          ),
          const SizedBox(width: AppSizes.sp3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(title, style: text.titleSmall),
                    if (saved) ...[
                      const SizedBox(width: 6),
                      Icon(
                        PhosphorIconsFill.checkCircle,
                        size: 14,
                        color: tokens.success,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: tokens.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sp2),
          if (trailing != null)
            trailing!
          else if (ctaIcon != null)
            _MiniCta(
              label: ctaLabel ?? '',
              icon: ctaIcon!,
              color: accent,
            ),
        ],
      ),
    );
  }
}

class _MiniCta extends StatelessWidget {
  const _MiniCta({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return Icon(icon, size: 18, color: color);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: context.text.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Navigation CTAs
// ===========================================================================

/// Two buttons shown in the haul detail, wired to the M11 navigation
/// controller:
///   * "Ikuti Jalur" — starts follow-track with the haul's polyline.
///   * "Pandu ke Akhir" — starts go-to to the last recorded fix of
///     this haul.
/// Both CTAs depend on [pointsAsync] actually resolving; while Drift
/// is resolving the points both buttons render disabled. A haul with
/// zero recorded points collapses the row to a short "no GPS data"
/// pill — better than a silent dead button.
class _NavigationCtaRow extends ConsumerWidget {
  const _NavigationCtaRow({
    required this.haul,
    required this.pointsAsync,
  });

  final Haul haul;
  final AsyncValue<List<TrackPoint>> pointsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = pointsAsync.asData?.value;
    final loading = pointsAsync is AsyncLoading;
    final hasPath = points != null && points.length >= 2;

    if (!loading && (points == null || points.isEmpty)) {
      // No GPS data at all — show a compact hint instead of dead
      // buttons, so the detail screen's meaning is preserved.
      return _EmptyNavHint();
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: hasPath
                ? () => _onFollowTrackPressed(context, ref, points)
                : null,
            icon: const Icon(PhosphorIconsBold.footprints, size: 18),
            label: const Text('Ikuti Jalur'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.sp3),
            ),
          ),
        ),
        const SizedBox(width: AppSizes.sp2),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: hasPath
                ? () => _onGotoEndPressed(context, ref, points)
                : null,
            icon: const Icon(PhosphorIconsBold.navigationArrow, size: 18),
            label: const Text('Pandu ke Akhir'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.sp3),
            ),
          ),
        ),
      ],
    );
  }

  void _onFollowTrackPressed(
    BuildContext context,
    WidgetRef ref,
    List<TrackPoint> points,
  ) {
    final latLngs = points.map((p) => p.latLng).toList(growable: false);
    ref.read(navigationControllerProvider.notifier).startFollowTrack(
          FollowTrackTarget(
            pathPoints: latLngs,
            label: haul.displayName(),
            sourceType: FollowTrackSource.haul,
            sourceId: haul.id,
          ),
        );
    // Jump to the map so the user sees the reference polyline and
    // bearing arrow without having to navigate manually.
    context.go(AppRoutes.map);
  }

  void _onGotoEndPressed(
    BuildContext context,
    WidgetRef ref,
    List<TrackPoint> points,
  ) {
    final end = points.last.latLng;
    ref.read(navigationControllerProvider.notifier).startGoto(
          GotoTarget(
            position: end,
            label: '${haul.displayName()} (akhir)',
          ),
        );
    context.go(AppRoutes.map);
  }
}

class _EmptyNavHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    return GlassCard(
      level: GlassLevel.level1,
      padding: const EdgeInsets.all(AppSizes.sp3 + 2),
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.info,
            size: 18,
            color: tokens.textTertiary,
          ),
          const SizedBox(width: AppSizes.sp2),
          Expanded(
            child: Text(
              'Tarikan ini belum punya titik GPS — pandu tidak tersedia.',
              style: text.bodySmall?.copyWith(
                color: tokens.textSecondary,
              ),
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
            Text('Gagal memuat tarikan', style: text.titleMedium),
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
            Text('Tarikan tidak ditemukan', style: text.titleMedium),
            const SizedBox(height: AppSizes.sp2),
            Text(
              'Tarikan ini mungkin sudah dihapus.',
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
