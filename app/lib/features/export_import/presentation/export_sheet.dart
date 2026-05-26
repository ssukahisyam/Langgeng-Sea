import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../../tracking/domain/entities/trip.dart';
import '../data/export_service.dart';

/// Bottom sheet for exporting trip data.
///
/// Shows trip preview info, format picker, share app shortcuts,
/// and a "Bagikan Sekarang" primary button. Matches Screen 09 prototype.
class ExportSheet extends ConsumerStatefulWidget {
  const ExportSheet({
    super.key,
    required this.trip,
  });

  final Trip trip;

  /// Convenience static method to show the export sheet.
  static Future<void> show(BuildContext context, Trip trip) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExportSheet(trip: trip),
    );
  }

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  ExportFormat _selectedFormat = ExportFormat.lseaJson;
  bool _isExporting = false;
  // PR #27 R6 — toggle "Sertakan penanda dalam area trip". Default ON
  // supaya share-per-trip dari TripDetailScreen otomatis bawa marker
  // (perilaku kemarin), tapi user bisa matikan kalau hanya butuh
  // jalur saja.
  bool _includeMarkers = true;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = context.text;

    return GlassCard(
      level: GlassLevel.level3,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSizes.radiusXl),
      ),
      padding: const EdgeInsets.all(AppSizes.sp6),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSizes.sp5),
                decoration: BoxDecoration(
                  color: tokens.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Text(
              'Ekspor Data Trip',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSizes.sp2),

            // Trip preview info
            Text(
              widget.trip.name ??
                  'Trip ${widget.trip.startedAt.day}/${widget.trip.startedAt.month}/${widget.trip.startedAt.year}',
              style: textTheme.bodyMedium?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.sp5),

            // Format picker
            Text(
              'Format File',
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.sp3),
            Row(
              children: [
                Expanded(
                  child: _FormatItem(
                    label: 'Styra',
                    subtitle: '.lsea.json',
                    icon: PhosphorIconsBold.fileCode,
                    isActive: _selectedFormat == ExportFormat.lseaJson,
                    onTap: () => setState(() {
                      _selectedFormat = ExportFormat.lseaJson;
                    }),
                  ),
                ),
                const SizedBox(width: AppSizes.sp3),
                Expanded(
                  child: _FormatItem(
                    label: 'GPX Universal',
                    subtitle: '.gpx',
                    icon: PhosphorIconsBold.mapPin,
                    isActive: _selectedFormat == ExportFormat.gpx,
                    onTap: () => setState(() {
                      _selectedFormat = ExportFormat.gpx;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sp4),

            // PR #27 R6 — toggle penanda. Hanya berfungsi di GPX
            // (LSEA-JSON path lama selalu ikut markers; tetap kita
            // honor toggle-nya supaya UX konsisten).
            _IncludeMarkersToggle(
              value: _includeMarkers,
              onChanged: (v) => setState(() => _includeMarkers = v),
            ),
            const SizedBox(height: AppSizes.sp5),

            // Share app icons
            Text(
              'Bagikan Via',
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.sp3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const _ShareAppIcon(
                  icon: PhosphorIconsBold.whatsappLogo,
                  label: 'WhatsApp',
                  color: Color(0xFF25D366),
                ),
                const _ShareAppIcon(
                  icon: PhosphorIconsBold.telegramLogo,
                  label: 'Telegram',
                  color: Color(0xFF0088CC),
                ),
                _ShareAppIcon(
                  icon: PhosphorIconsBold.envelope,
                  label: 'Email',
                  color: tokens.textSecondary,
                ),
                _ShareAppIcon(
                  icon: PhosphorIconsBold.floppyDisk,
                  label: 'Simpan',
                  color: tokens.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sp6),

            // Primary action
            PrimaryActionButton(
              label: _isExporting ? 'Memproses...' : 'Bagikan Sekarang',
              icon: PhosphorIconsBold.shareFat,
              onPressed: _isExporting ? null : _handleExport,
            ),
            const SizedBox(height: AppSizes.sp3),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);

    try {
      final exportService = ref.read(exportServiceProvider);
      // PR #27 R6 — pakai exportTrip yang sekarang otomatis menarik
      // user profile dari repository (lihat ExportService.exportTrip).
      // userName/vesselName diisi `null` supaya fallback ke
      // UserProfile, jadi file GPX yang di-share dari sini punya
      // <lsea:exporter> block yang sama dengan path Settings → Ekspor.
      final file = await exportService.exportTrip(
        tripId: widget.trip.id,
        format: _selectedFormat,
        includeMarkers: _includeMarkers,
      );

      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Data Trip - Styra',
        text: 'Data trip dari Styra',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengekspor: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }
}

/// A format option tile with active/inactive state.
class _FormatItem extends StatelessWidget {
  const _FormatItem({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSizes.sp4),
        decoration: BoxDecoration(
          color: isActive ? tokens.primarySoft : tokens.surface1,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: isActive ? colors.primary : tokens.border,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isActive ? colors.primary : tokens.textSecondary,
              size: 28,
            ),
            const SizedBox(height: AppSizes.sp2),
            Text(
              label,
              style: context.text.labelMedium?.copyWith(
                color: isActive ? colors.primary : null,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            Text(
              subtitle,
              style: context.text.bodySmall?.copyWith(
                color: tokens.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Share app shortcut icon.
class _ShareAppIcon extends StatelessWidget {
  const _ShareAppIcon({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: AppSizes.sp1),
        Text(
          label,
          style: context.text.bodySmall?.copyWith(
            color: context.tokens.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}


/// Toggle row "Sertakan penanda dalam area trip".
///
/// Visual: chip-style row dengan icon, judul, subtitle, dan Switch
/// di kanan. Mirror visual style dari `_FormatItem` tapi single-row
/// (bukan card 2-column).
class _IncludeMarkersToggle extends StatelessWidget {
  const _IncludeMarkersToggle({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    final text = context.text;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.sp3,
            vertical: AppSizes.sp2,
          ),
          decoration: BoxDecoration(
            color: value ? tokens.primarySoft : tokens.surface1,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(
              color: value ? colors.primary : tokens.border,
              width: value ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                PhosphorIconsBold.mapPin,
                size: 18,
                color: value ? colors.primary : tokens.textSecondary,
              ),
              const SizedBox(width: AppSizes.sp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sertakan Penanda',
                      style: text.labelMedium?.copyWith(
                        color: value ? colors.primary : null,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Spot produktif, karang, pelabuhan',
                      style: text.bodySmall?.copyWith(
                        color: tokens.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
