# Manual Verification Checklist — PR #32 Marker Pick on Map

> Sandbox tidak punya Flutter toolchain. Pure-Dart unit test
> (`marker_pick_tooltip_test.dart`) sudah lulus. Daftar di bawah harus
> dijalankan oleh user / QA di device sebelum merge.

## Build

```sh
cd app
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run --release
```

## Long-press peta tetap berfungsi (R1)

- [ ] **R1 — Long-press peta**
  Buka MapScreen, long-press di lokasi sembarang.
  `LongPressMenu` muncul dengan dua opsi: `Mulai Navigasi ke Sini` dan
  `Tandai sebagai Penanda`. Tap `Tandai sebagai Penanda` → dialog
  `AddMarkerDialog` muncul dengan koordinat dari titik long-press.
  Submit → marker tersimpan di koordinat itu.

## Add Marker button dual-mode (R2)

- [ ] **R2 — Tap pendek (existing)**
  Saat ada GPS fix, tap floating button Add Marker (icon +).
  Dialog `AddMarkerDialog` muncul dengan koordinat dari posisi GPS
  saat ini. Submit → marker tersimpan.

- [ ] **R2 — Tap pendek tanpa GPS**
  Saat tidak ada GPS fix, tap floating button.
  Snackbar "Tunggu sinyal GPS dulu sebelum menandai lokasi" muncul.
  Tidak ada dialog atau mode change.

- [ ] **R2 — Long-press FAB**
  Tekan dan tahan tombol Add Marker selama ≥ 500ms.
  Haptic feedback ringan terasa. UI berganti ke mode crosshair
  (lihat R3 di bawah).

- [ ] **R2 AC3 — Semantics**
  Aktifkan TalkBack. Fokus ke tombol Add Marker. Screen reader
  membaca "Tambah penanda di posisi saat ini. Tekan lama untuk
  pilih lokasi di peta."

## Mode pickMarkerLocation crosshair (R3)

- [ ] **R3 AC1 — Crosshair fixed di tengah**
  Setelah masuk mode (long-press FAB atau dari Markers list),
  crosshair (lingkaran + icon target + dot tengah, warna primary)
  muncul tepat di tengah viewport.

- [ ] **R3 AC2 — Crosshair tetap di tengah saat pan**
  Pan peta ke segala arah. Crosshair tetap di tengah layar (fixed
  terhadap viewport, bukan koordinat peta).

- [ ] **R3 AC3 — Bottom sheet instruksi**
  Bottom sheet glass card muncul di bawah dengan teks
  "Pan peta sampai crosshair berada di lokasi yang ingin ditandai."

- [ ] **R3 AC4 — Koordinat live update**
  Pan peta perlahan. Koordinat di bottom sheet
  ("-7.20451, 113.40123" misalnya) update mengikuti center peta
  setiap kali camera berubah.

- [ ] **R3 AC5 — Tombol Batal dan Tandai**
  Tombol [Batal] di kiri (lebih kecil), [Tandai di Sini] di kanan
  (lebih lebar, dengan icon checkCircle).

- [ ] **R3 AC6 — Tap Tandai membuka AddMarkerDialog**
  Pan peta ke lokasi sembarang, tap [Tandai di Sini].
  Mode reset ke idle. `AddMarkerDialog` muncul dengan koordinat
  yang sama persis dengan yang ditampilkan di bottom sheet
  sebelum di-tap.

- [ ] **R3 AC7 — Tap Batal kembali ke idle**
  Masuk mode pick, tap [Batal].
  Mode reset ke idle. Tidak ada dialog yang muncul. Tidak ada
  marker yang dibuat.

- [ ] **R3 AC8 — Kontrol map lain hidden**
  Saat mode pick aktif, _ActionPanel (Mulai/Berhenti tracking)
  tidak rendered. _AddMarkerButton FAB juga tetap visible (di
  spec original di-hide, tapi visibility-nya tidak menggangu
  karena disable saat mode pick).

