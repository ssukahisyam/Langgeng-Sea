import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/permissions/tracking_permissions_provider.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';

/// Card "Status Perangkat" di Settings yang menggabungkan status &
/// toggle untuk 3 permission tracking-related: Lokasi, Notifikasi,
/// Hemat Daya.
///
/// PR #41 — sebelumnya cuma ada `BatteryOptimizationTile` standalone
/// di tengah-tengah Tools card, dan tidak ada surface sama sekali
/// untuk Notifikasi. User komplain tidak ada feedback jelas apakah
/// permission sudah diizinkan atau belum.
///
/// Card ini:
/// - Render switch toggle per permission. Saat granted, tombol
///   posisi ON (tap → buka Settings sistem untuk revoke); saat
///   denied/permanentlyDenied, posisi OFF (tap → trigger request
///   atau buka Settings).
/// - Background warning (orange-ish surface) saat ada permission
///   wajib (Lokasi/Notifikasi) yang belum granted.
/// - Reactive ke `trackingPermissionsProvider` — update otomatis
///   saat user balik dari Settings sistem.
class DeviceStatusCard extends ConsumerWidget {
  const DeviceStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final text = context.text;
    final state = ref.watch(trackingPermissionsProvider);
    final hasIssue =
        !state.allRequired || (Platform.isAndroid && !state.battery.isGranted);

    return GlassCard(
      level: GlassLevel.level2,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          // Soft warning background saat ada masalah supaya card
          // menarik perhatian. Saat semua granted, transparan.
          color: hasIssue
              ? tokens.warning.withValues(alpha: 0.06)
              : Colors.transparent,
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSizes.sp4,
          AppSizes.sp3,
          AppSizes.sp4,
          AppSizes.sp3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  hasIssue
                      ? PhosphorIconsBold.warningCircle
                      : PhosphorIconsBold.shieldCheck,
                  size: 18,
                  color: hasIssue ? tokens.warning : context.colors.primary,
                ),
                const SizedBox(width: AppSizes.sp2),
                Text(
                  'Status Perangkat',
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sp3),
            _PermissionRow(
              icon: PhosphorIconsBold.mapPin,
              title: 'Lokasi GPS',
              description: 'Wajib untuk merekam jejak tarikan',
              status: state.location,
              onRequest: () => ref
                  .read(trackingPermissionsProvider.notifier)
                  .requestLocation(),
              required: true,
            ),
            const SizedBox(height: AppSizes.sp2),
            _PermissionRow(
              icon: PhosphorIconsBold.bell,
              title: 'Notifikasi',
              description: 'Tampilkan indikator tracking aktif',
              status: state.notification,
              onRequest: () => ref
                  .read(trackingPermissionsProvider.notifier)
                  .requestNotification(),
              required: true,
            ),
            if (Platform.isAndroid) ...[
              const SizedBox(height: AppSizes.sp2),
              _PermissionRow(
                icon: PhosphorIconsBold.lightning,
                title: 'Hemat Daya',
                description: 'Akurasi GPS saat layar mati',
                status: state.battery,
                onRequest: () => ref
                    .read(trackingPermissionsProvider.notifier)
                    .requestBattery(),
                required: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    required this.onRequest,
    required this.required,
  });

  final IconData icon;
  final String title;
  final String description;
  final PermissionStatus status;
  final Future<PermissionStatus> Function() onRequest;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    final text = context.text;
    final granted = status.isGranted;
    final permanentlyDenied = status.isPermanentlyDenied;

    final iconColor = granted
        ? colors.primary
        : (permanentlyDenied ? tokens.danger : tokens.textSecondary);
    final iconBg = granted
        ? tokens.primarySoft
        : (permanentlyDenied
            ? tokens.danger.withValues(alpha: 0.10)
            : tokens.surface1);

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: AppSizes.sp3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(title, style: text.labelMedium),
                  if (required) ...[
                    const SizedBox(width: 6),
                    Text(
                      '*',
                      style: text.labelSmall?.copyWith(
                        color: tokens.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _statusSubtitle(status, description),
                style: text.bodySmall?.copyWith(
                  color: tokens.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSizes.sp2),
        _PermissionToggle(
          status: status,
          onTap: () async {
            if (status.isPermanentlyDenied || status.isGranted) {
              // Permanent denied → harus dari Settings sistem.
              // Granted → user mungkin mau cabut, juga lewat Settings.
              await openAppSettings();
            } else {
              await onRequest();
            }
          },
        ),
      ],
    );
  }

  String _statusSubtitle(PermissionStatus status, String description) {
    if (status.isGranted) return 'Aktif — $description';
    if (status.isPermanentlyDenied) {
      return 'Diblokir di pengaturan — ketuk untuk membuka';
    }
    return description;
  }
}

class _PermissionToggle extends StatelessWidget {
  const _PermissionToggle({
    required this.status,
    required this.onTap,
  });

  final PermissionStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    final granted = status.isGranted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: granted ? colors.primary : tokens.surface1,
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          border: Border.all(
            color: granted ? colors.primary : tokens.border,
            width: 1,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          alignment: granted ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
