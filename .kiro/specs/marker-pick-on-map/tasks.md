# Tasks — PR #32 Marker Pick on Map

> Eksekusi atas-ke-bawah. Setiap phase = 1 commit di branch
> `feat/marker-pick-on-map`.

## Pre-flight

- [x] **0.1** Branch `feat/marker-pick-on-map` dibuat dari
  `origin/main` terbaru.
- [ ] **0.2** Spec docs (`requirements.md`, `design.md`,
  `tasks.md`) di `.kiro/specs/marker-pick-on-map/`. Commit pertama
  planning-only.
- [ ] **0.3** Buat PR draft #32 ke `main`.

---

## Phase 1 — MapMode enum + tooltip flag storage

- [ ] **1.1** Update `app/lib/features/map/application/map_mode.dart`:
  tambah `pickMarkerLocation` ke enum + getter `isPicking`.

- [ ] **1.2** Update `map_mode_provider.dart` kalau perlu helper
  setter / transition guards.

- [ ] **1.3** Cek `pubspec.yaml` apakah `shared_preferences` sudah
  ada. Kalau belum, tambah `shared_preferences: ^2.x`.

- [ ] **1.4** Buat
  `app/lib/features/map/presentation/widgets/marker_pick_tooltip.dart`
  dengan static helper class:
  - `Future<bool> hasBeenShown()`
  - `Future<void> markShown()`
  - `OverlayEntry buildOverlay({...})` — render bubble + arrow +
    "Mengerti" button.

- [ ] **1.5** Test
  `app/test/features/map/marker_pick_tooltip_test.dart`:
  - Round-trip flag (default false → mark → true)
  - Pakai `SharedPreferences.setMockInitialValues({})`.

- [ ] **1.6** Commit: `feat(map): MapMode.pickMarkerLocation + tooltip flag`

---

## Phase 2 — PickLocationOverlay widget

- [ ] **2.1** Buat
  `app/lib/features/map/presentation/widgets/pick_location_overlay.dart`
  per design.md §2:
  - `ConsumerStatefulWidget` dengan `LatLng _currentCenter` state.
  - `initState`: subscribe ke `widget.mapController.mapEventStream`,
    update `_currentCenter` dengan throttle 100ms.
  - Build: `Stack` dengan crosshair `Center(Icon(crosshair))` di
    atas + `Align(bottom)` GlassCard kontrol.
  - Pakai `GestureDetector(behavior: HitTestBehavior.deferToChild)`
    pada area di atas/bawah crosshair supaya gesture peta tetap
    lewat ke flutter_map.

- [ ] **2.2** Widget test
  `app/test/features/map/widgets/pick_location_overlay_test.dart`:
  - Render → crosshair muncul, bottom sheet muncul.
  - Tap [Tandai di Sini] → `onConfirm` di-call dengan
    `mapController.camera.center`.
  - Tap [Batal] → `onCancel` di-call.

- [ ] **2.3** Commit: `feat(map): PickLocationOverlay widget`

---

## Phase 3 — Wire-up MapScreen + mode switching

- [ ] **3.1** Update `map_screen.dart` `_buildModeControls` switch
  untuk handle `MapMode.pickMarkerLocation` → return
  `PickLocationOverlay`.

- [ ] **3.2** Tambah method `_onPickMarkerConfirm(LatLng)` dan
  `_onPickMarkerCancel()` di `_MapScreenState`.

- [ ] **3.3** Hide IdleControls + TrackingBottomSheet saat mode
  pick aktif (sudah otomatis via switch case, tapi cek bahwa
  banner top-of-map dan FAB lain juga hide).

- [ ] **3.4** Commit: `feat(map): wire-up PickLocationOverlay in MapScreen`

---

## Phase 4 — Long-press Add Marker button

- [ ] **4.1** Update `idle_controls.dart` `_AddMarkerButton`:
  - Tambah `VoidCallback? onLongPress` parameter.
  - Wrap dengan `GestureDetector` atau pakai
    `Material(child: InkWell(onLongPress: ...))`.
  - `HapticFeedback.lightImpact()` di onLongPress handler.
  - `Semantics.label` update sesuai R2 AC3.

- [ ] **4.2** Update parent (idle controls atau map_screen) untuk
  pass `onLongPress: () { ... set MapMode.pickMarkerLocation }`.

- [ ] **4.3** Guard: kalau `state.isRecording`, tampilkan snackbar
  "Selesaikan tracking dulu untuk menandai lokasi non-GPS" di
  onLongPress handler — jangan masuk mode pick (R6 AC1).

- [ ] **4.4** Commit: `feat(map): long-press Add Marker button enters pick mode`

