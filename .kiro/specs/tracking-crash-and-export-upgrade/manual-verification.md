# Manual Verification Checklist — PR #27

> Sandbox tidak punya Flutter toolchain, jadi pure-Dart unit test +
> smoke-test Python sudah lewat. Daftar di bawah harus dijalankan
> oleh user / QA di device sebelum merge.

## Build

```sh
cd app
flutter pub get
flutter test
flutter run --release    # atau install APK release
```

## Crash regression (R1, R2)

Device target: Redmi Note 10 Pro · PixelOS · Android 14+.

- [ ] **R1 — Battery permission tidak crash**
  Tekan **MULAI** untuk pertama kali setelah install fresh.
  Sebagai notifikasi foreground service muncul dulu.
  ~2 detik setelah service hidup, dialog
  "Allow Langgeng Sea to ignore battery optimizations?" muncul.
  Tap **Allow** → aplikasi tidak crash, tracking tetap jalan,
  notifikasi tetap tampil. Tap **Tolak** → aplikasi tidak crash,
  tracking tetap jalan dengan akurasi normal.

- [ ] **R1 — Decline juga aman**
  Reset ulang permission via Settings sistem
  (App info → Permissions → Battery optimization → Optimize).
  Mulai tracking baru → dialog muncul → tap **Tolak/Don't allow**.
  Aplikasi tidak crash, tracking tetap jalan.

- [ ] **R1 — Race-fix**
  Mulai tracking → dalam 2 detik (sebelum dialog OS muncul),
  putar layar atau tekan tombol Home dan kembali ke app.
  Dialog tetap muncul dengan benar setelah 2 detik delay,
  apa pun pilihan user tidak crash.

- [ ] **R2 — Resume haul tidak crash**
  Mulai tracking, kemudian force-kill aplikasi via Recent Apps.
  Buka aplikasi lagi → popup "Tarikan #N masih merekam" muncul.
  Tap **Lanjutkan** → tracking resume tanpa crash, polyline
  sebelumnya muncul kembali.

- [ ] **R2 — Tutup juga aman**
  Ulangi force-kill scenario, tapi tap **Tutup** di popup.
  Haul difinalize, summary sheet muncul, aplikasi tidak crash.

- [ ] **R2 — Orphan trip resume**
  Mulai tracking, lalu di Riwayat hapus trip yang sedang aktif
  (kalau memungkinkan dari UI), lalu force-kill app.
  Buka lagi → popup → Lanjutkan → aplikasi tidak crash;
  haul orphan otomatis difinalize dengan summary sheet.

## Settings tile (R3)

- [ ] **R3 — Status awal**
  Buka **Pengaturan → Pengaturan Lanjutan**.
  Tile **Akurasi Saat Layar Mati** muncul.
  Subtitle mencerminkan status saat ini ("Aktif" / "Belum diatur" /
  "Diblokir di pengaturan sistem").

- [ ] **R3 — Grant flow**
  Kalau status "Belum diatur", tap tile.
  Dialog OS muncul, tap Allow.
  Setelah dialog tutup, subtitle update jadi "Aktif" tanpa restart.

- [ ] **R3 — Revoke flow**
  Kalau status "Aktif", tap tile.
  Layar Settings sistem terbuka di App info / Battery optimization.
  Cabut permission manual, kembali ke aplikasi (back button).
  Subtitle update jadi "Belum diatur" otomatis (lifecycle observer).

- [ ] **R3 — iOS hide**
  Kalau ada device iOS untuk test, tile harus self-hide
  (tidak muncul di list Settings).

## GPX export (R4 + R5)

Pre-syarat: ada minimal 2-3 trip dengan 5+ haul total dan
3+ marker dari berbagai kategori.

- [ ] **R4 — Semua data**
  Settings → Ekspor Data. Default: Jalur ✓, Penanda ✓,
  semua waktu, semua kategori. Tap Ekspor & Bagikan.
  Buka file `.gpx` di Notepad / text viewer:
  - `<author><name>Pak Budi</name>` (sesuai user profile)
  - `<lsea:exporter>` block dengan vesselName, ownerName,
    homePort, exportedAt, filterDescription
  - `<lsea:summary tripCount="..." haulCount="..." ...>`
  - 1 `<wpt>` per marker
  - 1 `<trk>` per haul, masing-masing dengan
    `<lsea:trip name="...">` + `<lsea:haul colorValue colorHex>`

