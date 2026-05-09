import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../onboarding/data/user_profile_repository.dart';
import '../../onboarding/presentation/widgets/profile_form.dart';

/// Edit an existing profile from Pengaturan. Pre-fills the form and pops
/// on save.
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
            loading: () =>
                const Center(child: CircularProgressIndicator()),
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
              child: ProfileForm(
                initial: profile,
                ctaLabel: 'Simpan Perubahan',
                onSaved: (_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profil tersimpan')),
                  );
                  context.pop();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
