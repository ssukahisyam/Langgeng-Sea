# Design — PR #29 Tracking Mode Toggle

> Companion ke `requirements.md`. Fokus: struktur kode, decision points,
> dan kontrak antar layer. Detail UI string ada di `requirements.md`.

## §1 Domain model

### TrackingMode enum

File baru: `app/lib/features/tracking/domain/entities/tracking_mode.dart`

```dart
/// Mode tracking yang dipilih user.
///
/// - [normal]: tracking pakai stream GPS foreground saja. Tidak start
///   foreground service Android, tidak request notif/battery permission.
///   Tracking pause natural saat app di-background. Hemat baterai,
///   cocok untuk trip pendek atau test fitur.
/// - [accurate]: tracking pakai foreground service +
///   POST_NOTIFICATIONS + (idealnya) battery optimization exemption.
///   Tracking tetap merekam saat layar mati / app di-background.
///   Cocok untuk trip panjang.
enum TrackingMode {
  normal,
  accurate;

  static TrackingMode fromDbValue(String value) =>
      switch (value) {
        'accurate' => TrackingMode.accurate,
        _ => TrackingMode.normal,
      };

  String get dbValue => name;

  /// Label untuk segmented button.
  String get displayLabel => switch (this) {
        TrackingMode.normal => 'Normal',
        TrackingMode.accurate => 'Akurasi',
      };

  String get subtitle => switch (this) {
        TrackingMode.normal =>
          'Tracking jalan saat aplikasi terbuka. Hemat baterai.',
        TrackingMode.accurate =>
          'Tracking tetap merekam saat layar mati. Memerlukan izin notifikasi.',
      };
}
```

Why enum (bukan boolean): siap untuk mode ketiga di masa depan
(misal "Power saver" — interval GPS panjang saat baterai <20%).

## §2 Persistence

### Schema bump v8 → v9

`app/lib/data/database/tables.dart` — tambah kolom di `AppSettingsTable`:

```dart
TextColumn get trackingMode =>
    text().withDefault(const Constant('normal'))();
```

`app/lib/data/database/app_database.dart` — bump `schemaVersion` ke 9
dan tambah migrasi:

```dart
if (from < 9) {
  await m.addColumn(appSettingsTable, appSettingsTable.trackingMode);
}
```

Drift `addColumn` aman karena kolom punya default value.

### Repository

`app/lib/core/settings/data/app_settings_repository.dart`:

```dart
Future<void> setTrackingMode(TrackingMode mode) =>
    _dao.setTrackingMode(mode.dbValue);
```

DAO method baru di `app_settings_dao.dart`:

```dart
Future<void> setTrackingMode(String value) async {
  await ensureSeeded();
  await (update(appSettingsTable)..where((t) => t.id.equals(kSettingsRowId)))
      .write(AppSettingsTableCompanion(
    trackingMode: Value(value),
    updatedAt: Value(DateTime.now()),
  ));
}
```

Domain entity `AppSettings` (di `app/lib/core/settings/domain/entities/app_settings.dart`):
- Tambah field `final TrackingMode trackingMode;`
- Update `defaults`, `copyWith`, `==`, `hashCode`, `toString`.
- Mapping di `_fromRow`: `TrackingMode.fromDbValue(r.trackingMode)`.

## §3 Activation flow

### File: `app/lib/features/tracking/application/tracking_mode_activation.dart`

