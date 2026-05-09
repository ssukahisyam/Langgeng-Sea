import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_action_button.dart';

/// First-run onboarding — 3 slide PageView with Lewati/Lanjut/Mulai buttons.
///
/// Mirrors prototype screen 08. When the user finishes (Mulai or swipes
/// past last page) they're sent to [AppRoutes.profileForm] to collect their
/// name + vessel.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _index = 0;

  static const _slides = <_OnboardingSlide>[
    _OnboardingSlide(
      icon: PhosphorIconsFill.sailboat,
      title: 'Jejak Setia di Lautan',
      body: 'Selamat datang di Langgeng Sea — teman setia nelayan trawl '
          'Indonesia untuk mencatat setiap tarikan alat tangkap.',
    ),
    _OnboardingSlide(
      icon: PhosphorIconsFill.crosshair,
      title: 'Tracking Offline',
      body: 'Rekam jejak kapal & trawl tanpa sinyal internet. Cukup GPS HP — '
          'tidak perlu alat tambahan.',
    ),
    _OnboardingSlide(
      icon: PhosphorIconsFill.gps,
      title: 'Multi-Haul Per Trip',
      body: 'Catat 2–5 tarikan per hari terpisah. Evaluasi spot mana yang '
          'paling produktif lewat dashboard.',
    ),
  ];

  bool get _isLast => _index == _slides.length - 1;

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  void _finish() {
    context.go(AppRoutes.profileForm);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;

    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top bar: Lewati
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.sp5,
                  AppSizes.sp3,
                  AppSizes.sp5,
                  0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Semantics(
                      label: 'Lewati onboarding',
                      button: true,
                      child: TextButton(
                        onPressed: _finish,
                        child: Text(
                          AppStrings.skip,
                          style: text.labelMedium?.copyWith(
                            color: tokens.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Slides
              Expanded(
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
                ),
              ),

              // Dots
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSizes.sp4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (i) {
                    final active = i == _index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active
                            ? context.colors.primary
                            : tokens.textTertiary.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),

              // CTA button
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.sp5,
                  0,
                  AppSizes.sp5,
                  AppSizes.sp6,
                ),
                child: Semantics(
                  label: _isLast ? 'Mulai, lanjut ke isi profil' : 'Lanjut',
                  button: true,
                  child: PrimaryActionButton(
                    label: _isLast ? 'Mulai' : AppStrings.continueText,
                    icon: _isLast
                        ? PhosphorIconsBold.arrowRight
                        : PhosphorIconsRegular.arrowRight,
                    variant: ActionButtonVariant.primary,
                    onPressed: _next,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.sp5,
        AppSizes.sp6,
        AppSizes.sp5,
        AppSizes.sp4,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon blob
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: tokens.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: tokens.glowPrimary,
                  blurRadius: 48,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Icon(slide.icon, color: Colors.white, size: 64),
          ),
          const SizedBox(height: AppSizes.sp8),
          GlassCard(
            level: GlassLevel.level2,
            padding: const EdgeInsets.all(AppSizes.sp6),
            child: Column(
              children: [
                Text(
                  slide.title,
                  style: text.headlineLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.sp3),
                Text(
                  slide.body,
                  style: text.bodyLarge?.copyWith(
                    color: tokens.textSecondary,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
