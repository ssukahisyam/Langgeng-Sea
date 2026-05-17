# Requirements — PR #33 GPX Import as Dataset

> Format: EARS (Event–Action–Result–State) · Bahasa Indonesia.
> Konteks: import GPX saat ini lossy (kategori marker hilang, tracks
> tidak di-import sama sekali) dan tidak punya konsep "asal data".
> User butuh import yang lossless dari ekspor PR #27, plus kemampuan
> mengelola banyak file GPX impor (toggle visibility, hapus utuh).

## Latar belakang

Status `gpx_importer.dart` saat ini:

| Field di file ekspor PR #27 | Di-import? |
|---|---|
| `<wpt lat lon>` + `<name>` + `<desc>` | Ya |
| `<wpt><extensions><lsea:marker category>` | TIDAK — semua jadi `MarkerCategory.other` |
| `<trk>` + `<trkseg>` + `<trkpt>` | Parse only — TIDAK di-import ke DB |
| `<trk><lsea:trip>` / `<trk><lsea:haul>` | TIDAK |
| `<metadata><lsea:exporter>` | TIDAK |

User mengeluhkan: "import sekarang sudah support fitur ekspor lengkap
PR #27?" — jawaban: belum.

Tambahan dari user: "kalau user import lebih dari 1 file GPX, di app
kita bisa memilih menampilkan semuanya atau file tertentu saja agar
tidak penuh mapnya?" — perlu konsep **dataset** dengan toggle
visibility per file.

Tambahan dari user untuk imported trips di Riwayat: "tampil di Riwayat
dengan badge Impor, **bisa di-delete cuma tidak bisa di-edit**".

## Requirements

### R1 — Import GPX jadi ImportedDataset row

**Saat** user pilih file GPX dan tap Impor di ImportScreen,
**aplikasi** harus membuat satu row `ImportedDataset` dengan
metadata file (nama file, exporter info) dan menyimpan semua
marker/trip/haul/trackpoint dengan FK ke dataset itu,
**sehingga** semua item dari satu file GPX bisa di-track sebagai
satu kesatuan dan bisa dihapus utuh atau di-toggle visibility.

**Acceptance criteria:**
- AC1: Tabel `imported_datasets` punya kolom `id`, `file_name`,
  `exporter_name`, `vessel_name`, `exported_at`, `imported_at`,
  `visible`, `marker_count`, `trip_count`, `haul_count`.
- AC2: 3 tabel existing (`markers`, `trips`, `hauls`) punya kolom
  baru `dataset_id TEXT NULL` dengan FK ke `imported_datasets.id`
  ON DELETE CASCADE.
- AC3: Schema bump v9 → v10 dengan migrasi yang aman:
  - `addColumn dataset_id` ke 3 tabel existing (default NULL =
    "data sendiri")
  - `createTable imported_datasets`
  - Migration test verify row existing tidak corrupt.
- AC4: Saat import, `ImportedDataset.id` di-generate dengan UUID
  (atau timestamp + filename hash), `imported_at` = now,
  `visible = true` default.
- AC5: `marker_count` / `trip_count` / `haul_count` denormalized
  saat import; di-update kalau user delete child row individual.

### R2 — Parse marker dengan kategori yang benar

**Saat** importer membaca `<wpt>` dengan
`<extensions><lsea:marker category="produktif">`,
**aplikasi** harus map nilai `category` ke `MarkerCategory` enum
yang benar dan menyimpan marker dengan kategori yang match,
**sehingga** roundtrip ekspor → import lossless untuk kategori.

**Acceptance criteria:**
- AC1: `MarkerCategory.fromGpxValue(String?)` static helper:
  - `'produktif'` → `MarkerCategory.productive`
  - `'pelabuhan'` → `MarkerCategory.port`
  - `'bahaya'` → `MarkerCategory.hazard`
  - `'lainnya'` atau null atau tidak dikenal → `MarkerCategory.other`
- AC2: Marker tanpa `<lsea:marker>` extension (file dari aplikasi
  GPX lain seperti OsmAnd) tetap di-import sebagai
  `MarkerCategory.other`.
- AC3: Marker imported simpan `dataset_id`, `name`, `category`,
  `latitude`, `longitude`, `notes` (dari `<desc>`).

### R3 — Parse tracks jadi Trip + Haul + TrackPoint

**Saat** importer membaca `<trk>` dengan
`<extensions><lsea:trip>` dan `<extensions><lsea:haul>`,
**aplikasi** harus membuat 1 Trip row + N Haul row + M TrackPoint
row di DB, semua dengan FK `dataset_id`, dan mempertahankan warna
yang di-encode di `colorValue` extension,
**sehingga** map dapat render polyline dengan warna yang sama
seperti di file asal.

