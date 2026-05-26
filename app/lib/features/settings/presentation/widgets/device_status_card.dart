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

/// Card "Status Perangkat" di Settings yang menampilkan status &
/// aksi untuk 3 permission tracking-related: Lokasi, Notifikasi,
/// Hemat Daya.
///
/// PR #41 — first version pakai toggle switch per permission.
///
/// PR #42 — toggle switch diganti **badge status + tombol aksi**.
/// Alasan: OS Android & iOS tidak izinkan app revoke permission yang
/// sudah granted (tidak ada API). Toggle switch implies "tap = beralih
/// instan" — itu misleading karena yang sebenarnya terjadi adalah
/// app me-redirect ke Settings sistem. Sekarang representasi visual
/// lebih jujur:
///
/// - **Granted**: badge hijau "Aktif" + tombol "Atur" → dialog
///   konfirmasi cabut, lalu `openAppSettings()`.
/// - **Denied**: badge kuning "Belum" + tombol "Izinkan" → dialog
///   OS native muncul.
/// - **PermanentlyDenied**: badge merah "Diblokir" + tombol
///   "Buka Settings" → langsung redirect (dialog OS sudah tidak
///   muncul setelah permanent deny).
///
/// Card otomatis di-warn (background orange) saat ada permission
/// wajib (Lokasi/Notifikasi) atau opsional (Battery di Android)
/// yang belum granted. Reactive ke `trackingPermissionsProvider` —
/// auto-update saat user balik dari Settings sistem.
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
              permission: Permission.location,
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
              permission: Permission.notification,
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
                permission: Permission.ignoreBatteryOptimizations,
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
    required this.permission,
    required this.onRequest,
    required this.required,
  });

  final IconData icon;
  final String title;
  final String description;
  final PermissionStatus status;
  final Permission permission;
  final Future<PermissionStatus> Function() onRequest;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    final text = context.text;
    final granted = status == PermissionStatus.granted;
    final permanentlyDenied = status == PermissionStatus.permanentlyDenied;

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
                  Flexible(
                    child: Text(
                      title,
                      style: text.labelMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
                  const SizedBox(width: AppSizes.sp2),
                  _StatusBadge(status: status),
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
        _ActionButton(
          status: status,
          permission: permission,
          permissionLabel: title,
          onRequest: onRequest,
        ),
      ],
    );
  }
}

/// Badge kecil yang menunjukkan status permission (Aktif / Belum /
/// Diblokir) dengan icon + warna sesuai.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final PermissionStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    final granted = status == PermissionStatus.granted;
    final permanentlyDenied = status == PermissionStatus.permanentlyDenied;

    final IconData icon;
    final Color color;
    final String label;

    if (granted) {
      icon = PhosphorIconsFill.checkCircle;
      color = colors.primary;
      label = 'Aktif';
    } else if (permanentlyDenied) {
      icon = PhosphorIconsFill.xCircle;
      color = tokens.danger;
      label = 'Diblokir';
    } else {
      icon = PhosphorIconsFill.warningCircle;
      color = tokens.warning;
      label = 'Belum';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Tombol aksi kontekstual sesuai status:
/// - Granted → "Atur" (buka dialog konfirmasi cabut, lalu redirect)
/// - Denied → "Izinkan" (langsung trigger request OS)
/// - PermanentlyDenied → "Buka Settings" (langsung redirect, dialog
///   OS sudah tidak muncul karena user pernah pilih "Don't ask")
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.status,
    required this.permission,
    required this.permissionLabel,
    required this.onRequest,
  });

  final PermissionStatus status;

  /// Permission identity untuk dipakai pilih intent deep-link yang
  /// tepat (notif → ACTION_APP_NOTIFICATION_SETTINGS, battery →
  /// ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS, dll).
  final Permission permission;

  /// Label permission untuk dipakai di copy dialog konfirmasi.
  /// Mis. "Lokasi GPS", "Notifikasi", "Hemat Daya".
  final String permissionLabel;

  final Future<PermissionStatus> Function() onRequest;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    final granted = status == PermissionStatus.granted;
    final permanentlyDenied = status == PermissionStatus.permanentlyDenied;

    final String label;
    if (granted) {
      label = 'Atur';
    } else if (permanentlyDenied) {
      label = 'Buka Settings';
    } else {
      label = 'Izinkan';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleTap(context),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.sp3,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            // Granted = outlined (less attention-grabbing).
            // Denied / permanentlyDenied = filled primary (CTA).
            color: granted ? Colors.transparent : colors.primary,
            borderRadius: BorderRadius.circular(AppSizes.radiusPill),
            border: Border.all(
              color: granted ? tokens.border : colors.primary,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: granted ? tokens.textSecondary : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    final granted = status == PermissionStatus.granted;
    final permanentlyDenied = status == PermissionStatus.permanentlyDenied;

    if (granted) {
      // Tap "Atur" pada permission granted = user mau cabut. Tampilkan
      // dialog konfirmasi dulu supaya user paham akan ke Settings
      // sistem (tidak ada API in-app untuk revoke).
      final confirmed = await _RevokePermissionDialog.show(
        context,
        permissionLabel: permissionLabel,
        permission: permission,
      );
      if (confirmed && context.mounted) {
        // PR #43: pakai PermissionSettingsLauncher supaya user
        // dilempar ke halaman permission spesifik (notif → halaman
        // notifikasi, battery → halaman battery optimization).
        // Untuk lokasi tetap fallback ke App Info umum karena
        // Android tidak punya intent spesifik untuk itu.
        await PermissionSettingsLauncher.open(permission);
      }
    } else if (permanentlyDenied) {
      // PermanentlyDenied = user pernah pilih "Don't ask again".
      // Dialog OS sudah tidak akan muncul lagi. Langsung redirect
      // ke halaman permission spesifik tanpa konfirmasi.
      await PermissionSettingsLauncher.open(permission);
    } else {
      // Denied biasa = user belum pernah respond, atau pilih "Deny"
      // tanpa "Don't ask again". Trigger request OS — dialog akan
      // muncul.
      await onRequest();
    }
  }
}

