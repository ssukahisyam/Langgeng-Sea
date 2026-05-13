import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../../../core/theme/app_theme.dart';

class MapScaleIndicator extends StatelessWidget {
  const MapScaleIndicator({
    super.key,
    required this.mapController,
  });

  final MapController mapController;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MapEvent>(
      stream: mapController.mapEventStream,
      builder: (context, snapshot) {
        try {
          final zoom = mapController.camera.zoom;
          final center = mapController.camera.center;

          final latitude = center.latitude;
          final metersPerPixel =
              (40075016.686 * math.cos(latitude * math.pi / 180.0)) /
                  (256.0 * math.pow(2, zoom));

          final maxMeters = metersPerPixel * 100.0;
          final scaleValues = [
            10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000,
            100000, 200000, 500000, 1000000, 2000000, 5000000
          ];

          int selectedScale = 10;
          for (final val in scaleValues) {
            if (val > maxMeters) break;
            selectedScale = val;
          }

          final scaleWidthPixels = selectedScale / metersPerPixel;

          String label;
          if (selectedScale >= 1000) {
            label = '${selectedScale ~/ 1000} km';
          } else {
            label = '$selectedScale m';
          }

          final tokens = context.tokens;
          final text = context.text;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Z: ${zoom.toStringAsFixed(1)}',
                style: text.labelSmall?.copyWith(
                  color: context.colors.onSurface,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  shadows: [
                    Shadow(color: tokens.surface1, blurRadius: 4),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: scaleWidthPixels,
                height: 12,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: context.colors.onSurface, width: 2),
                    left: BorderSide(color: context.colors.onSurface, width: 2),
                    right: BorderSide(color: context.colors.onSurface, width: 2),
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      label,
                      style: text.labelSmall?.copyWith(
                        color: context.colors.onSurface,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(color: tokens.surface1, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        } catch (_) {
          return const SizedBox.shrink();
        }
      },
    );
  }
}
