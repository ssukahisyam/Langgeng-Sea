import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';

/// Destructive confirmation dialog used before deleting a trip or haul.
/// Resolves to `true` when the user explicitly confirms.
class DeleteConfirmDialog extends StatelessWidget {
  const DeleteConfirmDialog({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String body,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => DeleteConfirmDialog(title: title, body: body),
    );
    return result == true;
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
      icon: Icon(PhosphorIconsFill.trash, color: tokens.danger, size: 36),
      title: Text(title, style: text.titleLarge, textAlign: TextAlign.center),
      content: Text(
        body,
        style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Batal',
            style: text.labelMedium?.copyWith(color: tokens.textSecondary),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: tokens.danger,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
          child: const Text('Hapus'),
        ),
      ],
    );
  }
}
