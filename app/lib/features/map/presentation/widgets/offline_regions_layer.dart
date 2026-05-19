import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../offline_map/data/offline_region_repository.dart';
import '../../../offline_map/domain/entities/offline_region.dart';

/// Toggle visibility area peta offline yang sudah didownload (PR
/// follow-up Bug 3). Default `false` supaya tidak mengganggu visual
/// tracking. User aktifkan via tombol toggle di MapScreen overlay
/// controls.
final offlineRegionsOverlayProvider = StateProvider<bool>((ref) => false);

/// Render polygon translucent untuk semua [OfflineRegion] yang sudah
/// `completed`. Region yang masih `downloading`, `pending`, atau
/// `failed` di-skip karena tile-nya belum lengkap.
///
/// Style: fill primary semi-transparan + border solid supaya area
/// tetap kelihatan tanpa menutupi tile peta di bawahnya.
class OfflineRegionsLayer extends ConsumerWidget {
  const OfflineRegionsLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regionsAsync = ref.watch(offlineRegionsProvider);
    final regions = regionsAsync.asData?.value ?? const <OfflineRegion>[];
    final completed = regions.where((r) => r.isReady).toList();
    if (completed.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = context.colors;
    final tokens = context.tokens;

    final polygons = <Polygon>[
      for (final r in completed)
        Polygon(
          points: _boundsToCorners(r.bounds),
          color: colors.primary.withValues(alpha: 0.10),
          borderColor: colors.primary.withValues(alpha: 0.65),
          borderStrokeWidth: 1.5,
          // Label tidak di-set di sini — bisa noisy kalau banyak
          // region. User bisa lihat nama via screen Peta Offline.
        ),
    ];

    return PolygonLayer(
      polygons: polygons,
      // Menjaga performa: `simplify` hanya merging close points,
      // tidak butuh untuk rectangular bounds 4 points.
    );
  }

  static List<LatLng> _boundsToCorners(LatLngBounds bounds) => [
        LatLng(bounds.north, bounds.west),
        LatLng(bounds.north, bounds.east),
        LatLng(bounds.south, bounds.east),
        LatLng(bounds.south, bounds.west),
      ];
}
