import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../application/tracking_controller.dart';

/// Top-bar glass banner during active recording. Pulsing red dot + haul
/// name. Replaces the idle vessel-info bar on the Map screen.
class RecordingBanner extends ConsumerWidget {
  const RecordingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final haul = ref.watch(trackingControllerProvider).haul;
    if (haul == null) return const SizedBox.shrink();

    final tokens = context.tokens;
    final text = context.text;

    return GlassCard(
      level: GlassLevel.level3,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sp3,
        vertical: AppSizes.sp3,
      ),
      child: Row(
        children: [
          _PulsingDot(color: tokens.danger),
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
          Icon(PhosphorIconsBold.ruler, size: 14, color: tokens.textTertiary),
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
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        final spread = 8 * (1 - t);
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: (1 - t) * 0.6),
                blurRadius: spread,
                spreadRadius: spread * 0.3,
              ),
            ],
          ),
        );
      },
    );
  }
}