**Acceptance criteria:**
- AC1: Group `<trk>` yang punya `<lsea:trip name>` sama → 1 Trip
  row dengan name dari extension.
- AC2: Per `<trk>`, parse `<lsea:haul colorValue>` → simpan
  `colorValue` di Haul row (kolom existing dari M5).
- AC3: Per `<trkpt>`, parse `lat` `lon` `<time>` → TrackPoint row.
- AC4: Trip row tanpa `<lsea:trip>` extension (file dari aplikasi
  lain) buat fallback Trip dengan name "Impor: {filename}".
- AC5: Trip row hasil import set `name` = nama dari extension
  (mis. "Trip Pak Hasan 25 Mei") atau fallback "Impor: {filename}".
- AC6: Stats agregat (distance, duration, swept_area, avg speed,
  avg heading) di-recompute dari trkpt saat import — bukan
  di-trust dari extension. Ini supaya data konsisten dengan
  trip user-created.

### R4 — Dataset Manager screen

**Sebagai** nelayan,
**saya bisa** membuka layar Kelola Data Impor dari Settings dan
melihat list semua file GPX yang sudah di-impor dengan tombol
toggle visibility dan tombol hapus per dataset,
**sehingga** saya dapat mengatur tampilan peta tanpa harus
hapus item satu per satu.

**Acceptance criteria:**
- AC1: Route baru `/imported-datasets` terdaftar di `app_router.dart`.
- AC2: Tile baru "Kelola Data Impor" di Settings, di bawah tile
  "Impor Data (GPX)", dengan counter "{n} dataset diimpor".
- AC3: Layar `ImportedDatasetsScreen` menampilkan list card per
  dataset:
  - Header: nama file
  - Subtitle: vessel name + ownerName + exported_at (kalau ada)
  - Counter: "{m} marker · {t} trip · {h} tarikan"
  - Imported at timestamp
  - Checkbox visible (kiri atas)
  - Tombol Hapus (icon delete di kanan)
- AC4: Tap checkbox toggle `visible` flag (DB write). Map otomatis
  refresh untuk hide/show item-item dari dataset itu.
- AC5: Tap Hapus tampilkan dialog konfirmasi "Hapus dataset {nama}?
  Akan menghapus {n} marker, {m} trip, {h} tarikan." dengan tombol
  Batal + Hapus.
- AC6: Konfirmasi hapus → cascade delete (FK ON DELETE CASCADE) →
  refresh list.

### R5 — MapScreen filter per dataset

**Saat** user buka MapScreen overlay panel kontrol,
**aplikasi** harus menampilkan checkbox per dataset yang sudah
di-impor di samping toggle "Penanda Saya",
**sehingga** user dapat dengan cepat mengaktifkan/menonaktifkan
data dari file tertentu langsung dari layar peta.

