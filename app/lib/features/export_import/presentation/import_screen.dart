import 'dart:io' as io;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../data/gpx_importer.dart';

/// Screen for importing .gpx files exchanged between fishermen.
///
/// Flow: pick file -> validate -> show preview -> commit (insert
/// waypoints as markers; tracks are previewed only until that flow is
/// wired up — see [GpxImporter.import]).
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  GpxImportPreview? _preview;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Impor Data GPX'),
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
                _InfoBanner(),
                const SizedBox(height: AppSizes.sp5),

                // File picker card
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
                              'Pilih File .gpx',
                              style: context.text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Cari file GPX dari aplikasi peta lain '
                              'atau hasil ekspor Langgeng Sea',
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

                if (_preview != null) ...[
                  const SizedBox(height: AppSizes.sp5),
                  _PreviewCard(preview: _preview!),
                  const SizedBox(height: AppSizes.sp5),
                  PrimaryActionButton(
                    label: _isImporting ? 'Mengimpor...' : 'Impor ke Aplikasi',
                    icon: PhosphorIconsBold.downloadSimple,
                    onPressed:
                        (_preview!.hasAny && !_isImporting) ? _handleImport : null,
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
        type: FileType.any,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final file = result.files.first;
      String content;
      if (file.bytes != null) {
        content = String.fromCharCodes(file.bytes!);
      } else if (file.path != null) {
        content = await io.File(file.path!).readAsString();
      } else {
        throw const FormatException('Tidak dapat membaca file.');
      }

      final importer = ref.read(gpxImporterProvider);
      final preview = importer.parse(content, fileName: file.name);

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

  Future<void> _handleImport() async {
    if (_preview == null) return;
    setState(() => _isImporting = true);
    try {
      final importer = ref.read(gpxImporterProvider);
      final inserted = await importer.import(_preview!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berhasil impor $inserted penanda.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _errorMessage = 'Gagal mengimpor: $e';
      });
    }
  }
}

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
              'Saat ini hanya penanda (waypoint) yang langsung masuk '
              'ke daftar penanda Anda. Jejak track akan ditampilkan di '
              'pratinjau saja.',
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

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final GpxImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = context.text;

    return GlassCard(
      level: GlassLevel.level2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pratinjau',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSizes.sp3),
          _StatRow(
            icon: PhosphorIconsBold.mapPinLine,
            label: 'Penanda',
            value: '${preview.waypointCount}',
          ),
          const SizedBox(height: AppSizes.sp2),
          _StatRow(
            icon: PhosphorIconsBold.path,
            label: 'Jejak Track',
            value: '${preview.trackCount}',
          ),
          const SizedBox(height: AppSizes.sp2),
          _StatRow(
            icon: PhosphorIconsBold.dotsSixVertical,
            label: 'Total Titik Track',
            value: '${preview.totalTrackPoints}',
          ),
          if (!preview.hasAny) ...[
            const SizedBox(height: AppSizes.sp3),
            Text(
              'File tidak berisi data yang bisa diimpor.',
              style: textTheme.bodySmall?.copyWith(color: tokens.danger),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.tokens.textSecondary),
        const SizedBox(width: AppSizes.sp3),
        Expanded(
          child: Text(
            label,
            style: context.text.bodyMedium?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