```dart
sealed class ActivateAccurateResult {
  const ActivateAccurateResult();
}

/// Notifikasi + battery semua granted.
final class AccurateActivated extends ActivateAccurateResult {
  const AccurateActivated();
}

/// Notifikasi/battery permanently denied — user harus ke system
/// settings. Tidak bisa di-fix dengan dialog runtime.
final class AccurateNeedsSystemSettings extends ActivateAccurateResult {
  const AccurateNeedsSystemSettings(this.reason);
  final NeedSettingsReason reason;
}

/// User tolak izin notifikasi (denied, bukan permanently). Mode tetap
/// Normal — auto-rollback per R4 AC1.
final class AccurateDeclined extends ActivateAccurateResult {
  const AccurateDeclined();
}

/// Platform tidak support (iOS / desktop).
final class AccurateUnsupportedPlatform extends ActivateAccurateResult {
  const AccurateUnsupportedPlatform();
}

/// Battery optional — granted untuk notif tapi battery denied.
/// Mode TETAP pindah ke Akurasi, hanya warning yang ditampilkan.
final class AccurateActivatedWithBatteryWarning extends ActivateAccurateResult {
  const AccurateActivatedWithBatteryWarning();
}

enum NeedSettingsReason { notifications, battery }

Future<ActivateAccurateResult> activateAccurateMode({
  required PermissionHandler handler,
}) async {
  final sdkInt = await handler.androidSdkInt();
  if (sdkInt < 0) {
    return const AccurateUnsupportedPlatform();
  }

  // Step 1 — POST_NOTIFICATIONS (Android 13+ wajib).
  if (sdkInt >= 33) {
    var notif = await handler.checkNotifications();
    if (!notif.isGranted) {
      notif = await handler.requestNotifications();
    }
    if (notif.isPermanentlyDenied) {
      return const AccurateNeedsSystemSettings(NeedSettingsReason.notifications);
    }
    if (!notif.isGranted) {
      return const AccurateDeclined();
    }
  }

  // Step 2 — ignoreBatteryOptimizations (optional tapi recommended).
  var battery = await handler.checkIgnoreBattery();
  if (!battery.isGranted) {
    battery = await handler.requestIgnoreBattery();
  }
  if (battery.isPermanentlyDenied) {
    // Tutorial muncul tapi mode tetap pindah Akurasi (R4 AC4).
    return const AccurateNeedsSystemSettings(NeedSettingsReason.battery);
  }
  if (!battery.isGranted) {
    return const AccurateActivatedWithBatteryWarning();
  }

  return const AccurateActivated();
}
```

### Update `PermissionHandler` interface

Tambah 2 method di `tracking_permission_flow.dart`:

```dart
Future<PermissionStatus> checkIgnoreBattery();
Future<PermissionStatus> requestIgnoreBattery();
```

Implementasi di `RealPermissionHandler`:

```dart
@override
Future<PermissionStatus> checkIgnoreBattery() =>
    Permission.ignoreBatteryOptimizations.status;

@override
Future<PermissionStatus> requestIgnoreBattery() =>
    Permission.ignoreBatteryOptimizations.request();
```

## §4 UI: TrackingModeCard

### File: `app/lib/features/settings/presentation/widgets/tracking_mode_card.dart`

`ConsumerStatefulWidget` (state untuk busy flag selama activation flow).

Layout:

```
┌─ GlassCard ────────────────────────────┐
│ ┌──┐                                    │
│ │📡│  Mode Tracking                     │
│ └──┘  <subtitle dinamis>                │
│                                         │
│ ┌────────────┬────────────────────────┐│
│ │  Normal    │   Akurasi              ││
│ └────────────┴────────────────────────┘│
└─────────────────────────────────────────┘
```

State machine UI:

```
(idle) ──tap Akurasi──> (confirm dialog)
                         │
                  ┌──────┴──────┐
                  │             │
              Lanjutkan       Batal
                  │             └─> (idle)
                  v
          (busy + activation flow)
                  │
       ┌──────────┼──────────┬──────────┬───────────────┐
       v          v          v          v               v
  Activated   Declined   NeedsSettings  WithBatteryWarning  Unsupported
       │          │          │          │               │
   save mode   snackbar   tutorial    save mode     show toast
   snackbar             sheet + idle  + warning       + idle
```

Saat user tap `Normal` (dari Akurasi):
- Tidak ada konfirmasi (less friction untuk turun mode).
- Direct `setTrackingMode(normal)`.
- Kalau ada haul recording aktif: panggil
  `TrackingController.downgradeBackgroundService()` — method baru di
  Phase 7 — untuk stop foreground service tanpa stop haul.

### Provider

```dart
final trackingModeProvider = Provider<TrackingMode>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.asData?.value.trackingMode ?? TrackingMode.normal;
});
```

Card watch provider ini supaya UI auto-rebuild saat mode berubah.

## §5 UI: TrackingModeTutorialSheet

### File: `app/lib/features/settings/presentation/widgets/tracking_mode_tutorial_sheet.dart`

