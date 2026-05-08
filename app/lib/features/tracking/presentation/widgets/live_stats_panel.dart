import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../application/tracking_controller.dart';

/// Top-bar glass panel shown during active haul recording.
///
/// Three live metrics: duration, distance, current speed. Duration updates
/// on a 1 Hz timer independent of the GPS stream so the counter stays
/// smooth even between fixes.
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trackingControllerProvider);
    final tokens = context.tokens;

    final haul = state.haul;
    final duration = haul == null
        ? Duration.zero
        : DateTime.now().difference(haul.startedAt);

    return GlassCard(
      level: GlassLevel.level2,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sp3,
        vertical: AppSizes.sp3 + 2,
      ),
      child: Row(
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
              value: Formatters.distance(state.metrics.distanceMeters),
            ),
          ),
          _Sep(color: tokens.border),
          Expanded(
            child: _Stat(
              label: 'Kecepatan',
              value: Formatters.knots(state.metrics.currentSpeedKnots),
            ),
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
            fontSize: 17,
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
