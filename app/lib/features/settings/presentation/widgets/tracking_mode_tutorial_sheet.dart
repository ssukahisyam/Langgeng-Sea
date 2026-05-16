import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/observability/logger.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../../tracking/application/tracking_mode_activation.dart';

/// Modal bottom sheet yang menjelaskan cara grant permission yang
/// diblokir permanently di system settings (PR #29 R4 AC2 + AC4).
///
/// Dipanggil oleh `TrackingModeCard` saat
/// [activateAccurateMode] return [AccurateNeedsSystemSettings].
/// Konten 4-5 langkah dinamis sesuai [reason]:
/// - [NeedSettingsReason.notifications]: blokir total — mode akan
///   tetap di Normal sampai user buka pengaturan dan grant.
/// - [NeedSettingsReason.battery]: warning saja — mode tetap pindah
///   ke Akurasi, tapi GPS bisa di-throttle Android Doze saat layar
///   mati. User disarankan ke pengaturan untuk akurasi maksimal.
class TrackingModeTutorialSheet extends StatelessWidget {
  const TrackingModeTutorialSheet({super.key, required this.reason});

  final NeedSettingsReason reason;

  /// Show helper. Pakai pola sama dengan
  /// `LocationPermissionSheet.show` supaya konsisten dengan sheet lain.
  static Future<void> show(
    BuildContext context, {
    required NeedSettingsReason reason,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TrackingModeTutorialSheet(reason: reason),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;

    final config = _configFor(reason);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.sp4,
        right: AppSizes.sp4,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            AppSizes.sp4,
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
            // Drag handle
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

            // Icon header
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
                child: Icon(
                  config.icon,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.sp4),

            // Title + body
            Text(
              config.title,
              textAlign: TextAlign.center,
              style: text.headlineSmall,
            ),
            const SizedBox(height: AppSizes.sp2),
            Text(
              config.body,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: AppSizes.sp5),

            // Numbered steps
            ...config.steps.asMap().entries.map((entry) {
              final i = entry.key;
              final step = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.sp2),
                child: _NumberedStep(index: i + 1, label: step),
              );
            }),
            const SizedBox(height: AppSizes.sp5),

            // CTA
            PrimaryActionButton(
              label: 'Buka Pengaturan',
              icon: PhosphorIconsBold.gearSix,
              onPressed: () async {
                try {
                  await openAppSettings();
                } catch (e) {
                  Logger.instance.warn(
                    'tracking.tutorial_open_settings_failed',
                    {'error': e.toString()},
                  );
                }
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
            ),
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
        ),
      ),
    );
  }

  _TutorialConfig _configFor(NeedSettingsReason reason) {
    return switch (reason) {
      NeedSettingsReason.notifications => const _TutorialConfig(
          icon: PhosphorIconsFill.bellRinging,
          title: 'Izin Notifikasi Diblokir',
          body:
              'Mode Akurasi memerlukan notifikasi tracking yang tetap '
                  'tampil saat aplikasi berjalan di belakang. Saat ini '
                  'izin notifikasi diblokir di pengaturan sistem.',
          steps: [
            'Buka Pengaturan Sistem',
            'Pilih Aplikasi → Langgeng Sea',
            'Tap Notifikasi',
            'Aktifkan "Izinkan Notifikasi"',
            'Kembali ke aplikasi',
          ],
        ),
      NeedSettingsReason.battery => const _TutorialConfig(
          icon: PhosphorIconsFill.batteryWarning,
          title: 'Pengoptimalan Baterai Aktif',
          body:
              'Mode Akurasi sudah aktif, tapi sistem masih membatasi '
                  'aplikasi saat layar mati. GPS bisa berhenti merekam. '
                  'Lakukan langkah berikut untuk akurasi maksimal.',
          steps: [
            'Buka Pengaturan Sistem',
            'Pilih Aplikasi → Langgeng Sea',
            'Tap Baterai',
            'Pilih "Tidak Dibatasi" atau "Tanpa Pembatasan"',
            'Kembali ke aplikasi',
          ],
        ),
    };
  }
}

class _TutorialConfig {
  const _TutorialConfig({
    required this.icon,
    required this.title,
    required this.body,
    required this.steps,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<String> steps;
}

/// Single numbered step: badge bulat berisi angka + label.
class _NumberedStep extends StatelessWidget {
  const _NumberedStep({required this.index, required this.label});

  final int index;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    final colors = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tokens.primarySoft,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: text.labelMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppSizes.sp3),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(color: colors.onSurface),
            ),
          ),
        ),
      ],
    );
  }
}
