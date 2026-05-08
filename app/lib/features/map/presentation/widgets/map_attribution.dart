import 'package:flutter/material.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';

/// OpenStreetMap & OpenSeaMap attribution.
/// Required by the respective Tile Usage Policies.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return GlassCard(
      level: GlassLevel.level1,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sp2 + 2,
        vertical: 4,
      ),
      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      elevated: false,
      child: Text(
        '© OpenStreetMap · OpenSeaMap',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
          color: tokens.textTertiary,
        ),
      ),
    );
  }
}
