import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../application/offline_download_controller.dart';
import '../data/tile_cache_service.dart';

/// Map-picker that lets the user frame an offline region.
///
/// The selection rectangle is a fixed inset of the viewport — the user
/// changes which area they're capturing by panning and zooming the map
/// underneath it. This keeps the interaction forgiving on a boat
/// pitching at sea (no fiddly corner handles) and matches the
/// Screen 13 prototype layout.
class RegionPickerScreen extends ConsumerStatefulWidget {
  const RegionPickerScreen({super.key});

  @override
  ConsumerState<RegionPickerScreen> createState() =>
      _RegionPickerScreenState();
}

class _RegionPickerScreenState extends ConsumerState<RegionPickerScreen> {
  // Inset of the selection rect from each screen edge.
  static const double _horizontalInset = 32;
  static const double _topInset = 96; // below the app bar
  static const double _bottomInset = 300; // above the config panel

  // Zoom range offered in the dialog. Capped at 16 to respect OSM ToS
  // (dense urban zooms aren't helpful at sea anyway).
  static const int _defaultMinZoom = 8;
  static const int _defaultMaxZoom = 14;

  final MapController _map = MapController();
  LatLngBounds? _currentSelection;
  Size _viewportSize = Size.zero;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  /// Recompute geographic bounds from the fixed-inset rectangle on
  /// screen using the current camera.
  void _recomputeBounds() {
    if (!mounted || _viewportSize == Size.zero) return;
    final topLeft = Offset(_horizontalInset, _topInset);
    final bottomRight = Offset(
      _viewportSize.width - _horizontalInset,
      _viewportSize.height - _bottomInset,
    );
    final nw = _map.camera.pointToLatLng(topLeft);
    final se = _map.camera.pointToLatLng(bottomRight);
    final bounds = LatLngBounds(
      LatLng(se.latitude, nw.longitude),
      LatLng(nw.latitude, se.longitude),
    );
    if (_currentSelection == null ||
        _currentSelection!.north != bounds.north ||
        _currentSelection!.south != bounds.south ||
        _currentSelection!.east != bounds.east ||
        _currentSelection!.west != bounds.west) {
      setState(() => _currentSelection = bounds);
    }
  }

  Future<void> _openDownloadSheet() async {
    final bounds = _currentSelection;
    if (bounds == null) return;

    final estimate = ref.read(offlineDownloadControllerProvider.notifier).estimate(
          bounds: bounds,
          minZoom: _defaultMinZoom,
          maxZoom: _defaultMaxZoom,
        );

    final result = await showModalBottomSheet<_DownloadConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DownloadSheet(
        bounds: bounds,
        estimate: estimate,
        defaultMinZoom: _defaultMinZoom,
        defaultMaxZoom: _defaultMaxZoom,
      ),
    );
    if (result == null || !mounted) return;

    await ref.read(offlineDownloadControllerProvider.notifier).startDownload(
          name: result.name,
          bounds: bounds,
          minZoom: result.minZoom,
          maxZoom: result.maxZoom,
        );
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;

    return AmbientBackground(
      showBlobs: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            onPressed: () => _pop(context),
            icon: const Icon(PhosphorIconsRegular.arrowLeft),
          ),
          title: Text(
            'Pilih Area',
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        body: LayoutBuilder(builder: (context, constraints) {
          _viewportSize = constraints.biggest;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _recomputeBounds());

          return Stack(
            children: [
              // Map
              Positioned.fill(
                child: FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: const LatLng(-7.25, 113.42),
                    initialZoom: 9,
                    minZoom: 3,
                    maxZoom: 16,
                    onMapEvent: (_) => _recomputeBounds(),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: TileEndpoints.osm,
                      userAgentPackageName: TileEndpoints.userAgent,
                      maxNativeZoom: 19,
                      retinaMode: RetinaMode.isHighDensity(context),
                      tileProvider: ref
                          .read(tileCacheServiceProvider)
                          .cachedTileProvider(
                            userAgentPackageName: TileEndpoints.userAgent,
                          ),
                    ),
                  ],
                ),
              ),

              // Dimmed overlay + selection cutout
              IgnorePointer(
                child: CustomPaint(
                  size: constraints.biggest,
                  painter: _SelectionOverlayPainter(
                    selectionRect: Rect.fromLTRB(
                      _horizontalInset,
                      _topInset,
                      constraints.maxWidth - _horizontalInset,
                      constraints.maxHeight - _bottomInset,
                    ),
                    borderColor: context.colors.primary,
                    shadeColor: tokens.shadowMd.withValues(alpha: 0.45),
                  ),
                ),
              ),

              // Config panel at the bottom
              Positioned(
                left: AppSizes.sp4,
                right: AppSizes.sp4,
                bottom: AppSizes.sp4,
                child: _ConfigPanel(
                  bounds: _currentSelection,
                  onContinue: _openDownloadSheet,
                  minZoom: _defaultMinZoom,
                  maxZoom: _defaultMaxZoom,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  void _pop(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.offlineMap);
    }
  }
}

// ===========================================================================
// Overlay painter
// ===========================================================================

class _SelectionOverlayPainter extends CustomPainter {
  _SelectionOverlayPainter({
    required this.selectionRect,
    required this.borderColor,
    required this.shadeColor,
  });

