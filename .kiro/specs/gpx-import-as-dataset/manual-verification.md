# Manual Verification Checklist — PR #33 GPX Import as Dataset

> Sandbox tidak punya Flutter toolchain. Pure-Dart unit test
> (`imported_dataset_test.dart`, `gpx_importer_v2_test.dart`,
> `migration_test.dart` v9→v10) sudah lulus. Daftar di bawah harus
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

build_runner WAJIB karena schema bump v9 → v10: `imported_datasets`
table baru + 3 kolom `dataset_id` di markers/trips/hauls.

## Migration safety (R7)

- [ ] **Existing user upgrade v9 → v10**
  Pakai user yang sudah pernah install build sebelum PR #33 (schema
  v9). Tap **Update**, jangan reinstall fresh. Setelah upgrade
  selesai, buka aplikasi:
  - Riwayat: trip lama tetap ada, tidak ada badge "Impor"
  - MarkersList: marker lama tetap ada, tidak ada badge "Impor"
  - Dashboard: stats sama persis dengan sebelum upgrade
  - MapScreen: polyline + marker user-created tetap render normal
  - Settings → Kelola Data Impor: "Belum ada data impor"

## Import lossless dari ekspor PR #27 (R10)

- [ ] **Roundtrip ekspor → import**
  Export GPX dari Settings → Ekspor Data dengan opsi default (Jalur ✓
  Penanda ✓, semua waktu, semua kategori). Simpan file lalu import
  kembali via Settings → Impor Data.
  - Preview screen menampilkan exporter info (vessel + ownerName +
    homePort)
  - Counter waypoint per kategori match dengan jumlah marker original
  - Tap Impor → dataset row muncul di Settings → Kelola Data Impor
  - MapScreen menampilkan polyline + marker dari import (warna match)
  - Trip imported di Riwayat punya badge "Impor"
  - Marker imported di MarkersList punya badge "Impor"

## Import file dari aplikasi GPX lain (R2 fallback)

- [ ] **Import file OsmAnd / generic GPX**
  Download file `.gpx` dari OsmAnd atau aplikasi GPX lain (yang
  tidak punya `<lsea:*>` extensions). Import via Settings → Impor
  Data.
  - Preview: exporter info kosong (tidak ada vessel name)
  - Waypoint count = jumlah `<wpt>`, semua kategori "Lainnya"
  - Track count = jumlah `<trk>`
  - Tap Impor → dataset dibuat dengan vessel/exporter null
  - Trip baru dibuat dengan name "Impor: {filename}"

## Dataset Manager screen (R4)

- [ ] **R4 AC1 — Buka layar dari Settings**
  Settings → tile **Kelola Data Impor** → tap. Layar muncul.

- [ ] **R4 AC3 — List card per dataset**
  Setiap card menampilkan:
  - Nama file (mis. "Trip Pak Hasan 25 Mei.gpx")
  - Subtitle: vessel + exporter + exportedAt (kalau ada)
  - Counter chip: marker, trip, tarikan
  - Switch toggle visibility (default ON)
  - Tombol Hapus

- [ ] **R4 AC4 — Toggle visibility live**
  Tap Switch off → kembali ke MapScreen → polyline + marker dari
  dataset itu HILANG. Toggle on lagi → muncul kembali.

- [ ] **R4 AC5+AC6 — Hapus dataset cascade**
  Tap tombol Hapus → dialog konfirmasi: "Akan menghapus N marker, M
  trip, K tarikan dari aplikasi. File asli di perangkat Anda tidak
  terhapus."
  Tap Hapus → snackbar "Dataset dihapus." → list card hilang →
  MapScreen tidak menampilkan data dari dataset itu lagi.

## MapScreen overlay filter per dataset (R5)

- [ ] **R5 — Toggle filter dari MapScreen**
  Import 2+ dataset. Buka MapScreen. Di kolom kanan kontrol, ada
  tombol baru dengan icon folder + badge angka (visible count).
  Tap tombol → modal sheet "Filter Data Impor" muncul dengan
  CheckboxListTile per file.

- [ ] **R5 AC2 — Centang per file**
  Centang/uncheck checkbox per dataset. Map polyline + marker
  langsung update sesuai centang.

