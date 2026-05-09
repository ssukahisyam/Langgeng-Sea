import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../domain/entities/marker.dart';

/// Dialog untuk menambahkan marker baru.
///
/// [latitude] dan [longitude] biasanya didapat dari long-press di peta.
/// Mengembalikan [AppMarker] jika user konfirmasi, null jika batal.
class AddMarkerDialog extends StatefulWidget {
  const AddMarkerDialog({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  @override
  State<AddMarkerDialog> createState() => _AddMarkerDialogState();
}

class _AddMarkerDialogState extends State<AddMarkerDialog> {
  static const _uuid = Uuid();

  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  MarkerCategory _category = MarkerCategory.productive;

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama marker wajib diisi')),
      );
      return;
    }

    final marker = AppMarker(
      id: _uuid.v4(),
      name: name,
      category: _category,
      latitude: widget.latitude,
      longitude: widget.longitude,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: DateTime.now(),
    );

    Navigator.of(context).pop(marker);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Marker'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Koordinat info
            Text(
              '${widget.latitude.toStringAsFixed(5)}, ${widget.longitude.toStringAsFixed(5)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: AppSizes.sp4),

            // Nama
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nama Marker',
                hintText: 'cth: Spot Udang Utara',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSizes.sp4),

            // Kategori
            DropdownButtonFormField<MarkerCategory>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                border: OutlineInputBorder(),
              ),
              items: MarkerCategory.values
                  .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(cat.displayLabel),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _category = val);
              },
            ),
            const SizedBox(height: AppSizes.sp4),

            // Notes (opsional)
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'Catatan tambahan...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