  final Rect selectionRect;
  final Color borderColor;
  final Color shadeColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Shade everything outside the selection using even-odd fill.
    final full = Path()..addRect(Offset.zero & size);
    final inner = Path()
      ..addRRect(RRect.fromRectAndRadius(selectionRect,
          const Radius.circular(AppSizes.radiusMd)));
    final shade = Path.combine(PathOperation.difference, full, inner);
    canvas.drawPath(shade, Paint()..color = shadeColor);

    // Border around the selection.
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = borderColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          selectionRect, const Radius.circular(AppSizes.radiusMd)),
      border,
    );

    // Corner brackets for extra affordance.
    final corner = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const cornerLen = 18.0;
    void bracket(double x, double y, double dx, double dy) {
      canvas.drawLine(Offset(x, y), Offset(x + dx * cornerLen, y), corner);
      canvas.drawLine(Offset(x, y), Offset(x, y + dy * cornerLen), corner);
    }

    bracket(selectionRect.left, selectionRect.top, 1, 1);
    bracket(selectionRect.right, selectionRect.top, -1, 1);
    bracket(selectionRect.left, selectionRect.bottom, 1, -1);
    bracket(selectionRect.right, selectionRect.bottom, -1, -1);
  }

  @override
  bool shouldRepaint(covariant _SelectionOverlayPainter old) =>
      old.selectionRect != selectionRect ||
      old.borderColor != borderColor ||
      old.shadeColor != shadeColor;
}

// ===========================================================================
// Bottom config panel
// ===========================================================================

class _ConfigPanel extends ConsumerWidget {
  const _ConfigPanel({
    required this.bounds,
    required this.onContinue,
    required this.minZoom,
    required this.maxZoom,
  });

  final LatLngBounds? bounds;
  final VoidCallback onContinue;
  final int minZoom;
  final int maxZoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.text;
    final tokens = context.tokens;

    final estimate = bounds == null
        ? null
        : ref.read(offlineDownloadControllerProvider.notifier).estimate(
              bounds: bounds!,
              minZoom: minZoom,
              maxZoom: maxZoom,
            );

