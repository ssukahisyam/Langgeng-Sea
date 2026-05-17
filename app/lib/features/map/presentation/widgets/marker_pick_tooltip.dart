import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';

/// Helper untuk first-time tooltip yang menjelaskan fitur
/// **long-press tombol Tambah Penanda** (PR #32).
///
/// Disimpan di [SharedPreferences] (bukan di Drift `app_settings`)
/// karena flag ini adalah device-state, bukan domain data — tidak
/// berpengaruh ke ekspor / migration / sinkronisasi. Disimpan dengan
/// suffix `_v1` supaya kalau di masa depan kita ingin re-show tooltip
/// (mis. setelah perubahan UX besar), cukup bump ke `_v2`.
class MarkerPickTooltip {
  static const _kSeenKey = 'seen_marker_pick_tooltip_v1';

  /// Apakah tooltip sudah pernah ditampilkan (dan di-dismiss user
  /// atau auto-dismiss timer). Default `false` di first install.
  static Future<bool> hasBeenShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kSeenKey) ?? false;
    } catch (_) {
      // Defensive: kalau plugin tidak tersedia (mis. test environment),
      // anggap sudah pernah ditampilkan supaya tooltip tidak muncul di
      // tempat yang aneh. Test yang butuh tooltip wajib mock dengan
      // `setMockInitialValues`.
      return true;
    }
  }

  /// Tandai tooltip sudah ditampilkan. Idempotent — aman dipanggil
  /// berulang kali (tradeoff: kalau app crash sebelum user dismiss,
  /// tooltip dianggap shown supaya tidak muncul ulang setiap launch).
  static Future<void> markShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSeenKey, true);
    } catch (_) {
      // Swallow — kegagalan persist bukan blocker untuk feature.
    }
  }

  /// Build [OverlayEntry] yang menampilkan bubble tooltip dengan
  /// arrow yang menunjuk ke tombol target.
  ///
  /// Caller bertanggung jawab:
  /// - `Overlay.of(context).insert(entry)` untuk show
  /// - `entry.remove()` saat user tap "Mengerti" atau timer 5s
  ///   habis
  /// - Panggil [markShown] setelah remove supaya tidak muncul lagi
  ///
  /// [targetKey] harus terpasang di widget tombol `_AddMarkerButton`
  /// supaya tooltip dapat menghitung posisi global tombol untuk
  /// menempatkan bubble dan arrow.
  static OverlayEntry buildOverlay({
    required BuildContext context,
    required GlobalKey targetKey,
    required VoidCallback onDismiss,
  }) {
    return OverlayEntry(
      builder: (overlayContext) {
        final renderBox =
            targetKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) {
          // Target belum di-mount — render no-op overlay yang akan
          // di-remove segera oleh caller.
          return const SizedBox.shrink();
        }
        final size = renderBox.size;
        final position = renderBox.localToGlobal(Offset.zero);
        final tokens = overlayContext.tokens;
        final colors = overlayContext.colors;
        final text = overlayContext.text;

        // Bubble width fixed supaya ringkas; tinggi auto. Letakkan
        // bubble di atas tombol dengan arrow ke bawah.
        const bubbleWidth = 240.0;
        final bubbleLeft = (position.dx + size.width / 2 - bubbleWidth / 2)
            .clamp(AppSizes.sp3, MediaQuery.of(overlayContext).size.width - bubbleWidth - AppSizes.sp3);
        final bubbleBottom =
            MediaQuery.of(overlayContext).size.height - position.dy + 12;

        return Stack(
          children: [
            // Tap-outside dismiss layer — transparan, menutup seluruh
            // layar tapi terbatas ke region di luar bubble target.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: onDismiss,
              ),
            ),
            Positioned(
              left: bubbleLeft,
              bottom: bubbleBottom,
              width: bubbleWidth,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(AppSizes.sp3),
                  decoration: BoxDecoration(
                    gradient: tokens.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: tokens.shadowMd,
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            PhosphorIconsFill.lightbulb,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: AppSizes.sp2),
                          Expanded(
                            child: Text(
                              'Tahu fitur ini?',
                              style: text.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.sp2),
                      Text(
                        'Tekan lama tombol Tambah Penanda untuk pilih '
                        'lokasi langsung di peta — tidak perlu menunggu '
                        'GPS atau berada di lokasi.',
                        style: text.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: AppSizes.sp2),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: onDismiss,
                          style: TextButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.18),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.sp3,
                              vertical: 4,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            'Mengerti',
                            style: text.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Arrow pointing down, simulasi tail bubble.
            Positioned(
              left: position.dx + size.width / 2 - 8,
              bottom:
                  MediaQuery.of(overlayContext).size.height - position.dy + 4,
              child: IgnorePointer(
                child: Transform.rotate(
                  angle: 0.785398, // 45 deg
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
