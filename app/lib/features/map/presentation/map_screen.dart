import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../../../core/widgets/status_chip.dart';

/// Home tab — map + GPS tracking controls.
/// Full map integration (flutter_map + FMTC) arrives in M1.
/// For M0, this is a design-accurate placeholder.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    final colors = context.colors;

    return AmbientBackground(
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Placeholder "map" area - will be flutter_map in M1
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPainter(color: tokens.border),
              ),
            ),

            // Top app bar
            Positioned(
              top: AppSizes.sp3,
              left: AppSizes.sp4,
              right: AppSizes.sp4,
              child: GlassCard(
                level: GlassLevel.level2,
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
                        gradient: tokens.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: tokens.glowPrimary,
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        PhosphorIconsFill.sailboat,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sp3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'KM Belum Diisi',
                            style: text.titleSmall,
                          ),
                          Text(
                            'Isi profil di Pengaturan',
                            style: text.bodySmall?.copyWith(
                              color: tokens.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const StatusChip(
                      label: AppStrings.noTrip,
                      variant: StatusVariant.neutral,
                      showDot: true,
                    ),
                  ],
                ),
              ),
            ),

            // GPS accuracy chip (fake for M0)
            Positioned(
              top: 100,
              right: AppSizes.sp5,
              child: GlassCard(
                level: GlassLevel.level1,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.sp3,
                  vertical: AppSizes.sp2,
                ),
                borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhosphorIconsBold.crosshair,
                      size: 14,
                      color: tokens.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '±—m',
                      style: text.labelSmall?.copyWith(
                        color: tokens.textTertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Center boat icon placeholder
            Center(
              child: _BoatMarker(tokens: tokens, colors: colors),
            ),

            // Bottom action panel
            Positioned(
              left: AppSizes.sp4,
              right: AppSizes.sp4,
              bottom: 100, // above bottom nav
              child: GlassCard(
                level: GlassLevel.level2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppStrings.readyToSail,
                                style: text.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'GPS tracking & peta siap di M1',
                                style: text.bodySmall?.copyWith(
                                  color: tokens.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _showMvpInfo(context),
                          icon: const Icon(PhosphorIconsRegular.info),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.sp3),
                    PrimaryActionButton(
                      label: AppStrings.startTrawl,
                      icon: PhosphorIconsFill.playCircle,
                      variant: ActionButtonVariant.success,
                      critical: true,
                      onPressed: () => _showMvpInfo(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMvpInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MvpInfoSheet(),
    );
  }
}

class _MvpInfoSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.all(AppSizes.sp4),
      child: GlassCard(
        level: GlassLevel.level3,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSizes.radius2xl),
        ),
        padding: const EdgeInsets.all(AppSizes.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSizes.sp5),
            Icon(
              PhosphorIconsFill.wrench,
              size: 48,
              color: context.colors.primary,
            ),
            const SizedBox(height: AppSizes.sp3),
            Text('Sedang Dibangun', style: text.headlineSmall),
            const SizedBox(height: AppSizes.sp2),
            Text(
              'Ini adalah M0 Foundation. Integrasi GPS, peta offline, dan tracking haul akan tersedia di milestone berikutnya.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: AppSizes.sp5),
            PrimaryActionButton(
              label: 'Mengerti',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoatMarker extends StatelessWidget {
  const _BoatMarker({required this.tokens, required this.colors});
  final LangTokens tokens;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1.1),
      duration: const Duration(seconds: 2),
      curve: Curves.easeInOut,
      builder: (_, scale, __) => Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: scale,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withValues(alpha: 0.25),
              ),
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: tokens.primaryGradient,
              shape: BoxShape.circle,
              border: Border.all(color: colors.surface, width: 2),
              boxShadow: [
                BoxShadow(
                  color: tokens.glowPrimary,
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              PhosphorIconsFill.sailboat,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple grid painter as a map placeholder until flutter_map is wired up in M1.
class _GridPainter extends CustomPainter {
  _GridPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.color != color;
}
