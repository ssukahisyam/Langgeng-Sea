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

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sp2 + 2,
        vertical: 4,
      ),
      child: Text(
        '© OpenStreetMap · OpenSeaMap',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
          color: Colors.white70,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}
