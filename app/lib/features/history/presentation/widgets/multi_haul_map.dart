import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/latlng_bounds_util.dart';
import '../../../tracking/domain/entities/haul.dart';
import '../../../tracking/domain/entities/track_point.dart';

/// Static multi-haul preview map.
///
/// Renders every haul in [pointsByHaulId] as its own colored polyline
/// with start (green) and end (red) dots, then auto-fits the camera.
/// Non-interactive by default so it works inside scrollables.
class MultiHaulMap extends StatefulWidget {
  const MultiHaulMap({
    super.key,
    required this.hauls,
    required this.pointsByHaulId,
    this.height = 180,
    this.interactive = false,
  });

  final List<Haul> hauls;
  final Map<String, List<TrackPoint>> pointsByHaulId;
  final double height;
  final bool interactive;

  @override
  State<MultiHaulMap> createState() => _MultiHaulMapState();
}

class _MultiHaulMapState extends State<MultiHaulMap> {
  final MapController _controller = MapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MultiHaulMap old) {
    super.didUpdateWidget(old);
    if (old.pointsByHaulId != widget.pointsByHaulId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    }
  }

  void _fit() {
    final allPoints = widget.pointsByHaulId.values
        .expand((list) => list.map((p) => p.latLng));
    final bounds = LatLngBoundsUtil.fromPoints(allPoints);
    if (bounds == null) return;
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final polylines = <Polyline>[];
    final markers = <Marker>[];

    for (final haul in widget.hauls) {
      final points = widget.pointsByHaulId[haul.id] ?? const <TrackPoint>[];
      if (points.length < 2) continue;
      final latLngs = points.map((p) => p.latLng).toList(growable: false);
      final color = AppColors.colorForHaul(haul.orderIndex);
      polylines.add(
        Polyline(
          points: latLngs,
          strokeWidth: 8,
          color: color.withValues(alpha: 0.22),
        ),
      );
      polylines.add(
        Polyline(
          points: latLngs,
          strokeWidth: 4,
          color: color,
          borderStrokeWidth: 1.2,
          borderColor: Colors.white.withValues(alpha: 0.6),
        ),
      );
      markers
        ..add(_endpointMarker(latLngs.first, tokens.success))
        ..add(_endpointMarker(latLngs.last, tokens.danger));
    }

    final hasData = polylines.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasData)
              FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: _defaultCenter(),
                  initialZoom: 11,
                  interactionOptions: InteractionOptions(
                    flags: widget.interactive
                        ? InteractiveFlag.all & ~InteractiveFlag.rotate
                        : InteractiveFlag.none,
                  ),
                  onMapReady: _fit,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'id.co.langgengsea',
                    maxNativeZoom: 19,
                    retinaMode: RetinaMode.isHighDensity(context),
                  ),
                  PolylineLayer(polylines: polylines),
                  MarkerLayer(markers: markers),
                ],
              )
            else
              _NoTrackData(),
          ],
        ),
      ),
    );
  }

  LatLng _defaultCenter() {
    final first = widget.pointsByHaulId.values
        .expand((list) => list)
        .firstOrNull;
    return first?.latLng ?? const LatLng(-7.25, 113.42);
  }

  Marker _endpointMarker(LatLng at, Color color) => Marker(
        point: at,
        width: 16,
        height: 16,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      );
}

class _NoTrackData extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    return Container(
      color: tokens.surface1,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.path,
              size: 28,
              color: tokens.textTertiary,
            ),
            const SizedBox(height: 6),
            Text(
              'Belum ada titik GPS',
              style: text.bodySmall?.copyWith(color: tokens.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
