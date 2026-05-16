# Tasks — PR #29 Tracking Mode Toggle

> Eksekusi atas-ke-bawah. Setiap phase = 1 commit di branch
> `feat/tracking-mode-toggle-pr29` supaya diff per area jelas dan
> reviewer bisa cherry-pick / revert per phase.

## Pre-flight

- [x] **0.1** Branch `feat/tracking-mode-toggle-pr29` dibuat dari
  `origin/main` terbaru (sudah include PR #28 fix POST_NOTIFICATIONS).
- [ ] **0.2** Spec docs (`requirements.md`, `design.md`, `tasks.md`)
  selesai — commit pertama planning-only.
- [ ] **0.3** Buat PR draft #29 dengan judul `[Planning] PR #29 —
  Tracking Mode toggle (Normal / Akurasi)` ke `main`.

---

## Phase 1 — Domain entity TrackingMode

- [ ] **1.1** Buat
  `app/lib/features/tracking/domain/entities/tracking_mode.dart`
  dengan enum `TrackingMode { normal, accurate }`. Tambah getter
  `dbValue`, `displayLabel`, `subtitle`, dan static
  `fromDbValue(String)`. Lihat design.md §1.

- [ ] **1.2** Buat
  `app/test/features/tracking/domain/tracking_mode_test.dart`:
  - `fromDbValue('normal')` → `TrackingMode.normal`
  - `fromDbValue('accurate')` → `TrackingMode.accurate`
  - `fromDbValue('invalid')` → fallback `normal`
  - `displayLabel` & `subtitle` value sesuai requirements R1 AC4

  **Definition of done:** `dart test app/test/features/tracking/domain/tracking_mode_test.dart` lulus.

- [ ] **1.3** Commit: `feat(tracking): add TrackingMode enum`

---

## Phase 2 — DB schema bump v9 + migration

- [ ] **2.1** Update `app/lib/data/database/tables.dart`
  `AppSettingsTable`: tambah `TextColumn get trackingMode =>
  text().withDefault(const Constant('normal'))();`. Letakkan setelah
  `polylineWidth`.

- [ ] **2.2** Update `app/lib/data/database/app_database.dart`:
  - `schemaVersion` → 9
  - `onUpgrade`: tambah block `if (from < 9) { await m.addColumn(
    appSettingsTable, appSettingsTable.trackingMode); }`

- [ ] **2.3** Generate ulang Drift:
  `cd app && flutter pub run build_runner build --delete-conflicting-outputs`
  (pelanjut konteks: kalau sandbox tidak punya Flutter toolchain, lakukan
  manual edit minimal di `app_database.g.dart` mengikuti pola
  `polylineWidth` — atau skip dan biarkan CI yang generate).

- [ ] **2.4** Update `app/test/data/database/migration_test.dart`:
  - Test case baru "v8 → v9 menambah kolom tracking_mode dengan
    default 'normal'":
    1. Open DB v8 (lewat schemaHelper)
    2. Insert baris dummy ke `app_settings` dengan polyline_width=10
    3. Migrate ke v9
    4. Query baris itu
    5. Assert `trackingMode == 'normal'`

  **Definition of done:** migration test lulus tanpa data corruption.

- [ ] **2.5** Commit: `feat(db): app_settings.tracking_mode column (v8 → v9)`

---

## Phase 3 — Domain entity AppSettings + repository wiring

- [ ] **3.1** Update
  `app/lib/core/settings/domain/entities/app_settings.dart`:
  - Tambah field `final TrackingMode trackingMode;` (import dari
    `features/tracking/domain/entities/tracking_mode.dart`)
  - Update constructor, `defaults` (set ke `TrackingMode.normal`),
    `copyWith`, `==`, `hashCode`, `toString`.

- [ ] **3.2** Update
  `app/lib/data/database/daos/app_settings_dao.dart`:
  - Tambah method `Future<void> setTrackingMode(String value)`
    yang panggil `ensureSeeded` lalu update kolom.

- [ ] **3.3** Update
  `app/lib/core/settings/data/app_settings_repository.dart`:
  - Tambah method `setTrackingMode(TrackingMode)`
  - Update `_fromRow` untuk include `trackingMode:
    TrackingMode.fromDbValue(r.trackingMode)`.

- [ ] **3.4** Tambah Riverpod provider di
  `app/lib/core/settings/application/app_settings_provider.dart`:

  ```dart
  final trackingModeProvider = Provider<TrackingMode>((ref) {
    final settings = ref.watch(appSettingsProvider);
    return settings.asData?.value.trackingMode ?? TrackingMode.normal;
  });
  ```

- [ ] **3.5** Update existing test
  `app/test/core/settings/app_settings_repository_test.dart` (kalau
  ada) untuk include field baru. Kalau belum ada, skip.

- [ ] **3.6** Commit: `feat(settings): TrackingMode field on AppSettings entity + repository`

---

## Phase 4 — Activation flow + tests

- [ ] **4.1** Update interface `PermissionHandler` di
  `app/lib/features/tracking/application/tracking_permission_flow.dart`:
  tambah 2 method abstract `checkIgnoreBattery()` dan
  `requestIgnoreBattery()`. Implementasi di `RealPermissionHandler`.

- [ ] **4.2** Buat
  `app/lib/features/tracking/application/tracking_mode_activation.dart`:
  - Sealed class `ActivateAccurateResult`:
    - `AccurateActivated`
    - `AccurateActivatedWithBatteryWarning`
    - `AccurateNeedsSystemSettings(reason)`
    - `AccurateDeclined`
    - `AccurateUnsupportedPlatform`
  - Enum `NeedSettingsReason { notifications, battery }`
  - Function `activateAccurateMode({required PermissionHandler
    handler})` per design.md §3.

- [ ] **4.3** Buat
  `app/test/features/tracking/application/tracking_mode_activation_test.dart`:
  - Fake `PermissionHandler` yang bisa di-script per test.
  - Test cases (lihat design.md §11):
    1. Granted notif + granted battery → `AccurateActivated`
    2. Granted notif + denied battery → `AccurateActivatedWithBatteryWarning`
    3. Granted notif + permanentlyDenied battery →
       `AccurateNeedsSystemSettings(battery)`
    4. Denied notif → `AccurateDeclined`
    5. PermanentlyDenied notif →
       `AccurateNeedsSystemSettings(notifications)`
    6. Non-Android (sdkInt = -1) → `AccurateUnsupportedPlatform`
    7. Android < 13 (sdkInt = 31) → skip notif step, langsung battery

  **Definition of done:** semua case lulus.

- [ ] **4.4** Commit: `feat(tracking): activateAccurateMode permission flow`

---

## Phase 5 — TrackingModeCard widget

- [ ] **5.1** Buat
  `app/lib/features/settings/presentation/widgets/tracking_mode_card.dart`
  sebagai `ConsumerStatefulWidget`:
  - State: `bool _busy = false`
  - Build: `GlassCard` dengan header icon + title, subtitle dinamis
    dari `mode.subtitle`, segmented `Normal | Akurasi`.
  - Selection logic: `Set<TrackingMode> _selected = {currentMode}`
    yang di-update saat user tap segment.
  - Saat tap `Akurasi` (current = Normal): show `AlertDialog`
    konfirmasi → kalau Lanjutkan, set `_busy = true`,
    panggil `activateAccurateMode()`, handle 5 result type.
  - Saat tap `Normal` (current = Akurasi): set `setTrackingMode(normal)`
    langsung, tanpa konfirmasi. Kalau `state.isRecording`, panggil
    `trackingController.downgradeBackgroundService()` (method baru
    di Phase 7 — di phase ini siapkan TODO + comment).

- [ ] **5.2** Test widget (smoke test, kalau memungkinkan):
  - Render dengan default mode = Normal: segmented show "Normal" selected.
  - Tap "Akurasi" → AlertDialog muncul.

- [ ] **5.3** Commit: `feat(settings): TrackingModeCard widget`

---

## Phase 6 — TrackingModeTutorialSheet widget

- [ ] **6.1** Buat
  `app/lib/features/settings/presentation/widgets/tracking_mode_tutorial_sheet.dart`:
  - Function `Future<void> showTrackingModeTutorial(context, {required reason})`
    yang call `showModalBottomSheet`.
  - Widget `TrackingModeTutorialSheet({required reason})`:
    `StatelessWidget` dengan konten dinamis per `NeedSettingsReason`.
  - Render: heading + numbered list (1-5 langkah dengan badge bulat
    nomor) + 2 tombol bawah ("Buka Pengaturan" primary, "Nanti saja"
    secondary).
  - Tombol primary panggil `openAppSettings()` dari
    permission_handler, tutup sheet.

- [ ] **6.2** Commit: `feat(settings): TrackingModeTutorialSheet widget`

---

## Phase 7 — Wire-up TrackingController mode-aware

- [ ] **7.1** Inject `AppSettingsRepository` ke `TrackingController`
  via getter Riverpod (sama pattern dengan `_trips`, `_hauls`).
  Kalau provider belum ada untuk repo, tambah.

- [ ] **7.2** Update `startHaul()`:
  - Sebelum `_bgService.start(...)`, baca
    `final mode = (await _settingsRepo.get()).trackingMode;`
  - Kalau `mode == normal`: skip `_bgService.start`, set
    `backgroundStatus: stopped`, return haul.
  - Kalau `mode == accurate`: lanjut ke try-catch existing.

- [ ] **7.3** Update `resumeHaul()`: sama pattern. Kalau Normal,
  skip `_bgService.start`. Tetap subscribe `_gpsSub`.

- [ ] **7.4** Tambah method baru:
  - `Future<void> downgradeBackgroundService()` — stop bg service
    tanpa stop haul.
  - `Future<void> upgradeBackgroundService()` — start bg service
    untuk haul yang sedang recording. Bisa rethrow exception agar
    caller di Settings handle rollback.

- [ ] **7.5** Update `_attemptRetry()`: skip kalau mode = Normal.
  Read mode lewat `ref.read(trackingModeProvider)`.

- [ ] **7.6** Update `tracking_controller_test.dart`:
  - Override `appSettingsProvider` dengan `Stream.value` dari
    `AppSettings.defaults.copyWith(trackingMode: ...)`.
  - Tambah fake `BackgroundTrackingService` yang track call counts.
  - Override `backgroundTrackingServiceProvider` dengan fake.
  - Test: "startHaul mode Normal: bg service start TIDAK dipanggil"
  - Test: "startHaul mode Akurasi: bg service start DIPANGGIL"
  - Test: "downgradeBackgroundService: bg service stop dipanggil"

- [ ] **7.7** Wire-up Phase 5 TODO: `TrackingModeCard` saat user
  pilih Normal di tengah recording → panggil
  `downgradeBackgroundService()`. Saat pilih Akurasi di tengah
  recording (setelah activation success) → panggil
  `upgradeBackgroundService()`.

- [ ] **7.8** Commit: `feat(tracking): mode-aware startHaul + downgrade/upgrade hooks`

---

## Phase 8 — Banner mode Normal di MapScreen

- [ ] **8.1** Update `app/lib/features/map/presentation/map_screen.dart`
  area banner sekitar line 1086:
  - Tambah variable `final trackingMode =
    ref.watch(trackingModeProvider);` di build method.
  - Tambah banner info biru di atas banner backgroundDegraded:

    ```dart
    if (isRecording && trackingMode == TrackingMode.normal)
      Padding(
        padding: const EdgeInsets.only(bottom: AppSizes.sp2),
        child: GlassCard(
          ...
          child: Row(
            children: [
              Icon(PhosphorIconsFill.info, size: 16,
                color: context.colors.primary),
              const SizedBox(width: AppSizes.sp2),
              Expanded(
                child: Text(
                  'Mode Normal — tracking pause saat layar mati',
                  ...,
                ),
              ),
            ],
          ),
        ),
      ),
    ```

- [ ] **8.2** Commit: `feat(map): banner Mode Normal info`

---

## Phase 9 — Settings integration & polish

- [ ] **9.1** Update `settings_screen.dart`:
  - Import `TrackingModeCard`.
  - Sisipkan card setelah profile card / theme selector, tepat
    SEBELUM card "Lebar Bukaan Trawl + Peta Offline + …".
  - `BatteryOptimizationTile` self-hide kalau mode = Normal: edit
    `battery_optimization_tile.dart` `build()` tambah:
    ```dart
    final mode = ref.watch(trackingModeProvider);
    if (mode == TrackingMode.normal) return const SizedBox.shrink();
    ```

- [ ] **9.2** Update `manual-verification.md` di
  `.kiro/specs/tracking-mode-toggle/`:
  - Checklist 8 case (lihat requirements R1-R7).
  - Section "Build & install" sama seperti PR #27.

- [ ] **9.3** Commit: `feat(settings): integrate TrackingModeCard + auto-hide BatteryTile`

---

## Phase 10 — Push & PR final

- [ ] **10.1** `git push origin feat/tracking-mode-toggle-pr29`

- [ ] **10.2** Update PR #29 dari draft ke ready-for-review:
  - Title: hapus prefix `[Planning]` →
    `feat: Tracking Mode toggle (Normal / Akurasi)`
  - Body: ringkas requirements + manual checklist + dependency note
    "Bergantung pada PR #28 yang sudah merged".

- [ ] **10.3** Tunggu CI lulus.

- [ ] **10.4** Coordinate dengan user untuk manual testing di device
  Redmi Note 10 Pro / PixelOS.

---

## Estimasi waktu

- Phase 1-3: 1.5 jam (domain + DB + repo)
- Phase 4: 1 jam (activation flow + tests)
- Phase 5-6: 1.5 jam (UI Settings + tutorial sheet)
- Phase 7: 1 jam (wire-up TrackingController)
- Phase 8-9: 1 jam (banner + integration)
- Phase 10: 30 menit (push + PR)

Total ≈ 5-6 jam dev. Sandbox tidak punya Flutter toolchain, jadi
build_runner Drift codegen mungkin butuh manual edit di `.g.dart`
atau biarkan CI yang generate (untungnya CI ada `Flutter CI`
workflow yang `flutter pub get` + analyze + test).

---

## Catatan untuk pelanjut konteks

Kalau context window habis di tengah eksekusi:

1. **Cek sudah sampai phase mana** dengan `git log --oneline
   origin/main..HEAD`. Setiap phase = 1 commit dengan prefix yang
   konsisten.
2. **Baca ulang `requirements.md` dan `design.md`** untuk konteks.
3. **Phase 2 paling kritis**: kalau migration salah, existing user
   bisa kena data corruption. Test migration WAJIB lulus sebelum
   commit phase 2.
4. **Phase 4 paling complex**: activation flow punya banyak edge
   case. Tulis test sebelum implementasi (TDD).
5. **Phase 5-6 boleh di-tukar urutan** kalau lebih nyaman pasang
   tutorial sheet dulu (dependency-wise card depend sheet, jadi
   sheet dulu mungkin lebih bagus).
6. **Phase 7 wajib SETELAH 1-4** karena import `TrackingMode`,
   provider mode, dan exception types.
7. **Tidak perlu build APK lokal** untuk verify — push ke CI yang
   sudah include `flutter build apk` di workflow rilis.
