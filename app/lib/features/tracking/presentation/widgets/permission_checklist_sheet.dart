import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/permissions/permission_settings_launcher.dart';
import '../../../../core/permissions/tracking_permissions_provider.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_action_button.dart';

/// Bottom sheet checklist permission yang otomatis muncul saat user
/// tap MULAI di map screen kalau ada permission yang belum granted.
///
/// PR #41 — sebelumnya request battery exemption dilakukan
/// fire-and-forget tanpa UI feedback. User sering tidak ngeh ada
/// dialog OS yang muncul, atau dismiss tanpa memahami konsekuensinya.
/// Sekarang gating eksplisit dengan checklist visual.
///
/// Flow:
/// 1. User tap MULAI di map.
/// 2. Caller cek `trackingPermissionsProvider.allRequired`. Kalau
///    sudah complete, langsung start tracking — sheet tidak muncul.
/// 3. Kalau ada yang missing, caller buka sheet ini.
/// 4. User tap "Izinkan" per row → trigger request OS.
/// 5. Tombol "Lanjut Mulai Tracking" enable saat semua wajib granted.
/// 6. User tap tombol → sheet pop dengan return value `true`,
///    caller lanjut start tracking.
/// 7. User tap "Tutup" / dismiss → sheet pop dengan `false`,
///    caller batalkan start.
class PermissionChecklistSheet extends ConsumerWidget {
  const PermissionChecklistSheet({super.key});

  /// Helper untuk caller. Buka sheet dan return apakah user sudah
  /// grant cukup untuk lanjut start tracking.
  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PermissionChecklistSheet(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final text = context.text;
    final state = ref.watch(trackingPermissionsProvider);
    final canProceed = state.allRequired;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.sp4,
        right: AppSizes.sp4,
        top: AppSizes.sp4,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.sp4,
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
              'Izin yang Dibutuhkan',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSizes.sp2),
            Text(
              'Aktifkan izin ini supaya tracking bisa jalan akurat & '
              'tetap merekam saat layar mati.',
              style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: AppSizes.sp4),
            _ChecklistRow(
              icon: PhosphorIconsBold.mapPin,
              title: 'Lokasi GPS',
              description: 'Untuk merekam jejak tarikan',
              status: state.location,
              permission: Permission.location,
              required: true,
              onTap: () => ref
                  .read(trackingPermissionsProvider.notifier)
                  .requestLocation(),
            ),
            const SizedBox(height: AppSizes.sp2),
            _ChecklistRow(
              icon: PhosphorIconsBold.bell,
              title: 'Notifikasi',
              description: 'Indikator tracking aktif di status bar',
              status: state.notification,
              permission: Permission.notification,
              required: true,
              onTap: () => ref
                  .read(trackingPermissionsProvider.notifier)
                  .requestNotification(),
            ),
            if (Platform.isAndroid) ...[
              const SizedBox(height: AppSizes.sp2),
              _ChecklistRow(
                icon: PhosphorIconsBold.lightning,
                title: 'Hemat Daya',
                description: 'Akurasi GPS saat layar mati '
                    '(opsional tapi sangat dianjurkan)',
                status: state.battery,
                permission: Permission.ignoreBatteryOptimizations,
                required: false,
                onTap: () => ref
                    .read(trackingPermissionsProvider.notifier)
                    .requestBattery(),
              ),
            ],
            const SizedBox(height: AppSizes.sp5),
            PrimaryActionButton(
              label: canProceed
                  ? 'Lanjut Mulai Tracking'
                  : 'Aktifkan izin di atas dulu',
              icon: canProceed
                  ? PhosphorIconsFill.checkCircle
                  : PhosphorIconsBold.warningCircle,
              onPressed:
                  canProceed ? () => Navigator.of(context).pop(true) : null,
            ),
            const SizedBox(height: AppSizes.sp2),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Tutup',
                style: text.labelMedium?.copyWith(color: tokens.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    required this.permission,
    required this.required,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final PermissionStatus status;
  final Permission permission;
  final bool required;
  final Future<PermissionStatus> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    final text = context.text;
    final granted = status.isGranted;
    final permanentlyDenied = status.isPermanentlyDenied;

    return GlassCard(
      level: GlassLevel.level1,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sp3,
        vertical: AppSizes.sp3,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: granted
                  ? tokens.primarySoft
                  : (permanentlyDenied
                      ? tokens.danger.withValues(alpha: 0.10)
                      : tokens.accentSoft),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: granted
                  ? colors.primary
                  : (permanentlyDenied ? tokens.danger : tokens.textSecondary),
            ),
          ),
          const SizedBox(width: AppSizes.sp3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: text.labelLarge,
                      ),
                    ),
                    if (!required)
                      Text(
                        'Opsional',
                        style: text.labelSmall?.copyWith(
                          color: tokens.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: text.bodySmall?.copyWith(
                    color: tokens.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sp2),
          if (granted)
            Icon(
              PhosphorIconsFill.checkCircle,
              size: 24,
              color: colors.primary,
            )
          else
            _GrantButton(
              permanentlyDenied: permanentlyDenied,
              onTap: () async {
                if (permanentlyDenied) {
                  // PR #43: deep-link ke halaman permission spesifik.
                  await PermissionSettingsLauncher.open(permission);
                } else {
                  await onTap();
                }
              },
            ),
        ],
      ),
    );
  }
}

class _GrantButton extends StatelessWidget {
  const _GrantButton({
    required this.permanentlyDenied,
    required this.onTap,
  });

  final bool permanentlyDenied;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.sp3,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            gradient: tokens.primaryGradient,
            borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          ),
          child: Text(
            permanentlyDenied ? 'Buka Settings' : 'Izinkan',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