**Acceptance criteria:**
- AC1: MapScreen overlay panel (tempat ada toggle "Penanda" / "Jejak
  Riwayat") tambah section "Data Impor".
- AC2: Per dataset, satu checkbox dengan label `{file_name}`.
- AC3: Tap checkbox toggle `visible` flag di DB (sama provider yang
  dipakai di Dataset Manager).
- AC4: Map polyline + marker auto-refresh berdasarkan visibility.
- AC5: Kalau tidak ada dataset diimpor, section "Data Impor" tidak
  rendered (clean UI).
- AC6: Visibility flag persist antar session.

### R6 — Riwayat tampilkan imported trips dengan badge

**Saat** user buka tab Riwayat dan ada trip yang di-import dari GPX,
**aplikasi** harus menampilkan trip itu dalam list dengan badge
visual "Impor" supaya user tahu asalnya, dan mengizinkan delete
tapi block edit,
**sehingga** user dapat menghapus item yang mereka tidak butuhkan
lagi tanpa risiko mengubah data dari sumber luar.

**Acceptance criteria:**
- AC1: Trip card di Riwayat menampilkan badge kecil bertuliskan
  "Impor" (warna sekunder, pill shape) di samping nama trip.
- AC2: Trip detail screen tombol Edit di-disable + tooltip
  "Trip dari data impor tidak bisa diedit".
- AC3: Trip detail screen tombol Hapus tetap aktif. Konfirmasi
  hapus → delete trip + cascade delete haul + trackpoint.
- AC4: Marker info sheet untuk imported markers: tombol Edit
  disabled, tombol Hapus tetap aktif (saran: hapus per item juga
  OK, tidak perlu hapus dataset utuh).
- AC5: Delete imported trip terakhir dari sebuah dataset yang
  juga sudah tidak punya marker tersisa: dataset row otomatis
  dihapus (auto-cleanup).

### R7 — MarkersListScreen badge + filter

**Saat** user buka layar Kelola Penanda,
**aplikasi** harus menampilkan badge "Impor" pada marker yang
berasal dari dataset, dan menyediakan filter Sumber: Semua / Saya
Saja / Per Dataset di header,
**sehingga** user dapat mencari marker spesifik dengan cepat.

**Acceptance criteria:**
- AC1: Marker tile tampilkan badge kecil "Impor" + nama dataset
  pendek (kalau ada lebih dari 1 dataset).
- AC2: Dropdown filter Sumber di app bar atau di area filter
  existing.
- AC3: Tombol Edit di-disable untuk imported markers; tombol
  Hapus tetap aktif (sama pola dengan Trip).

### R8 — Dashboard toggle "Sertakan data impor"

**Saat** user buka Dashboard,
**aplikasi** harus menampilkan toggle "Sertakan data impor" di
header (default off), dan kalau toggle aktif statistik
(total distance, hari berlayar, dll) menghitung juga data dari
imported tracks,
**sehingga** user dapat mengatur agar progress tracking pribadi
mereka tidak tercampur dengan data orang lain by default.

**Acceptance criteria:**
- AC1: Default OFF di first install — Dashboard hanya hitung
  data milik user (`dataset_id IS NULL`).
- AC2: Toggle persist antar session (SharedPreferences atau
  app_settings table).
- AC3: Saat toggle ON, query stats include `dataset_id IS NOT
  NULL` rows juga.
- AC4: Label di Dashboard saat toggle ON: tambah subtitle kecil
  "Termasuk {n} dataset impor".

### R9 — Auto-cleanup empty dataset

**Saat** user delete child terakhir (marker atau trip) dari sebuah
dataset,
**aplikasi** harus automatic delete row `ImportedDataset` itu juga,
**sehingga** Dataset Manager tidak menumpuk dataset kosong.

**Acceptance criteria:**
- AC1: Setelah delete operation di marker / trip repository,
  panggil cleanup helper yang cek apakah dataset masih punya child.
- AC2: Kalau `marker_count = 0 AND trip_count = 0 AND haul_count = 0`,
  delete dataset row.
- AC3: Tradeoff: kalau user hapus semua child manual lalu menyesal,
  dataset hilang. Tidak ada undo. Konfirmasi: dataset row hanya
  metadata, file asli tetap di filesystem (kalau user simpan).

### R10 — Roundtrip lossless export PR #27 → import

**Saat** user export GPX dengan filter lengkap (Phase 4 PR #27),
lalu import file itu di device yang sama (atau device lain),
**aplikasi** harus mempertahankan semua field yang di-encode di
ekspor: kategori marker, warna trip & haul, nama tarikan, info
exporter,
**sehingga** transfer data antar nelayan tidak kehilangan
informasi.

**Acceptance criteria:**
- AC1: Test integration `gpx_roundtrip_test.dart`:
  1. Buat trip + haul + trackpoint + marker dummy
  2. Export ke string GPX (panggil `GpxExporter.exportFiltered`)
  3. Import string itu (panggil `GpxImporter.parse + import`)
  4. Verify count match: marker = original, trip = original, dst.
  5. Verify field per item: kategori marker match, colorValue match.
- AC2: Test pakai `MarkerCategory.values` semua kategori.
- AC3: Test untuk file dari sumber lain (OsmAnd minimal track-only):
  parse berhasil, tracks masuk sebagai Trip "Impor: {filename}",
  marker semua kategori `other`.

## Correctness properties

- **P1 — FK constraint enforced**: cascade delete saat
  `ImportedDataset` row hapus → semua child di-hapus juga
  (verify lewat raw SQL test).
- **P2 — Visibility filter race-safe**: kalau user toggle visible
  bersamaan dengan map render, render selalu pakai snapshot
  konsisten (Drift `watchSingle` stream sudah handle ini).
- **P3 — Import idempotent kalau file dipilih ulang**: kalau user
  pilih file yang sama dua kali, dataset baru dibuat (tidak
  merge). Tradeoff: bisa duplikat. Bisa di-revisit dengan hash
  detection nanti.
- **P4 — Counter denorm konsisten**: setiap delete child trigger
  recount di dataset row (atau pakai SQL trigger).

## Non-functional

- **NFR1 — Performance**: import file besar (10k trkpt) selesai
  dalam < 30 detik di device target.
- **NFR2 — Memory**: parse XML stream-able kalau memungkinkan
  (`xml` package punya `parseEvents` API). Optional optimasi.
- **NFR3 — Migration safe**: schema bump v10 wajib reversible test
  (existing trip user tetap di-load benar dengan `dataset_id IS NULL`).
- **NFR4 — A11y**: badge "Impor" punya `Semantics.label` "Trip dari
  file impor", checkbox visibility di Dataset Manager dapat di-fokus.
- **NFR5 — String 100% Bahasa Indonesia**.
