import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../providers/location_permission_provider.dart';
import 'location_permission_sheet.dart';

/// Banner shown when location is unavailable (service off, permission denied, etc).
///
/// Renders a compact glass bar with an icon, description, and tappable CTA.
/// Returns [SizedBox.shrink] when state is ready.
class GpsErrorBanner extends ConsumerWidget {
  const GpsErrorBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(locationPermissionProvider);
    if (state == LocationPermissionState.ready ||
        state == LocationPermissionState.unknown) {
      return const SizedBox.shrink();
    }

    final text = context.text;
    final tokens = context.tokens;

    final (title, subtitle, icon) = switch (state) {
      LocationPermissionState.serviceDisabled => (
          'GPS Mati',
          'Aktifkan lokasi untuk merekam jejak',
          PhosphorIconsFill.warning,
        ),
      LocationPermissionState.deniedForever => (
          'Izin Diblokir',
          'Buka pengaturan aplikasi',
          PhosphorIconsFill.lockKey,
        ),
      LocationPermissionState.denied => (
          'Izin Lokasi Diperlukan',
          'Ketuk untuk memberi izin',
          PhosphorIconsFill.mapPinArea,
        ),
      LocationPermissionState.ready ||
      LocationPermissionState.unknown =>
        ('', '', PhosphorIconsFill.info),
    };

    return GlassCard(
      level: GlassLevel.level2,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: InkWell(
          onTap: () => LocationPermissionSheet.show(context),
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.sp3 + 2),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tokens.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: tokens.danger),
                ),
                const SizedBox(width: AppSizes.sp3),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: text.labelLarge?.copyWith(
                          color: tokens.danger,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(
                          color: tokens.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  PhosphorIconsRegular.caretRight,
                  size: 16,
                  color: tokens.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
