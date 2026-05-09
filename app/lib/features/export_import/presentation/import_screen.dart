import 'dart:io' as io;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../data/lsea_json_importer.dart';

/// Screen for importing .lsea.json files from other users.
///
/// Flow: pick file → validate → show preview → (placeholder) import.
/// Accessible from the History tab or Settings.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  ImportPreview? _preview;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Impor Data'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.sp5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info banner
                _InfoBanner(),
                const SizedBox(height: AppSizes.sp5),

                // Pick file button
                GlassCard(
                  level: GlassLevel.level2,
                  onTap: _isLoading ? null : _pickFile,
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIconsBold.folderOpen,
                        color: context.colors.primary,
                        size: 28,
                      ),
                      const SizedBox(width: AppSizes.sp4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pilih File .lsea.json',
                              style: context.text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Cari file yang dikirim dari aplikasi Langgeng Sea lain',
                              style: context.text.bodySmall?.copyWith(
                                color: context.tokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          PhosphorIconsBold.caretRight,
                          color: context.tokens.textTertiary,
                        ),
                    ],
                  ),
                ),

                // Error message
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSizes.sp4),
                  GlassCard(
                    level: GlassLevel.level1,
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIconsBold.warningCircle,
                          color: context.tokens.danger,
                          size: 20,
                        ),
                        const SizedBox(width: AppSizes.sp3),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: context.text.bodySmall?.copyWith(
                              color: context.tokens.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Preview card
                if (_preview != null) ...[
                  const SizedBox(height: AppSizes.sp5),
                  _PreviewCard(preview: _preview!),
                  const SizedBox(height: AppSizes.sp5),
                  PrimaryActionButton(
                    label: 'Impor ke Data Bersama',
                    icon: PhosphorIconsBold.downloadSimple,
                    onPressed: _handleImport,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _preview = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final file = result.files.first;

      // If bytes is null (Android/iOS), try reading from path
      String jsonContent;
      if (file.bytes != null) {
        jsonContent = String.fromCharCodes(file.bytes!);
      } else if (file.path != null) {
        jsonContent = await io.File(file.path!).readAsString();
      } else {
        throw const FormatException('Tidak dapat membaca file.');
      }

      final importer = LseaJsonImporter();
      final preview = importer.parse(jsonContent);

      setState(() {
        _preview = preview;
        _isLoading = false;
      });
    } on FormatException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal membaca file: $e';
        _isLoading = false;
      });
    }
  }

  void _handleImport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data berhasil diimpor'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
  }
}

/// Info banner explaining imported data stays separate.
class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return GlassCard(
      level: GlassLevel.level1,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            PhosphorIconsBold.info,
            color: context.colors.primary,
            size: 20,
          ),
          const SizedBox(width: AppSizes.sp3),
          Expanded(
            child: Text(
              'Data yang diimpor akan tersimpan terpisah dari data '
              'trip Anda sendiri. Anda bisa melihat rute dan statistik '
              'dari nelayan lain tanpa mengubah data asli.',
              style: context.text.bodySmall?.copyWith(
                color: tokens.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Preview card showing imported data summary.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final ImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = context.text;
    final distanceKm = (preview.totalDistanceMeters / 1000).toStringAsFixed(1);
    final date =
        '${preview.exportedAt.day}/${preview.exportedAt.month}/${preview.exportedAt.year}';

    return GlassCard(
      level: GlassLevel.level2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with sender info
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tokens.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIconsBold.user,
                  color: context.colors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSizes.sp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.senderName,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      preview.vesselName,
                      style: textTheme.bodySmall?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sp4),

          // Stats row
          Row(
            children: [
              _StatItem(
                icon: PhosphorIconsBold.anchor,
                label: '${preview.haulCount} Haul',
              ),
              const SizedBox(width: AppSizes.sp5),
              _StatItem(
                icon: PhosphorIconsBold.path,
                label: '$distanceKm km',
              ),
              const SizedBox(width: AppSizes.sp5),
              _StatItem(
                icon: PhosphorIconsBold.calendar,
                label: date,
              ),
            ],
          ),

          if (preview.tripName != null) ...[
            const SizedBox(height: AppSizes.sp3),
            Text(
              'Trip: ${preview.tripName}',
              style: textTheme.bodySmall?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: context.tokens.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: context.text.bodySmall?.copyWith(
            color: context.tokens.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