---

## Phase 5 — Markers list "+" → mode pick

- [ ] **5.1** Update `markers_list_screen.dart`:
  - Hapus tombol `FloatingActionButton` lama yang pakai placeholder
    lat/lon = 0 (kalau ada — line 128-129 di code lama).
  - Tambah `FloatingActionButton.extended` baru dengan label
    "Tambah" + icon `+`.
  - onTap: `Navigator.maybePop()` lalu
    `context.go('/')` ke tab Map → `Future.microtask` set
    `mapModeProvider = pickMarkerLocation`.

- [ ] **5.2** Cek `app_shell.dart` / `app_router.dart` untuk
  pastikan navigasi tab kerja. Test manual.

- [ ] **5.3** Commit: `feat(markers): "Tambah Baru" enters map pick mode`

---

## Phase 6 — First-time tooltip

- [ ] **6.1** `MapScreen.initState()`: panggil
  `MarkerPickTooltip.hasBeenShown()`. Kalau `false`, schedule
  `OverlayEntry` insert via `addPostFrameCallback` setelah build
  pertama selesai.

- [ ] **6.2** Tooltip pakai `GlobalKey` di `_AddMarkerButton`
  untuk dapatkan posisi target. Render bubble + arrow ke arah
  tombol.

- [ ] **6.3** Tap "Mengerti" atau timer 5 detik → remove overlay
  + `MarkerPickTooltip.markShown()`.

- [ ] **6.4** Pastikan tooltip TIDAK render kalau sudah ada
  `OverlayEntry` lain yang dominan (mis. permission sheet).

- [ ] **6.5** Commit: `feat(map): first-time tooltip for Add Marker long-press`

---

## Phase 7 — Defensive guards + edge cases

- [ ] **7.1** Update `TrackingController.startHaul`: kalau
  `mapModeProvider != idle && mapModeProvider != tracking`,
  log warning + return tanpa start. UI di MapScreen tidak akan
  panggil ini saat mode pick (button startHaul ke-hide), tapi
  defensive.

- [ ] **7.2** App lifecycle: di `MapScreen.didChangeAppLifecycleState`,
  kalau `state == paused` dan `mapModeProvider == pickMarkerLocation`,
  reset ke idle (R6-ish, edge case di design.md §8).

- [ ] **7.3** Back button handler: tambah `PopScope` di MapScreen
  yang intercept saat mode pick aktif → reset ke idle, swallow
  pop. Supaya back button = cancel, tidak keluar app.

- [ ] **7.4** Commit: `feat(map): defensive guards for pick mode`

---

## Phase 8 — Manual verification + push + PR final

- [ ] **8.1** Buat
  `.kiro/specs/marker-pick-on-map/manual-verification.md` dengan
  checklist sesuai requirements R1-R6.

- [ ] **8.2** `git push origin feat/marker-pick-on-map`

- [ ] **8.3** Update PR #32 dari draft ke ready-for-review:
  - Title: hapus prefix `[Planning]` →
    `feat: Pilih lokasi marker di peta (mode crosshair)`
  - Body: ringkas requirements + manual verification + dependency

- [ ] **8.4** Tunggu CI lulus.

- [ ] **8.5** Coordinate dengan user untuk manual testing.

---

## Estimasi

- Phase 1: 30 menit (enum + tooltip storage)
- Phase 2: 1 jam (overlay widget)
- Phase 3: 30 menit (MapScreen wire-up)
- Phase 4: 30 menit (long-press button)
- Phase 5: 30 menit (Markers list integration)
- Phase 6: 1 jam (tooltip overlay implementation)
- Phase 7: 30 menit (defensive guards)
- Phase 8: 30 menit (push + PR)

Total ≈ 5 jam dev.

---

## Catatan untuk pelanjut konteks

1. **Phase 2 paling kompleks**: overlay yang tidak block map gestures
   butuh `HitTestBehavior` yang tepat. Kalau crosshair atau bottom
   sheet menyerap semua tap, peta tidak bisa di-pan. Test manual
   wajib di setiap iterasi.

2. **Phase 6 (tooltip)** boleh di-skip kalau prioritas tinggi
   selesaikan PR #33. Tooltip discoverability adalah polish, bukan
   blocker. Kalau di-skip, hapus dari requirements R4 dan tutup
   sebagai follow-up issue.

3. **`mapEventStream` listener** di Phase 2 — jangan lupa cancel di
   `dispose()` supaya tidak leak setelah keluar dari mode pick.

4. **Markers list integration (Phase 5)** mungkin butuh refactor
   minor di `app_shell.dart` untuk navigasi tab programatis.
   Cek dulu sebelum commit.
