import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../data/log_book_repository.dart';
import '../domain/entities/catch_item.dart';
import '../domain/entities/log_book_entry.dart';
import '../domain/fish_species_catalog.dart';

/// Form screen untuk log book digital.
///
/// Route params: haulId ATAU tripId (salah satu wajib).
class LogBookFormScreen extends ConsumerStatefulWidget {
  const LogBookFormScreen({
    super.key,
    this.haulId,
    this.tripId,
  });

  final String? haulId;
  final String? tripId;

  @override
  ConsumerState<LogBookFormScreen> createState() => _LogBookFormScreenState();
}

class _LogBookFormScreenState extends ConsumerState<LogBookFormScreen> {
  static const _uuid = Uuid();

  final _notesController = TextEditingController();

  Weather? _weather;
  WaveCondition? _wave;
  final List<_CatchRow> _catchRows = [];
  bool _isLoading = true;
  String? _existingEntryId;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final repo = ref.read(logBookRepositoryProvider);
    LogBookEntry? entry;
    if (widget.haulId != null) {
      entry = await repo.getByHaulId(widget.haulId!);
    } else if (widget.tripId != null) {
      entry = await repo.getByTripId(widget.tripId!);
    }

    if (entry != null && mounted) {
      setState(() {
        _existingEntryId = entry!.id;
        _weather = entry.weather;
        _wave = entry.wave;
        _notesController.text = entry.notes ?? '';
        _catchRows.addAll(
          entry.catches.map(
            (c) => _CatchRow(
              id: c.id,
              speciesController: TextEditingController(text: c.species),
              weightController: TextEditingController(
                text: c.weightKg?.toString() ?? '',
              ),
            ),
          ),
        );
      });
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final row in _catchRows) {
      row.speciesController.dispose();
      row.weightController.dispose();
    }
    super.dispose();
  }

  void _addCatchRow() {
    setState(() {
      _catchRows.add(
        _CatchRow(
          id: _uuid.v4(),
          speciesController: TextEditingController(),
          weightController: TextEditingController(),
        ),
      );
    });
  }

  void _removeCatchRow(int index) {
    final row = _catchRows.removeAt(index);
    row.speciesController.dispose();
    row.weightController.dispose();
    setState(() {});
  }

  Future<void> _save() async {
    final catches = _catchRows
        .where((r) => r.speciesController.text.trim().isNotEmpty)
        .map(
          (r) => CatchItem(
            id: r.id,
            species: r.speciesController.text.trim(),
            weightKg: double.tryParse(r.weightController.text.trim()),
          ),
        )
        .toList();

    final scope = widget.haulId != null ? LogBookScope.haul : LogBookScope.trip;
    final now = DateTime.now();

    final entry = LogBookEntry(
      id: _existingEntryId ?? _uuid.v4(),
      scope: scope,
      tripId: widget.tripId,
      haulId: widget.haulId,
      catches: catches,
      weather: _weather,
      wave: _wave,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: now,
      updatedAt: now,
    );

    final repo = ref.read(logBookRepositoryProvider);
    await repo.save(entry);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log book tersimpan')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final isHaulScope = widget.haulId != null;
    final titleText = isHaulScope ? 'Log Book Tarikan' : 'Log Book Trip';

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(titleText),
      ),
      body: AmbientBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSizes.sp5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- Catch Items ---
                      const _SectionHeader(
                        icon: PhosphorIconsBold.fish,
                        title: 'Hasil Tangkapan (opsional)',
                      ),
                      const SizedBox(height: AppSizes.sp3),
                      ..._buildCatchRows(),
                      const SizedBox(height: AppSizes.sp3),
                      OutlinedButton.icon(
                        onPressed: _addCatchRow,
                        icon: const Icon(PhosphorIconsBold.plus),
                        label: const Text('Tambah Jenis Ikan'),
                      ),

                      const SizedBox(height: AppSizes.sp6),

                      // --- Weather ---
                      const _SectionHeader(
                        icon: PhosphorIconsBold.sun,
                        title: 'Cuaca (opsional)',
                      ),
                      const SizedBox(height: AppSizes.sp3),
                      _buildWeatherPicker(tokens),

                      const SizedBox(height: AppSizes.sp6),

                      // --- Wave ---
                      const _SectionHeader(
                        icon: PhosphorIconsBold.waves,
                        title: 'Gelombang (opsional)',
                      ),
                      const SizedBox(height: AppSizes.sp3),
                      _buildWavePicker(tokens),

                      const SizedBox(height: AppSizes.sp6),

                      // --- Notes ---
                      const _SectionHeader(
                        icon: PhosphorIconsBold.notepad,
                        title: 'Catatan (opsional)',
                      ),
                      const SizedBox(height: AppSizes.sp3),
                      GlassCard(
                        child: TextField(
                          controller: _notesController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Catatan tambahan...',
                            border: InputBorder.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSizes.sp8),

                      // --- Save ---
                      PrimaryActionButton(
                        label: 'Simpan Log Book',
                        icon: PhosphorIconsBold.floppyDisk,
                        onPressed: _save,
                      ),

                      const SizedBox(height: AppSizes.sp6),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  List<Widget> _buildCatchRows() {
    return List.generate(_catchRows.length, (i) {
      final row = _catchRows[i];
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSizes.sp3),
        child: GlassCard(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Autocomplete<String>(
                  initialValue:
                      TextEditingValue(text: row.speciesController.text),
                  optionsBuilder: (value) {
                    if (value.text.isEmpty) return const [];
                    return FishSpeciesCatalog.search(value.text);
                  },
                  onSelected: (selected) {
                    row.speciesController.text = selected;
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onSubmitted) {
                    // Sync external controller
                    controller.addListener(() {
                      row.speciesController.text = controller.text;
                    });
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        hintText: 'Jenis ikan',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSizes.sp3),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: row.weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  decoration: const InputDecoration(
                    hintText: 'Kg',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(PhosphorIconsBold.trash, size: 18),
                onPressed: () => _removeCatchRow(i),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildWeatherPicker(dynamic tokens) {
    return GlassCard(
      child: SegmentedButton<Weather?>(
        segments: const [
          ButtonSegment(value: Weather.cerah, label: Text('Cerah')),
          ButtonSegment(value: Weather.mendung, label: Text('Mendung')),
          ButtonSegment(value: Weather.hujan, label: Text('Hujan')),
        ],
        selected: {_weather},
        onSelectionChanged: (set) => setState(() => _weather = set.first),
        emptySelectionAllowed: true,
        showSelectedIcon: false,
      ),
    );
  }

  Widget _buildWavePicker(dynamic tokens) {
    return GlassCard(
      child: SegmentedButton<WaveCondition?>(
        segments: const [
          ButtonSegment(value: WaveCondition.tenang, label: Text('Tenang')),
          ButtonSegment(value: WaveCondition.sedang, label: Text('Sedang')),
          ButtonSegment(value: WaveCondition.tinggi, label: Text('Tinggi')),
        ],
        selected: {_wave},
        onSelectionChanged: (set) => setState(() => _wave = set.first),
        emptySelectionAllowed: true,
        showSelectedIcon: false,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: AppSizes.sp2),
        Text(title, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

/// Internal model for a mutable catch row in the form.
class _CatchRow {
  _CatchRow({
    required this.id,
    required this.speciesController,
    required this.weightController,
  });

  final String id;
  final TextEditingController speciesController;
  final TextEditingController weightController;
}
