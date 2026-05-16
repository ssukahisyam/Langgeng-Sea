# Requirements — PR #29 Tracking Mode Toggle

> Format: EARS (Event–Action–Result–State) · Bahasa Indonesia.
> Konteks: setelah PR #27 (crash fix tracking + GPX export) dan PR #28
> (POST_NOTIFICATIONS gate), user butuh kontrol eksplisit untuk memilih
> kapan tracking pakai foreground service (yang minta izin notifikasi
> + battery optimization) dan kapan tidak — supaya app tidak memaksa
> izin yang user tidak butuhkan untuk skenario singkat.

## Latar belakang

Saat ini setiap tap **MULAI** memicu permintaan permission notifikasi
(R1 PR #28) dan permintaan battery optimization (R1 PR #27). Untuk
sebagian user — terutama saat test tracking singkat di darat atau
trip pendek dengan layar selalu aktif — dialog izin itu mengganggu
dan tidak relevan. Sebaliknya, untuk trip panjang dengan layar mati,
permission tersebut wajib supaya GPS tidak terhenti oleh Android Doze.

Jawaban: tambahkan **toggle Mode Tracking** di Settings, dengan dua
pilihan: **Normal** (foreground sederhana, tanpa permission tambahan)
dan **Akurasi** (foreground service dengan notifikasi + battery
optimization exemption).

## Requirements

### R1 — User bisa memilih mode tracking dari Settings

**Sebagai** nelayan,
**saya bisa** memilih antara mode tracking Normal dan Akurasi dari
layar Pengaturan,
**supaya** saya tidak diminta izin yang tidak relevan untuk skenario
penggunaan saya.

**Acceptance criteria:**
- AC1: Tile "Mode Tracking" muncul di Settings dengan kontrol
  segmented `Normal | Akurasi`.
- AC2: Pilihan persist antar session aplikasi (disimpan di tabel
  `app_settings`).
- AC3: Default first install adalah `Normal`.
- AC4: Tile menampilkan subtitle dinamis yang menjelaskan behavior
  mode aktif:
  - Normal: "Tracking jalan saat aplikasi terbuka. Hemat baterai."
  - Akurasi: "Tracking tetap merekam saat layar mati. Memerlukan
    izin notifikasi."

### R2 — Mode Normal: tracking sederhana tanpa permission tambahan

**Saat** mode tracking adalah Normal dan user tap MULAI,
**aplikasi** harus memulai tracking memakai stream GPS foreground
saja (tanpa foreground service Android),
**sehingga** tidak ada dialog izin notifikasi atau battery yang
muncul.

**Acceptance criteria:**
- AC1: `FlutterBackgroundTrackingService.start()` TIDAK dipanggil
  saat mode Normal.
- AC2: Tidak ada dialog `Permission.notification.request()` yang
  muncul saat tap MULAI di mode Normal.
- AC3: Tidak ada dialog `Permission.ignoreBatteryOptimizations.request()`.
- AC4: `_gps.watchPosition()` foreground subscription tetap aktif
  selama haul recording, sehingga polyline bertambah selama app
  terbuka.
- AC5: Saat app dipindah ke background, tracking pause secara natural
  (sesuai pola Android: stream Geolocator foreground berhenti). Tidak
  crash, tidak corrupted data.
- AC6: Saat app kembali ke foreground, GPS subscription resume
  otomatis (perilaku existing dari `_gps.watchPosition()`), tidak
  perlu user re-tap MULAI.
- AC7: Banner info "Mode Normal — tracking pause saat layar mati"
  muncul saat tracking aktif di mode Normal (bukan banner warning;
  level info biru).

### R3 — Mode Akurasi: foreground service dengan permission flow

**Saat** user mengubah mode dari Normal ke Akurasi di Settings,
**aplikasi** harus minta izin notifikasi (Android 13+) dan izin
battery optimization exemption,
**sehingga** saat user tap MULAI berikutnya tidak ada dialog
mendadak — semua izin sudah disiapkan saat user secara sadar
memilih mode Akurasi.

**Acceptance criteria:**
- AC1: Tap segmented `Akurasi` menampilkan dialog konfirmasi:
  "Mode Akurasi memerlukan izin notifikasi dan akses pengaturan
  baterai. Lanjutkan?" dengan tombol `Lanjutkan` dan `Batal`.
- AC2: Tap `Batal` → mode tetap Normal, tidak ada side effect.
- AC3: Tap `Lanjutkan` → app cek + request `POST_NOTIFICATIONS`
  (skip kalau Android < 13).
- AC4: Setelah notifikasi diberikan, app cek + request
  `ignoreBatteryOptimizations`.
- AC5: Kalau dua-duanya granted, mode tersimpan = `accurate` di DB,
  snackbar "Mode Akurasi aktif".
- AC6: Saat startHaul mode Akurasi berikutnya,
  `FlutterBackgroundTrackingService.start()` dipanggil seperti
  perilaku PR #28 (sudah include `Permission.notification` re-check
  + idempotent guard + fire-and-forget battery).

### R4 — Auto-rollback kalau permission gagal di mode Akurasi

