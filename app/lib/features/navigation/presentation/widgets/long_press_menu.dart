import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_action_button.dart';

/// Bottom sheet shown when the user long-presses the map: offers
/// "Pandu ke titik ini" and "Tambah penanda di sini" actions at the
/// tapped coordinate.
///
/// Keeps the map's long-press UX terse -- two primary actions, both
/// framed around the coordinate preview so the user can double-check
/// they are targeting the right spot.
class LongPressMenu extends StatelessWidget {
  const LongPressMenu({
    super.key,
    required this.coord,
    required this.onNavigate,
    required this.onAddMarker,
  });

  final LatLng coord;
  final VoidCallback onNavigate;
  final VoidCallback onAddMarker;

  /// Convenience: host the sheet in the shell navigator so AppShell's
  /// bottom-nav padding reaches the content (same pattern as
  /// LocationPermissionSheet / HaulSummarySheet / MarkerInfoSheet).
  static Future<void> show(
    BuildContext context, {
    required LatLng coord,
    required VoidCallback onNavigate,
    required VoidCallback onAddMarker,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LongPressMenu(
        coord: coord,
        onNavigate: onNavigate,
        onAddMarker: onAddMarker,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.sp4,
        right: AppSizes.sp4,
        top: AppSizes.sp4,
        bottom: bottomSafe + AppSizes.sp4,
      ),
      child: GlassCard(
        level: GlassLevel.level3,
        padding: const EdgeInsets.fromLTRB(
          AppSizes.sp5,
          AppSizes.sp3,
          AppSizes.sp5,
          AppSizes.sp5,
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
            Text(
              'Titik Peta',
              style: text.titleMedium,
            ),
            const SizedBox(height: AppSizes.sp1),
            Row(
              children: [
                Icon(
                  PhosphorIconsRegular.crosshair,
                  size: 14,
                  color: tokens.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatCoords(coord),
                  style: text.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sp5),
            PrimaryActionButton(
              label: 'Pandu ke titik ini',
              icon: PhosphorIconsBold.navigationArrow,
              onPressed: onNavigate,
            ),
            const SizedBox(height: AppSizes.sp2),
            OutlinedButton.icon(
              onPressed: onAddMarker,
              icon: const Icon(PhosphorIconsBold.mapPinPlus, size: 18),
              label: const Text('Tambah penanda di sini'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSizes.sp3),
              ),
            ),
            const SizedBox(height: AppSizes.sp1),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Batal',
                style: text.labelMedium?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCoords(LatLng c) {
    final lat = c.latitude.toStringAsFixed(5);
    final lng = c.longitude.toStringAsFixed(5);
    return '$lat, $lng';
  }
}
