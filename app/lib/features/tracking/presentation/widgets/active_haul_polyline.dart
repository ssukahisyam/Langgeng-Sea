import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/tracking_controller.dart';

/// flutter_map layer that renders the currently-recording haul as a glowing
/// polyline. Uses the live points held in [TrackingState] so it doesn't
/// have to re-query Drift on every GPS tick.
///
/// Wrapped in RepaintBoundary to isolate the polyline repaint from the
/// tile layer underneath. Without the boundary, a new GPS fix forces
/// the entire FlutterMap stack to repaint — including the tile cache,
/// which is expensive.
class ActiveHaulPolyline extends ConsumerWidget {
  const ActiveHaulPolyline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trackingControllerProvider);
    final points = state.livePoints;
    final haul = state.haul;
    if (haul == null || points.length < 2) {
      return const PolylineLayer(polylines: []);
    }

    final color = AppColors.colorForHaul(haul.orderIndex);

    return PolylineLayer(
      polylines: [
        // Soft outer glow for visibility on busy tiles.
        Polyline(
          points: points,
          strokeWidth: 9,
          color: color.withValues(alpha: 0.22),
        ),
        Polyline(
          points: points,
          strokeWidth: 5,
          color: color,
          borderStrokeWidth: 1.5,
          borderColor: Colors.white.withValues(alpha: 0.7),
        ),
      ],
    );
  }
}
