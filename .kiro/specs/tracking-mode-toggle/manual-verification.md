# Manual Verification Checklist — PR #29 Tracking Mode Toggle

> Sandbox tidak punya Flutter toolchain. Pure-Dart unit test (`tracking_mode_test.dart`,
> `tracking_mode_activation_test.dart`, `migration_test.dart`) sudah lulus. Daftar
> di bawah harus dijalankan oleh user / QA di device sebelum merge.

## Build

```sh
cd app
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run --release    # atau install APK release
```

Build runner WAJIB dijalankan setelah pull karena schema `app_settings` di-update
(kolom `tracking_mode`). Tanpa codegen ulang, `app_database.g.dart` tidak punya
field baru dan kompilasi gagal.

## Persistence (R1, R7)

- [ ] **R1 — First install Mode = Normal**
  Uninstall app dulu, kemudian install fresh APK. Buka Settings,
  cek tile **Mode Tracking**. Segmented harus menunjukkan `Normal`
  selected. Subtitle: "Tracking jalan saat aplikasi terbuka. Hemat baterai."

- [ ] **R7 — Existing user upgrade Mode = Normal**
  Pakai user yang sudah pernah install build sebelum PR #29
  (schema v8). Tap **Update**, jangan reinstall.
  Setelah upgrade selesai, buka Settings → Mode Tracking.
  Mode harus `Normal` (default migrasi v8 → v9).

- [ ] **R1 — Mode persist antar session**
  Pindah ke Akurasi (lihat R3 di bawah), force-kill app, buka
  ulang. Mode harus tetap `Akurasi`.

## Mode Akurasi flow (R3, R4)

Device target: Redmi Note 10 Pro · PixelOS · Android 14+.

- [ ] **R3 — Tap Akurasi tampilkan dialog konfirmasi**
  Settings → Mode Tracking. Tap segment `Akurasi`.
  AlertDialog muncul dengan judul "Aktifkan Mode Akurasi?".
  Body menyebutkan kebutuhan izin notifikasi & baterai.
  Tombol: `Batal` dan `Lanjutkan`.

- [ ] **R3 — Batal → mode tetap Normal**
  Tap `Batal`. Dialog tertutup. Tile Mode Tracking masih
  menunjukkan `Normal`. Tidak ada dialog izin OS yang muncul.

- [ ] **R3 — Lanjutkan → grant notif + grant battery → mode jadi Akurasi**
  Tap `Lanjutkan`. Dialog OS notifikasi muncul (kalau belum
  granted). Tap `Izinkan`. Dialog OS battery muncul. Tap `Allow`.
  Snackbar "Mode Akurasi aktif." muncul. Tile Mode Tracking
  menunjukkan `Akurasi` selected. Subtitle: "Tracking tetap
  merekam saat layar mati. Memerlukan izin notifikasi."
  BatteryOptimizationTile MUNCUL di list Settings (sebelumnya hidden
  di mode Normal).

- [ ] **R4 AC1 — Tolak notifikasi → mode rollback ke Normal**
  Reset permission notifikasi via Settings sistem (Apps →
  Langgeng Sea → Notifications → Block notifications).
  Buka app → Settings → tap Akurasi → Lanjutkan → tap `Tolak`
  di dialog OS.
  Snackbar muncul: "Izin notifikasi dibutuhkan untuk Mode
  Akurasi. Mode tetap Normal." Tile Mode Tracking masih `Normal`.
  TIDAK ada permintaan battery permission setelahnya.

- [ ] **R4 AC2 — Notif permanently denied → tutorial sheet**
  Reset permission notifikasi, lalu di dialog OS tap `Tolak`
  beberapa kali sampai sistem set permanently denied. Buka app
  → Settings → tap Akurasi → Lanjutkan.
  TrackingModeTutorialSheet muncul dengan judul "Izin Notifikasi
  Diblokir", 5 langkah numbered list, dan tombol primary
  "Buka Pengaturan" + secondary "Nanti saja".
  Tap "Buka Pengaturan" → Settings sistem terbuka. Aktifkan notif
  manual, kembali ke app. Tile Mode Tracking masih `Normal` (mode
  tidak auto-pindah; user perlu tap Akurasi lagi).

- [ ] **R4 AC3 — Battery denied non-permanent → mode tetap pindah Akurasi**
  Reset battery permission. Buka app → Settings → tap Akurasi →
  Lanjutkan → grant notif → tap `Tolak` di dialog OS battery.
  Snackbar muncul: "Mode Akurasi aktif, tapi pengoptimalan baterai
  belum dimatikan. GPS bisa dibatasi saat layar mati."
  Tile Mode Tracking menunjukkan `Akurasi`. BatteryOptimizationTile
  muncul dengan status "Belum diatur".

