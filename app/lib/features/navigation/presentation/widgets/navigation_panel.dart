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
/// M11a renders the [GotoTarget] branch: target label, distance,
/// bearing (compass + cardinal hint), and ETA if the boat is moving.
/// The [FollowTrackTarget] branch renders the same header plus a
/// progress bar stub -- filled in more completely in M11b when
/// follow-track metrics come online.
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

    // Pick icon + colour based on target type and arrival state so the
    // same panel reads as "heading there" vs "sudah sampai" at a
    // glance.
    final iconData = isFollowTrack
        ? PhosphorIconsFill.footprints
        : (isArrived
            ? PhosphorIconsFill.checkCircle
            : PhosphorIconsFill.navigationArrow);
    final iconColor = isArrived ? tokens.success : context.colors.primary;

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

          // --- Row 3 (follow-track only): progress bar ---------------------
          if (isFollowTrack) ...[
            const SizedBox(height: AppSizes.sp2),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusPill),
              child: LinearProgressIndicator(
                value: progress.percentAlongPath.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: tokens.surface1,
                valueColor:
                    AlwaysStoppedAnimation<Color>(context.colors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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
