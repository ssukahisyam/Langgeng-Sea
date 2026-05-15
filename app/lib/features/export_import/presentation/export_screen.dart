import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../data/gpx_exporter.dart';

/// Data categories the user can select for export.
enum ExportCategory {
  all,
  tracksOnly,
  markersOnly,
}

/// Full-screen GPX export with checkbox-based data selection.
///
/// Issue 5 & 6 fix: replaces the old per-trip ExportSheet with a
/// global export screen that lets the user choose WHAT to export
/// (all data, tracks only, markers only) as checkboxes, then
/// generates a single .gpx file and opens the system share sheet.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  final Set<ExportCategory> _selected = {ExportCategory.all};
  bool _isExporting = false;

  void _onCategoryChanged(ExportCategory cat, bool checked) {
    setState(() {
      if (cat == ExportCategory.all) {
        // "Semua" is mutually exclusive with the others.
        if (checked) {
          _selected
            ..clear()
            ..add(ExportCategory.all);
        } else {
          _selected.remove(ExportCategory.all);
        }
      } else {
        // Toggling a specific category clears "Semua".
        _selected.remove(ExportCategory.all);
        if (checked) {
          _selected.add(cat);
        } else {
          _selected.remove(cat);
        }
        // If both specific categories are checked, collapse to "Semua".
        if (_selected.contains(ExportCategory.tracksOnly) &&
            _selected.contains(ExportCategory.markersOnly)) {
          _selected
            ..clear()
            ..add(ExportCategory.all);
        }
      }
    });
  }

  bool get _hasSelection => _selected.isNotEmpty;

  bool get _includeTracks =>
      _selected.contains(ExportCategory.all) ||
      _selected.contains(ExportCategory.tracksOnly);

  bool get _includeMarkers =>
      _selected.contains(ExportCategory.all) ||
      _selected.contains(ExportCategory.markersOnly);

  Future<void> _handleExport() async {
    if (!_hasSelection) return;
    setState(() => _isExporting = true);

    try {
      final exporter = ref.read(gpxExporterProvider);
      final file = await exporter.exportAll(
        includeTracks: _includeTracks,
        includeMarkers: _includeMarkers,
      );

      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Data GPX - Langgeng Sea',
        text: 'Data navigasi dari Langgeng Sea',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengekspor: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Ekspor Data'),
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
                GlassCard(
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
                          'Pilih data yang ingin diekspor. File akan '
                          'disimpan dalam format GPX yang bisa dibuka di '
                          'aplikasi peta manapun.',
                          style: text.bodySmall?.copyWith(
                            color: tokens.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.sp5),

                // Format indicator
                GlassCard(
                  level: GlassLevel.level2,
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIconsBold.mapPin,
                        color: context.colors.primary,
                        size: 28,
                      ),
                      const SizedBox(width: AppSizes.sp4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Format GPX',
                              style: text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'GPS Exchange Format (.gpx)',
                              style: text.bodySmall?.copyWith(
                                color: tokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.sp3,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.primarySoft,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusPill),
                        ),
                        child: Text(
                          'Universal',
                          style: text.labelSmall?.copyWith(
                            color: context.colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.sp5),

                // Data selection header
                Text(
                  'Pilih Data yang Diekspor',
                  style: text.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.sp3),

                // Checkboxes
                _ExportCheckbox(
                  icon: PhosphorIconsFill.database,
                  label: 'Semua Data',
                  subtitle: 'Trip, jalur, dan penanda',
                  checked: _selected.contains(ExportCategory.all),
                  onChanged: (v) =>
                      _onCategoryChanged(ExportCategory.all, v ?? false),
                ),
                const SizedBox(height: AppSizes.sp2),
                _ExportCheckbox(
                  icon: PhosphorIconsFill.path,
                  label: 'Jalur Saja',
                  subtitle: 'Track points dari semua tarikan',
                  checked: _selected.contains(ExportCategory.tracksOnly) ||
                      _selected.contains(ExportCategory.all),
                  onChanged: (v) =>
                      _onCategoryChanged(ExportCategory.tracksOnly, v ?? false),
                ),
                const SizedBox(height: AppSizes.sp2),
                _ExportCheckbox(
                  icon: PhosphorIconsFill.mapPinLine,
                  label: 'Penanda Saja',
                  subtitle: 'Semua waypoint / penanda',
                  checked: _selected.contains(ExportCategory.markersOnly) ||
                      _selected.contains(ExportCategory.all),
                  onChanged: (v) => _onCategoryChanged(
                      ExportCategory.markersOnly, v ?? false),
                ),

                const Spacer(),

                // Export button
                PrimaryActionButton(
                  label: _isExporting ? 'Memproses...' : 'Ekspor & Bagikan',
                  icon: PhosphorIconsBold.export,
                  onPressed:
                      (_hasSelection && !_isExporting) ? _handleExport : null,
                ),
                const SizedBox(height: AppSizes.sp3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExportCheckbox extends StatelessWidget {
  const _ExportCheckbox({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.checked,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool checked;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;

    return GlassCard(
      level: checked ? GlassLevel.level2 : GlassLevel.level1,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sp3,
        vertical: AppSizes.sp2,
      ),
      child: InkWell(
        onTap: () => onChanged(!checked),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Row(
          children: [
            Icon(
              icon,
              color: checked ? context.colors.primary : tokens.textTertiary,
              size: 22,
            ),
            const SizedBox(width: AppSizes.sp3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: checked ? null : tokens.textSecondary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: text.bodySmall?.copyWith(
                      color: tokens.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: checked,
              onChanged: onChanged,
              activeColor: context.colors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
