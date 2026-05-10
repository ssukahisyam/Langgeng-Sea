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
import '../../logbook/data/log_book_repository.dart';
import '../../logbook/domain/entities/log_book_entry.dart';
import '../../map/application/map_overlay_state.dart';
import '../../navigation/application/navigation_controller.dart';
import '../../navigation/domain/entities/navigation_target.dart';
import '../../tracking/data/haul_repository.dart';
import '../../tracking/data/track_point_repository.dart';
import '../../tracking/data/trip_repository.dart';
import '../../tracking/domain/entities/haul.dart';
import '../../tracking/domain/entities/track_point.dart';
import '../../tracking/domain/entities/trip.dart';
import 'widgets/delete_confirm_dialog.dart';
import 'widgets/follow_haul_picker_sheet.dart';
import 'widgets/haul_list_tile.dart';
import 'widgets/item_options_sheet.dart';
import 'widgets/multi_haul_map.dart';
import 'widgets/rename_dialog.dart';

/// Detail view of a single trip. Shows hero map with every haul as its
/// own polyline, headline metrics, and a tappable list of hauls.
class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripByIdProvider(tripId));
    final haulsAsync = ref.watch(haulsByTripProvider(tripId));
    final pointsAsync = ref.watch(pointsByHaulForTripProvider(tripId));

    return AmbientBackground(
      showBlobs: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(context, ref, tripAsync.valueOrNull),
        body: tripAsync.when(
          loading: () => const _CenteredSpinner(),
          error: (e, _) => _ErrorState(message: '$e'),
          data: (trip) {
            if (trip == null) return const _NotFoundState();
            return haulsAsync.when(
              loading: () => const _CenteredSpinner(),
              error: (e, _) => _ErrorState(message: '$e'),
              data: (hauls) => _Body(
                trip: trip,
                hauls: hauls,
                pointsAsync: pointsAsync,
                onHaulTap: (haul) =>
                    context.push(AppRoutes.haulDetail(haul.id)),
                onExpandMap: () {
                  ref
                      .read(mapOverlayControllerProvider.notifier)
                      .showTrip(trip.id);
                  context.go(AppRoutes.map);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    Trip? trip,
  ) {
    final text = context.text;
    return AppBar(
      leading: IconButton(
        onPressed: () => _pop(context),
        icon: const Icon(PhosphorIconsRegular.arrowLeft),
      ),
      title: Text(
        'Trip Detail',
        style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          onPressed: trip == null
              ? null
              : () => _onOptionsPressed(context, ref, trip),
          tooltip: 'Opsi',
          icon: const Icon(PhosphorIconsRegular.dotsThree),
        ),
      ],
    );
  }

  Future<void> _onOptionsPressed(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) async {
    final currentTitle = trip.name?.isNotEmpty == true
        ? trip.name!
        : 'Trip ${Formatters.shortDate(trip.startedAt)}';
    final result = await ItemOptionsSheet.show(
      context,
      title: currentTitle,
      subtitle: Formatters.sectionDate(trip.startedAt),
    );
    if (!context.mounted) return;

    switch (result) {
      case ItemOption.rename:
        final newName = await RenameDialog.show(
          context,
          title: 'Ubah Nama Trip',
          initial: trip.name ?? '',
          hint: 'Contoh: Trip Pagi - Probolinggo',
        );
        if (newName == null || !context.mounted) return;
        await ref
            .read(tripRepositoryProvider)
            .rename(trip.id, newName.isEmpty ? null : newName);
      case ItemOption.delete:
        final confirmed = await DeleteConfirmDialog.show(
          context,
          title: 'Hapus Trip?',
          body: 'Semua tarikan, titik GPS, dan log yang terkait akan '
              'ikut terhapus. Tindakan ini tidak dapat dibatalkan.',
        );
        if (!confirmed || !context.mounted) return;
        await ref.read(tripRepositoryProvider).deleteTrip(trip.id);
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
    required this.trip,
    required this.hauls,
    required this.pointsAsync,
    required this.onHaulTap,
    required this.onExpandMap,
  });

  final Trip trip;
  final List<Haul> hauls;
  final AsyncValue<Map<String, List<TrackPoint>>> pointsAsync;
  final void Function(Haul) onHaulTap;
  final VoidCallback onExpandMap;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;

    final totalDistance =
        hauls.fold<double>(0, (s, h) => s + h.distanceMeters);
    final totalDuration = Duration(
      seconds: hauls.fold<int>(0, (s, h) => s + h.durationSeconds),
    );
    final totalArea = hauls.fold<double>(0, (s, h) => s + h.sweptAreaM2);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.sp5,
        AppSizes.sp2,
        AppSizes.sp5,
        AppSizes.sp8,
      ),
      children: [
        _Hero(trip: trip),
        const SizedBox(height: AppSizes.sp3),

        // Map preview
        pointsAsync.when(
          loading: () => _MapSkeleton(),
          error: (_, __) => const _MapError(),
          data: (pointsMap) => MultiHaulMap(
            hauls: hauls,
            pointsByHaulId: pointsMap,
            onExpandTap: onExpandMap,
          ),
        ),
        const SizedBox(height: AppSizes.sp3),

        // Metric strip
        _MetricStrip(
          distance: totalDistance,
          duration: totalDuration,
          sweptAreaM2: totalArea,
        ),
        const SizedBox(height: AppSizes.sp4),

        // Navigation CTAs -- shown above the hauls list so they read
        // as actions on the trip as a whole, not on any individual
        // haul below.
        _NavigationCtaRow(hauls: hauls, pointsAsync: pointsAsync),
        const SizedBox(height: AppSizes.sp5),

        // Section header for hauls
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSizes.sp2),
          child: Text(
            '${hauls.length} TARIKAN',
            style: text.labelSmall?.copyWith(
              color: tokens.textTertiary,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ),
        if (hauls.isEmpty)
          _EmptyHauls()
        else
          for (final haul in hauls) ...[
            HaulListTile(haul: haul, onTap: () => onHaulTap(haul)),
            const SizedBox(height: AppSizes.sp2 + 2),
          ],

        const SizedBox(height: AppSizes.sp4),
        _TripLogBookCard(tripId: trip.id),
      ],
    );
  }
}

