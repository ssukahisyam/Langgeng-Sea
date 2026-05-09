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
import '../../map/application/map_overlay_state.dart';
import '../../tracking/data/haul_repository.dart';
import '../../tracking/data/track_point_repository.dart';
import '../../tracking/data/trip_repository.dart';
import '../../tracking/domain/entities/haul.dart';
import '../../tracking/domain/entities/track_point.dart';
import '../../tracking/domain/entities/trip.dart';
import 'widgets/delete_confirm_dialog.dart';
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
          body: 'Semua haul, titik GPS, dan log yang terkait akan '
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
        const SizedBox(height: AppSizes.sp5),

        // Section header for hauls
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSizes.sp2),
          child: Text(
            '${hauls.length} HAUL',
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
        _TripLogPlaceholder(),
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
              'Trip ini belum punya haul.',
              style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripLogPlaceholder extends StatelessWidget {
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
              color: tokens.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              PhosphorIconsRegular.notebook,
              size: 18,
              color: context.colors.primary,
            ),
          ),
          const SizedBox(width: AppSizes.sp3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Log Book Trip', style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'BBM, kru, biaya — tersedia di M5',
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
