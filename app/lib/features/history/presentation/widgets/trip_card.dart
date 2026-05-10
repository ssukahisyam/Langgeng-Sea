import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../tracking/domain/entities/trip.dart';
import '../../../tracking/domain/entities/trip_summary.dart';

/// One row in the History list. Shows trip name/date, headline metric,
/// and a few chips. Route-pushes to the trip detail on tap.
class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.summary,
    required this.onTap,
  });

  final TripSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    final trip = summary.trip;

    final startClock = Formatters.wallClock(trip.startedAt);
    final endClock = trip.endedAt != null
        ? Formatters.wallClock(trip.endedAt!)
        : '—';

    final title = trip.name?.isNotEmpty == true
        ? trip.name!
        : (trip.homePort?.isNotEmpty == true
            ? 'Trip ${trip.homePort}'
            : 'Trip ${Formatters.shortDate(trip.startedAt)}');

    return GlassCard(
      level: GlassLevel.level2,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSizes.sp4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$startClock - $endClock · ${summary.haulCount} tarikan',
                      style: text.bodySmall?.copyWith(
                        color: tokens.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (trip.status == TripStatus.active)
                _ActiveBadge(color: tokens.success)
              else
                _MetricHero(
                  value: summary.totalDistanceMeters >= 1000
                      ? (summary.totalDistanceMeters / 1000)
                          .toStringAsFixed(1)
                      : summary.totalDistanceMeters.toStringAsFixed(0),
                  unit: summary.totalDistanceMeters >= 1000 ? 'km' : 'm',
                  label: 'Jarak',
                  color: context.colors.primary,
                ),
            ],
          ),
          const SizedBox(height: AppSizes.sp3),
          _ChipRow(summary: summary),
          if (summary.haulCount > 0) ...[
            const SizedBox(height: AppSizes.sp3),
            _MiniTrack(summary: summary),
          ],
        ],
      ),
    );
  }
}

class _MetricHero extends StatelessWidget {
  const _MetricHero({
    required this.value,
    required this.unit,
    required this.label,
    required this.color,
  });

  final String value;
  final String unit;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: text.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: text.bodySmall?.copyWith(
                color: tokens.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Text(
          label.toUpperCase(),
          style: text.labelSmall?.copyWith(
            color: tokens.textTertiary,
            fontSize: 9,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sp3,
        vertical: AppSizes.sp2 - 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            'BERJALAN',
            style: text.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.summary});
  final TripSummary summary;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _Chip(
        icon: PhosphorIconsRegular.path,
        label: Formatters.distance(summary.totalDistanceMeters),
      ),
      _Chip(
        icon: PhosphorIconsRegular.timer,
        label: Formatters.compactDuration(summary.totalDuration),
      ),
      _Chip(
        icon: PhosphorIconsRegular.frameCorners,
        label: _formatArea(summary.totalSweptAreaM2),
      ),
    ];
    return Wrap(
      spacing: AppSizes.sp2,
      runSpacing: AppSizes.sp2,
      children: chips,
    );
  }

  String _formatArea(double m2) {
    if (m2 <= 0) return '0 m²';
    if (m2 < 10000) return '${m2.round()} m²';
    final ha = m2 / 10000.0;
    return '${ha.toStringAsFixed(ha < 10 ? 2 : 1)} ha';
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sp3 - 2,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: tokens.surface1,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: tokens.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: text.labelSmall?.copyWith(
              color: tokens.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Decorative mini polyline. For now, draws `haulCount` evenly-spaced
/// curved segments in different colors — proper per-haul previews require
/// loading each haul's points, which we do lazily on the detail screen.
class _MiniTrack extends StatelessWidget {
  const _MiniTrack({required this.summary});
  final TripSummary summary;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: tokens.surface1,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: CustomPaint(
        painter: _MiniTrackPainter(
          haulCount: summary.haulCount,
          colors: List<Color>.generate(
            summary.haulCount,
            (i) => AppColors.colorForHaul(i + 1),
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _MiniTrackPainter extends CustomPainter {
  _MiniTrackPainter({required this.haulCount, required this.colors});
  final int haulCount;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (haulCount == 0) return;
    final segmentWidth = size.width / haulCount;
    for (var i = 0; i < haulCount; i++) {
      final path = Path();
      final x0 = i * segmentWidth;
      final x1 = x0 + segmentWidth;
      final yMid = size.height / 2;
      path.moveTo(x0 + 4, yMid);
      path.cubicTo(
        x0 + segmentWidth * 0.3, yMid - 12,
        x0 + segmentWidth * 0.7, yMid + 10,
        x1 - 4, yMid,
      );

      final paint = Paint()
        ..color = colors[i % colors.length]
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniTrackPainter old) =>
      old.haulCount != haulCount;
}
