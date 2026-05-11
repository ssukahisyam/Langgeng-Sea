
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../data/dashboard_stats_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.text;
    final statsAsync = ref.watch(dashboardStatsProvider);

    return AmbientBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.sp5, AppSizes.sp4, AppSizes.sp5, 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppStrings.tabDashboard, style: text.headlineLarge),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(PhosphorIconsRegular.export),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.sp3),

            // Period switcher
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSizes.sp5),
              child: _PeriodSwitcher(),
            ),
            const SizedBox(height: AppSizes.sp4),

            // Content
            Expanded(
              child: statsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator.adaptive(),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.sp6),
                    child: Text(
                      'Gagal memuat data.\n$e',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(
                        color: context.tokens.textSecondary,
                      ),
                    ),
                  ),
                ),
                data: (stats) => stats.isEmpty
                    ? _EmptyState()
                    : _DashboardContent(stats: stats),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Period Switcher
// =============================================================================

class _PeriodSwitcher extends ConsumerWidget {
  const _PeriodSwitcher();

  static const _labels = ['Hari ini', '7 Hari', '30 Hari', 'Total'];
  static const _periods = DashboardPeriod.values;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(dashboardPeriodProvider);
    final tokens = context.tokens;
    final text = context.text;

    return GlassCard(
      level: GlassLevel.level1,
      padding: const EdgeInsets.all(4),
      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      elevated: false,
      child: Row(
        children: List.generate(_periods.length, (i) {
          final isActive = selected == _periods[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => ref.read(dashboardPeriodProvider.notifier).state =
                  _periods[i],
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive
                      ? context.colors.primary.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                ),
                alignment: Alignment.center,
                child: Text(
                  _labels[i],
                  style: text.labelSmall?.copyWith(
                    color: isActive
                        ? context.colors.primary
                        : tokens.textSecondary,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// =============================================================================
// Empty State
// =============================================================================

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.sp5, 0, AppSizes.sp5, 120,
      ),
      children: [
        const SizedBox(height: AppSizes.sp5),
        GlassCard(
          level: GlassLevel.level2,
          padding: const EdgeInsets.all(AppSizes.sp6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BELUM ADA DATA',
                style: text.labelSmall?.copyWith(
                  color: tokens.textTertiary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSizes.sp1 + 2),
              Text('0 kg', style: text.displayLarge),
              const SizedBox(height: AppSizes.sp2),
              Text(
                'Statistik tangkapan & trip akan muncul setelah Anda mulai tracking.',
                style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Dashboard Content (with data)
// =============================================================================

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.sp5, 0, AppSizes.sp5, 120,
      ),
      children: [
        // Hero metric: Total Catch
        _HeroCard(stats: stats),
        const SizedBox(height: AppSizes.sp4),

        // 2x2 metric grid
        _MetricGrid(stats: stats),
        const SizedBox(height: AppSizes.sp4),

        // Bar chart: daily catches
        _CatchBarChart(dailyCatches: stats.dailyCatches),
        const SizedBox(height: AppSizes.sp4),

        // Top 5 spots
        if (stats.topSpots.isNotEmpty) _TopSpotsCard(spots: stats.topSpots),
      ],
    );
  }
}

// =============================================================================
// Hero Card
// =============================================================================

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;

    final catchStr = stats.totalCatchKg < 1000
        ? '${stats.totalCatchKg.toStringAsFixed(1)} kg'
        : '${(stats.totalCatchKg / 1000).toStringAsFixed(2)} ton';

    return GlassCard(
      level: GlassLevel.level2,
      padding: const EdgeInsets.all(AppSizes.sp6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL TANGKAPAN',
            style: text.labelSmall?.copyWith(
              color: tokens.textTertiary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSizes.sp1 + 2),
          Text(
            catchStr,
            style: text.displayLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppSizes.sp2),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.sp3,
              vertical: AppSizes.sp1,
            ),
            decoration: BoxDecoration(
              color: tokens.primarySoft,
              borderRadius: BorderRadius.circular(AppSizes.radiusPill),
            ),
            child: Text(
              '${stats.haulCount} tarikan dalam ${stats.tripCount} trip',
              style: text.labelSmall?.copyWith(
                color: context.colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Metric Grid (2x2)
// =============================================================================

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final distanceKm = stats.totalDistanceMeters / 1000;
    final items = [
      (PhosphorIconsBold.boat, 'Trip', '${stats.tripCount}'),
      (PhosphorIconsBold.arrowsClockwise, 'Tarikan', '${stats.haulCount}'),
      (
        PhosphorIconsBold.path,
        'Jarak',
        '${distanceKm.toStringAsFixed(distanceKm < 10 ? 2 : 1)} km',
      ),
      (
        PhosphorIconsBold.gasPump,
        'BBM',
        '${stats.totalFuelLiters.toStringAsFixed(1)} L',
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSizes.sp3,
      crossAxisSpacing: AppSizes.sp3,
      childAspectRatio: 1.5,
      children: [
        for (final item in items) _MetricTile(item: item),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.item});
  final (IconData, String, String) item;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    final (icon, label, value) = item;

    return GlassCard(
      level: GlassLevel.level1,
      padding: const EdgeInsets.all(AppSizes.sp4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tokens.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: context.colors.primary),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: text.headlineSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: text.labelSmall?.copyWith(color: tokens.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Bar Chart Card
// =============================================================================

class _CatchBarChart extends StatelessWidget {
  const _CatchBarChart({required this.dailyCatches});
  final List<DailyCatch> dailyCatches;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    final primary = context.colors.primary;

    if (dailyCatches.isEmpty) return const SizedBox.shrink();

    // Take last 7 entries max
    final data = dailyCatches.length > 7
        ? dailyCatches.sublist(dailyCatches.length - 7)
        : dailyCatches;

    final maxKg = data.map((e) => e.kg).reduce((a, b) => a > b ? a : b);

    return GlassCard(
      level: GlassLevel.level2,
      padding: const EdgeInsets.all(AppSizes.sp5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TANGKAPAN HARIAN',
            style: text.labelSmall?.copyWith(
              color: tokens.textTertiary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSizes.sp4),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxKg * 1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.length) {
                          return const SizedBox.shrink();
                        }
                        final d = data[idx].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${d.day}/${d.month}',
                            style: text.labelSmall?.copyWith(
                              color: tokens.textTertiary,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(data.length, (i) {
                  final isMax = data[i].kg == maxKg;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: data[i].kg,
                        width: 24,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: isMax
                              ? [
                                  context.colors.secondary.withOpacity(0.5),
                                  context.colors.secondary,
                                ]
                              : [
                                  primary.withOpacity(0.3),
                                  primary,
                                ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Top 5 Spots
// =============================================================================

class _TopSpotsCard extends StatelessWidget {
  const _TopSpotsCard({required this.spots});
  final List<TopSpot> spots;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;

    return GlassCard(
      level: GlassLevel.level2,
      padding: const EdgeInsets.all(AppSizes.sp5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOP SPOT TANGKAPAN',
            style: text.labelSmall?.copyWith(
              color: tokens.textTertiary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSizes.sp4),
          ...List.generate(spots.length, (i) {
            final spot = spots[i];
            return Padding(
              padding: EdgeInsets.only(
                bottom: i < spots.length - 1 ? AppSizes.sp3 : 0,
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: i == 0
                          ? context.colors.secondary.withOpacity(0.15)
                          : tokens.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: text.labelSmall?.copyWith(
                        color: i == 0
                            ? context.colors.secondary
                            : context.colors.primary,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.sp3),
                  Expanded(
                    child: Text(
                      spot.name,
                      style: text.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${spot.catchKg.toStringAsFixed(1)} kg',
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
