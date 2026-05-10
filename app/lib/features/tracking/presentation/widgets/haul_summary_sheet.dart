import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../application/tracking_state.dart';
import '../../data/haul_repository.dart';
import '../../domain/entities/haul.dart';
import 'end_trip_dialog.dart';

/// Post-recording summary. Shows metrics + lets user rename + pick a
/// colour for this haul, then choose: save / end trip / close.
///
/// The user's action is returned to the caller as a [HaulSummaryAction]
/// so the map screen can stay idle afterwards — starting another haul
/// is triggered explicitly from the main "MULAI TEBAR" button.
enum HaulSummaryAction { dismissed, saved, endTrip }

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
      useRootNavigator: false,
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
  int? _pickedColorValue;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(
      text: widget.completion.haul.name ?? widget.completion.haul.displayName(),
    );
    _pickedColorValue = widget.completion.haul.colorValue;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  Future<void> _persistEdits() async {
    final typed = _nameCtl.text.trim();
    final original = widget.completion.haul;
    final name = typed.isEmpty || typed == original.displayName() ? null : typed;
    final repo = ref.read(haulRepositoryProvider);

    if (name != original.name) {
      await repo.rename(original.id, name);
    }
    if (_pickedColorValue != original.colorValue) {
      await repo.setColor(original.id, _pickedColorValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.completion.haul;
    final text = context.text;
    final tokens = context.tokens;

    // With `useRootNavigator: false` the sheet lives in the shell's
    // Navigator, so AppShell's `MediaQuery.padding.bottom` injection
    // already covers the floating nav clearance. viewInsets handles
    // the keyboard if it shows up for the rename field.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.sp4,
        right: AppSizes.sp4,
        top: AppSizes.sp4,
        bottom: bottomInset + bottomSafe + AppSizes.sp4,
      ),
      child: GlassCard(
        level: GlassLevel.level3,
        padding: const EdgeInsets.fromLTRB(
          AppSizes.sp5,
          AppSizes.sp3,
          AppSizes.sp5,
          AppSizes.sp5,
        ),
        child: SingleChildScrollView(
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
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PhosphorIconsBold.checkCircle,
                            size: 14, color: tokens.success),
                        const SizedBox(width: 4),
                        Text('TARIKAN SELESAI',
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
              Text('Tarikan #${h.orderIndex}',
                  style: text.bodySmall?.copyWith(
                    color: tokens.textTertiary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  )),
              const SizedBox(height: 2),
              TextField(
                controller: _nameCtl,
                style: text.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Nama tarikan (opsional)',
                  hintStyle: text.headlineSmall?.copyWith(
                    color: tokens.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.sp3),
              _ColorPicker(
                value: _pickedColorValue,
                onChanged: (newValue) =>
                    setState(() => _pickedColorValue = newValue),
              ),
              const SizedBox(height: AppSizes.sp4),
              _MetricGrid(
                haul: h,
                pointCount: widget.completion.pointCount,
              ),
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
                      label: 'Simpan',
                      icon: PhosphorIconsBold.checkCircle,
                      variant: ActionButtonVariant.success,
                      onPressed: () async {
                        await _persistEdits();
                        if (!mounted) return;
                        Navigator.of(context).pop(HaulSummaryAction.saved);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.sp2),
              TextButton(
                onPressed: () async {
                  await _persistEdits();
                  if (!mounted) return;
                  // Use the tripId off the just-completed haul rather
                  // than state.activeTrip — the latter can be stale
                  // after a race with stopHaul() upstream.
                  final tripId = widget.completion.haul.tripId;
                  final confirmed = await EndTripDialog.show(
                    context,
                    tripId: tripId,
                  );
                  if (!mounted) return;
                  if (confirmed) {
                    Navigator.of(context).pop(HaulSummaryAction.endTrip);
                  }
                  // If cancelled, stay on the summary sheet.
                },
                child: Text(
                  'Akhiri Trip',
                  style: text.labelMedium
                      ?.copyWith(color: tokens.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Colour picker (8 preset swatches + "clear" when tapping the selected one).
// ---------------------------------------------------------------------------

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WARNA JEJAK',
          style: text.labelSmall?.copyWith(
            color: tokens.textTertiary,
            letterSpacing: 0.5,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSizes.sp2),
        Wrap(
          spacing: AppSizes.sp2,
          runSpacing: AppSizes.sp2,
          children: [
            for (final entry in AppColors.pickablePalette)
              _ColorSwatch(
                entry: entry,
                selected: value == entry.color.toARGB32(),
                onTap: () {
                  final argb = entry.color.toARGB32();
                  // Tap selected → clear (back to auto-palette).
                  onChanged(value == argb ? null : argb);
                },
              ),
          ],
        ),
        if (value == null) ...[
          const SizedBox(height: 6),
          Text(
            'Pilih warna agar tarikan ini mudah dikenali di peta & riwayat.',
            style: text.bodySmall?.copyWith(
              color: tokens.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final PickableColor entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      label: 'Warna tarikan: ${entry.label}',
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: entry.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.white : tokens.border,
              width: selected ? 3 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: entry.color.withValues(alpha: 0.55),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: selected
              ? const Icon(
                  PhosphorIconsBold.check,
                  size: 14,
                  color: Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Secondary (outlined) helper button + metric grid (unchanged from PR #16).
// ---------------------------------------------------------------------------

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