// ===========================================================================
// Hero
// ===========================================================================

class _Hero extends StatelessWidget {
  const _Hero({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    final title = trip.name?.isNotEmpty == true
        ? trip.name!
        : 'Trip ${Formatters.shortDate(trip.startedAt)}';

    return GlassCard(
      level: GlassLevel.level2,
      padding: const EdgeInsets.all(AppSizes.sp4 + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Formatters.sectionDate(trip.startedAt).toUpperCase(),
                  style: text.labelSmall?.copyWith(
                    color: tokens.textTertiary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          _StatusPill(active: trip.status == TripStatus.active),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    final color = active ? tokens.warning : tokens.success;
    final icon = active
        ? PhosphorIconsFill.circleNotch
        : PhosphorIconsFill.checkCircle;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSizes.sp3, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            active ? 'Berjalan' : 'Selesai',
            style: text.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Metric strip (3 columns)
// ===========================================================================

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({
    required this.distance,
    required this.duration,
    required this.sweptAreaM2,
  });

  final double distance;
  final Duration duration;
  final double sweptAreaM2;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return GlassCard(
      level: GlassLevel.level1,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sp3,
        vertical: AppSizes.sp3 + 2,
      ),
      child: Row(
        children: [
          Expanded(
            child: _MetricColumn(
              label: 'Jarak',
              value: Formatters.distance(distance),
            ),
          ),
          _Sep(color: tokens.border),
          Expanded(
            child: _MetricColumn(
              label: 'Durasi',
              value: Formatters.compactDuration(duration),
            ),
          ),
          _Sep(color: tokens.border),
          Expanded(
            child: _MetricColumn(
              label: 'Sapuan',
              value: _formatArea(sweptAreaM2),
            ),
          ),
        ],
      ),
    );
  }

  String _formatArea(double m2) {
    if (m2 <= 0) return '0 m²';
    if (m2 < 10000) return '${m2.round()} m²';
    final ha = m2 / 10000.0;
    return '${ha.toStringAsFixed(ha < 10 ? 2 : 1)} ha';
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: text.labelSmall?.copyWith(
            color: tokens.textTertiary,
            letterSpacing: 0.5,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: text.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: color);
}

// ===========================================================================
// Placeholder widgets
// ===========================================================================

class _MapSkeleton extends StatelessWidget {
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

class _EmptyHauls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    return GlassCard(
      level: GlassLevel.level1,
      padding: const EdgeInsets.all(AppSizes.sp4),
      child: Row(
        children: [
          Icon(PhosphorIconsRegular.info, size: 18, color: tokens.textTertiary),
          const SizedBox(width: AppSizes.sp2),
          Expanded(
            child: Text(
              'Trip ini belum punya tarikan.',
              style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripLogBookCard extends ConsumerWidget {
  const _TripLogBookCard({required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(logBookByTripProvider(tripId));
    final text = context.text;
    final tokens = context.tokens;

    final (title, subtitle, ctaLabel, ctaIcon, saved) = switch (async) {
      AsyncData(value: null) => (
          'Log Book Trip',
          'Belum ada — catat BBM, kru, biaya untuk trip ini',
          'Isi Log Book',
          PhosphorIconsBold.plus,
          false,
        ),
      AsyncData(value: LogBookEntry(:final totalCatchKg, :final crewCount, :final fuelLiters, :final notes)) =>
        (
          'Log Book Trip',
          _tripSummary(
            totalCatchKg: totalCatchKg,
            crewCount: crewCount,
            fuelLiters: fuelLiters,
            notes: notes,
          ),
          'Edit Log Book',
          PhosphorIconsBold.pencilSimple,
          true,
        ),
      AsyncError() => (
          'Log Book Trip',
          'Gagal memuat log',
          'Buka',
          PhosphorIconsBold.arrowRight,
          false,
        ),
      _ => ('Log Book Trip', 'Memuat…', '', null, false),
    };

    final accent = saved ? tokens.success : context.colors.primary;
    final iconBg = saved
        ? tokens.success.withValues(alpha: 0.14)
        : tokens.primarySoft;

    return GlassCard(
      level: GlassLevel.level1,
      padding: const EdgeInsets.all(AppSizes.sp4),
      onTap: async is AsyncLoading
          ? null
          : () => context.push(AppRoutes.logBookForTrip(tripId)),
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
          if (async is AsyncLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (ctaIcon != null) ...[
            Icon(ctaIcon, size: 14, color: accent),
            const SizedBox(width: 4),
            Text(
              ctaLabel,
              style: text.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _tripSummary({
    required double totalCatchKg,
    required int? crewCount,
    required double? fuelLiters,
    required String? notes,
  }) {
    final parts = <String>[];
    if (totalCatchKg > 0) {
      parts.add('${totalCatchKg.toStringAsFixed(1)} kg tangkap');
    }
    if (fuelLiters != null && fuelLiters > 0) {
      parts.add('${fuelLiters.toStringAsFixed(0)} L BBM');
    }
    if (crewCount != null && crewCount > 0) {
      parts.add('$crewCount kru');
    }
    if (parts.isEmpty && notes != null && notes.isNotEmpty) {
      parts.add('Catatan tersimpan');
    }
    return parts.isEmpty ? 'Log tersimpan' : parts.join(' · ');
  }
}

// ===========================================================================
// Navigation CTAs
// ===========================================================================

/// Two buttons shown in the trip detail that kick the M11 navigation
/// controller into action. Mirrors [HaulDetailScreen]'s CTA row
/// semantically but operates at the trip scope:
///
///   * "Ikuti Jalur Tarikan" -- follow-track mode. If the trip has
///     exactly one haul that haul is auto-picked; for 2+ hauls the
///     [FollowHaulPickerSheet] pops to resolve which haul to follow.
///     This matches spec sect 8.4's resolved open question: no
///     gabungan polyline for multi-haul trips, instead a picker
///     disambiguates because inter-haul gaps (boat repositioning
///     between tarikan) would otherwise confuse the reference
///     polyline.
///   * "Pandu ke Akhir" -- go-to the last GPS fix of the last haul
///     in the trip (ordered by orderIndex, which [haulsByTripProvider]
///     already yields sorted).
///
/// Both CTAs depend on [pointsAsync] having resolved; while Drift
/// is still resolving the points both buttons render disabled. When
/// no haul has any GPS data a short hint pill replaces the row.
class _NavigationCtaRow extends ConsumerWidget {
  const _NavigationCtaRow({
    required this.hauls,
    required this.pointsAsync,
  });

  final List<Haul> hauls;
  final AsyncValue<Map<String, List<TrackPoint>>> pointsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (hauls.isEmpty) return const SizedBox.shrink();

    final pointsMap = pointsAsync.asData?.value;
    final loading = pointsAsync is AsyncLoading;

    // A haul is "navigable" when it has at least 2 GPS points. Trips
    // with only crashed/empty hauls collapse to the no-data hint.
    final navigableHauls = pointsMap == null
        ? const <Haul>[]
        : hauls
            .where((h) => (pointsMap[h.id]?.length ?? 0) >= 2)
            .toList(growable: false);

    if (!loading && navigableHauls.isEmpty) {
      return _EmptyNavHint();
    }

    final enabled = navigableHauls.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: enabled
                ? () => _onFollowTrackPressed(
                      context,
                      ref,
                      navigableHauls,
                      pointsMap!,
                    )
                : null,
            icon: const Icon(PhosphorIconsBold.footprints, size: 18),
            label: const Text('Ikuti Jalur Tarikan'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.sp3),
            ),
          ),
        ),
        const SizedBox(width: AppSizes.sp2),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: enabled
                ? () => _onGotoEndPressed(
                      context,
                      ref,
                      navigableHauls,
                      pointsMap!,
                    )
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

  Future<void> _onFollowTrackPressed(
    BuildContext context,
    WidgetRef ref,
    List<Haul> navigableHauls,
    Map<String, List<TrackPoint>> pointsMap,
  ) async {
    final picked = navigableHauls.length == 1
        ? navigableHauls.single
        : await FollowHaulPickerSheet.show(context, hauls: navigableHauls);
    if (picked == null || !context.mounted) return;

    final points = pointsMap[picked.id] ?? const <TrackPoint>[];
    if (points.length < 2) return; // defensive; picker filtered already.

    final latLngs = points.map((p) => p.latLng).toList(growable: false);
    ref.read(navigationControllerProvider.notifier).startFollowTrack(
          FollowTrackTarget(
            pathPoints: latLngs,
            label: picked.displayName(),
            // FollowTrackSource.haul (not .trip) because the active
            // reference is a single haul's polyline -- the trip-level
            // entry point is just how the user got here. Spec sect
            // 8.4 leaves `.trip` as forward-looking only.
            sourceType: FollowTrackSource.haul,
            sourceId: picked.id,
          ),
        );
    if (context.mounted) {
      context.go(AppRoutes.map);
    }
  }

  void _onGotoEndPressed(
    BuildContext context,
    WidgetRef ref,
    List<Haul> navigableHauls,
    Map<String, List<TrackPoint>> pointsMap,
  ) {
    // haulsByTripProvider yields hauls sorted by orderIndex so the
    // *last* navigable haul is already the trip's chronological end.
    final lastHaul = navigableHauls.last;
    final points = pointsMap[lastHaul.id] ?? const <TrackPoint>[];
    if (points.isEmpty) return;

    final end = points.last.latLng;
    ref.read(navigationControllerProvider.notifier).startGoto(
          GotoTarget(
            position: end,
            label: '${lastHaul.displayName()} (akhir)',
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
              'Trip ini belum punya titik GPS — pandu tidak tersedia.',
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
// Error/not-found states
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
            Text('Gagal memuat trip', style: text.titleMedium),
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
            Text('Trip tidak ditemukan', style: text.titleMedium),
            const SizedBox(height: AppSizes.sp2),
            Text(
              'Trip ini mungkin sudah dihapus.',
              style: text.bodySmall?.copyWith(color: tokens.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
