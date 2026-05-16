import 'package:flutter/material.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';

/// Section wrapper untuk satu kelompok filter di ExportScreen.
///
/// Visual: header (icon + title) di luar GlassCard, isi (children)
/// di dalam GlassCard. Ini menjaga tata letak ExportScreen rapih
/// dengan vertical rhythm yang konsisten antar section.
class ExportFilterSection extends StatelessWidget {
  const ExportFilterSection({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSizes.sp1,
            right: AppSizes.sp1,
            bottom: AppSizes.sp2,
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: tokens.textSecondary),
              const SizedBox(width: AppSizes.sp2),
              Expanded(
                child: Text(
                  title,
                  style: text.labelLarge?.copyWith(
                    color: tokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        GlassCard(
          level: GlassLevel.level2,
          padding: const EdgeInsets.all(AppSizes.sp3),
          child: child,
        ),
      ],
    );
  }
}