    return GlassCard(
      level: GlassLevel.level3,
      padding: const EdgeInsets.all(AppSizes.sp4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Geser & zoom peta untuk memilih area',
            style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: AppSizes.sp3),
          Row(
            children: [
              Expanded(
                child: _EstimateTile(
                  icon: PhosphorIconsRegular.database,
                  label: 'Estimasi',
                  value: estimate == null
                      ? '—'
                      : _bytesHuman(estimate.estimatedBytes),
                ),
              ),
              const SizedBox(width: AppSizes.sp2),
              Expanded(
                child: _EstimateTile(
                  icon: PhosphorIconsRegular.stack,
                  label: 'Tile',
                  value: estimate == null
                      ? '—'
                      : _countHuman(estimate.tileCount),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sp3),
          Row(
            children: [
              Icon(PhosphorIconsRegular.info,
                  size: 14, color: tokens.textTertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Sebaiknya download via wifi',
                  style: text.bodySmall?.copyWith(
                    color: tokens.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sp3),
          PrimaryActionButton(
            label: 'Lanjut',
            icon: PhosphorIconsFill.downloadSimple,
            onPressed: bounds == null ? null : onContinue,
          ),
        ],
      ),
    );
  }

  static String _bytesHuman(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String _countHuman(int c) {
    if (c < 1000) return '$c';
    if (c < 1_000_000) return '${(c / 1000).toStringAsFixed(1)}K';
    return '${(c / 1_000_000).toStringAsFixed(1)}M';
  }
}

class _EstimateTile extends StatelessWidget {
  const _EstimateTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    return GlassCard(
      level: GlassLevel.level1,
      padding: const EdgeInsets.all(AppSizes.sp3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.colors.primary),
          const SizedBox(width: AppSizes.sp3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  label,
                  style: text.bodySmall?.copyWith(
                    color: tokens.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Download-config sheet
// ===========================================================================

class _DownloadConfig {
  const _DownloadConfig({
    required this.name,
    required this.minZoom,
    required this.maxZoom,
  });
  final String name;
  final int minZoom;
  final int maxZoom;
}

class _DownloadSheet extends ConsumerStatefulWidget {
  const _DownloadSheet({
    required this.bounds,
    required this.estimate,
    required this.defaultMinZoom,
    required this.defaultMaxZoom,
  });

  final LatLngBounds bounds;
  final ({int tileCount, int estimatedBytes}) estimate;
  final int defaultMinZoom;
  final int defaultMaxZoom;

  @override
  ConsumerState<_DownloadSheet> createState() => _DownloadSheetState();
}

class _DownloadSheetState extends ConsumerState<_DownloadSheet> {
  late final TextEditingController _nameCtl;
  late int _minZoom;
  late int _maxZoom;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController();
    _minZoom = widget.defaultMinZoom;
    _maxZoom = widget.defaultMaxZoom;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Beri nama dulu area ini'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      _DownloadConfig(name: name, minZoom: _minZoom, maxZoom: _maxZoom),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;

    final newEstimate =
        ref.read(offlineDownloadControllerProvider.notifier).estimate(
              bounds: widget.bounds,
              minZoom: _minZoom,
              maxZoom: _maxZoom,
            );

    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.sp4,
        right: AppSizes.sp4,
        top: AppSizes.sp4,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.sp4,
      ),
      child: GlassCard(
        level: GlassLevel.level3,
        padding: const EdgeInsets.fromLTRB(
          AppSizes.sp5,
          AppSizes.sp3,
          AppSizes.sp5,
          AppSizes.sp5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.sp4),
            Text(
              'Detail Unduhan',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSizes.sp3),
            TextField(
              controller: _nameCtl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nama area',
                hintText: 'Contoh: Selat Madura',
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
            const SizedBox(height: AppSizes.sp4),
            Text(
              'Zoom ${_minZoom} – ${_maxZoom}',
              style: text.labelMedium,
            ),
            RangeSlider(
              values: RangeValues(_minZoom.toDouble(), _maxZoom.toDouble()),
              min: 3,
              max: 16,
              divisions: 13,
              labels: RangeLabels('$_minZoom', '$_maxZoom'),
              onChanged: (v) {
                setState(() {
                  _minZoom = v.start.round();
                  _maxZoom = v.end.round();
                });
              },
            ),
            Row(
              children: [
                Icon(PhosphorIconsRegular.database,
                    size: 14, color: tokens.textTertiary),
                const SizedBox(width: 6),
                Text(
                  _formatEstimate(newEstimate),
                  style: text.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sp5),
            PrimaryActionButton(
              label: 'Download Sekarang',
              icon: PhosphorIconsFill.downloadSimple,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSizes.sp2),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Batal',
                style: text.labelMedium?.copyWith(color: tokens.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatEstimate(({int tileCount, int estimatedBytes}) e) {
    final tileStr = e.tileCount < 1000
        ? '${e.tileCount} tile'
        : '${(e.tileCount / 1000).toStringAsFixed(1)}K tile';
    final bytesStr = e.estimatedBytes < 1024 * 1024
        ? '${(e.estimatedBytes / 1024).toStringAsFixed(0)} KB'
        : e.estimatedBytes < 1024 * 1024 * 1024
            ? '${(e.estimatedBytes / (1024 * 1024)).toStringAsFixed(0)} MB'
            : '${(e.estimatedBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    return '$tileStr · $bytesStr estimasi';
  }
}
