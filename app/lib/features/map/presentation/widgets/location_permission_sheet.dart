import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../providers/location_permission_provider.dart';

/// Bottom sheet that explains why we need location and guides the user
/// through granting permission. Adapts its CTA based on current state.
class LocationPermissionSheet extends ConsumerWidget {
  const LocationPermissionSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const LocationPermissionSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.text;
    final tokens = context.tokens;
    final state = ref.watch(locationPermissionProvider);
    final controller = ref.read(locationPermissionProvider.notifier);

    final (title, body, ctaLabel, ctaIcon, Future<void> Function() onCta) = switch (state) {
      LocationPermissionState.serviceDisabled => (
          'Aktifkan Lokasi',
          'Langgeng Sea butuh GPS aktif untuk merekam jejak trawl. '
              'Nyalakan layanan lokasi di pengaturan perangkat Anda.',
          'Buka Pengaturan',
          PhosphorIconsBold.gearSix,
          controller.openLocationSettings,
        ),
      LocationPermissionState.deniedForever => (
          'Izin Lokasi Diblokir',
          'Anda pernah menolak izin lokasi secara permanen. '
              'Aktifkan manual di pengaturan aplikasi.',
          'Buka Pengaturan Aplikasi',
          PhosphorIconsBold.gearSix,
          controller.openAppSettings,
        ),
      LocationPermissionState.ready => (
          'Lokasi Aktif',
          'GPS Anda sudah siap dipakai untuk merekam jejak trawl.',
          'Tutup',
          PhosphorIconsBold.checkCircle,
          () async => Navigator.of(context).pop(),
        ),
      LocationPermissionState.denied ||
      LocationPermissionState.unknown =>
        (
          'Izinkan Lokasi',
          'Agar bisa merekam jejak kapal dan trawl secara akurat, '
              'Langgeng Sea memerlukan akses ke GPS.\n\n'
              'Data Anda disimpan lokal di HP. Tidak ada server, tidak dibagikan.',
          'Izinkan Akses Lokasi',
          PhosphorIconsBold.mapPinArea,
          controller.request,
        ),
    };

    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.sp4,
        right: AppSizes.sp4,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.sp4,
        top: AppSizes.sp4,
      ),
      child: GlassCard(
        level: GlassLevel.level3,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSizes.radius2xl),
          bottom: Radius.circular(AppSizes.radius2xl),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSizes.sp6,
          AppSizes.sp4,
          AppSizes.sp6,
          AppSizes.sp6,
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
            const SizedBox(height: AppSizes.sp5),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: tokens.primaryGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.glowPrimary,
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  PhosphorIconsFill.mapPinArea,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.sp4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.headlineSmall,
            ),
            const SizedBox(height: AppSizes.sp2),
            Text(
              body,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: AppSizes.sp6),
            PrimaryActionButton(
              label: ctaLabel,
              icon: ctaIcon,
              onPressed: () async {
                await onCta();
                if (!context.mounted) return;
                final newState = ref.read(locationPermissionProvider);
                if (newState == LocationPermissionState.ready) {
                  Navigator.of(context).pop();
                }
              },
            ),
            if (state != LocationPermissionState.ready) ...[
              const SizedBox(height: AppSizes.sp2),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Nanti saja',
                  style: text.labelMedium?.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
