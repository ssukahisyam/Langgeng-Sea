import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../../marker/domain/entities/marker.dart';
import '../../tracking/data/trip_repository.dart';
import '../../tracking/domain/entities/trip_summary.dart';
import '../application/export_preview_provider.dart';
import '../data/export_service.dart';
import '../domain/entities/date_range.dart';
import '../domain/entities/export_filter.dart';
import 'widgets/export_filter_section.dart';
import 'widgets/trip_multi_select_sheet.dart';

/// Screen ekspor lengkap (PR #27 R5).
///
/// 4 section filter:
/// 1. **Konten** — jalur tarikan / penanda / keduanya.
/// 2. **Rentang tanggal** — semua waktu / 7 hari / 30 hari / kustom.
/// 3. **Trip** — semua dalam rentang / pilih subset.
/// 4. **Kategori penanda** — chip per kategori.
///
/// Footer: ringkasan dari `exportPreviewProvider(filter)` + tombol
/// "Ekspor & Bagikan" yang disabled kalau preview kosong.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

/// Preset rentang tanggal yang ditawarkan di section 2.
enum _DateRangePreset { all, last7Days, last30Days, custom }

class _ExportScreenState extends ConsumerState<ExportScreen> {
  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------
  bool _includeTracks = true;
  bool _includeMarkers = true;

  _DateRangePreset _datePreset = _DateRangePreset.all;
  DateRange? _customRange;

  Set<String>? _selectedTripIds; // null = "semua dalam rentang"

  // null in filter = "semua kategori" (default).
  // Internal state tracks explicit selection set; we collapse to null
  // when all are selected.
  Set<MarkerCategory> _markerCategories = MarkerCategory.values.toSet();

  bool _isExporting = false;

  // ---------------------------------------------------------------------------
  // Filter computation
  // ---------------------------------------------------------------------------

  ExportFilter get _filter {
    final dateRange = _resolveDateRange();
    final markerCats = _markerCategories.length == MarkerCategory.values.length
        ? null
        : Set<MarkerCategory>.from(_markerCategories);

    return ExportFilter(
      includeTracks: _includeTracks,
      includeMarkers: _includeMarkers,
      dateRange: dateRange,
      tripIds: _selectedTripIds,
      markerCategories: markerCats,
    );
  }