**Saat** user mencoba aktifkan mode Akurasi tapi notifikasi ditolak,
**aplikasi** harus mengembalikan mode ke Normal dengan pesan yang
jelas, ATAU mengarahkan user ke pengaturan sistem kalau permission
permanently denied,
**sehingga** state mode di Settings selalu mencerminkan kondisi
permission yang sebenarnya — tidak ada "mode Akurasi tapi tidak
bisa digunakan".

**Acceptance criteria:**
- AC1: Result `denied` (user tap Tolak di dialog OS): mode tetap
  Normal, snackbar "Izin notifikasi dibutuhkan untuk mode Akurasi.
  Mode tetap Normal."
- AC2: Result `permanentlyDenied` (user tap "Don't ask again"):
  tampilkan `TrackingModeTutorialSheet` dengan reason `notifications`,
  mode tetap Normal.
- AC3: Battery permission `denied` (user tap Tolak): mode masih bisa
  pindah ke Akurasi (battery bukan blocker mutlak — tracking foreground
  service tetap jalan tanpa exemption, hanya akurasi saat layar mati
  yang berkurang). Snackbar warning ditampilkan.
- AC4: Battery permission `permanentlyDenied`: tampilkan
  `TrackingModeTutorialSheet` dengan reason `battery`, tapi mode
  TETAP pindah ke Akurasi (sesuai AC3).
- AC5: Tutorial sheet menyediakan tombol primary "Buka Pengaturan"
  yang panggil `openAppSettings()`, dan tombol secondary "Nanti saja".

### R5 — Mode Normal saat haul sedang recording

**Saat** user mengubah mode dari Akurasi ke Normal saat ada haul
yang sedang recording,
**aplikasi** harus menghentikan foreground service tapi mempertahankan
recording dengan foreground GPS subscription,
**sehingga** data yang sudah terekam tidak hilang dan user bisa
lanjut tap "Angkat Trawl" seperti normal.

**Acceptance criteria:**
- AC1: Pindah mode Akurasi → Normal saat tracking aktif: foreground
  service di-stop (`_bgService.stop()`), tapi `_gpsSub` tetap aktif.
- AC2: `state.haul` tidak berubah, polyline tetap muncul, metric
  hitung normal.
- AC3: Banner Mode Normal muncul setelah switch.
- AC4: Pindah mode Normal → Akurasi saat tracking aktif: tampilkan
  dialog "Aktifkan mode Akurasi sekarang juga? (foreground service
  akan start)". Konfirmasi → activation flow seperti R3, lalu start
  foreground service tanpa restart haul.

### R6 — UI tetap konsisten di non-Android

**Saat** aplikasi berjalan di iOS atau desktop,
**tile Mode Tracking** harus disabled atau di-hide,
**sehingga** user tidak bingung dengan kontrol yang tidak berdampak
di platform-nya.

**Acceptance criteria:**
- AC1: Di non-Android, segmented disabled dengan label
  "Tidak tersedia di platform ini".
- AC2: Atau alternatif: tile self-hide (sama seperti
  `BatteryOptimizationTile` di iOS).
- AC3: Mode internal tetap default `Normal` di non-Android.

### R7 — Backward compatibility & migration

**Saat** existing user upgrade dari schema v8 ke v9,
**migration** harus menambah kolom `tracking_mode` dengan default
`'normal'`,
**sehingga** existing user mendapat behavior yang sama dengan first
install (Normal default), bukan random tergantung migration.

**Acceptance criteria:**
- AC1: `app_settings` table v9 punya kolom `tracking_mode TEXT NOT
  NULL DEFAULT 'normal'`.
- AC2: Migration test (`migration_test.dart`) verifikasi v8 → v9:
  semua row existing dapat `tracking_mode = 'normal'`.
- AC3: `BatteryOptimizationTile` tetap rendered di Settings, TAPI
  conditional: hanya muncul kalau mode = Akurasi (di mode Normal,
  tile ini tidak relevan).

## Correctness properties

- **P1 — Mode terlarang tidak bisa dipersist**: hanya 2 nilai valid
  `normal` dan `accurate`. Repository validate input (atau Drift
  CHECK constraint).
- **P2 — Activation flow idempotent**: kalau user spam-tap segmented
  Akurasi, tidak ada race ganda dialog. Pakai busy flag / lock di
  widget state.
- **P3 — Mode normal-> tidak ada side effect Android**: tracking di
  mode Normal harus 100% bisa di-test di sandbox tanpa platform
  channel (no permission_handler, no flutter_background_service).
  Test wajib bisa lulus dengan mock GPS saja.
- **P4 — Persistence tahan crash**: kalau app force-killed setelah
  user pilih mode Akurasi, mode tersimpan saat re-open (tabel sudah
  flushed sebelum exit activation flow).

## Non-functional

- **NFR1 — Database migration safe**: schema bump v8 → v9 wajib
  reversible secara test. Tidak boleh corrupt data row existing.
- **NFR2 — A11y**: segmented button punya `Semantics` label per
  segment ("Mode Normal", "Mode Akurasi"). Subtitle dibaca screen
  reader saat mode berubah.
- **NFR3 — Tutorial sheet 100% Bahasa Indonesia**: tidak ada label
  yang campur Inggris.
- **NFR4 — Tidak block UI**: activation flow async, dengan
  CircularProgressIndicator di tile saat menunggu hasil dialog OS.
