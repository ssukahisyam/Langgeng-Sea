import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ambient_background.dart';
import 'widgets/profile_form.dart';

/// First-run profile setup. Collects name + vessel (+ optional GT, port,
/// trawl width). On save, navigates to the main map screen.
class ProfileFormScreen extends ConsumerWidget {
  const ProfileFormScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.text;
    final tokens = context.tokens;

    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.sp5,
              AppSizes.sp5,
              AppSizes.sp5,
              AppSizes.sp8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Profil Nelayan', style: text.headlineLarge),
                const SizedBox(height: AppSizes.sp2),
                Text(
                  'Isi data dasar sekali saja — bisa diubah kapan pun dari Pengaturan.',
                  style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
                ),
                const SizedBox(height: AppSizes.sp5),
                ProfileForm(
                  ctaLabel: 'Simpan & Mulai',
                  onSaved: (_) => context.go(AppRoutes.map),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
