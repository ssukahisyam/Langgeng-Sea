import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/observability/logger.dart';
import '../../../../core/settings/application/app_settings_provider.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../tracking/domain/entities/tracking_mode.dart';

/// Settings tile yang menampilkan & mengatur permission
/// `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
///
/// Menjawab Requirement R3 PR #27:
/// > "Sebagai nelayan yang awalnya menolak permission battery (atau
/// > uninstall-install ulang dan ingin re-grant), saya bisa buka
/// > Settings → Pengaturan Lanjutan dan toggle/buka permission battery
/// > dari sana, tanpa harus mulai tarikan dulu."
///
/// Kebenaran:
/// - Reaktif terhadap perubahan permission saat app resume dari
///   background (mis. user balik dari layar Settings sistem). Pakai
///   [WidgetsBindingObserver.didChangeAppLifecycleState].
/// - Defensif terhadap `PermissionStatus` non-`granted/denied/perm-denied`
///   (kalau plugin/OEM emit nilai yang tidak terduga, fallback ke
///   "Belum diatur").
/// - Best-effort: semua error platform ditelan, tile tetap render.
/// - Hanya rendering meaningful di Android (di iOS Permission
///   `ignoreBatteryOptimizations` selalu return `denied` karena tidak
///   ada konsep itu di iOS) — tile self-hide di non-Android.
class BatteryOptimizationTile extends ConsumerStatefulWidget {
  const BatteryOptimizationTile({super.key});

  @override
  ConsumerState<BatteryOptimizationTile> createState() =>
      _BatteryOptimizationTileState();
}

class _BatteryOptimizationTileState
    extends ConsumerState<BatteryOptimizationTile>
    with WidgetsBindingObserver {
  PermissionStatus? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Jika user baru kembali dari Settings sistem (mis. setelah cabut
    // permission manual), refresh status supaya tile mencerminkan
    // realita tanpa restart aplikasi.
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    if (!Platform.isAndroid) return;
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (!mounted) return;
      setState(() => _status = status);
    } catch (e) {
      Logger.instance.warn(
        'settings.battery_opt_status_check_failed',
        {'error': e.toString()},
      );
    }
  }

  Future<void> _onTap() async {
    if (!Platform.isAndroid || _busy) return;
    setState(() => _busy = true);
    try {
      final current = _status ?? await Permission.ignoreBatteryOptimizations.status;
      if (current.isGranted) {
        // Sudah aktif → bawa user ke layar Settings sistem supaya
        // bisa cabut/ganti manual.
        await openAppSettings();
      } else {
        // Belum diatur / ditolak → request lagi (dialog OS muncul).
        await Permission.ignoreBatteryOptimizations.request().timeout(
          const Duration(seconds: 10),
          onTimeout: () => PermissionStatus.denied,
        );
      }
    } catch (e) {
      Logger.instance.warn(
        'settings.battery_opt_action_failed',
        {'error': e.toString()},
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
      // Status kemungkinan berubah; refresh.
      await _refreshStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      // Self-hide di iOS / desktop — permission ini tidak berlaku.
      return const SizedBox.shrink();
    }

    // PR #29: self-hide kalau mode tracking = Normal. Battery
    // optimization exemption tidak relevan saat foreground service
    // tidak digunakan, jadi tile cuma menambah noise di Settings.
    // Kalau user pindah ke Akurasi nanti, tile otomatis muncul.
    final mode = ref.watch(trackingModeProvider);
    if (mode == TrackingMode.normal) {
      return const SizedBox.shrink();
    }

    final tokens = context.tokens;
    final colors = context.colors;
    final text = context.text;

    final iconData = _iconForStatus(_status);
    final iconColor = _iconColorFor(context, _status);
    final iconBg = _iconBgFor(context, _status);
    final subtitle = _subtitleForStatus(_status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy ? null : _onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.sp3 + 2,
            AppSizes.sp3,
            AppSizes.sp3 + 2,
            AppSizes.sp3,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(iconData, size: 16, color: iconColor),
              ),
              const SizedBox(width: AppSizes.sp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Akurasi Saat Layar Mati', style: text.labelMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: text.bodySmall?.copyWith(
                        color: tokens.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (_busy)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                )
              else
                Icon(
                  PhosphorIconsRegular.caretRight,
                  size: 16,
                  color: tokens.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Status presentation helpers
  // ---------------------------------------------------------------------------

  IconData _iconForStatus(PermissionStatus? s) {
    if (s == null) return PhosphorIconsBold.lightning;
    if (s.isGranted) return PhosphorIconsFill.lightning;
    if (s.isPermanentlyDenied) return PhosphorIconsBold.warningCircle;
    return PhosphorIconsBold.lightning;
  }

  Color _iconColorFor(BuildContext context, PermissionStatus? s) {
    final tokens = context.tokens;
    final colors = context.colors;
    if (s == null) return tokens.textSecondary;
    if (s.isGranted) return colors.primary;
    if (s.isPermanentlyDenied) return tokens.danger;
    return tokens.textSecondary;
  }

  Color _iconBgFor(BuildContext context, PermissionStatus? s) {
    final tokens = context.tokens;
    if (s == null) return tokens.accentSoft;
    if (s.isGranted) return tokens.primarySoft;
    if (s.isPermanentlyDenied) return tokens.danger.withValues(alpha: 0.12);
    return tokens.accentSoft;
  }

  String _subtitleForStatus(PermissionStatus? s) {
    if (s == null) return 'Memeriksa status…';
    if (s.isGranted) {
      return 'Aktif — tracking akurat saat layar mati';
    }
    if (s.isPermanentlyDenied) {
      return 'Diblokir di pengaturan sistem — ketuk untuk membuka';
    }
    if (s.isDenied) {
      return 'Belum diatur — ketuk untuk mengizinkan';
    }
    // PermissionStatus.restricted, .limited, .provisional, dan nilai
    // tak terduga lainnya → fallback ke "Belum diatur" untuk menjaga
    // UX yang konsisten.
    return 'Belum diatur — ketuk untuk mengizinkan';
  }
}