  DateRange? _resolveDateRange() {
    switch (_datePreset) {
      case _DateRangePreset.all:
        return null;
      case _DateRangePreset.last7Days:
        return DateRange.last7Days();
      case _DateRangePreset.last30Days:
        return DateRange.last30Days();
      case _DateRangePreset.custom:
        return _customRange;
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.sp4,
                    AppSizes.sp3,
                    AppSizes.sp4,
                    AppSizes.sp4,
                  ),
                  children: [
                    _buildContentSection(),
                    const SizedBox(height: AppSizes.sp4),
                    if (_includeTracks) ...[
                      _buildDateRangeSection(),
                      const SizedBox(height: AppSizes.sp4),
                      _buildTripSection(),
                      const SizedBox(height: AppSizes.sp4),
                    ],
                    if (_includeMarkers) ...[
                      _buildCategorySection(),
                      const SizedBox(height: AppSizes.sp4),
                    ],
                  ],
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 1 — Konten
  // ---------------------------------------------------------------------------

  Widget _buildContentSection() {
    return ExportFilterSection(
      icon: PhosphorIconsBold.fileCode,
      title: 'Konten yang Diekspor',
      child: Column(
        children: [
          _ContentToggleRow(
            icon: PhosphorIconsBold.path,
            title: 'Jalur Tarikan',
            subtitle: 'Polyline + stats per haul',
            value: _includeTracks,
            onChanged: (v) => setState(() => _includeTracks = v),
          ),
          const SizedBox(height: AppSizes.sp1),
          _ContentToggleRow(
            icon: PhosphorIconsBold.mapPin,
            title: 'Penanda',
            subtitle: 'Spot produktif, karang, pelabuhan',
            value: _includeMarkers,
            onChanged: (v) => setState(() => _includeMarkers = v),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 2 — Rentang tanggal
  // ---------------------------------------------------------------------------

  Widget _buildDateRangeSection() {
    final tokens = context.tokens;
    final text = context.text;

    return ExportFilterSection(
      icon: PhosphorIconsBold.calendar,
      title: 'Rentang Tanggal',
      child: Column(
        children: [
          _RadioRow<_DateRangePreset>(
            value: _DateRangePreset.all,
            groupValue: _datePreset,
            label: 'Semua waktu',
            onChanged: _onDatePresetChanged,
          ),
          _RadioRow<_DateRangePreset>(
            value: _DateRangePreset.last7Days,
            groupValue: _datePreset,
            label: '7 hari terakhir',
            onChanged: _onDatePresetChanged,
          ),
          _RadioRow<_DateRangePreset>(
            value: _DateRangePreset.last30Days,
            groupValue: _datePreset,
            label: '30 hari terakhir',
            onChanged: _onDatePresetChanged,
          ),
          _RadioRow<_DateRangePreset>(
            value: _DateRangePreset.custom,
            groupValue: _datePreset,
            label: _customRange != null
                ? 'Kustom — ${_customRange!.describeIndonesian()}'
                : 'Pilih rentang…',
            onChanged: (v) {
              setState(() => _datePreset = v);
              _pickCustomDateRange();
            },
            trailing: _datePreset == _DateRangePreset.custom &&
                    _customRange != null
                ? Padding(
                    padding: const EdgeInsets.only(left: AppSizes.sp2),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _pickCustomDateRange,
                      child: Text(
                        'Ubah',
                        style: text.bodySmall?.copyWith(
                          color: tokens.textSecondary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  void _onDatePresetChanged(_DateRangePreset v) {
    setState(() {
      _datePreset = v;
      // Subset trip eksplisit di-reset kalau user ganti preset
      // tanggal — supaya tidak clash (subset trip override range
      // anyway, tapi UX lebih jelas).
      if (v != _DateRangePreset.custom && _selectedTripIds != null) {
        _selectedTripIds = null;
      }
    });
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final initial = _customRange ??
        DateRange.fromDates(
          from: now.subtract(const Duration(days: 14)),
          to: now,
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(
        start: initial.start,
        end: initial.end.subtract(const Duration(days: 1)),
      ),
      helpText: 'Pilih rentang tanggal',
      saveText: 'Pakai',
      cancelText: 'Batal',
    );
    if (picked == null) return;
    setState(() {
      _customRange = DateRange.fromDates(from: picked.start, to: picked.end);
      _datePreset = _DateRangePreset.custom;
    });
  }

  // ---------------------------------------------------------------------------
  // Section 3 — Trip
  // ---------------------------------------------------------------------------

  Widget _buildTripSection() {
    final tokens = context.tokens;
    final text = context.text;
    final summariesAsync = ref.watch(tripSummariesProvider);

    return ExportFilterSection(
      icon: PhosphorIconsFill.sailboat,
      title: 'Trip yang Diikutkan',
      child: summariesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSizes.sp3),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.sp3),
          child: Text(
            'Gagal memuat daftar trip: $e',
            style: text.bodySmall?.copyWith(color: tokens.danger),
          ),
        ),
        data: (summaries) {
          final filteredByDate = _filterTripsByDate(summaries);

          // Subset Set null → "semua dalam rentang" → count = filteredByDate.
          final activeCount =
              _selectedTripIds?.length ?? filteredByDate.length;

          final subtitle = _selectedTripIds == null
              ? 'Semua $activeCount trip dalam rentang'
              : '$activeCount dari ${filteredByDate.length} trip dipilih';

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: summaries.isEmpty
                  ? null
                  : () => _openTripPicker(summaries),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.sp2,
                  vertical: AppSizes.sp2,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            summaries.isEmpty
                                ? 'Belum ada trip tersimpan'
                                : 'Pilih trip…',
                            style: text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: text.bodySmall?.copyWith(
                              color: tokens.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedTripIds != null)
                      TextButton(
                        onPressed: () =>
                            setState(() => _selectedTripIds = null),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Reset',
                          style: text.bodySmall?.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                    Icon(
                      PhosphorIconsBold.caretRight,
                      size: 16,
                      color: tokens.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<TripSummary> _filterTripsByDate(List<TripSummary> all) {
    final r = _resolveDateRange();
    if (r == null) return all;
    return all.where((s) => r.contains(s.trip.startedAt)).toList();
  }

  Future<void> _openTripPicker(List<TripSummary> allTrips) async {
    final filteredByDate = _filterTripsByDate(allTrips);

    // Sheet pakai daftar yang sudah difilter rentang tanggal supaya
    // user tidak bingung kenapa trip lama muncul tapi tidak ikut.
    final picked = await TripMultiSelectSheet.show(
      context,
      allTrips: filteredByDate,
      initialSelection: _selectedTripIds,
    );

    if (!mounted) return;
    setState(() {
      _selectedTripIds = picked;
    });
  }

  // ---------------------------------------------------------------------------
  // Section 4 — Kategori penanda
  // ---------------------------------------------------------------------------

  Widget _buildCategorySection() {
    return ExportFilterSection(
      icon: PhosphorIconsBold.tag,
      title: 'Kategori Penanda',
      child: Wrap(
        spacing: AppSizes.sp2,
        runSpacing: AppSizes.sp2,
        children: [
          for (final cat in MarkerCategory.values)
            FilterChip(
              label: Text(cat.displayLabel),
              selected: _markerCategories.contains(cat),
              onSelected: (v) => setState(() {
                if (v) {
                  _markerCategories.add(cat);
                } else {
                  _markerCategories.remove(cat);
                }
              }),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Footer
  // ---------------------------------------------------------------------------

  Widget _buildFooter() {
    final tokens = context.tokens;
    final text = context.text;
    final filter = _filter;

    final previewAsync = filter.hasAnyContent
        ? ref.watch(exportPreviewProvider(filter))
        : const AsyncValue<ExportPreview>.data(ExportPreview.empty);

    final preview = previewAsync.maybeWhen(
      data: (p) => p,
      orElse: () => ExportPreview.empty,
    );
    final previewLoading = previewAsync.isLoading;

    final canExport = filter.hasAnyContent && !preview.isEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.sp4,
        AppSizes.sp3,
        AppSizes.sp4,
        AppSizes.sp4,
      ),
      decoration: BoxDecoration(
        color: tokens.surface3.withValues(alpha: 0.6),
        border: Border(
          top: BorderSide(color: tokens.border, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!filter.hasAnyContent)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.sp3),
              child: Text(
                'Pilih minimal satu konten (jalur atau penanda) '
                'untuk diekspor.',
                style: text.bodySmall?.copyWith(color: tokens.danger),
                textAlign: TextAlign.center,
              ),
            )
          else if (preview.isEmpty && !previewLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.sp3),
              child: Text(
                'Tidak ada data yang cocok dengan filter ini.',
                style: text.bodySmall?.copyWith(color: tokens.textSecondary),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            Row(
              children: [
                Icon(
                  PhosphorIconsBold.fileCode,
                  size: 14,
                  color: tokens.textSecondary,
                ),
                const SizedBox(width: AppSizes.sp1),
                Expanded(
                  child: Text(
                    _summaryLine(preview, filter),
                    style: text.bodySmall?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
                if (previewLoading)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                else
                  Text(
                    '≈ ${preview.formatEstimatedSize()}',
                    style: text.bodySmall?.copyWith(
                      color: tokens.textTertiary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.sp3),
          ],
          PrimaryActionButton(
            label: _isExporting ? 'Memproses…' : 'Ekspor & Bagikan',
            icon: PhosphorIconsBold.shareFat,
            onPressed:
                (canExport && !_isExporting) ? _handleExport : null,
          ),
        ],
      ),
    );
  }

  String _summaryLine(ExportPreview p, ExportFilter filter) {
    final parts = <String>[];
    if (filter.includeTracks) parts.add('${p.haulCount} tarikan');
    if (filter.includeMarkers) parts.add('${p.markerCount} penanda');
    return parts.join(' · ');
  }

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);
    try {
      // 1. Generate file ke internal app cache (existing path).
      final service = ref.read(exportServiceProvider);
      final file = await service.exportFiltered(filter: _filter);
      if (!mounted) return;

      // 2. Save copy ke folder pilihan user via Storage Access
      // Framework Android. User dapat pilih Downloads, Documents,
      // atau folder apapun di File Manager — file akan visible di
      // file manager OEM tanpa perlu permission khusus.
      final fileName = file.uri.pathSegments.last;
      final bytes = await file.readAsBytes();
      String? savedPath;
      try {
        savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Simpan file ekspor',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: const ['gpx'],
          bytes: bytes,
        );
      } catch (_) {
        // SAF picker gagal di beberapa OEM ROM (Xiaomi MIUI lama,
        // Huawei tanpa Google services). Fallback ke share-only.
        savedPath = null;
      }

      if (!mounted) return;

      // 3. Tampilkan snackbar konfirmasi dengan action Bagikan.
      if (savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Disimpan di $savedPath'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Bagikan',
              onPressed: () async {
                await Share.shareXFiles(
                  [XFile(file.path)],
                  subject: 'Data Styra',
                  text: 'Data ekspor dari aplikasi Styra',
                );
              },
            ),
          ),
        );
      } else {
        // Save dialog di-cancel atau gagal — fallback langsung ke share.
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Data Styra',
          text: 'Data ekspor dari aplikasi Styra',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengekspor: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

// =============================================================================
// Internal helper widgets
// =============================================================================

class _ContentToggleRow extends StatelessWidget {
  const _ContentToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
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
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.sp2,
            vertical: AppSizes.sp2,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: value ? tokens.primarySoft : tokens.accentSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: value ? colors.primary : tokens.textSecondary,
                ),
              ),
              const SizedBox(width: AppSizes.sp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: text.labelMedium),
                    const SizedBox(height: 2),
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

class _RadioRow<T> extends StatelessWidget {
  const _RadioRow({
    required this.value,
    required this.groupValue,
    required this.label,
    required this.onChanged,
    this.trailing,
  });

  final T value;
  final T groupValue;
  final String label;
  final ValueChanged<T> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sp1,
          vertical: AppSizes.sp1,
        ),
        child: Row(
          children: [
            Radio<T>(
              value: value,
              groupValue: groupValue,
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              activeColor: colors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: AppSizes.sp1),
            Expanded(child: Text(label, style: text.bodyMedium)),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
