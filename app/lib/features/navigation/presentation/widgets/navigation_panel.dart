import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../application/navigation_state.dart';
import '../../domain/entities/navigation_progress.dart';
import '../../domain/entities/navigation_target.dart';

/// Top-of-map glass card shown whenever navigation is active.
///
/// Renders both navigation branches:
///   * [GotoTarget]: label, distance, bearing (degrees + cardinal
///     Bahasa), optional ETA, and a "Sudah Sampai" terminal state.
///   * [FollowTrackTarget]: same header + a progress bar 0..100% that
///     switches colour when the follow-track alarm machine enters
///     off-route. An inline warning pill "Keluar jalur X m" surfaces
///     inside the card so the user sees it without looking down at
///     the map.
class NavigationPanel extends StatelessWidget {
  const NavigationPanel({
    super.key,
    required this.state,
    required this.onStop,
  });

  final NavigationActive state;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    final target = state.target;
    final progress = state.progress;

    final isFollowTrack = target is FollowTrackTarget;
    final isArrived = state.alarmState == NavigationAlarmState.arrived;

    // Surface off-route to the panel whenever the controller has
    // *committed* to the alarm, i.e. after the 5s debounce has lapsed.
    // Countdown states deliberately don't trigger the warning UI --
    // doing so would make the warning flicker on borderline jitter.
    final isOffRoute = state.alarmState == NavigationAlarmState.offRoute ||
        state.alarmState == NavigationAlarmState.returnCountdown;

    // Pick icon + colour based on target type and arrival state so the
    // same panel reads as "heading there" vs "sudah sampai" at a
    // glance.
    final iconData = isFollowTrack
        ? PhosphorIconsFill.footprints
        : (isArrived
            ? PhosphorIconsFill.checkCircle
            : PhosphorIconsFill.navigationArrow);
    // Arrival dominates all other colouring; otherwise follow-track in
    // an off-route state shows the warning tint to draw the eye.
    final Color iconColor;
    if (isArrived) {
      iconColor = tokens.success;
    } else if (isFollowTrack && isOffRoute) {
      iconColor = tokens.warning;
    } else {
      iconColor = context.colors.primary;
    }

    return GlassCard(
      level: GlassLevel.level2,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.sp3,
        AppSizes.sp2 + 2,
        AppSizes.sp2,
        AppSizes.sp3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Row 1: icon + label + stop ----------------------------------
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(iconData, color: iconColor, size: 18),
              ),
              const SizedBox(width: AppSizes.sp2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isArrived
                          ? 'Sudah Sampai'
                          : (isFollowTrack ? 'Ikuti Jalur' : 'Pandu ke'),
                      style: text.labelSmall?.copyWith(
                        color: tokens.textTertiary,
                        letterSpacing: 0.5,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      target.displayLabel,
                      style: text.titleSmall?.copyWith(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Akhiri panduan',
                onPressed: onStop,
                icon: const Icon(PhosphorIconsRegular.x, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSizes.sp2),

          // --- Row 2: distance / bearing / ETA -----------------------------
          _ProgressLine(progress: progress, arrived: isArrived),

          // --- Row 3 (follow-track only): off-route warning + bar ----------
          if (isFollowTrack) ...[
            if (isOffRoute) ...[
              const SizedBox(height: AppSizes.sp2),
              _OffRouteBadge(crossTrackMeters: progress.crossTrackMeters),
            ],
            const SizedBox(height: AppSizes.sp2),
            _ProgressBar(
              value: progress.percentAlongPath,
              offRoute: isOffRoute,
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// Progress line
// ===========================================================================

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.progress, required this.arrived});

  final NavigationProgress progress;
  final bool arrived;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;

    final distanceLabel = Formatters.distance(progress.distanceToTargetMeters);
    final bearingLabel =
        '${Formatters.heading(progress.bearingDegrees)} ${_cardinal(progress.bearingDegrees)}';
    final eta = progress.etaSeconds;

    final style = text.bodySmall?.copyWith(
      color: tokens.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

    if (arrived) {
      return Text(
        'Tekan X untuk menutup panduan',
        style: style?.copyWith(color: tokens.success),
      );
    }

    return Wrap(
      spacing: AppSizes.sp2,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Pill(text: distanceLabel, icon: PhosphorIconsBold.ruler),
        _Pill(
          text: bearingLabel,
          icon: PhosphorIconsBold.compass,
        ),
        if (eta != null)
          _Pill(text: _formatEta(eta), icon: PhosphorIconsBold.clock),
      ],
    );
  }

  String _formatEta(double seconds) {
    if (!seconds.isFinite || seconds < 0) return '--';
    final d = Duration(seconds: seconds.round());
    if (d.inHours > 0) {
      return 'ETA ${d.inHours}j ${d.inMinutes % 60}m';
    }
    if (d.inMinutes > 0) {
      return 'ETA ${d.inMinutes} min';
    }
    return 'ETA <1 min';
  }

  /// Compass cardinal (short Bahasa) for a bearing in degrees.
  /// 8-point rose: N, NE, E, SE, S, SW, W, NW -> U, TL, T, TG, S, BD, B, BL.
  static String _cardinal(double degrees) {
    const labels = ['U', 'TL', 'T', 'TG', 'S', 'BD', 'B', 'BL'];
    final idx = (((degrees % 360) + 22.5) ~/ 45) % 8;
    return labels[idx];
  }
}

// ===========================================================================
// Off-route badge
// ===========================================================================

class _OffRouteBadge extends StatelessWidget {
  const _OffRouteBadge({required this.crossTrackMeters});

  final double crossTrackMeters;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    // Nearest 5m — 27m reads as "~25m", keeps the chip stable instead
    // of bouncing every GPS tick.
    final rounded = (crossTrackMeters / 5).round() * 5;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sp3,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: tokens.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        border: Border.all(
          color: tokens.warning.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIconsFill.warningCircle,
            size: 14,
            color: tokens.warning,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Keluar jalur $rounded m',
              style: text.labelSmall?.copyWith(
                color: tokens.warning,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Progress bar
// ===========================================================================

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.offRoute});

  final double value;
  final bool offRoute;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    final clamped = value.clamp(0.0, 1.0);
    final pct = (clamped * 100).round();
    final barColour = offRoute ? tokens.warning : context.colors.primary;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusPill),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 4,
              backgroundColor: tokens.surface1,
              valueColor: AlwaysStoppedAnimation<Color>(barColour),
            ),
          ),
        ),
        const SizedBox(width: AppSizes.sp2),
        SizedBox(
          width: 34,
          child: Text(
            '$pct%',
            textAlign: TextAlign.right,
            style: text.labelSmall?.copyWith(
              color: tokens.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Pill
// ===========================================================================

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: tokens.surface1,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: tokens.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: context.text.bodySmall?.copyWith(
              color: tokens.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
