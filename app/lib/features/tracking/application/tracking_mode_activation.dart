import 'package:permission_handler/permission_handler.dart';

import '../../../core/observability/logger.dart';
import 'tracking_permission_flow.dart';

/// Hasil aktivasi mode Akurasi (PR #29).
///
/// Sealed class supaya pemanggil di Settings UI bisa pattern-match
/// secara lengkap (compiler enforce exhaustive `switch`). Lima
/// variant menutup semua kombinasi notifikasi × battery × platform.
sealed class ActivateAccurateResult {
  const ActivateAccurateResult();
}

/// Notifikasi DAN battery optimization granted. Mode bisa langsung
/// disimpan = `accurate` tanpa rollback / warning.
final class AccurateActivated extends ActivateAccurateResult {
  const AccurateActivated();
}

/// Notifikasi granted, battery optimization tidak granted (denied
/// biasa, bukan permanently). Mode TETAP pindah ke `accurate` —
/// foreground service tetap bisa jalan tanpa exemption, hanya
/// akurasi saat layar mati yang berkurang. UI sebaiknya tampilkan
/// snackbar warning supaya user paham trade-off-nya.
final class AccurateActivatedWithBatteryWarning extends ActivateAccurateResult {
  const AccurateActivatedWithBatteryWarning();
}

/// Permission yang user butuh untuk grant ada di sistem settings,
/// bukan dialog runtime. Biasanya karena user sebelumnya tap
/// "Don't ask again". UI tampilkan
/// `TrackingModeTutorialSheet(reason)` yang mengarahkan user ke
/// `openAppSettings()`.
///
/// Khusus reason [NeedSettingsReason.notifications]: mode TIDAK
/// pindah ke `accurate` (foreground service akan crash tanpa
/// notifikasi).
///
/// Khusus reason [NeedSettingsReason.battery]: mode tetap pindah ke
/// `accurate` karena foreground service bisa jalan tanpa exemption.
final class AccurateNeedsSystemSettings extends ActivateAccurateResult {
  const AccurateNeedsSystemSettings(this.reason);
  final NeedSettingsReason reason;
}

/// User tap "Tolak" di dialog OS untuk notifikasi (denied biasa,
/// bukan permanently). Mode tetap Normal — auto-rollback per R4 AC1.
/// UI tampilkan snackbar penjelasan.
final class AccurateDeclined extends ActivateAccurateResult {
  const AccurateDeclined();
}

/// Aplikasi berjalan di iOS / desktop / platform yang tidak punya
/// konsep foreground service Android. Mode toggle harus disabled
/// atau di-hide di UI.
final class AccurateUnsupportedPlatform extends ActivateAccurateResult {
  const AccurateUnsupportedPlatform();
}

/// Kategori permission yang perlu dibuka manual di system settings.
enum NeedSettingsReason {
  notifications,
  battery,
}

/// Activation flow untuk memindahkan mode tracking dari Normal ke
/// Akurasi (PR #29 R3).
///
/// Algoritma:
/// 1. Kalau `androidSdkInt < 0` (non-Android), return
///    [AccurateUnsupportedPlatform].
/// 2. Kalau Android 13+ (sdkInt ≥ 33), cek
///    `POST_NOTIFICATIONS`. Belum granted → request. Hasil:
///    - `permanentlyDenied` → [AccurateNeedsSystemSettings(notifications)]
///    - `denied` → [AccurateDeclined] (mode tetap Normal)
///    - `granted` → lanjut step 3
///    Android 12 dan ke bawah skip step ini (notif permission
///    runtime tidak ada).
/// 3. Cek `ignoreBatteryOptimizations`. Belum granted → request.
///    Hasil:
///    - `permanentlyDenied` → [AccurateNeedsSystemSettings(battery)]
///      (TAPI mode tetap pindah Akurasi — battery optional)
///    - `denied` → [AccurateActivatedWithBatteryWarning]
///    - `granted` → [AccurateActivated]
///
/// Function ini PURE dari sisi UI — semua side effect tampilan
/// (snackbar, sheet) dilakukan oleh caller berdasarkan result.
/// Ini supaya activation flow gampang di-test dengan
/// fake [PermissionHandler] di sandbox.
Future<ActivateAccurateResult> activateAccurateMode({
  required PermissionHandler handler,
}) async {
  final sdkInt = await handler.androidSdkInt();
  if (sdkInt < 0) {
    return const AccurateUnsupportedPlatform();
  }

  // Step 1 — POST_NOTIFICATIONS gate (Android 13+).
  if (sdkInt >= 33) {
    var notif = await handler.checkNotifications();
    if (!notif.isGranted) {
      notif = await handler.requestNotifications();
    }
    if (notif.isPermanentlyDenied) {
      Logger.instance.info(
        'tracking.activate_accurate_blocked',
        const {'reason': 'notifications_permanently_denied'},
      );
      return const AccurateNeedsSystemSettings(NeedSettingsReason.notifications);
    }
    if (!notif.isGranted) {
      Logger.instance.info(
        'tracking.activate_accurate_declined',
        const {'reason': 'notifications_denied'},
      );
      return const AccurateDeclined();
    }
  }

  // Step 2 — ignoreBatteryOptimizations gate.
  // Selalu jalan (API 23+), tidak butuh sdk gating.
  var battery = await handler.checkIgnoreBattery();
  if (!battery.isGranted) {
    battery = await handler.requestIgnoreBattery();
  }
  if (battery.isPermanentlyDenied) {
    Logger.instance.info(
      'tracking.activate_accurate_battery_blocked',
      const {'reason': 'battery_permanently_denied'},
    );
    return const AccurateNeedsSystemSettings(NeedSettingsReason.battery);
  }
  if (!battery.isGranted) {
    Logger.instance.info(
      'tracking.activate_accurate_battery_warning',
      const {'reason': 'battery_denied'},
    );
    return const AccurateActivatedWithBatteryWarning();
  }

  Logger.instance.info(
    'tracking.activate_accurate_success',
    const {'sdkInt': 'see_log'},
  );
  return const AccurateActivated();
}
