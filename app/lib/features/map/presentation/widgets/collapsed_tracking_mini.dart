import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../tracking/application/tracking_controller.dart';

/// Mini collapsed banner shown when tracking is active concurrently with
/// an active Navigation session (Requirement 4.12 / AC 12a).
///
/// Layout priority in the concurrent `Map_Mode = Navigating + Tracking`
/// case puts the full `NavigationPanel` on top of the map and this
/// banner underneath it as a secondary slot. The banner:
///
///  * deliberately does **not** surface cumulative distance or speed
///    (those live in the full tracking bottom sheet shown when
///    `Map_Mode = Tracking` alone) — only the duration readout and a
///    "Berhenti" action make the cut,
///  * stays `≤ 48` logical pixels tall so the map keeps breathing room
///    between the NavigationPanel and other bottom overlays,
///  * renders with a warning-tinted background (amber/orange from
///    [LangTokens.warning]) so the user immediately notices that two
///    concurrent tasks are running — they are navigating *and* their
///    haul is still being recorded,
///  * ticks the elapsed-duration readout once per second via a local
///    [Timer] so the number doesn't freeze between GPS emissions
///    (Doze_Mode readings can be 15–30 s apart per Requirement 1.4).
///
/// Positioning is the caller's concern: the parent `MapScreen` in task
/// 9.6 will place this banner directly below the `NavigationPanel` in
/// the widget tree, leaving standard map controls room at the bottom.
class CollapsedTrackingMini extends ConsumerStatefulWidget {
  const CollapsedTrackingMini({
    super.key,
    required this.onStop,
  });

  /// Invoked when the user taps "Berhenti". The caller wires this to
  /// the same handler used by the full `TrackingBottomSheet` so the
  /// Haul summary flow stays consistent regardless of which surface
  /// initiated the stop. The widget intentionally does not call
  /// `stopHaul` directly — the summary sheet + haptics are concerns of
  /// the hosting screen.
  final VoidCallback onStop;

  @override
  ConsumerState<CollapsedTrackingMini> createState() =>
      _CollapsedTrackingMiniState();
}

class _CollapsedTrackingMiniState extends ConsumerState<CollapsedTrackingMini> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // 1 Hz tick mirrors [LiveStatsPanel] so the duration keeps ticking
    // between GPS fixes. Cheap — tick only calls setState.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(trackingControllerProvider);
    final haul = tracking.haul;

    // Guard against transient rebuild ordering — if tracking has just
    // ended, the parent will drop us on the next frame but we should
    // render nothing meanwhile rather than crash on a null haul.
    if (haul == null) {
      return const SizedBox.shrink();
    }

    final tokens = context.tokens;
    final text = context.text;
    final duration = DateTime.now().difference(haul.startedAt);

    return ConstrainedBox(
      // Hard cap at 48 logical pixels per task spec. The padding + icon
      // sizing below measure out at ~40 px; the cap guards against
      // future text-scale or theme changes pushing the pill taller.
      constraints: const BoxConstraints(maxHeight: 48),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sp3,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: tokens.warning.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          border: Border.all(
            color: tokens.warning.withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsFill.record,
              size: 14,
              color: tokens.warning,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                Formatters.duration(duration),
                style: text.labelMedium?.copyWith(
                  color: tokens.warning,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  letterSpacing: 0.4,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSizes.sp2),
            _StopButton(onPressed: widget.onStop),
          ],
        ),
      ),
    );
  }
}

/// Compact "Berhenti" action tuned to the 48 px banner.
class _StopButton extends StatelessWidget {
  const _StopButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;

    // Material handles the tap target so hit testing extends past the
    // drawn pixels; the borderRadius is matched to the container so
    // the inkwell ripple doesn't spill out of the pill shape.
    return Material(
      color: tokens.warning,
      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.sp3,
            vertical: 5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PhosphorIconsFill.stopCircle,
                size: 13,
                color: tokens.surface1,
              ),
              const SizedBox(width: 4),
              Text(
                'Berhenti',
                style: text.labelSmall?.copyWith(
                  color: tokens.surface1,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