/// Dialog konfirmasi sebelum redirect ke Settings sistem untuk
/// mencabut permission yang sudah granted.
///
/// Reusable: terima `permissionLabel` untuk personalize copy.
/// Return `true` kalau user tap "Buka Settings", `false` kalau
/// "Batal" atau dismiss.
///
/// PR #43 — copy step-by-step disesuaikan per [Permission] supaya
/// instruksi-nya akurat. Untuk Notifikasi & Battery, deep-link
/// langsung ke halaman yang relevan (user cuma perlu tap toggle).
/// Untuk Lokasi (atau permission lain tanpa intent spesifik), user
/// masih perlu navigasi via Permissions menu.
class _RevokePermissionDialog extends StatelessWidget {
  const _RevokePermissionDialog({
    required this.permissionLabel,
    required this.permission,
  });

  final String permissionLabel;
  final Permission permission;

  static Future<bool> show(
    BuildContext context, {
    required String permissionLabel,
    required Permission permission,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _RevokePermissionDialog(
        permissionLabel: permissionLabel,
        permission: permission,
      ),
    );
    return result ?? false;
  }

  /// Steps yang ditampilkan tergantung deep-link availability.
  ///
  /// - Notifikasi → langsung ke halaman notifikasi app (1 step)
  /// - Battery → langsung ke halaman battery optimization (2 step)
  /// - Lokasi/lainnya → App Info umum, butuh navigasi tambahan
  List<String> _stepsForPermission() {
    switch (permission) {
      case Permission.notification:
        return [
          'Tap toggle "Allow notifications" / "Tampilkan notifikasi"',
          'Konfirmasi pilihan',
        ];
      case Permission.ignoreBatteryOptimizations:
        return [
          'Cari "Langgeng Sea" di daftar app',
          'Pilih "Optimized" atau "Restricted"',
        ];
      default:
        // Lokasi & lainnya — tidak ada intent spesifik.
        return [
          'Tap menu "Permissions" / "Izin"',
          'Pilih "$permissionLabel"',
          'Tap "Don\'t allow" / "Tolak"',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    final steps = _stepsForPermission();

    return AlertDialog(
      backgroundColor: tokens.surface3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      icon: Icon(
        PhosphorIconsFill.warningCircle,
        size: 36,
        color: tokens.warning,
      ),
      title: Text(
        'Cabut Izin $permissionLabel?',
        style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aplikasi tidak bisa mencabut izin secara langsung — ini '
            'aturan dari sistem operasi.',
            style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: AppSizes.sp3),
          Text(
            'Anda akan dialihkan ke halaman pengaturan yang relevan. '
            'Cara mencabut di sana:',
            style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: AppSizes.sp2),
          for (var i = 0; i < steps.length; i++)
            _Step(number: '${i + 1}', text: steps[i]),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Batal',
            style: text.labelMedium?.copyWith(color: tokens.textSecondary),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: context.colors.primary,
          ),
          child: const Text('Buka Settings'),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = context.text;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: tokens.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: context.colors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.sp2),
          Expanded(
            child: Text(
              text,
              style: theme.bodySmall?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
