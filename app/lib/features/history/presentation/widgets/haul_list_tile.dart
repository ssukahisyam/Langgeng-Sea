import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../tracking/domain/entities/haul.dart';

/// Single-line row used in the trip detail to list that trip's hauls.
/// The colored bar on the left matches the polyline color on the map
/// above so users can cross-reference at a glance.
class HaulListTile extends StatelessWidget {
  const HaulListTile({
    super.key,
    required this.haul,
    required this.onTap,
  });

  final Haul haul;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    final color = AppColors.colorForHaul(haul.orderIndex);

    return GlassCard(
      level: GlassLevel.level2,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.sp3,
        AppSizes.sp3 + 2,
        AppSizes.sp3,
        AppSizes.sp3 + 2,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: AppSizes.sp3 + 2),
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
                const SizedBox(height: 3),
                Text(
                  _subtitle(),
                  style: text.bodySmall?.copyWith(
                    color: tokens.textTertiary,
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          if (haul.status == HaulStatus.recording) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sp2,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: tokens.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.radiusPill),
              ),
              child: Text(
                'REKAMAN',
                style: text.labelSmall?.copyWith(
                  color: tokens.danger,
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.sp2),
          ],
          Icon(
            PhosphorIconsRegular.caretRight,
            size: 16,
            color: tokens.textTertiary,
          ),
        ],
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[];
    final started = Formatters.wallClock(haul.startedAt);
    final ended = haul.endedAt != null
        ? Formatters.wallClock(haul.endedAt!)
        : '…';
    parts.add('$started - $ended');
    parts.add(Formatters.distance(haul.distanceMeters));
    if (haul.avgSpeedKnots != null) {
      parts.add(Formatters.knots(haul.avgSpeedKnots));
    }
    return parts.join(' · ');
  }
}
