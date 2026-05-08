import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;

    return AmbientBackground(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.sp5,
            AppSizes.sp4,
            AppSizes.sp5,
            120, // leave room for bottom nav
          ),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppStrings.tabDashboard, style: text.headlineLarge),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(PhosphorIconsRegular.export),
                ),
              ],
            ),
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
                  Text(
                    '0 kg',
                    style: text.displayLarge,
                  ),
                  const SizedBox(height: AppSizes.sp2),
                  Text(
                    'Statistik tangkapan & trip akan muncul setelah Anda mulai tracking.',
                    style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.sp4),
            _MetricPlaceholderGrid(),
          ],
        ),
      ),
    );
  }
}

class _MetricPlaceholderGrid extends StatelessWidget {
  const _MetricPlaceholderGrid();

  @override
  Widget build(BuildContext context) {
    final items = [
      (PhosphorIconsBold.boat, 'Trip', '0'),
      (PhosphorIconsBold.arrowsClockwise, 'Haul', '0'),
      (PhosphorIconsBold.path, 'Jarak', '0 km'),
      (PhosphorIconsBold.gasPump, 'BBM', '0 L'),
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
              Text(value, style: text.headlineSmall),
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
