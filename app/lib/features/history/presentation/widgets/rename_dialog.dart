import 'package:flutter/material.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';

/// Modal text dialog for renaming a trip or haul.
///
/// Resolves with the trimmed new name, or `null` if cancelled. Callers
/// map an empty string to "clear the name" (so the UI falls back to the
/// auto-generated "Haul #N" display name).
class RenameDialog extends StatefulWidget {
  const RenameDialog({
    super.key,
    required this.title,
    required this.initial,
    this.hint,
  });

  final String title;
  final String initial;
  final String? hint;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String initial,
    String? hint,
  }) {
    return showDialog<String?>(
      context: context,
      barrierDismissible: true,
      builder: (_) => RenameDialog(
        title: title,
        initial: initial,
        hint: hint,
      ),
    );
  }

  @override
  State<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<RenameDialog> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.initial);
    _ctl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_ctl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    return AlertDialog(
      backgroundColor: tokens.surface3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
      ),
      title: Text(widget.title, style: text.titleLarge),
      content: TextField(
        controller: _ctl,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: widget.hint ?? 'Nama (opsional)',
          filled: true,
          fillColor: tokens.surface1,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            borderSide: BorderSide(color: tokens.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            borderSide: BorderSide(color: tokens.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            borderSide: BorderSide(color: context.colors.primary, width: 2),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Batal',
            style: text.labelMedium?.copyWith(color: tokens.textSecondary),
          ),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: context.colors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
