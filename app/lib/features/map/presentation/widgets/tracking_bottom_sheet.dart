import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../../tracking/application/tracking_controller.dart';
import '../../../tracking/application/tracking_state.dart';

/// Collapsible glass bottom sheet surfaced while [MapMode.tracking] is
/// active. Shows live duration, cumulative distance, and last reported
/// speed from [trackingControllerProvider], plus a "Berhenti tracking"
/// button that delegates to [TrackingController.stopHaul].
///
/// The widget owns its own expanded/collapsed state so the map screen
/// can drop it in without threading UI state back up. Duration is
/// re-rendered at 1 Hz via an internal ticker, matching the pattern
/// used by `LiveStatsPanel` — GPS fixes arrive every few seconds but
/// the wall-clock counter needs to keep moving.
///
/// Integration with [MapScreen] is deferred to task 9.6; until wired
/// up, the widget is consumable standalone (e.g. for widget tests).
class TrackingBottomSheet extends ConsumerStatefulWidget {
  const TrackingBottomSheet({
    super.key,
    this.initiallyExpanded = true,
    this.onStopPressed,
  });

  /// Initial collapsed/expanded state. Defaults to expanded so users
  /// who just tapped "Mulai tracking" see the full metrics sheet.
  final bool initiallyExpanded;

  /// Optional override for the Stop button. When null the widget calls
  /// [TrackingController.stopHaul] directly; callers that want to show
  /// a summary sheet (see task 9.6) provide their own handler.
  final VoidCallback? onStopPressed;

  @override
  ConsumerState<TrackingBottomSheet> createState() =>
      _TrackingBottomSheetState();
}

class _TrackingBottomSheetState extends ConsumerState<TrackingBottomSheet> {
  late bool _expanded;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    // 1 Hz tick: duration reads `DateTime.now() - haul.startedAt`, so
    // we repaint each second to keep the HH:MM:SS counter smooth even
    // between GPS fixes.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _toggle() => setState(() => _expanded = !_expanded);

  void _onStopPressed() {
    final override = widget.onStopPressed;
    if (override != null) {
      override();
      return;
    }
    // Fire-and-forget: stopHaul returns a HaulCompletion the caller may
    // want to display, but the default wiring here just stops tracking.
    unawaited(ref.read(trackingControllerProvider.notifier).stopHaul());
  }

  /// Cumulative distance in kilometres, always two decimals per
  /// Requirement 4.7 / task 9.2 ("cumulative distance (km, 2 decimals)").
  /// Formatters.distance flips to 1-decimal past 10 km, so we format
  /// locally instead of delegating.
  static String _formatDistanceKm(double meters) {
    if (meters.isNaN || meters.isInfinite) return '— km';
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(2)} km';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trackingControllerProvider);
    if (!state.isRecording) return const SizedBox.shrink();

