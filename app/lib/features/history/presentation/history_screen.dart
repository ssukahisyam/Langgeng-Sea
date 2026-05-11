import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../tracking/data/trip_repository.dart';
import 'history_grouping.dart';
import 'widgets/trip_card.dart';

/// Riwayat tab — reactive list of all completed & active trips.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.text;
    final tokens = context.tokens;
    final summariesAsync = ref.watch(tripSummariesProvider);

    return AmbientBackground(
      child: SafeArea(
        bottom: false,
        child: summariesAsync.when(
          loading: () => const _Loading(),
          error: (e, _) => _ErrorState(message: '$e'),
          data: (summaries) {
            if (summaries.isEmpty) {
              return const _Scaffold(
                child: _EmptyState(),
              );
            }
            final rows = groupTripsByDay(summaries);
            return _Scaffold(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.sp5,
                  AppSizes.sp3,
                  AppSizes.sp5,
                  140,
                ),
                itemCount: rows.length,
                separatorBuilder: (_, i) {
                  // Smaller gap between cards within the same day.
                  final row = rows[i];
                  return SizedBox(
                    height: row is HistorySectionHeader
                        ? AppSizes.sp1
                        : AppSizes.sp3 - 2,
                  );
                },
                itemBuilder: (_, i) {
                  final row = rows[i];
                  if (row is HistorySectionHeader) {
                    return Padding(
                      padding: EdgeInsets.only(
                        top: i == 0 ? 0 : AppSizes.sp5,
                        bottom: AppSizes.sp2,
                        left: 4,
                      ),
                      child: Text(
                        Formatters.sectionDate(row.day).toUpperCase(),
                        style: text.labelSmall?.copyWith(
                          color: tokens.textTertiary,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  if (row is HistoryTripItem) {
                    return TripCard(
                      summary: row.summary,
                      onTap: () => context.push(
                        AppRoutes.tripDetail(row.summary.trip.id),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.sp5,
            AppSizes.sp4,
            AppSizes.sp5,
            0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppStrings.tabHistory, style: text.headlineLarge),
              // Filter coming in M6 polish. Kept visually so the layout
              // doesn't jump when enabled.
              const IconButton(
                onPressed: null,
                icon: Icon(PhosphorIconsRegular.funnel),
                tooltip: 'Filter (segera)',
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return _Scaffold(
      child: Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor:
                AlwaysStoppedAnimation<Color>(context.colors.primary),
          ),
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
    return _Scaffold(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.sp6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PhosphorIconsFill.warning,
                size: 48,
                color: tokens.danger,
              ),
              const SizedBox(height: AppSizes.sp3),
              Text('Gagal memuat riwayat', style: text.titleMedium),
              const SizedBox(height: AppSizes.sp2),
              Text(
                message,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: tokens.textTertiary),
              ),
            ],
          ),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: tokens.primarySoft,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              ),
              child: Icon(
                PhosphorIconsRegular.clockCounterClockwise,
                size: 36,
                color: context.colors.primary,
              ),
            ),
            const SizedBox(height: AppSizes.sp5),
            Text(AppStrings.emptyHistoryTitle, style: text.headlineSmall),
            const SizedBox(height: AppSizes.sp2),
            Text(
              AppStrings.emptyHistorySub,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