- [ ] **R5 — 7 hari terakhir**
  Pilih "Jalur Tarikan ✓ Penanda ✗", radio "7 hari terakhir".
  Footer menampilkan ringkasan & estimasi ukuran. Tap Ekspor.
  File hasil hanya berisi haul dari 7 hari terakhir.
  Nama file: `langgeng_sea_jalur_7hari_<today>.gpx`.

- [ ] **R5 — Custom range**
  Radio "Pilih rentang…" → DateRangePicker → pilih 1 minggu
  spesifik. Subtitle menjadi "Kustom — 1 Mei – 7 Mei 2026".
  Ekspor → file hanya berisi haul dalam rentang itu.
  Nama file menyertakan tanggal dari-sampai.

- [ ] **R5 — Trip subset**
  Tap tile "Trip yang Diikutkan" → modal sheet.
  Centang 2 trip spesifik → Apply (2). Footer update.
  Ekspor → file hanya berisi 2 trip itu.
  Nama file: `langgeng_sea_lengkap_2trip_<today>.gpx`.

- [ ] **R5 — Kategori penanda**
  Uncheck "Karang/Bahaya" dan "Lainnya" (sisakan Produktif + Pelabuhan).
  Ekspor → file `<wpt>` hanya berisi marker kategori produktif & port.

- [ ] **R5 — Filter zero-result disabled**
  Uncheck Jalur DAN Penanda.
  Tombol Ekspor disabled, helper text muncul:
  "Pilih minimal satu konten untuk diekspor."

- [ ] **R5 — Date range tanpa data → disabled**
  Pilih "7 hari terakhir" pada akun yang trip terakhirnya 30 hari
  lalu. Footer menampilkan "0 tarikan, 0 penanda". Tombol disabled,
  helper text "Tidak ada data yang cocok dengan filter ini."

## Per-trip share (R6)

- [ ] **R6 — Per-trip GPX dapat metadata penuh**
  Riwayat → buka detail trip → Bagikan.
  Pilih GPX Universal. Tap Bagikan Sekarang.
  Buka file di Notepad: `<lsea:exporter><lsea:vesselName>...` muncul
  (bukan placeholder "Nelayan"/"Kapal").

- [ ] **R6 — Toggle penanda**
  Di sheet Bagikan trip, switch "Sertakan Penanda" default ON.
  Test OFF → file hasil tidak punya `<wpt>` sama sekali, hanya
  `<trk>` haul-haul dari trip tersebut.

## Compatibility (NFR)

- [ ] **GPX universal — Google Earth**
  Buka file ekspor di Google Earth (web atau Pro).
  Tracks + waypoints terlihat, label nama haul/marker tampil.

- [ ] **GPX universal — OsmAnd**
  Buka file di OsmAnd Android.
  Polyline + marker pin tampil di peta dengan benar.

- [ ] **Locale Bahasa Indonesia**
  Semua label di ExportScreen, ExportSheet, dan settings tile
  pakai Bahasa Indonesia (tidak campur Inggris).

## Performance

- [ ] **Ekspor besar < 5 detik**
  Akun dengan 10+ trip × 50+ haul × 500+ point + 100+ marker.
  Tap Ekspor & Bagikan → progress sheet → file selesai dalam
  < 5 detik di Redmi Note 10 Pro.

## Sandbox-side verification (sudah lulus)

- [x] `dart test app/test/features/export_import/export_filter_test.dart`
  — 30+ asserts ExportFilter & DateRange behaviour.
- [x] `dart test app/test/features/export_import/gpx_exporter_test.dart`
  — backward-compat output shape.
- [x] `dart test app/test/features/export_import/gpx_exporter_filter_test.dart`
  — 12 case `<lsea:exporter>` / `<lsea:summary>` / filter axes /
  color encoding / zero-result.
- [x] `dart test app/test/features/tracking/tracking_controller_test.dart`
  — orphan resume → finalize.
- [x] `python3 .kiro/scripts/gpx_smoketest.py` — 5 case GPX shape
  yang setara dengan exportFiltered Dart.