```dart
Future<void> showTrackingModeTutorial(
  BuildContext context, {
  required NeedSettingsReason reason,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => TrackingModeTutorialSheet(reason: reason),
  );
}
```

Konten dinamis per `reason`:

**reason = notifications:**

> ### Izin Notifikasi Diblokir
>
> Mode Akurasi memerlukan notifikasi tracking yang tetap tampil saat
> aplikasi berjalan di belakang. Saat ini izin notifikasi diblokir
> di pengaturan sistem.
>
> 1. Buka Pengaturan Sistem
> 2. Pilih Aplikasi → Langgeng Sea
> 3. Tap Notifikasi
> 4. Aktifkan "Izinkan Notifikasi"
> 5. Kembali ke aplikasi
>
> [Buka Pengaturan]   [Nanti saja]

**reason = battery:**

> ### Pengoptimalan Baterai Aktif
>
> Mode Akurasi sudah aktif, tapi sistem masih membatasi aplikasi saat
> layar mati. GPS bisa berhenti merekam. Lakukan langkah berikut
> untuk akurasi maksimal.
>
> 1. Buka Pengaturan Sistem
> 2. Pilih Aplikasi → Langgeng Sea
> 3. Tap Baterai
> 4. Pilih "Tidak Dibatasi" atau "Tanpa Pembatasan"
> 5. Kembali ke aplikasi
>
> [Buka Pengaturan]   [Nanti saja]

Implementasi pakai `GlassCard` untuk konsistensi tema. Nomor langkah
pakai badge berlatar `tokens.primarySoft`.

## §6 Wire-up tracking flow

### `TrackingController.startHaul`

```dart
Future<Haul> startHaul({required double trawlWidthMeters}) async {
  ...
  // Read mode SEBELUM start
  final settings = await _settingsRepo.get();
  final mode = settings.trackingMode;

  ...

  // Foreground GPS subscription (sama untuk dua mode)
  _gpsSub = _gps.watchPosition().listen(_onReading, ...);

  if (mode == TrackingMode.normal) {
    // Mode Normal: skip foreground service
    Logger.instance.info(
      'tracking.start_normal_mode',
      {'haulId': haul.id},
    );
    state = state.copyWith(
      backgroundStatus: BackgroundTrackingStatus.stopped,
    );
    return haul;
  }

  // Mode Akurasi: jalankan foreground service (path PR #28)
  try {
    await _bgService.start(...);
    _subscribeBgStatus();
  } on NotificationPermissionDeniedException catch (e) {
    ...
  } on BackgroundServiceStartException catch (e) {
    ...
  } catch (e) {
    ...
  }

  return haul;
}
```

### `TrackingController.resumeHaul`

Sama pattern — cek mode saat resume. Kalau Normal, skip `_bgService.start`.

### Method baru `downgradeBackgroundService()`

Untuk R5 AC1 (switch Akurasi → Normal saat recording):

```dart
Future<void> downgradeBackgroundService() async {
  if (state.haul == null) return; // tidak ada yang recording
  try {
    await _bgService.stop();
  } catch (e) {
    Logger.instance.warn('tracking.downgrade_failed', {'error': '$e'});
  }
  state = state.copyWith(
    backgroundStatus: BackgroundTrackingStatus.stopped,
  );
}
```

### Method baru `upgradeBackgroundService()`

Untuk R5 AC4 (switch Normal → Akurasi saat recording):

```dart
Future<void> upgradeBackgroundService() async {
  final haul = state.haul;
  if (haul == null) return;
  try {
    await _bgService.start(
      haulId: haul.id,
      notificationTitle: 'Langgeng Sea — Merekam',
      notificationBody: '${haul.displayName()} — mode Akurasi',
    );
    _subscribeBgStatus();
  } on NotificationPermissionDeniedException catch (e) {
    Logger.instance.warn('tracking.upgrade_blocked_notif', {'error': '$e'});
    state = state.copyWith(backgroundStatus: BackgroundTrackingStatus.failed);
    rethrow; // caller di Settings handle rollback
  } catch (e) {
    Logger.instance.warn('tracking.upgrade_failed', {'error': '$e'});
    rethrow;
  }
}
```

### `_attemptRetry`

Tambah guard di awal:

