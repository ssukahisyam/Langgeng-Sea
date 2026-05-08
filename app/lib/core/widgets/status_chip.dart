import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

enum StatusVariant { success, warning, danger, neutral, info }

/// Small pill-shaped status indicator.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.icon,
    this.variant = StatusVariant.neutral,
    this.showDot = false,
  });

  final String label;
  final IconData? icon;
  final StatusVariant variant;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;

    final (bg, fg) = switch (variant) {
      StatusVariant.success => (
          tokens.success.withValues(alpha: 0.12),
          tokens.success,
        ),
      StatusVariant.warning => (
          tokens.warning.withValues(alpha: 0.15),
          tokens.warning,
        ),
      StatusVariant.danger => (
          tokens.danger.withValues(alpha: 0.12),
          tokens.danger,
        ),
      StatusVariant.info => (
          tokens.primarySoft,
          context.colors.primary,
        ),
      StatusVariant.neutral => (
          tokens.surface1,
          tokens.textSecondary,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sp3,
        vertical: AppSizes.sp1 + 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: fg,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSizes.sp2),
          ],
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: AppSizes.sp1 + 2),
          ],
          Text(
            label,
            style: text.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
