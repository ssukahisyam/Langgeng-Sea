import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/offline_region.dart';

/// One row in the "Peta Offline" list. Leads with a status dot, shows
/// the region name + byte size + zoom range, and ends with a trailing
/// options button.
class RegionTile extends StatelessWidget {
  const RegionTile({
    super.key,
    required this.region,
    required this.onTap,
    required this.onDelete,
    this.onRetry,
    this.progressFraction,
  });

  final OfflineRegion region;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// Non-null when this region is the currently-running download.
  final VoidCallback? onRetry;
  final double? progressFraction;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    final isDownloading = region.status == OfflineRegionStatus.downloading;
    final isFailed = region.status == OfflineRegionStatus.failed;

    final (statusLabel, statusColor) = switch (region.status) {
      OfflineRegionStatus.completed => ('Tersimpan', tokens.success),
      OfflineRegionStatus.downloading => ('Mengunduh', context.colors.primary),
      OfflineRegionStatus.pending => ('Antri', tokens.textTertiary),
      OfflineRegionStatus.failed => ('Gagal', tokens.danger),
    };

    return GlassCard(
      level: GlassLevel.level2,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSizes.sp4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _StatusDot(color: statusColor, pulsing: isDownloading),
              const SizedBox(width: AppSizes.sp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      region.name,
                      style: text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$statusLabel · ${region.humanReadableSize()} · '
                      'zoom ${region.minZoom}–${region.maxZoom}',
                      style: text.bodySmall?.copyWith(
                        color: tokens.textTertiary,
                        fontSize: 12,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: 'Hapus',
                icon: Icon(
                  PhosphorIconsRegular.trash,
                  size: 18,
                  color: tokens.textTertiary,
                ),
              ),
            ],
          ),
          if (isDownloading && progressFraction != null) ...[
            const SizedBox(height: AppSizes.sp3),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusPill),
              child: LinearProgressIndicator(
                value: progressFraction,
                minHeight: 6,
                backgroundColor: tokens.surface1,
                valueColor:
                    AlwaysStoppedAnimation<Color>(context.colors.primary),
              ),
            ),
          ],
          if (isFailed && region.lastError != null) ...[
            const SizedBox(height: AppSizes.sp3),
            _ErrorRow(
              message: region.lastError!,
              onRetry: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.color, required this.pulsing});
  final Color color;
  final bool pulsing;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.pulsing) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant _StatusDot old) {
    super.didUpdateWidget(old);
    if (widget.pulsing && !_c.isAnimating) _c.repeat();
    if (!widget.pulsing && _c.isAnimating) _c.stop();
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
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: widget.pulsing
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: (1 - t) * 0.5),
                      blurRadius: 8 * (1 - t),
                      spreadRadius: 4 * (1 - t),
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message, required this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    return Row(
      children: [
        Icon(PhosphorIconsFill.warning, size: 14, color: tokens.danger),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: text.bodySmall?.copyWith(
              color: tokens.danger,
              fontSize: 11,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Ulangi',
              style: text.labelSmall?.copyWith(
                color: context.colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}
