import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';

/// Bottom sheet for picking a haul/trip polyline colour.
///
/// Surfaces the pre-defined [AppColors.pickablePalette] as a grid of
/// colour swatches, plus a "Kustom…" option that opens a hex colour
/// picker via `flutter_colorpicker`.
///
/// Returns the selected colour as an `int?` (ARGB32). Returns `null`
/// when the user taps "Hapus warna" to revert to the auto-assigned
/// palette colour.
///
/// _Requirements: 11.1, 12.2_
class ColorPickerSheet extends StatefulWidget {
  const ColorPickerSheet({
    super.key,
    this.currentColorValue,
  });

  /// Current colour (ARGB32 int) if the user has previously picked one.
  /// `null` means "auto-assigned" — the Reset button is hidden in that
  /// case.
  final int? currentColorValue;

  /// Show the sheet and return the picked colour, or `null` to clear.
  ///
  /// Returns `Future<int?>` where:
  /// - `int` = user picked a colour (ARGB32).
  /// - `null` = user wants to clear the colour (reset to auto).
  /// - If the user dismisses without picking, the Future completes
  ///   without popping a value (caller should guard for this).
  static Future<int?> show(
    BuildContext context, {
    int? currentColorValue,
  }) async {
    return showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ColorPickerSheet(
        currentColorValue: currentColorValue,
      ),
    );
  }

  @override
  State<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<ColorPickerSheet> {
  Color? _customColor;

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

            Text('Pilih Warna', style: text.titleMedium),
            const SizedBox(height: AppSizes.sp3),

            // Palette grid
            Wrap(
              spacing: AppSizes.sp2,
              runSpacing: AppSizes.sp2,
              children: [
                for (final entry in AppColors.pickablePalette)
                  _SwatchButton(
                    color: entry.color,
                    label: entry.label,
                    isSelected: widget.currentColorValue == entry.color.toARGB32(),
                    onTap: () => Navigator.of(context).pop(entry.color.toARGB32()),
                  ),
                // Custom colour button
                _SwatchButton(
                  color: null,
                  label: 'Kustom',
                  isSelected: false,
                  isCustom: true,
                  onTap: () => _showCustomPicker(context),
                ),
              ],
            ),

            // Reset button (only shown when a colour is currently set)
            if (widget.currentColorValue != null) ...[
              const SizedBox(height: AppSizes.sp3),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(null),
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Hapus warna (otomatis)'),
                style: TextButton.styleFrom(
                  foregroundColor: tokens.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomPicker(BuildContext context) async {
    _customColor = widget.currentColorValue != null
        ? Color(widget.currentColorValue!)
        : AppColors.haulColors.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Warna Kustom'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _customColor!,
            onColorChanged: (c) => _customColor = c,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Pilih'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted && _customColor != null) {
      Navigator.of(context).pop(_customColor!.toARGB32());
    }
  }
}

/// A single swatch button in the palette grid.
class _SwatchButton extends StatelessWidget {
  const _SwatchButton({
    required this.color,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isCustom = false,
  });

  final Color? color;
  final String label;
  final bool isSelected;
  final bool isCustom;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isCustom ? tokens.surface3 : color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? Colors.white
                  : tokens.borderStrong,
              width: isSelected ? 3 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (color ?? tokens.textTertiary)
                          .withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: isCustom
              ? Icon(
                  Icons.palette,
                  color: tokens.textSecondary,
                  size: 20,
                )
              : isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
        ),
      ),
    );
  }
}

// Extension to get ARGB32 int from Color (Flutter 3.27+ compatible).
extension _ColorToARGB32 on Color {
  int toARGB32() {
    return (a * 255).round() << 24 |
        (r * 255).round() << 16 |
        (g * 255).round() << 8 |
        (b * 255).round();
  }
}
