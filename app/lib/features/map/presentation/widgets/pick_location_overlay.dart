import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';

/// Overlay yang aktif di MapScreen saat
/// `MapMode.pickMarkerLocation` (PR #32 R3).
///
/// Menampilkan:
/// - Crosshair fixed di tengah viewport peta. User pan / zoom peta
///   biasa untuk menggerakkan koordinat target ke crosshair.
/// - Bottom card kontrol berisi instruksi, koordinat live, dan
///   tombol [Batal] / [Tandai di Sini].
///
/// Widget ini SENGAJA tidak membungkus map atau memblokir gestures.
/// Semua interactive surfaces (crosshair + bottom card) duduk di
/// atas Stack `MapScreen` sebagai overlay; area kosong di antaranya
/// memakai [IgnorePointer] supaya pan / zoom peta tetap diterima
/// flutter_map.
///
/// Live coordinate update di bottom card menggunakan
/// [MapController.mapEventStream] dengan [StreamBuilder] — sama
/// pola dengan `MapScaleIndicator` dan `CompassIndicator` existing.
/// Stream ini sudah throttled secara natural oleh flutter_map (event
/// hanya emit saat camera berubah), jadi tidak butuh debouncer
/// manual.
class PickLocationOverlay extends ConsumerWidget {
  const PickLocationOverlay({
    super.key,
    required this.mapController,
    required this.onConfirm,
    required this.onCancel,
  });

  final MapController mapController;
  final void Function(LatLng coord) onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Crosshair: dipasang via Center supaya selalu di tengah
        // viewport (fixed di layar, bukan koordinat peta). Ukuran
        // diset cukup besar untuk visibility di siang hari di laut
        // tanpa mengganggu visibility tile peta di bawahnya.
        const Center(
          child: IgnorePointer(
            child: _Crosshair(),
          ),
        ),

        // Bottom card kontrol — tidak blok area di atasnya, jadi
        // peta tetap bisa di-pan walau ada bottom card.
        Positioned(
          left: AppSizes.sp4,
          right: AppSizes.sp4,
          bottom: AppSizes.sp4,
          child: SafeArea(
            top: false,
            child: _BottomCard(
              mapController: mapController,
              onConfirm: onConfirm,
              onCancel: onCancel,
            ),
          ),
        ),
      ],
    );
  }
}

/// Crosshair widget — Phosphor `crosshair` icon di lingkaran
/// semi-transparan dengan glow primary. Disengaja dibuat dengan
/// dot kecil di tengah supaya user paham titik tepatnya, tidak
/// hanya area kasar.
class _Crosshair extends StatelessWidget {
  const _Crosshair();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    return Semantics(
      label: 'Crosshair pemilih lokasi',
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: tokens.surface3.withValues(alpha: 0.4),
                shape: BoxShape.circle,
                border: Border.all(color: colors.primary, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: tokens.glowPrimary,
                    blurRadius: 16,
                  ),
                ],
              ),
            ),
            Icon(
              PhosphorIconsBold.crosshair,
              size: 28,
              color: colors.primary,
            ),
            // Dot tengah — penanda titik exact
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomCard extends StatelessWidget {
  const _BottomCard({
    required this.mapController,
    required this.onConfirm,
    required this.onCancel,
  });

  final MapController mapController;
  final void Function(LatLng) onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    final colors = context.colors;

    return GlassCard(
      level: GlassLevel.level3,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.sp4,
        AppSizes.sp3,
        AppSizes.sp4,
        AppSizes.sp3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tokens.primarySoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  PhosphorIconsBold.mapPin,
                  size: 18,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: AppSizes.sp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Pilih Lokasi Penanda',
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pan peta sampai crosshair berada di lokasi yang ingin ditandai.',
                      style: text.bodySmall?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sp3),
          // Live koordinat — update via mapEventStream (sama pola
          // dengan MapScaleIndicator).
          _LiveCoordinate(mapController: mapController),
          const SizedBox(height: AppSizes.sp3),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    backgroundColor: tokens.surface3,
                    foregroundColor: tokens.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: AppSizes.sp2),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () {
                    final coord = mapController.camera.center;
                    onConfirm(coord);
                  },
                  icon: const Icon(PhosphorIconsBold.checkCircle, size: 18),
                  label: const Text('Tandai di Sini'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveCoordinate extends StatelessWidget {
  const _LiveCoordinate({required this.mapController});

  final MapController mapController;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    return StreamBuilder<MapEvent>(
      stream: mapController.mapEventStream,
      builder: (context, snapshot) {
        // Defensive: kalau camera belum ready saat first build,
        // tampilkan placeholder. flutter_map biasanya sudah ready
        // sebelum overlay ini di-mount, tapi defensive supaya
        // widget tidak throw saat hot-reload atau test environment.
        LatLng? center;
        try {
          center = mapController.camera.center;
        } catch (_) {
          center = null;
        }
        final latStr = center?.latitude.toStringAsFixed(5) ?? '—';
        final lonStr = center?.longitude.toStringAsFixed(5) ?? '—';
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.sp3,
            vertical: AppSizes.sp2,
          ),
          decoration: BoxDecoration(
            color: tokens.surface3,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                PhosphorIconsRegular.target,
                size: 14,
                color: tokens.textTertiary,
              ),
              const SizedBox(width: AppSizes.sp2),
              Text(
                '$latStr, $lonStr',
                style: text.bodySmall?.copyWith(
                  color: tokens.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
