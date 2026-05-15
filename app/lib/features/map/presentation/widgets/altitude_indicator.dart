import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/services/gps_reading.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';

/// Compact pill that shows the current GPS altitude in meters.
///
/// Sits in the top-left indicator column right under the map scale so
/// the user can read both the horizontal scale ("how far across is
/// this view") and the vertical altitude ("how high am I") at a
/// glance. Renders nothing when there is no usable altitude reading
/// yet — we explicitly avoid showing "Alt: 0 m" because that's almost
/// always wrong (it's the default value when the GPS chip hasn't
/// reported an altitude yet).
class AltitudeIndicator extends StatelessWidget {
  const AltitudeIndicator({
    super.key,
    required this.reading,
  });

  final GpsReading? reading;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;

    final altitude = reading?.altitudeMeters;
    if (altitude == null || altitude.isNaN || !altitude.isFinite) {
      return const SizedBox.shrink();
    }

    // Round to whole meters — sub-meter precision is misleading at the
    // accuracy levels typical of consumer GPS chips (±5–15 m).
    // Label clarifies this is altitude (MDPL) NOT zoom level.
    final meters = altitude.round();
    final label = 'MDPL $meters m';

    return GlassCard(
      level: GlassLevel.level2,
      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sp2 + 2,
        vertical: 4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIconsBold.mountains,
            size: 12,
            color: tokens.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: text.labelSmall?.copyWith(
              color: tokens.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
