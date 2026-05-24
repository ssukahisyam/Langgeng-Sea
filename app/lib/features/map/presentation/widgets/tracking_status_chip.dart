import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/permissions/tracking_permissions_provider.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../tracking/application/tracking_controller.dart';
import '../../../tracking/data/background_tracking_service.dart';
import '../../../tracking/presentation/widgets/permission_checklist_sheet.dart';

/// Chip kecil yang menunjukkan status background tracking saat
/// haul aktif sedang merekam.
///
/// PR #41 — sebelumnya `LiveStatsPanel` cuma menampilkan indikator
/// "MEREKAM" tanpa info apakah background service / battery
/// exemption sehat. User tidak ada cara untuk tahu kalau tracking
/// degraded atau kalau permission diam-diam dicabut.
///
/// State:
/// - **BG aktif** (hijau): foreground service running + battery
///   granted. Tracking optimal saat layar mati.
/// - **BG terbatas** (kuning): service running tapi battery
///   exemption denied. Tracking jalan tapi mungkin throttled saat
///   layar mati. Tap → buka [PermissionChecklistSheet].
/// - **BG mengulang** (kuning + spinner): service sedang restarting
///   setelah crash. Auto-recover.
/// - **BG gagal** (merah): service stopped/failed. Tap → trigger
///   restart attempt via TrackingController.
/// - **Memulai** (abu + spinner): service masih starting up.
///
/// Widget self-hide kalau tidak sedang recording — chip hanya
/// relevan saat haul aktif.
class TrackingStatusChip extends ConsumerWidget {
  const TrackingStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingState = ref.watch(trackingControllerProvider);
    if (!trackingState.isRecording) {
      return const SizedBox.shrink();
    }

    final perms = ref.watch(trackingPermissionsProvider);
    final bgStatus = trackingState.backgroundStatus;
    final tokens = context.tokens;
    final text = context.text;

    final visual = _resolveVisual(
      bgStatus: bgStatus,
      batteryGranted: perms.battery.isGranted,
      tokens: tokens,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleTap(context, bgStatus, perms.battery.isGranted),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sp2,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: visual.background,
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          border: Border.all(
            color: visual.foreground.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (visual.spinner)
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: visual.foreground,
                ),
              )
            else
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: visual.foreground,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: 6),
            Text(
              visual.label,
              style: text.labelSmall?.copyWith(
                color: visual.foreground,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _ChipVisual _resolveVisual({
    required BackgroundTrackingStatus bgStatus,
    required bool batteryGranted,
    required dynamic tokens,
  }) {
    switch (bgStatus) {
      case BackgroundTrackingStatus.starting:
        return _ChipVisual(
          label: 'MEMULAI',
          foreground: tokens.textSecondary as Color,
          background: tokens.surface1 as Color,
          spinner: true,
        );
      case BackgroundTrackingStatus.running:
        if (batteryGranted) {
          return _ChipVisual(
            label: 'BG AKTIF',
            foreground: const Color(0xFF14B86A),
            background: const Color(0xFF14B86A).withValues(alpha: 0.12),
            spinner: false,
          );
        }
        return _ChipVisual(
          label: 'BG TERBATAS',
          foreground: tokens.warning as Color,
          background: (tokens.warning as Color).withValues(alpha: 0.14),
          spinner: false,
        );
      case BackgroundTrackingStatus.restarting:
        return _ChipVisual(
          label: 'MENGULANG',
          foreground: tokens.warning as Color,
          background: (tokens.warning as Color).withValues(alpha: 0.14),
          spinner: true,
        );
      case BackgroundTrackingStatus.failed:
        return _ChipVisual(
          label: 'BG GAGAL',
          foreground: tokens.danger as Color,
          background: (tokens.danger as Color).withValues(alpha: 0.14),
          spinner: false,
        );
      case BackgroundTrackingStatus.stopped:
        return _ChipVisual(
          label: 'BG STOP',
          foreground: tokens.textTertiary as Color,
          background: tokens.surface1 as Color,
          spinner: false,
        );
    }
  }

  Future<void> _handleTap(
    BuildContext context,
    BackgroundTrackingStatus bgStatus,
    bool batteryGranted,
  ) async {
    // Untuk semua kondisi non-optimal, buka checklist sheet supaya
    // user bisa lihat permission mana yang missing dan grant ulang.
    if (!batteryGranted ||
        bgStatus == BackgroundTrackingStatus.failed ||
        bgStatus == BackgroundTrackingStatus.stopped) {
      await PermissionChecklistSheet.show(context);
    }
  }
}

class _ChipVisual {
  const _ChipVisual({
    required this.label,
    required this.foreground,
    required this.background,
    required this.spinner,
  });

  final String label;
  final Color foreground;
  final Color background;
  final bool spinner;
}
