import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../logbook/data/log_book_repository.dart';
import '../../../logbook/domain/entities/log_book_entry.dart';
import '../../../tracking/domain/entities/haul.dart';

/// Bottom sheet that lets the user pick which haul of a multi-haul
/// trip they want to follow.
///
/// Surfaces in [TripDetailScreen] when the user taps "Ikuti Jalur
/// Tarikan" on a trip that has two or more hauls. For single-haul
/// trips the caller auto-selects the lone haul and never shows this
/// sheet — the picker exists to resolve the "which one" question,
/// not to be a mandatory confirmation.
///
/// Per spec sect 8.4:
///   * Each card shows haul name + wall-clock range + distance +
///     duration.
///   * If a haul has a persisted log book entry, the catch summary
///     is shown inline so the user can pick "the productive one"
///     without drilling into haul detail.
///   * Tapping a card pops the sheet with the picked [Haul].
///   * A bottom "Batal" button pops with null.
///
/// Hosted in the shell navigator (same pattern as
/// [LocationPermissionSheet], [HaulSummarySheet], [MarkerInfoSheet])
/// so the injected bottom-nav padding reaches the sheet.
class FollowHaulPickerSheet extends ConsumerWidget {
  const FollowHaulPickerSheet._({required this.hauls});

  final List<Haul> hauls;

  /// Shows the sheet and resolves to the picked [Haul], or null when
  /// the user dismisses via "Batal" / swipe / barrier tap.
  static Future<Haul?> show(
    BuildContext context, {
    required List<Haul> hauls,
  }) {
    return showModalBottomSheet<Haul>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FollowHaulPickerSheet._(hauls: hauls),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final text = context.text;
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.8;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.sp4,
        right: AppSizes.sp4,
        top: AppSizes.sp4,
        bottom: bottomSafe + AppSizes.sp4,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: GlassCard(
          level: GlassLevel.level3,
          padding: const EdgeInsets.fromLTRB(
            AppSizes.sp4,
            AppSizes.sp3,
            AppSizes.sp4,
            AppSizes.sp4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.sp4),
              Row(
                children: [
                  Icon(
                    PhosphorIconsBold.footprints,
                    size: 18,
                    color: context.colors.primary,
                  ),
                  const SizedBox(width: AppSizes.sp2),
                  Expanded(
                    child: Text(
                      'Pilih Tarikan untuk Ikuti Jalur',
                      style: text.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.sp1),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(
                  'Peta akan menampilkan jalur tarikan yang dipilih.',
                  style: text.bodySmall?.copyWith(
                    color: tokens.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.sp3),

              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: hauls.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSizes.sp2 + 2),
                  itemBuilder: (_, i) => _HaulCard(
                    haul: hauls[i],
                    onTap: () => Navigator.of(context).pop(hauls[i]),
                  ),
                ),
              ),

              const SizedBox(height: AppSizes.sp3),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Batal',
                  style: text.labelMedium?.copyWith(
                    color: tokens.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Haul card
// ===========================================================================

class _HaulCard extends ConsumerWidget {
  const _HaulCard({required this.haul, required this.onTap});

  final Haul haul;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final text = context.text;
    final color = AppColors.colorForHaul(haul.orderIndex);
    final logAsync = ref.watch(logBookByHaulProvider(haul.id));

    return GlassCard(
      level: GlassLevel.level2,
      onTap: onTap,
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
            children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: AppSizes.sp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      haul.displayName(),
                      style: text.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(),
                      style: text.bodySmall?.copyWith(
                        color: tokens.textTertiary,
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                PhosphorIconsBold.caretRight,
                size: 14,
                color: tokens.textTertiary,
              ),
            ],
          ),

          // Log book catch summary — only if an entry exists + it has
          // a positive total catch. The nice-to-have per spec sect
          // 8.4: surfaces "80 kg tenggiri" so the user can pick the
          // productive haul without drilling in. AsyncLoading /
          // AsyncError and empty logs both render nothing, so there
          // is no layout jitter while Riverpod resolves.
          _CatchHintRow(async: logAsync, tokens: tokens, text: text),
        ],
      ),
    );
  }

  String _subtitle() {
    final started = Formatters.wallClock(haul.startedAt);
    final ended = haul.endedAt != null
        ? Formatters.wallClock(haul.endedAt!)
        : '…';
    return '$started - $ended · ${Formatters.distance(haul.distanceMeters)} · '
        '${Formatters.compactDuration(haul.duration)}';
  }
}

class _CatchHintRow extends StatelessWidget {
  const _CatchHintRow({
    required this.async,
    required this.tokens,
    required this.text,
  });

  final AsyncValue<LogBookEntry?> async;
  final LangTokens tokens;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final entry = async.asData?.value;
    if (entry == null) return const SizedBox.shrink();
    final hint = _hintFor(entry);
    if (hint == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(
        top: AppSizes.sp2 + 2,
        left: 4 + AppSizes.sp3, // align with the haul name above
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIconsFill.fishSimple,
            size: 12,
            color: tokens.success,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              hint,
              style: text.bodySmall?.copyWith(
                color: tokens.success,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Summarise the log book entry's catch. Returns null (no row) when
  /// the entry has neither catch weight nor species listed, so empty
  /// logs don't render a misleading row.
  String? _hintFor(LogBookEntry entry) {
    if (entry.totalCatchKg > 0) {
      final kg = entry.totalCatchKg;
      final weight = kg >= 10
          ? '${kg.round()} kg'
          : '${kg.toStringAsFixed(1)} kg';
      if (entry.catches.isNotEmpty) {
        // Top 2 species by mass, just enough for "picked the best
        // haul" discrimination without turning the card into a
        // summary dashboard.
        final top = [...entry.catches]
          ..sort((a, b) => (b.weightKg ?? 0).compareTo(a.weightKg ?? 0));
        final names = top.take(2).map((c) => c.species).join(', ');
        return '$weight · $names';
      }
      return weight;
    }
    if (entry.catches.isNotEmpty) {
      return '${entry.catches.length} jenis tangkap tercatat';
    }
    return null;
  }
}
