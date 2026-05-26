import 'dart:io' show Platform;

import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';

import '../observability/logger.dart';

/// Helper untuk deep-link ke halaman permission spesifik di Settings
/// sistem.
///
/// PR #43 — sebelumnya semua tap "Atur" / "Buka Settings" panggil
/// `openAppSettings()` dari permission_handler. Itu hanya membuka
/// halaman App Info umum, user masih harus tap "Permissions" lalu
/// pilih permission yang dimaksud secara manual. User komplain
/// flow-nya kurang langsung.
///
/// Sekarang setiap permission punya intent Android-spesifik:
///
/// - **Notifikasi** → `ACTION_APP_NOTIFICATION_SETTINGS` langsung
///   buka halaman notifikasi app. Tersedia API 26+.
/// - **Hemat Daya** → `ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`
///   buka halaman daftar battery optimization. User scroll cari app
///   ini. Tersedia API 23+.
/// - **Lokasi** → tidak ada intent spesifik di Android. Fallback ke
///   App Info umum (sama seperti openAppSettings). User masih harus
///   tap "Permissions" → "Lokasi". Ini batasan OS, tidak bisa
///   diakali.
///
/// Di iOS / non-Android: semua fallback ke `openAppSettings()` —
/// iOS tidak expose deep-link permission per-tipe.
class PermissionSettingsLauncher {
  const PermissionSettingsLauncher._();

  /// Buka halaman Settings yang paling relevan untuk [permission].
  ///
  /// Best-effort: kalau intent spesifik gagal (mis. OEM custom ROM
  /// tidak handle), fallback ke `openAppSettings()`.
  static Future<void> open(Permission permission) async {
    if (!Platform.isAndroid) {
      await openAppSettings();
      return;
    }

    try {
      switch (permission) {
        case Permission.notification:
          await _openNotificationSettings();
        case Permission.ignoreBatteryOptimizations:
          await _openBatteryOptimizationSettings();
        default:
          // Lokasi & lainnya — Android tidak punya deep-link
          // spesifik. Buka App Info umum, user lanjut manual.
          await openAppSettings();
      }
    } catch (e) {
      Logger.instance.warn(
        'permission.deep_link_failed',
        {
          'permission': permission.toString(),
          'error': e.toString(),
        },
      );
      // Fallback aman: openAppSettings selalu bekerja di Android.
      await openAppSettings();
    }
  }

  /// `Settings.ACTION_APP_NOTIFICATION_SETTINGS` — Android 8.0+
  /// (API 26). Buka halaman notifikasi spesifik untuk app ini.
  static Future<void> _openNotificationSettings() async {
    const intent = AndroidIntent(
      action: 'android.settings.APP_NOTIFICATION_SETTINGS',
      arguments: {
        'android.provider.extra.APP_PACKAGE': 'id.co.langgengsea',
      },
    );
    await intent.launch();
  }

  /// `Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS` — Android
  /// 6.0+ (API 23). Buka halaman daftar battery optimization. User
  /// scroll cari app ini di list (tidak ada intent yang langsung
  /// targetkan single app — itu reserved untuk system apps).
  static Future<void> _openBatteryOptimizationSettings() async {
    const intent = AndroidIntent(
      action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
    );
    await intent.launch();
  }
}
