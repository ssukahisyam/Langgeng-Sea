import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
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

class _LiveStatsPanelState extends ConsumerState<LiveStatsPanel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // 1 Hz tick so the duration counter keeps incrementing between GPS
    // fixes. Cheap — it only calls setState.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static String _formatDistanceKm(double meters) {
    if (meters.isNaN || meters.isInfinite) return '— km';
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(2)} km';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trackingControllerProvider);
    final tokens = context.tokens;

    final haul = state.haul;
    final duration = haul == null
        ? Duration.zero
        : DateTime.now().difference(haul.startedAt);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                value: _formatDistanceKm(state.metrics.distanceMeters),
                label: 'Jarak tempuh',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.sp2),
        Row(
          children: [
            Expanded(
              child: _Tile(
                icon: PhosphorIconsBold.speedometer,
                iconBg: tokens.primarySoft,
                iconColor: context.colors.primary,
                value: Formatters.knots(state.metrics.currentSpeedKnots),
                label: 'Kecepatan terakhir',
              ),
            ),
            const SizedBox(width: AppSizes.sp2),
            // Empty expanded space to keep the speedometer tile the same width as the top row
            const Expanded(child: SizedBox.shrink()),
          ],
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
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;

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
            style: text.titleLarge?.copyWith(
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
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
