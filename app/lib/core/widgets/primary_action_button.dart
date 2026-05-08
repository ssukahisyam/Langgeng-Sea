import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// Variants for the primary liquid-glass CTA.
enum ActionButtonVariant { primary, success, danger, accent }

/// Big, thumb-friendly CTA button with gradient fill and soft glow.
/// Sized generously for use on a rocking boat deck.
class PrimaryActionButton extends StatefulWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = ActionButtonVariant.primary,
    this.critical = false,
    this.expanded = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final ActionButtonVariant variant;

  /// Critical = bigger (72dp min) for primary trawl actions.
  final bool critical;

  /// Expand to fill parent width.
  final bool expanded;

  @override
  State<PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<PrimaryActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;

    final gradient = switch (widget.variant) {
      ActionButtonVariant.primary => tokens.primaryGradient,
      ActionButtonVariant.success => tokens.successGradient,
      ActionButtonVariant.danger => tokens.dangerGradient,
      ActionButtonVariant.accent => tokens.accentGradient,
    };

    final glowColor = switch (widget.variant) {
      ActionButtonVariant.primary => tokens.glowPrimary,
      ActionButtonVariant.success => tokens.success.withValues(alpha: 0.4),
      ActionButtonVariant.danger => tokens.danger.withValues(alpha: 0.4),
      ActionButtonVariant.accent =>
        Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4),
    };

    final minHeight = widget.critical
        ? AppSizes.touchTargetCritical
        : AppSizes.touchTargetPrimary;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.expanded ? double.infinity : null,
          constraints: BoxConstraints(minHeight: minHeight),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            boxShadow: [
              BoxShadow(
                color: glowColor,
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.sp5,
                  vertical: AppSizes.sp4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        color: Colors.white,
                        size: widget.critical ? 24 : 20,
                      ),
                      const SizedBox(width: AppSizes.sp2),
                    ],
                    Flexible(
                      child: Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        style: text.labelLarge?.copyWith(
                          color: Colors.white,
                          fontSize: widget.critical ? 17 : 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: widget.critical ? 0.5 : 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
