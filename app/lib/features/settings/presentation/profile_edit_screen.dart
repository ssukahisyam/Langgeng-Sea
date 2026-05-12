import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/settings/application/app_settings_provider.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../onboarding/data/user_profile_repository.dart';
import '../../onboarding/presentation/widgets/profile_form.dart';

/// Edit an existing profile from Pengaturan. Pre-fills the form and pops
/// on save. M11 adds the "Alarm Navigasi" section below the profile
/// form -- two switches that read / write [appSettingsProvider] (i.e.
/// the `app_settings` table). Writes are direct (no save button);
/// settings toggle UX expected on mobile.
class ProfileEditScreen extends ConsumerWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final tokens = context.tokens;
    final text = context.text;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => context.pop(),
          tooltip: 'Kembali',
        ),
        title: const Text('Edit Profil'),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                'Gagal memuat profil: $e',
                style: text.bodyMedium?.copyWith(color: tokens.danger),
              ),
            ),
            data: (profile) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.sp5,
                AppSizes.sp4,
                AppSizes.sp5,
                AppSizes.sp8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfileForm(
                    initial: profile,
                    ctaLabel: 'Simpan Perubahan',
                    onSaved: (_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profil tersimpan')),
                      );
                      context.pop();
                    },
                  ),
                  const SizedBox(height: AppSizes.sp6),
                  const _AlarmSettingsSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Alarm Navigasi" section wrapping the two alarm toggles. Written
/// as a standalone widget so ProfileEditScreen's build stays shallow.
class _AlarmSettingsSection extends ConsumerWidget {
  const _AlarmSettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final text = context.text;
    final settingsAsync = ref.watch(appSettingsProvider);

    return GlassCard(
      level: GlassLevel.level2,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.sp4,
        AppSizes.sp3,
        AppSizes.sp2,
        AppSizes.sp3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSizes.sp1),
            child: Row(
              children: [
                Icon(
                  PhosphorIconsBold.bellRinging,
                  size: 18,
                  color: context.colors.primary,
                ),
                const SizedBox(width: AppSizes.sp2),
                Text('Alarm Navigasi', style: text.titleMedium),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.sp1),
          settingsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSizes.sp4),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSizes.sp3,
                horizontal: AppSizes.sp3,
              ),
              child: Text(
                'Gagal memuat pengaturan: $e',
                style: text.bodyMedium?.copyWith(color: tokens.danger),
              ),
            ),
            data: (settings) {
              final repo = ref.read(appSettingsRepositoryProvider);
              return Column(
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.sp1,
                    ),
                    title: Text('Suara (TTS)', style: text.bodyLarge),
                    subtitle: Text(
                      'Pengumuman suara saat sampai atau keluar jalur',
                      style: text.bodySmall?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                    value: settings.alarmSoundEnabled,
                    onChanged: (v) => repo.setSoundEnabled(v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.sp1,
                    ),
                    title: Text('Getar', style: text.bodyLarge),
                    subtitle: Text(
                      'Getar HP saat alarm berbunyi',
                      style: text.bodySmall?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                    value: settings.alarmVibrateEnabled,
                    onChanged: (v) => repo.setVibrateEnabled(v),
                  ),
                  const SizedBox(height: AppSizes.sp2),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.sp3,
                    ),
                    child: Text(
                      'Alarm berbunyi saat sudah sampai ke tujuan atau '
                      'keluar jalur saat ikuti tarikan.',
                      style: text.bodySmall?.copyWith(
                        color: tokens.textTertiary,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