- [ ] **R4 AC4 — Battery permanently denied → tutorial sheet + mode pindah**
  Skenario: di Settings sistem, set "Restrict background activity"
  atau "Blocked battery use". Buka app → Settings → tap Akurasi →
  Lanjutkan → grant notif → battery flow trigger permanently denied.
  TrackingModeTutorialSheet muncul dengan judul "Pengoptimalan
  Baterai Aktif", 5 langkah. Tile Mode Tracking PINDAH ke `Akurasi`
  (battery optional — tidak block).

- [ ] **R3 — Android < 13 (jika ada device test): skip notif step**
  Pakai device Android 12 (sdk 31). Tap Akurasi → Lanjutkan.
  TIDAK ada dialog notifikasi — flow langsung ke battery step.
  Setelah battery granted, mode pindah ke Akurasi.

## Mode switch saat tracking aktif (R5)

- [ ] **R5 AC1 — Akurasi → Normal saat recording**
  Mode = Akurasi. Tap MULAI di MapScreen → tracking jalan,
  notifikasi foreground service muncul.
  Buka Settings → tap Normal di Mode Tracking.
  Tidak ada konfirmasi dialog. Snackbar "Mode Normal aktif. Hemat
  baterai." muncul. Notifikasi foreground service HILANG.
  Banner "Mode Normal — tracking pause saat layar mati" muncul di
  MapScreen di bawah. Tracking tetap merekam selama app foreground.

- [ ] **R5 AC4 — Normal → Akurasi saat recording**
  Mode = Normal, ada haul aktif. Tap Akurasi → Lanjutkan → grant
  permissions. Foreground service start, notifikasi muncul.
  Banner Mode Normal di MapScreen HILANG. Haul ID & polyline tidak
  reset (recording dilanjutkan tanpa kehilangan data).

## Mode Normal behavior (R2)

- [ ] **R2 AC2 — Tap MULAI di Normal: tidak ada dialog**
  Mode = Normal, fresh recording (belum pernah Akurasi di session
  ini). Tap MULAI di MapScreen.
  TIDAK ada dialog notifikasi atau battery. Tracking langsung jalan.
  Banner "Mode Normal — tracking pause saat layar mati" muncul.

- [ ] **R2 AC4 — Foreground GPS jalan**
  Lihat live polyline di MapScreen, statistik distance/duration
  bertambah. Tidak ada notifikasi sistem (foreground service tidak
  start).

- [ ] **R2 AC5 — App di-background → tracking pause**
  Tekan tombol Home. Tunggu 30 detik. Buka app lagi.
  Polyline menunjukkan gap (titik yang tidak terekam saat
  background). Tracking lanjut normal setelah app foreground.
  TIDAK crash.

- [ ] **R2 AC6 — Kembali foreground → resume otomatis**
  Tracking otomatis resume saat app foreground. User tidak perlu
  re-tap MULAI.

## UI consistency (R6)

- [ ] **R6 AC1 — Non-Android (iOS / desktop)**
  Kalau ada device iOS / web build untuk test:
  - Tap Akurasi → snackbar "Mode Akurasi tidak tersedia di
    platform ini" muncul. Mode tidak berubah.
  - BatteryOptimizationTile self-hide.

- [ ] **A11y — Screen reader baca segmented**
  Aktifkan TalkBack. Fokus ke segmented Mode Tracking. Setiap
  segment di-baca: "Normal" / "Akurasi". Wrapper Semantics label
  "Pilih mode tracking" di-baca saat fokus pertama kali.

## Backward compatibility

- [ ] **Existing trips & hauls tetap utuh**
  Setelah upgrade ke v9, buka Riwayat. Semua trip & haul lama
  masih ada, polyline render normal, statistik tidak berubah.

- [ ] **Polyline width tetap value sebelumnya**
  Setting → Ketebalan Garis Peta. Slider di posisi yang sama
  dengan sebelum upgrade (v8 sudah punya `polyline_width`).

## Sandbox-side verification (sudah lulus)

- [x] `dart test app/test/features/tracking/domain/tracking_mode_test.dart`
  — round-trip enum & label.
- [x] `dart test app/test/features/tracking/application/tracking_mode_activation_test.dart`
  — 7 case permission state.
- [x] `dart test app/test/data/database/migration_test.dart`
  — v8 → v9 migration: kolom `tracking_mode` ada, default
  `'normal'` untuk pre-v9 rows, schemaVersion sampai 9.