```dart
void _attemptRetry() {
  // Skip retry kalau mode Normal — tidak ada bg service untuk
  // di-restart.
  final mode = ref.read(trackingModeProvider);
  if (mode == TrackingMode.normal) return;
  ...
}
```

## §7 Banner UI

`map_screen.dart` di area banner sekitar line 1086. Tambahkan
sebelum banner `backgroundDegraded`:

```dart
// Mode Normal info banner
if (isRecording &&
    trackingMode == TrackingMode.normal)
  Padding(
    padding: const EdgeInsets.only(bottom: AppSizes.sp2),
    child: GlassCard(
      level: GlassLevel.level1,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sp3,
        vertical: AppSizes.sp2,
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIconsFill.info,
            size: 16,
            color: context.colors.primary,
          ),
          const SizedBox(width: AppSizes.sp2),
          Expanded(
            child: Text(
              'Mode Normal — tracking pause saat layar mati',
              style: context.text.bodySmall?.copyWith(
                color: context.tokens.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    ),
  ),
```

`trackingMode` di-read via `ref.watch(trackingModeProvider)`.

Banner mode Normal dan banner `backgroundDegraded` saling exclusive
secara natural — di mode Normal, `backgroundStatus = stopped`,
`backgroundDegraded = false`.

## §8 BatteryOptimizationTile conditional

`settings_screen.dart`:

```dart
final mode = ref.watch(trackingModeProvider);
...
if (mode == TrackingMode.accurate)
  const BatteryOptimizationTile(),
```

Atau di dalam `BatteryOptimizationTile.build()` self-check:

```dart
final mode = ref.watch(trackingModeProvider);
if (mode == TrackingMode.normal) return const SizedBox.shrink();
```

Pilih self-hide (mirip pattern non-Android) supaya call site
`settings_screen.dart` tetap simple.

## §9 Decision points yang sudah final

| Topic | Decision | Rationale |
|---|---|---|
| Default first install | `Normal` | Tidak ada dialog izin di awal; user pindah saat butuh |
| Persistence | Drift `app_settings.tracking_mode` | Konsisten dengan polyline_width, alarm settings |
| Notif denied | Auto-rollback ke Normal | UI mode reflect realita |
| Battery denied | Tetap pindah ke Akurasi (warning) | Battery optional, foreground service tetap jalan |
| Mode Normal scope | Foreground GPS saja | Sesuai jawaban user "seperti awal sebelum keakuratan" |
| Switch saat recording | Allow + propagate ke service | UX tidak rusak haul yang sedang aktif |

## §10 Kompatibilitas

- **Android 13+ (target user):** flow lengkap berjalan, notif gate
  aktif.
- **Android 12 dan ke bawah:** `POST_NOTIFICATIONS` skip (sdkInt < 33),
  langsung ke battery step.
- **Android 8 dan ke bawah:** `ignoreBatteryOptimizations` tetap
  available (API 23+), aman.
- **iOS / desktop:** `activateAccurateMode` return
  `AccurateUnsupportedPlatform`. Card auto-disable atau hide.

## §11 Test strategy

### Unit (sandbox)

- `tracking_mode_test.dart` — enum `fromDbValue`, `dbValue`,
  `displayLabel`, `subtitle`.
- `tracking_mode_activation_test.dart` — semua kombinasi
  permission dengan fake `PermissionHandler`:
  - Granted notif + granted battery → `AccurateActivated`
  - Granted notif + denied battery → `AccurateActivatedWithBatteryWarning`
  - Granted notif + permanentlyDenied battery → `AccurateNeedsSystemSettings(battery)`
  - Denied notif → `AccurateDeclined`
  - PermanentlyDenied notif → `AccurateNeedsSystemSettings(notifications)`
  - Non-Android → `AccurateUnsupportedPlatform`
- `tracking_controller_test.dart` — case baru:
  - `startHaul` mode Normal → bg service `.start()` tidak dipanggil
  - `startHaul` mode Akurasi → bg service `.start()` dipanggil
  - `downgradeBackgroundService` → bg service `.stop()` dipanggil
  - `_attemptRetry` di mode Normal → no-op
- `migration_test.dart` — v8 → v9: kolom ada, default 'normal',
  row existing tidak corrupt.

### Manual (device)

Lihat §6 di `manual-verification.md`.
