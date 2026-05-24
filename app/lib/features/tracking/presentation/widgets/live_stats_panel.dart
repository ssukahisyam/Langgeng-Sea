import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../map/presentation/widgets/tracking_status_chip.dart';
import '../../application/tracking_controller.dart';

/// Top-bar glass panel shown during active haul recording.
///
/// Features a prominent 2x2 grid (duration, distance, speed) so the user
/// can see metrics clearly at the top of the map.
class LiveStatsPanel extends ConsumerStatefulWidget {
  const LiveStatsPanel({super.key});

  @override
  ConsumerState<LiveStatsPanel> createState() => _LiveStatsPanelState();
}

class _LiveStatsPanelState extends ConsumerState<LiveStatsPanel>
    with SingleTickerProviderStateMixin {
  Timer? _ticker;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  static String _formatDistanceM(double meters) {
    if (meters.isNaN || meters.isInfinite) return '— m';
    return '${meters.toStringAsFixed(0)} m';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trackingControllerProvider);
    final tokens = context.tokens;
    final text = context.text;

    final haul = state.haul;
    if (haul == null) return const SizedBox.shrink();

    final duration = DateTime.now().difference(haul.startedAt);

    return GlassCard(
      level: GlassLevel.level3,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sp3,
        vertical: AppSizes.sp3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Banner row
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) {
                  final t = _pulseController.value;
                  final spread = 8 * (1 - t);
                  return Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: tokens.danger,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: tokens.danger.withValues(alpha: (1 - t) * 0.6),
                          blurRadius: spread,
                          spreadRadius: spread * 0.3,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: AppSizes.sp2),
              Text(
                'MEREKAM ${haul.displayName().toUpperCase()}',
                style: text.labelMedium?.copyWith(
                  color: tokens.danger,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              // PR #41: chip status background tracking. Self-hide
              // kalau tracking tidak aktif (di sini selalu aktif —
              // panel cuma render saat haul running). Tap = buka
              // PermissionChecklistSheet untuk fix permission.
              const TrackingStatusChip(),
              const SizedBox(width: AppSizes.sp2),
              Icon(PhosphorIconsBold.ruler,
                  size: 14, color: tokens.textTertiary),
              const SizedBox(width: 4),
              Text(
                '${haul.trawlWidthMeters.toStringAsFixed(0)} m',
                style: text.bodySmall?.copyWith(
                  color: tokens.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sp2),
          Divider(color: tokens.border, height: 1),
          const SizedBox(height: AppSizes.sp2),
          // Stats row
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Durasi',
                  value: Formatters.duration(duration),
                ),
              ),
              _Sep(color: tokens.border),
              Expanded(
                child: _Stat(
                  label: 'Jarak',
                  value: _formatDistanceM(state.metrics.distanceMeters),
                ),
              ),
              _Sep(color: tokens.border),
              Expanded(
                child: _Stat(
                  label: 'Kecepatan',
                  value:
                      '${(state.metrics.currentSpeedKnots ?? 0.0).toStringAsFixed(1)} kn',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: text.labelSmall?.copyWith(
            color: tokens.textTertiary,
            fontSize: 10,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: text.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: color);
}