- [ ] **R5 — Tampilkan/Sembunyikan Semua**
  Tap **Sembunyikan Semua** → semua dataset off.
  Tap **Tampilkan Semua** → semua dataset on.

- [ ] **R5 AC5 — Tombol self-hide kalau belum ada dataset**
  Hapus semua dataset. Tombol filter di kolom kanan MapScreen
  hilang. Import 1 dataset → tombol muncul kembali.

## Riwayat: badge + edit guard (R6)

- [ ] **R6 AC1 — Badge muncul di trip card**
  Buka tab Riwayat. Trip yang berasal dari import GPX punya badge
  kecil "Impor" (icon download + label) di samping nama trip. Trip
  user-created tidak punya badge.

- [ ] **R6 AC2 — Edit blocked**
  Buka detail trip imported → tap menu opsi → tap "Ubah Nama".
  Snackbar "Trip dari data impor tidak bisa diedit. Hapus dataset
  utuh dari Kelola Data Impor." muncul. RenameDialog TIDAK terbuka.

- [ ] **R6 AC3 — Delete enabled + auto-cleanup**
  Detail trip imported → menu opsi → Hapus → konfirmasi.
  Trip terhapus, kembali ke Riwayat list. Kalau trip itu adalah
  child terakhir dari dataset (tidak ada trip lain + marker = 0),
  Settings → Kelola Data Impor menunjukkan dataset row otomatis
  hilang (R9 auto-cleanup).

## MarkersListScreen: badge + edit guard (R7)

- [ ] **Badge muncul di marker tile**
  Buka Settings → Kelola Penanda. Marker imported punya badge kecil
  "Impor" di samping nama. Marker user-created tidak.

- [ ] **Ubah kategori blocked**
  Marker imported → tap menu titik tiga → "Ubah kategori".
  Snackbar "Penanda dari data impor tidak bisa diedit..." muncul.
  EditMarkerCategorySheet TIDAK terbuka.

- [ ] **Delete enabled + auto-cleanup**
  Marker imported → menu → Hapus → konfirmasi.
  Marker terhapus. Kalau marker itu adalah child terakhir dataset,
  dataset row auto-cleanup.

## Dashboard toggle (R8)

- [ ] **R8 AC1 — Default off di first install**
  Belum pernah toggle. Dashboard stats hanya menghitung trip user.

- [ ] **R8 — Toggle hidden saat belum ada dataset**
  User yang belum pernah import: tab Dashboard tidak menampilkan
  toggle "Sertakan data impor" (clean UI, tidak ada noise).

- [ ] **R8 AC2 + AC3 — Toggle on**
  Setelah import 1 dataset, buka Dashboard. Toggle "Sertakan data
  impor" muncul (default off). Tap toggle → stats berubah, sekarang
  termasuk imported trip.

- [ ] **R8 AC2 persist** — Tutup app, buka lagi. Toggle masih on.

## Auto-cleanup empty dataset (R9)

- [ ] **R9 AC2 — Cleanup setelah child terakhir dihapus**
  Import file dengan 1 marker + 1 trip + 2 haul.
  Hapus marker → dataset masih ada (counter marker 0 tapi trip 1).
  Hapus trip dari Riwayat → dataset row otomatis hilang dari
  Kelola Data Impor karena semua child = 0.

## Sandbox-side verification (sudah lulus)

- [x] `dart test app/test/features/export_import/imported_dataset_test.dart`
  — 11 case entity helpers (displayLabel, isEmpty, copyWith,
  equality)
- [x] `dart test app/test/features/export_import/gpx_importer_v2_test.dart`
  — 7 case parse + import roundtrip:
  - Parse exporter metadata
  - Parse marker kategori dari `<lsea:marker>`
  - Parse track + lsea:trip + lsea:haul extensions
  - Parse OsmAnd-style file (no extensions, fallback)
  - Import PR #27 file → dataset + 3 markers + 1 trip + 2 hauls + 5 points
  - Import OsmAnd-style → fallback Trip "Impor: {filename}"
- [x] `dart test app/test/data/database/migration_test.dart`
  — v9 → v10: `imported_datasets` table exists, 3 kolom
  `dataset_id` exists, legacy rows default NULL, dataset table
  writable + default values benar.