## First-time tooltip (R4)

- [ ] **R4 AC1 — Muncul sekali per app install**
  Uninstall app, install ulang fresh. Buka MapScreen.
  Setelah location permission granted, tooltip bubble dengan
  arrow ke arah Add Marker FAB muncul:
  "Tahu fitur ini? Tekan lama tombol Tambah Penanda untuk pilih
  lokasi langsung di peta..."

- [ ] **R4 AC2 — Auto-dismiss 5 detik**
  Biarkan tooltip muncul. Setelah 5 detik, tooltip hilang
  otomatis.

- [ ] **R4 AC3 — Tombol Mengerti dismiss manual**
  Trigger tooltip lagi (uninstall + reinstall, atau hapus data).
  Tap tombol "Mengerti" sebelum 5 detik habis. Tooltip langsung
  hilang.

- [ ] **R4 AC4 — Tidak muncul lagi setelah dismiss**
  Tutup app, buka lagi. Tooltip TIDAK muncul ulang.

- [ ] **R4 — Tooltip dismissed saat user discover sendiri**
  Uninstall + reinstall. Sebelum tooltip muncul (atau tepat saat
  muncul), long-press tombol Add Marker. Tooltip langsung hilang
  (cleared by `_dismissMarkerPickTooltip` di handler long-press).

## Markers list "+" → mode pick (R5)

- [ ] **R5 AC1 — Tombol Tambah extended**
  Buka Settings → Kelola Penanda. FloatingActionButton.extended
  muncul di kanan bawah dengan label "Tambah" + icon mapPinPlus.

- [ ] **R5 AC2 — Tap pop ke MapScreen + mode pick**
  Tap "Tambah". Markers list pop, MapScreen tab aktif, mode
  langsung pickMarkerLocation. Crosshair + bottom sheet langsung
  muncul tanpa kedip ke idle controls dulu.

- [ ] **R5 AC3 — Marker baru muncul di list setelah konfirmasi**
  Pan peta, tap [Tandai di Sini], submit AddMarkerDialog. Kembali
  ke Markers list (back button atau tap tab Settings). Marker
  baru ada di list dengan koordinat yang dipilih.

## Tracking active guard (R6)

- [ ] **R6 AC1 — Long-press FAB blocked saat recording**
  Mulai tracking. Saat haul recording, long-press tombol Add
  Marker.
  Snackbar "Selesaikan tracking dulu untuk menandai lokasi
  non-GPS." muncul. TIDAK masuk mode pick.

- [ ] **R6 AC2 — Long-press peta tetap berfungsi saat recording**
  Saat haul recording, long-press di peta sembarang.
  `LongPressMenu` tetap muncul dengan opsi `Tandai sebagai
  Penanda`. Tap → AddMarkerDialog muncul dengan koordinat
  long-press (bukan GPS sekarang).

## Lifecycle & defensive (Phase 7)

- [ ] **App pause saat mode pick → reset**
  Masuk mode pick, tekan tombol Home. Tunggu 5 detik. Buka app
  dari Recent Apps.
  Mode kembali ke idle (bukan pick). Crosshair tidak muncul lagi.
  Action panel idle (Mulai tracking) muncul kembali.

- [ ] **Tap MULAI saat mode pick → reset + start tracking**
  Skenario edge case: kalau ada path yang men-trigger startHaul
  tanpa user lewat _ActionPanel (mis. via deep link, automated test,
  shortcut). Mode pick di-reset, tracking start normal.

- [ ] **Back button saat mode pick (skip — belum ada PopScope)**
  Phase 7 ini belum implement PopScope back button handler.
  Saat ini back button akan exit MapScreen tab (perilaku default
  Android). Bisa di-iterasi nanti kalau user keluhkan.

## Sandbox-side verification (sudah lulus)

- [x] `dart test app/test/features/map/marker_pick_tooltip_test.dart`
  — 4 case round-trip flag persistence dengan
  `SharedPreferences.setMockInitialValues({})`.
