import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../application/all_history_visible_provider.dart';
import '../../application/history_overlay_providers.dart';
import '../../application/map_camera_controller.dart';

/// Overlay controls shown at the bottom of the map while
/// `MapMode == viewingHistory`.
///
/// Provides:
/// - A toggle to turn the history overlay off.
/// - A "Paskan semua" (fit all) button that calls
///   [MapCameraController.fitCameraExplicit] to re-fit the camera to the
///   overlay bounds regardless of whether the user has panned (AC 2.5).
/// - Future: a filter dropdown (per trip / per date range).
///
/// This widget is placed inside the `AnimatedSwitcher` at the bottom of
/// `MapScreen` when `mapModeProvider == MapMode.viewingHistory`.
///
/// _Requirements: 2.5, 4.7, 4.8_
class HistoryOverlayControls extends ConsumerWidget {
  const HistoryOverlayControls({
    super.key,
    required this.cameraController,
    this.overlayBounds,
  });

  /// The camera controller that manages viewport fitting.
  final MapCameraController cameraController;

  /// Current overlay bounds. If null, the "Paskan semua" button is
  /// disabled (the overlay has no renderable data — AC 2.7).
  final dynamic overlayBounds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final text = context.text;
    final allHistoryOn = ref.watch(allHistoryVisibleProvider);
    final overlayAsync = ref.watch(allHistoryRenderProvider);

    return GlassCard(
      level: GlassLevel.level2,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sp3,
        vertical: AppSizes.sp2 + 2,
      ),
      child: Row(
        children: [
          // History icon indicator
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tokens.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              PhosphorIconsFill.footprints,
              size: 18,
              color: context.colors.primary,
            ),
          ),
          const SizedBox(width: AppSizes.sp2),

          // Label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Riwayat Jejak',
                  style: text.titleSmall?.copyWith(fontSize: 13),
                ),
                overlayAsync.when(
                  data: (render) => Text(
                    render.isEmpty
                        ? 'Tidak ada data'
                        : '${render.sourceHaulCount} tarikan',
                    style: text.bodySmall?.copyWith(
                      color: tokens.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                  loading: () => Text(
                    'Memuat…',
                    style: text.bodySmall?.copyWith(
                      color: tokens.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                  error: (_, __) => Text(
                    'Gagal memuat',
                    style: text.bodySmall?.copyWith(
                      color: tokens.danger,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Fit-all button
          _ControlButton(
            icon: PhosphorIconsBold.arrowsOut,
            tooltip: 'Paskan semua',
            onTap: () {
              final bounds =
                  overlayAsync.asData?.value.bounds;
              if (bounds != null) {
                cameraController.fitCameraExplicit(bounds);
              }
            },
          ),
          const SizedBox(width: 4),

          // Close / toggle off button
          _ControlButton(
            icon: PhosphorIconsRegular.x,
            tooltip: 'Tutup overlay',
            onTap: () {
              ref.read(allHistoryVisibleProvider.notifier).state = false;
            },
          ),
        ],
      ),
    );
  }
}

/// Small icon button used in the controls row.
class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}
