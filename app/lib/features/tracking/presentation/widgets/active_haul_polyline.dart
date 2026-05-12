import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/application/app_settings_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/tracking_controller.dart';

/// flutter_map layer that renders the currently-recording haul as a glowing
/// polyline. Uses the live points held in [TrackingState] so it doesn't
/// have to re-query Drift on every GPS tick.
class ActiveHaulPolyline extends ConsumerWidget {
  const ActiveHaulPolyline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trackingControllerProvider);
    final points = state.livePoints;
    final haul = state.haul;
    if (haul == null || points.length < 2) {
      return const PolylineLayer<Object>(polylines: []);
    }

    final color = AppColors.colorForHaul(haul.orderIndex);
    final sw = ref.watch(polylineWidthProvider);

    return PolylineLayer<Object>(
      polylines: [
        // Soft outer glow for visibility on busy tiles.
        Polyline(
          points: points,
          strokeWidth: sw + 3,
          color: color.withValues(alpha: 0.22),
        ),
        Polyline(
          points: points,
          strokeWidth: sw,
          color: color,
          borderStrokeWidth: 1.5,
          borderColor: Colors.white.withValues(alpha: 0.7),
        ),
      ],
    );
  }
}
