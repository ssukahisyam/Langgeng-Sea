import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../marker/domain/entities/marker.dart';

/// Bottom sheet for editing a marker's category.
///
/// Presents a list of [MarkerCategory] values as radio tiles. The user
/// taps to select, then confirms with "Simpan". Returns the selected
/// [MarkerCategory], or `null` if dismissed.
///
/// _Requirement: 13.4_
class EditMarkerCategorySheet extends StatefulWidget {
  const EditMarkerCategorySheet({
    super.key,
    required this.currentCategory,
    required this.markerName,
  });

  final MarkerCategory currentCategory;
  final String markerName;

  /// Show the sheet and return the selected category.
  static Future<MarkerCategory?> show(
    BuildContext context, {
    required MarkerCategory currentCategory,
    required String markerName,
  }) {
    return showModalBottomSheet<MarkerCategory>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditMarkerCategorySheet(
        currentCategory: currentCategory,
        markerName: markerName,
      ),
    );
  }

  @override
  State<EditMarkerCategorySheet> createState() =>
      _EditMarkerCategorySheetState();
}

class _EditMarkerCategorySheetState extends State<EditMarkerCategorySheet> {
  late MarkerCategory _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentCategory;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;

    return SafeArea(
      child: Padding(
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
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSizes.sp3),
                decoration: BoxDecoration(
                  color: tokens.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text(
              'Ubah Kategori',
              style: text.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              widget.markerName,
              style: text.bodySmall?.copyWith(color: tokens.textTertiary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSizes.sp3),

            // Category radio list
            for (final category in MarkerCategory.values)
              RadioListTile<MarkerCategory>(
                value: category,
                groupValue: _selected,
                onChanged: (v) {
                  if (v != null) setState(() => _selected = v);
                },
                title: Text(
                  category.displayLabel,
                  style: text.bodyMedium,
                ),
                secondary: Icon(
                  _iconForCategory(category),
                  color: _selected == category
                      ? context.colors.primary
                      : tokens.textTertiary,
                ),
                activeColor: context.colors.primary,
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),

            const SizedBox(height: AppSizes.sp3),

            // Save button
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_selected),
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.primary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                ),
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForCategory(MarkerCategory category) {
    return switch (category) {
      MarkerCategory.productive => PhosphorIconsFill.fish,
      MarkerCategory.hazard => PhosphorIconsFill.warningCircle,
      MarkerCategory.port => PhosphorIconsFill.anchor,
      MarkerCategory.other => PhosphorIconsFill.mapPin,
    };
  }
}
