import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';

/// The action chosen from [ItemOptionsSheet].
/// Declared at library scope so callers can switch on it without
/// importing private names.
enum ItemOption { rename, changeColor, delete, dismissed }

/// Generic glass bottom sheet with Rename / Delete actions.
/// Used for both trips and hauls — callers resolve the enum and apply
/// the matching repository call.
class ItemOptionsSheet extends StatelessWidget {
  const ItemOptionsSheet({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  static Future<ItemOption> show(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) async {
    final result = await showModalBottomSheet<ItemOption>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ItemOptionsSheet(title: title, subtitle: subtitle),
    );
    return result ?? ItemOption.dismissed;
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.sp4,
        right: AppSizes.sp4,
        top: AppSizes.sp4,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.sp4,
      ),
      child: GlassCard(
        level: GlassLevel.level3,
        padding: const EdgeInsets.fromLTRB(
          AppSizes.sp4,
          AppSizes.sp3,
          AppSizes.sp4,
          AppSizes.sp4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.sp4),
            Text(
              title,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: text.bodySmall?.copyWith(
                  color: tokens.textTertiary,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSizes.sp4),
            _OptionRow(
              icon: PhosphorIconsBold.pencilSimple,
              label: 'Ubah Nama',
              onTap: () =>
                  Navigator.of(context).pop(ItemOption.rename),
            ),
            Divider(height: 1, color: tokens.border),
            _OptionRow(
              icon: PhosphorIconsBold.palette,
              label: 'Ubah Warna',
              onTap: () =>
                  Navigator.of(context).pop(ItemOption.changeColor),
            ),
            Divider(height: 1, color: tokens.border),
            _OptionRow(
              icon: PhosphorIconsBold.trash,
              label: 'Hapus',
              destructive: true,
              onTap: () =>
                  Navigator.of(context).pop(ItemOption.delete),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    final color = destructive ? tokens.danger : tokens.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.sp3 + 2),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSizes.sp3),
              Text(
                label,
                style: text.labelLarge?.copyWith(
                  color: destructive ? tokens.danger : null,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
