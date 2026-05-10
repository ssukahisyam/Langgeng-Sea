import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/trip_repository.dart';

/// AlertDialog shown when the user taps "Akhiri Trip" from the haul
/// summary sheet. Lets them put an optional name on the trip before it
/// gets finalised.
///
/// Resolves to `true` when the user confirmed (name saved + trip
/// should now be ended by the caller), `false` when they cancelled.
class EndTripDialog extends ConsumerStatefulWidget {
  const EndTripDialog({
    super.key,
    required this.tripId,
    this.initialName,
  });

  final String tripId;
  final String? initialName;

  static Future<bool> show(
    BuildContext context, {
    required String tripId,
    String? initialName,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => EndTripDialog(
        tripId: tripId,
        initialName: initialName,
      ),
    );
    return result == true;
  }

  @override
  ConsumerState<EndTripDialog> createState() => _EndTripDialogState();
}

class _EndTripDialogState extends ConsumerState<EndTripDialog> {
  late final TextEditingController _ctl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);
    final typed = _ctl.text.trim();
    final name = typed.isEmpty ? null : typed;
    await ref
        .read(tripRepositoryProvider)
        .rename(widget.tripId, name);
    if (!mounted) return;
    Navigator.of(context).pop(true);
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
      title: Text('Akhiri Trip', style: text.titleLarge),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Beri nama trip ini agar mudah dicari di Riwayat.',
            style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: AppSizes.sp3),
          TextField(
            controller: _ctl,
            autofocus: true,
            textInputAction: TextInputAction.done,
            enabled: !_saving,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Nama trip (opsional)',
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
                borderSide:
                    BorderSide(color: context.colors.primary, width: 2),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(
            'Batal',
            style: text.labelMedium?.copyWith(color: tokens.textSecondary),
          ),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: tokens.danger,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Akhiri & Simpan'),
        ),
      ],
    );
  }
}
