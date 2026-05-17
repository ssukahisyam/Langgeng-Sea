import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/application/app_settings_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/tracking_controller.dart';
import '../../data/track_point_repository.dart';

/// flutter_map layer that renders the currently-recording haul as a glowing
/// polyline.
///
/// Source data: prefer DB stream via [trackPointsByHaulProvider]
/// (PR follow-up untuk fix bug active polyline tidak otomatis tampil
/// saat Mode Akurasi screen off). Fallback ke
/// [TrackingState.livePoints] kalau DB stream belum settle (mis. di
/// first frame setelah app resume) — supaya tidak ada flash polyline
/// kosong.
///
/// Background isolate Mode Akurasi menulis langsung ke DB lewat
/// [TrackPointDao.insertPoint] di
/// `flutter_background_tracking_service.dart` `onBackgroundStart` —
/// tanpa pernah menyentuh main isolate `TrackingState`. Sebelumnya
/// widget ini hanya membaca `state.livePoints` (in-memory) sehingga
/// saat user kembali dari layar mati, polyline tampak kosong walau
/// DB sudah berisi point. Setelah fix, user toggle "Tampilkan Jejak"
/// tidak lagi diperlukan untuk memunculkan active trace.
class ActiveHaulPolyline extends ConsumerWidget {
  const ActiveHaulPolyline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trackingControllerProvider);
    final haul = state.haul;
    if (haul == null) {
      return const PolylineLayer<Object>(polylines: []);
    }

    // DB-backed primary source. Drift stream sudah di-throttle internal,
    // jadi rebuild rate dapat di-handle untuk tracking 12 jam (≈ 4k
    // point) tanpa overhead UI yang signifikan.
    final dbPointsAsync = ref.watch(trackPointsByHaulProvider(haul.id));
    final dbPoints = dbPointsAsync.asData?.value;
    final livePoints = state.livePoints;

    // Pilih sumber dengan jumlah point terbesar — itu yang paling
    // up-to-date. Saat Mode Akurasi + screen off, DB > livePoints
    // (background isolate write). Saat Mode Normal foreground, dua
    // sumber match. Saat first frame setelah resume, livePoints
    // mungkin masih populated dari session sebelumnya sementara DB
    // stream belum emit — fallback ke yang lebih besar tetap aman.
    final useDbPoints =
        dbPoints != null && dbPoints.length >= livePoints.length;
    final points = useDbPoints
        ? [for (final p in dbPoints) p.latLng]
        : livePoints;

    if (points.length < 2) {
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
