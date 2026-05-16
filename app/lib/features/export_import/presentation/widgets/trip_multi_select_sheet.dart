import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../../tracking/domain/entities/trip_summary.dart';

/// Modal bottom sheet untuk memilih subset trip yang akan diekspor.
///
/// Resolved value: `Set<String>?`
/// - `null` = "semua trip dalam rentang" (user tutup tanpa apply, atau
///   tap "Pilih semua" + apply, atau "Reset")
/// - `Set<String>` non-empty = subset yang dipilih
/// - empty Set = user men-deselect semua (UI di parent menampilkan
///   tombol Ekspor disabled)
///
/// Lihat PR #27 R5 — section "Pilih trip" di ExportScreen.
class TripMultiSelectSheet extends StatefulWidget {
  const TripMultiSelectSheet({
    super.key,
    required this.allTrips,
    required this.initialSelection,
  });

  /// Daftar trip yang BISA dipilih. Caller biasanya kasih superset
  /// (semua trip) supaya user bisa juga melebar dari rentang
  /// tanggal aktif.
  final List<TripSummary> allTrips;

  /// Trip yang sudah ter-pilih sebelumnya. `null` = semua.
  final Set<String>? initialSelection;

  static Future<Set<String>?> show(
    BuildContext context, {
    required List<TripSummary> allTrips,
    required Set<String>? initialSelection,
  }) {
    return showModalBottomSheet<Set<String>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TripMultiSelectSheet(
        allTrips: allTrips,
        initialSelection: initialSelection,
      ),
    );
  }

  @override
  State<TripMultiSelectSheet> createState() => _TripMultiSelectSheetState();
}

class _TripMultiSelectSheetState extends State<TripMultiSelectSheet> {
  late Set<String> _selected;
  // Sentinel: initial selection null = "semua dipilih" mental model
  // saat sheet pertama kali dibuka. User boleh ubah jadi subset
  // eksplisit, lalu pas apply kita decide null vs Set di
  // [_resolvedValue].
  late bool _wasInitiallyAll;

  @override
  void initState() {
    super.initState();
    _wasInitiallyAll = widget.initialSelection == null;
    _selected = _wasInitiallyAll
        ? widget.allTrips.map((t) => t.trip.id).toSet()
        : Set<String>.from(widget.initialSelection!);
  }

  bool get _allSelected => _selected.length == widget.allTrips.length;
  bool get _noneSelected => _selected.isEmpty;

  Set<String>? _resolvedValue() {
    // Kalau user end-state-nya semua dipilih DAN sebelumnya juga
    // semua → return null supaya filter pakai "semua dalam rentang"
    // (lebih dynamic — kalau ada trip baru muncul, ikut otomatis).
    if (_allSelected && _wasInitiallyAll) return null;
    return Set<String>.from(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    final colors = context.colors;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return GlassCard(
          level: GlassLevel.level3,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSizes.radiusXl),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSizes.sp4,
            AppSizes.sp3,
            AppSizes.sp4,
            AppSizes.sp4,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSizes.sp4),
                    decoration: BoxDecoration(
                      color: tokens.textTertiary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header row: title + select-all toggle
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pilih Trip',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          if (_allSelected) {
                            _selected.clear();
                          } else {
                            _selected = widget.allTrips
                                .map((t) => t.trip.id)
                                .toSet();
                          }
                        });
                      },
                      icon: Icon(
                        _allSelected
                            ? PhosphorIconsBold.minusCircle
                            : PhosphorIconsBold.checkCircle,
                        size: 16,
                      ),
                      label: Text(
                        _allSelected ? 'Batalkan semua' : 'Pilih semua',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.sp1),
                Text(
                  '${_selected.length} dari ${widget.allTrips.length} trip dipilih',
                  style: text.bodySmall?.copyWith(
                    color: tokens.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSizes.sp3),

                // List trip dengan ringkasan + checkbox.
                Expanded(
                  child: widget.allTrips.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSizes.sp5),
                            child: Text(
                              'Belum ada trip yang tersimpan.',
                              style: text.bodyMedium?.copyWith(
                                color: tokens.textTertiary,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: widget.allTrips.length,
                          itemBuilder: (context, i) {
                            final summary = widget.allTrips[i];
                            final id = summary.trip.id;
                            final selected = _selected.contains(id);
                            return _TripCheckRow(
                              summary: summary,
                              selected: selected,
                              onToggle: () => setState(() {
                                if (selected) {
                                  _selected.remove(id);
                                } else {
                                  _selected.add(id);
                                }
                              }),
                            );
                          },
                        ),
                ),

                const SizedBox(height: AppSizes.sp3),

                // Apply / Cancel actions.
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSizes.sp3,
                          ),
                          side: BorderSide(color: tokens.border),
                        ),
                        child: Text(
                          'Batal',
                          style: text.labelLarge?.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.sp3),
                    Expanded(
                      flex: 2,
                      child: PrimaryActionButton(
                        label: _noneSelected
                            ? 'Pilih dulu trip-nya'
                            : 'Terapkan (${_selected.length})',
                        icon: PhosphorIconsBold.check,
                        onPressed: _noneSelected
                            ? null
                            : () => Navigator.of(context).pop(_resolvedValue()),
                      ),
                    ),
                  ],
                ),

                // Helper note: stepless info kalau noneSelected supaya
                // tidak silent disabled.
                if (_noneSelected) ...[
                  const SizedBox(height: AppSizes.sp2),
                  Text(
                    'Pilih minimal satu trip untuk menerapkan.',
                    style: text.bodySmall?.copyWith(color: colors.primary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Single row: trip ringkasan + checkbox.
class _TripCheckRow extends StatelessWidget {
  const _TripCheckRow({
    required this.summary,
    required this.selected,
    required this.onToggle,
  });

  final TripSummary summary;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    final colors = context.colors;

    final trip = summary.trip;
    final dateLabel = _formatDate(trip.startedAt);
    final stats = <String>[
      '${summary.haulCount} tarikan',
      if (summary.totalDistanceMeters > 0)
        '${(summary.totalDistanceMeters / 1000).toStringAsFixed(1)} km',
    ].join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.sp2,
            vertical: AppSizes.sp3,
          ),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (_) => onToggle(),
                activeColor: colors.primary,
              ),
              const SizedBox(width: AppSizes.sp1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      trip.name ?? 'Trip $dateLabel',
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dateLabel · $stats',
                      style: text.bodySmall?.copyWith(
                        color: tokens.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  String _formatDate(DateTime t) {
    return '${t.day} ${_months[t.month - 1]} ${t.year}';
  }
}
