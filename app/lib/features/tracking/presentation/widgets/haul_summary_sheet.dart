import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../application/tracking_controller.dart';
import '../../application/tracking_state.dart';
import '../../data/haul_repository.dart';
import '../../domain/entities/haul.dart';

/// Post-recording summary. Shows metrics + lets user rename the haul, then
/// choose: next haul / end trip / close.
///
/// The user's action is returned to the caller as a [HaulSummaryAction] so
/// the map screen can decide what to do next (stay idle, start another
/// haul, end the trip).
enum HaulSummaryAction { dismissed, nextHaul, endTrip }

class HaulSummarySheet extends ConsumerStatefulWidget {
  const HaulSummarySheet({super.key, required this.completion});

  final HaulCompletion completion;

  /// Present the sheet and resolve once dismissed.
  static Future<HaulSummaryAction> show(
    BuildContext context,
    HaulCompletion completion,
  ) async {
    final result = await showModalBottomSheet<HaulSummaryAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => HaulSummarySheet(completion: completion),
    );
    return result ?? HaulSummaryAction.dismissed;
  }

  @override
  ConsumerState<HaulSummarySheet> createState() => _HaulSummarySheetState();
}

class _HaulSummarySheetState extends ConsumerState<HaulSummarySheet> {
  late final TextEditingController _nameCtl;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(
      text: widget.completion.haul.name ?? widget.completion.haul.displayName(),
    );
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final typed = _nameCtl.text.trim();
    final original = widget.completion.haul;
    final name = typed.isEmpty || typed == original.displayName() ? null : typed;
    if (name != original.name) {
      await ref.read(haulRepositoryProvider).rename(original.id, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.completion.haul;
    final text = context.text;
    final tokens = context.tokens;

    // Bottom sheets appear via Navigator's root overlay — they do NOT
    // inherit the MediaQuery padding AppShell injects for its tab
    // children. So we have to add the nav-bar clearance manually
    // here. Values kept in sync with AppShell.
    const navClearance = 56 + 8 + AppSizes.sp3;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.sp4,
        right: AppSizes.sp4,
        top: AppSizes.sp4,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            navClearance +
            AppSizes.sp4,
      ),
      child: GlassCard(
        level: GlassLevel.level3,
        padding: const EdgeInsets.fromLTRB(
          AppSizes.sp5,
          AppSizes.sp3,
          AppSizes.sp5,
          AppSizes.sp5,
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
            const SizedBox(height: AppSizes.sp4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.sp3, vertical: 6),
                  decoration: BoxDecoration(
                    color: tokens.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIconsBold.checkCircle,
                          size: 14, color: tokens.success),
                      const SizedBox(width: 4),
                      Text('HAUL SELESAI',
                          style: text.labelSmall?.copyWith(
                            color: tokens.success,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          )),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(PhosphorIconsRegular.x, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sp3),
            Text('Haul #${h.orderIndex}',
                style: text.bodySmall?.copyWith(
                  color: tokens.textTertiary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                )),
            const SizedBox(height: 2),
            TextField(
              controller: _nameCtl,
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Nama haul (opsional)',
                hintStyle: text.headlineSmall?.copyWith(
                  color: tokens.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.sp4),
            _MetricGrid(haul: h, pointCount: widget.completion.pointCount),
            const SizedBox(height: AppSizes.sp4),
            Row(
              children: [
                Expanded(
                  child: _SecondaryButton(
                    icon: PhosphorIconsRegular.notebook,
                    label: 'Isi Log Book',
                    onPressed: () {
                      // Log book arrives in M5. For now, just confirm.
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Log Book tersedia di M5'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: AppSizes.sp2),
                Expanded(
                  child: PrimaryActionButton(
                    label: 'Haul Berikutnya',
                    icon: PhosphorIconsBold.plusCircle,
                    onPressed: () async {
                      await _saveName();
                      if (!mounted) return;
                      Navigator.of(context).pop(HaulSummaryAction.nextHaul);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sp2),
            TextButton(
              onPressed: () async {
                await _saveName();
                if (!mounted) return;
                Navigator.of(context).pop(HaulSummaryAction.endTrip);
              },
              child: Text(
                'Akhiri Trip',
                style: text.labelMedium?.copyWith(color: tokens.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.surface1,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: tokens.borderStrong),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: tokens.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: text.labelLarge?.copyWith(
                  fontSize: 14,
                  color: tokens.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.haul, required this.pointCount});

  final Haul haul;
  final int pointCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      children: [
        Row(children: [
          Expanded(
            child: _Tile(
              icon: PhosphorIconsBold.ruler,
              iconBg: tokens.primarySoft,
              iconColor: context.colors.primary,
              value: Formatters.distance(haul.distanceMeters),
              label: 'Jarak Tarik',
            ),
          ),
          const SizedBox(width: AppSizes.sp2),
          Expanded(
            child: _Tile(
              icon: PhosphorIconsBold.timer,
              iconBg: tokens.accentSoft,
              iconColor: context.colors.secondary,
              value: Formatters.duration(haul.duration),
              label: 'Durasi',
            ),
          ),
        ]),
        const SizedBox(height: AppSizes.sp2),
        Row(children: [
          Expanded(
            child: _Tile(
              icon: PhosphorIconsBold.speedometer,
              iconBg: tokens.primarySoft,
              iconColor: context.colors.primary,
              value: Formatters.knots(haul.avgSpeedKnots),
              label: 'Kecepatan rata-rata',
            ),
          ),
          const SizedBox(width: AppSizes.sp2),
          Expanded(
            child: _Tile(
              icon: PhosphorIconsBold.compass,
              iconBg: tokens.accentSoft,
              iconColor: context.colors.secondary,
              value: Formatters.heading(haul.avgHeadingDegrees),
              label: 'Arah dominan',
            ),
          ),
        ]),
        const SizedBox(height: AppSizes.sp2),
        _Tile(
          wide: true,
          icon: PhosphorIconsBold.frameCorners,
          iconBg: tokens.primarySoft,
          iconColor: context.colors.primary,
          value: '${haul.sweptAreaM2.round()} m²',
          label: 'Luas area sapuan trawl · $pointCount titik',
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
    this.wide = false,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    return GlassCard(
      level: GlassLevel.level1,
      padding: const EdgeInsets.all(AppSizes.sp3 + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: AppSizes.sp2),
          Text(
            value,
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(
              color: tokens.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