    return GlassCard(
      level: GlassLevel.level3,
      padding: EdgeInsets.zero,
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 250),
        sizeCurve: Curves.easeOutCubic,
        firstCurve: Curves.easeOut,
        secondCurve: Curves.easeIn,
        crossFadeState:
            _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        firstChild: _CollapsedBody(
          state: state,
          onTap: _toggle,
          onStopPressed: _onStopPressed,
        ),
        secondChild: _ExpandedBody(
          state: state,
          onCollapse: _toggle,
          onStopPressed: _onStopPressed,
          distanceFormatter: _formatDistanceKm,
        ),
        layoutBuilder: (topChild, topKey, bottomChild, bottomKey) {
          // Stack aligned bottom-start so the collapsed and expanded
          // states grow upward from the same baseline (the sheet sits
          // at the bottom of the screen).
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomLeft,
            children: [
              Positioned(
                key: bottomKey,
                left: 0,
                right: 0,
                bottom: 0,
                child: bottomChild,
              ),
              Positioned(
                key: topKey,
                left: 0,
                right: 0,
                bottom: 0,
                child: topChild,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Collapsed row: duration · distance · "Berhenti" button.
// ---------------------------------------------------------------------------

class _CollapsedBody extends StatelessWidget {
  const _CollapsedBody({
    required this.state,
    required this.onTap,
    required this.onStopPressed,
  });

  final TrackingState state;
  final VoidCallback onTap;
  final VoidCallback onStopPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    final haul = state.haul!;
    final duration = DateTime.now().difference(haul.startedAt);
    final distance = Formatters.distance(state.metrics.distanceMeters);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.sp4,
          AppSizes.sp3,
          AppSizes.sp2,
          AppSizes.sp3,
        ),
        child: Row(
          children: [
            Icon(
              PhosphorIconsFill.record,
              size: 10,
              color: tokens.danger,
            ),
            const SizedBox(width: AppSizes.sp2),
            Icon(
              PhosphorIconsBold.timer,
              size: 16,
              color: tokens.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              Formatters.duration(duration),
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: AppSizes.sp4),
            Icon(
              PhosphorIconsBold.ruler,
              size: 16,
              color: tokens.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                distance,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: AppSizes.sp3),
            _CompactStopButton(onPressed: onStopPressed),
            const SizedBox(width: AppSizes.sp2),
            Icon(
              PhosphorIconsBold.caretUp,
              size: 16,
              color: tokens.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactStopButton extends StatelessWidget {
  const _CompactStopButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    return Semantics(
      button: true,
      label: 'Berhenti tracking',
      child: Material(
        color: tokens.danger,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.sp3,
              vertical: 8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  PhosphorIconsFill.stopCircle,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  'Berhenti',
                  style: text.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expanded body: full metric trio + primary stop CTA.
// ---------------------------------------------------------------------------

class _ExpandedBody extends StatelessWidget {
  const _ExpandedBody({
    required this.state,
    required this.onCollapse,
    required this.onStopPressed,
    required this.distanceFormatter,
  });

  final TrackingState state;
  final VoidCallback onCollapse;
  final VoidCallback onStopPressed;
  final String Function(double meters) distanceFormatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    final haul = state.haul!;
    final duration = DateTime.now().difference(haul.startedAt);

    return Padding(
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
          // Drag handle doubles as "tap to collapse".
          InkWell(
            onTap: onCollapse,
            borderRadius: BorderRadius.circular(AppSizes.radiusPill),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSizes.sp2),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.sp3,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: tokens.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhosphorIconsFill.record,
                      size: 10,
                      color: tokens.danger,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'TRACKING AKTIF',
                      style: text.labelSmall?.copyWith(
                        color: tokens.danger,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Perkecil',
                icon: const Icon(PhosphorIconsRegular.caretDown, size: 20),
                onPressed: onCollapse,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sp2),
          Text(
            haul.displayName(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSizes.sp4),
          _MetricGrid(
            duration: duration,
            distanceMeters: state.metrics.distanceMeters,
            lastSpeedKnots: state.metrics.currentSpeedKnots,
            distanceFormatter: distanceFormatter,
          ),
          const SizedBox(height: AppSizes.sp4),
          PrimaryActionButton(
            label: 'Berhenti tracking',
            icon: PhosphorIconsFill.stopCircle,
            variant: ActionButtonVariant.danger,
            onPressed: onStopPressed,
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.duration,
    required this.distanceMeters,
    required this.lastSpeedKnots,
    required this.distanceFormatter,
  });

  final Duration duration;
  final double distanceMeters;
  final double? lastSpeedKnots;
  final String Function(double meters) distanceFormatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Tile(
                icon: PhosphorIconsBold.timer,
                iconBg: tokens.accentSoft,
                iconColor: context.colors.secondary,
                value: Formatters.duration(duration),
                label: 'Durasi',
              ),
            ),
            const SizedBox(width: AppSizes.sp2),
            Expanded(
              child: _Tile(
                icon: PhosphorIconsBold.ruler,
                iconBg: tokens.primarySoft,
                iconColor: context.colors.primary,
                value: distanceFormatter(distanceMeters),
                label: 'Jarak tempuh',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.sp2),
        _Tile(
          wide: true,
          icon: PhosphorIconsBold.speedometer,
          iconBg: tokens.primarySoft,
          iconColor: context.colors.primary,
          value: Formatters.knots(lastSpeedKnots),
          label: 'Kecepatan terakhir',
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
