import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../../history/presentation/widgets/delete_confirm_dialog.dart';
import '../../data/marker_repository.dart';
import '../../domain/entities/marker.dart';

/// Bottom sheet surfaced when the user taps a marker pin on the live
/// map. Shows category, name, formatted coords, notes, plus actions
/// to close or delete.
///
/// Hosted in the shell navigator (same pattern as
/// [LocationPermissionSheet] and [HaulSummarySheet]) so AppShell's
/// injected bottom padding reaches this sheet and it doesn't run
/// under the floating bottom nav.
class MarkerInfoSheet {
  MarkerInfoSheet._();

  static Future<void> show(BuildContext context, AppMarker marker) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MarkerInfoBody(marker: marker),
    );
  }
}

class _MarkerInfoBody extends ConsumerWidget {
  const _MarkerInfoBody({required this.marker});

  final AppMarker marker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final text = context.text;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    final color = _categoryColor(context, marker.category);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.sp4,
        right: AppSizes.sp4,
        top: AppSizes.sp4,
        bottom: bottomInset + bottomSafe + AppSizes.sp4,
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

            // Category pill
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.sp3,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _categoryIcon(marker.category),
                        size: 12,
                        color: color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        marker.category.displayLabel.toUpperCase(),
                        style: text.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(PhosphorIconsRegular.x, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sp3),

            // Name
            Text(
              marker.name,
              style: text.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSizes.sp2),

            // Coords
            Row(
              children: [
                Icon(
                  PhosphorIconsRegular.crosshair,
                  size: 14,
                  color: tokens.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatCoords(marker),
                  style: text.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),

            // Notes (optional)
            if (marker.notes != null && marker.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSizes.sp3),
              Container(
                padding: const EdgeInsets.all(AppSizes.sp3),
                decoration: BoxDecoration(
                  color: tokens.surface1,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  border: Border.all(color: tokens.border),
                ),
                child: Text(
                  marker.notes!.trim(),
                  style: text.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppSizes.sp5),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _onDeletePressed(context, ref),
                    icon: Icon(
                      PhosphorIconsBold.trash,
                      size: 18,
                      color: tokens.danger,
                    ),
                    label: Text(
                      'Hapus',
                      style: text.labelLarge?.copyWith(
                        color: tokens.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: tokens.danger),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSizes.sp3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.sp2),
                Expanded(
                  child: PrimaryActionButton(
                    label: 'Tutup',
                    icon: PhosphorIconsBold.checkCircle,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onDeletePressed(BuildContext context, WidgetRef ref) async {
    final confirmed = await DeleteConfirmDialog.show(
      context,
      title: 'Hapus Penanda?',
      body:
          'Penanda "${marker.name}" akan dihapus. Tindakan ini tidak dapat '
          'dibatalkan.',
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(markerRepositoryProvider).delete(marker.id);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  String _formatCoords(AppMarker m) {
    final lat = m.latitude.toStringAsFixed(5);
    final lng = m.longitude.toStringAsFixed(5);
    return '$lat, $lng';
  }

  Color _categoryColor(BuildContext context, MarkerCategory cat) {
    final tokens = context.tokens;
    return switch (cat) {
      MarkerCategory.productive => tokens.success,
      MarkerCategory.hazard => tokens.danger,
      MarkerCategory.port => context.colors.primary,
      MarkerCategory.other => tokens.textSecondary,
    };
  }

  /// Category icon mirrored from MarkerPin / MarkersListScreen so the
  /// info sheet pill reads the same as the map pin and the list tile.
  IconData _categoryIcon(MarkerCategory cat) => switch (cat) {
        MarkerCategory.productive => PhosphorIconsFill.fishSimple,
        MarkerCategory.hazard => PhosphorIconsFill.warning,
        MarkerCategory.port => PhosphorIconsFill.anchor,
        MarkerCategory.other => PhosphorIconsFill.mapPin,
      };
}
