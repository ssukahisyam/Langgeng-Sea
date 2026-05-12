import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/services/gps_reading.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../application/current_reading_provider.dart';

/// Floating chip that shows current GPS accuracy with color coding.
/// PRD FR-03.9: warn if accuracy > 20m.
class GpsAccuracyChip extends ConsumerWidget {
  const GpsAccuracyChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final text = context.text;

    final reading = ref.watch(currentReadingProvider).asData?.value;
    final tier = reading.accuracyTier;

    final (color, icon, label) = switch (tier) {
      GpsAccuracyTier.good => (
          tokens.success,
          PhosphorIconsBold.crosshair,
          Formatters.accuracy(reading?.accuracyMeters),
        ),
      GpsAccuracyTier.medium => (
          tokens.warning,
          PhosphorIconsBold.crosshair,
          Formatters.accuracy(reading?.accuracyMeters),
        ),
      GpsAccuracyTier.poor => (
          tokens.danger,
          PhosphorIconsBold.warningCircle,
          Formatters.accuracy(reading?.accuracyMeters),
        ),
      GpsAccuracyTier.unknown => (
          tokens.textTertiary,
          PhosphorIconsRegular.crosshair,
          'GPS…',
        ),
    };

    return GlassCard(
      level: GlassLevel.level1,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sp3,
        vertical: AppSizes.sp2,
      ),
      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      elevated: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tier == GpsAccuracyTier.unknown)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            )
          else
            Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: text.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
