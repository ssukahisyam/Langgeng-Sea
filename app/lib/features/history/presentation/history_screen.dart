import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ambient_background.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;

    return AmbientBackground(
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.sp5,
                AppSizes.sp4,
                AppSizes.sp5,
                AppSizes.sp5,
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppStrings.tabHistory, style: text.headlineLarge),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(PhosphorIconsRegular.funnel),
                    ),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                icon: PhosphorIconsRegular.clockCounterClockwise,
                title: AppStrings.emptyHistoryTitle,
                message: AppStrings.emptyHistorySub,
                tokens: tokens,
                text: text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.tokens,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String message;
  final LangTokens tokens;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.sp8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: tokens.primarySoft,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              ),
              child: Icon(
                icon,
                size: 36,
                color: context.colors.primary,
              ),
            ),
            const SizedBox(height: AppSizes.sp5),
            Text(title, style: text.headlineSmall),
            const SizedBox(height: AppSizes.sp2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
