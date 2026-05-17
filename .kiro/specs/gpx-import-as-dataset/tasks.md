# Tasks — PR #33 GPX Import as Dataset

> Eksekusi atas-ke-bawah. Setiap phase = 1 commit. Phase 2 (schema)
> paling kritis — wajib lulus migration test sebelum commit.

## Pre-flight

- [x] **0.1** Branch `feat/gpx-import-as-dataset` dari `origin/main`.
- [ ] **0.2** Spec docs di `.kiro/specs/gpx-import-as-dataset/` —
  commit pertama planning-only.
- [ ] **0.3** Buat PR draft #33 ke `main`.

---

## Phase 1 — Domain entity ImportedDataset

- [ ] **1.1** Buat
  `app/lib/features/export_import/domain/entities/imported_dataset.dart`
  per design.md §1. Entity immutable dengan `copyWith`, `==`,
  `hashCode`.

- [ ] **1.2** Test
  `app/test/features/export_import/imported_dataset_test.dart`:
  - `displayLabel` dengan vesselName non-null + null
  - `isEmpty` true saat semua counter 0
  - `copyWith` round-trip identity

- [ ] **1.3** Commit: `feat(import): add ImportedDataset entity`

---

## Phase 2 — Schema bump v9 → v10

- [ ] **2.1** Update `tables.dart`:
  - Tambah `ImportedDatasetsTable` class
  - 3 kolom `dataset_id` di `Markers`, `Trips`, `Hauls` (FK CASCADE)

- [ ] **2.2** Update `app_database.dart`:
  - `schemaVersion` = 10
  - `tables: [..., ImportedDatasetsTable]`
  - `daos: [..., ImportedDatasetDao]`
  - `onUpgrade` block `if (from < 10)` → createTable + 3 addColumn
  - `onCreate` jangan lupa create new table juga

- [ ] **2.3** Buat
  `app/lib/data/database/daos/imported_dataset_dao.dart` minimal
  (CRUD + watchAll + raw SQL recount). Drift codegen akan generate
  `_$ImportedDatasetDaoMixin`.

- [ ] **2.4** Test `migration_test.dart` grup baru "v9 → v10":
  - `imported_datasets` table exists
  - 3 kolom `dataset_id` exists
  - FK CASCADE: insert dataset row, insert marker dengan
    `dataset_id`, delete dataset → marker auto-deleted
  - Existing rows tetap query-able (NULL OK)

- [ ] **2.5** Commit: `feat(db): imported_datasets table + dataset_id FK (v9 → v10)`

---

## Phase 3 — Repositories

- [ ] **3.1** Buat
  `app/lib/features/export_import/data/imported_dataset_repository.dart`
  per design.md §3. Method: `create`, `getAll`, `watchAll`,
  `setVisible`, `delete`, `recountChildren`, `autoCleanupIfEmpty`.

- [ ] **3.2** Riverpod provider
  `importedDatasetRepositoryProvider` + `importedDatasetsProvider`
  (StreamProvider) + `visibleDatasetIdsProvider`.

- [ ] **3.3** Update `marker_repository.dart`:
  - `getAll({Set<String>? visibleDatasetIds})`
  - `getOwnOnly()`, `getByDataset(datasetId)`
  - `createForDataset({required datasetId, ...})`
  - `update(marker)` throw kalau `marker.datasetId != null`

- [ ] **3.4** Update `trip_repository.dart` analog.

- [ ] **3.5** Update `haul_repository.dart` analog.

- [ ] **3.6** Update `track_point_repository.dart`:
  - `appendImportedPoint({haulId, lat, lon, timestamp, ...})` —
    skip accuracy gate karena data dari file luar.

- [ ] **3.7** Test
  `imported_dataset_repository_test.dart`:
  - CRUD round-trip
  - Cascade delete: delete dataset → marker rows auto-removed
  - Recount logic
  - `autoCleanupIfEmpty` triggers delete saat counter semua 0

- [ ] **3.8** Commit: `feat(import): ImportedDatasetRepository + dataset filtering in existing repos`

---

## Phase 4 — GpxImporter overhaul

- [ ] **4.1** Update
  `app/lib/features/marker/domain/entities/marker.dart`:
  tambah static `MarkerCategory.fromGpxValue(String?)` per
  design.md §4.

- [ ] **4.2** Refactor `gpx_importer.dart`:
  - `_PendingWaypoint` tambah `MarkerCategory category`
  - `_PendingTrack` tambah `tripName`, `tripColorValue`,
    `haulName`, `haulColorValue`
  - `GpxImportPreview` tambah `fileName`, `exporterName`,
    `vesselName`, `exportedAt`
  - `parse()`: cari `<extensions><lsea:exporter>` di
    `<metadata>`, `<extensions><lsea:marker>` di `<wpt>`,
    `<extensions><lsea:trip>` + `<extensions><lsea:haul>` di
    `<trk>`. Robust kalau extension absent.
  - `import()`: buat dataset row → insert markers + tracks
    dengan `dataset_id`. Group tracks by tripName.

- [ ] **4.3** Test `gpx_importer_v2_test.dart`:
  - Golden GPX dengan `<lsea:marker category="produktif">` →
    waypoint kategori `productive`
  - Golden GPX tanpa extension → waypoint kategori `other`
  - Golden GPX dengan `<lsea:trip>` + `<lsea:haul>` → Trip + Haul
    rows dengan colorValue match
  - Golden GPX dengan tracks tanpa `<lsea:trip>` → fallback
    Trip name "Impor: {filename}"

- [ ] **4.4** Test `gpx_roundtrip_test.dart`:
  1. Generate trip + haul + trackpoint + marker dummy
  2. Call `GpxExporter.exportFiltered(...)` → string GPX
  3. Call `GpxImporter.parse + import(string)` ke fresh DB
  4. Assert marker count match, kategori match, colorValue match,
     trip name match.

- [ ] **4.5** Commit: `feat(import): parse lsea extensions, persist with dataset_id`

---

## Phase 5 — ImportedDatasetsScreen

- [ ] **5.1** Buat
  `app/lib/features/export_import/presentation/imported_datasets_screen.dart`
  per design.md §5. Watch `importedDatasetsProvider` stream.

- [ ] **5.2** Per item card: checkbox `visible`, header file_name,
  subtitle exporter info, counter, tombol delete dengan confirm
  dialog.

- [ ] **5.3** Empty state.

- [ ] **5.4** Tambah route `/imported-datasets` di
  `app_router.dart`.

- [ ] **5.5** Tambah `AppRoutes.importedDatasets` di constants.

- [ ] **5.6** Commit: `feat(import): ImportedDatasetsScreen`

---

## Phase 6 — Settings tile

- [ ] **6.1** Update `settings_screen.dart`:
  - Tile baru "Kelola Data Impor" setelah "Impor Data (GPX)"
  - Subtitle dinamis: `"{count} dataset diimpor"`
  - Watch `importedDatasetsProvider` untuk count

- [ ] **6.2** Commit: `feat(settings): tile Kelola Data Impor`

---

## Phase 7 — MapScreen overlay filter section

- [ ] **7.1** Lokalisasi area kontrol overlay di MapScreen
  (tempat ada toggle markers / history). Tambah section
  "Data Impor" kalau dataset list non-empty.

- [ ] **7.2** Per dataset: checkbox + label file_name. Tap
  toggle `visible` flag via repository.

- [ ] **7.3** Update `markersProvider` di MapScreen filter pakai
  `visibleDatasetIdsProvider` + `dataset_id IS NULL`.

- [ ] **7.4** Update `historyOverlayProvider` analog.

- [ ] **7.5** Commit: `feat(map): per-dataset visibility checkbox in overlay`

---

## Phase 8 — Riwayat badge + edit guard

- [ ] **8.1** Update `history_screen.dart` trip card:
  - Render badge "Impor" kalau `trip.datasetId != null`

- [ ] **8.2** Update `trip_detail_screen.dart`:
  - Tombol Edit disabled kalau imported
  - Tombol Hapus tetap aktif
  - Setelah delete sukses, panggil
    `recountChildren + autoCleanupIfEmpty` di dataset repo

- [ ] **8.3** Commit: `feat(history): badge + guard for imported trips`

---

## Phase 9 — MarkersListScreen badge + filter

- [ ] **9.1** Update `markers_list_screen.dart`:
  - Tile marker tambah badge kalau imported
  - Dropdown filter Sumber: Semua / Saya / Per Dataset
  - Tombol Edit di marker tile disabled kalau imported
  - Tombol Hapus tetap aktif + auto-cleanup hook

- [ ] **9.2** Commit: `feat(markers): badge + source filter for imported markers`

---

## Phase 10 — Dashboard toggle

- [ ] **10.1** Update `dashboard_screen.dart`:
  - Header tambah `SwitchListTile` "Sertakan data impor"
  - State load dari SharedPreferences `dashboard_include_imported_v1`
  - Pass flag ke `dashboardStatsProvider` (refactor kalau perlu)

- [ ] **10.2** Update `dashboard_stats_provider.dart`:
  - Parameter family `includeImported: bool`
  - Filter query: `dataset_id IS NULL` saat false

- [ ] **10.3** Commit: `feat(dashboard): toggle Sertakan data impor`

---

## Phase 11 — Manual verification + push + PR final

- [ ] **11.1** Buat
  `.kiro/specs/gpx-import-as-dataset/manual-verification.md`
  dengan checklist 10 case sesuai R1-R10.

- [ ] **11.2** `git push origin feat/gpx-import-as-dataset`

- [ ] **11.3** Update PR #33 dari draft ke ready-for-review.

- [ ] **11.4** Tunggu CI lulus.

---

## Estimasi

- Phase 1: 30 menit
- Phase 2: 1.5 jam (schema + migration test paling kritis)
- Phase 3: 2 jam (4 repository changes)
- Phase 4: 2 jam (parser + roundtrip test)
- Phase 5: 1 jam (Dataset Manager screen)
- Phase 6: 30 menit (Settings tile)
- Phase 7: 1.5 jam (MapScreen filter — refactor provider)
- Phase 8: 1 jam (Riwayat badge + guard)
- Phase 9: 1 jam (MarkersList badge + filter)
- Phase 10: 1 jam (Dashboard toggle + provider refactor)
- Phase 11: 30 menit

Total ≈ 12.5 jam dev. Karena scope besar, bisa di-split jadi 2-3
sub-PR kalau review jadi terlalu banyak.

---

## Catatan untuk pelanjut konteks

1. **Phase 2 (schema) wajib selesai sebelum Phase 3+**. Migration
   test wajib lulus, jangan commit kalau migration corrupt data
   existing user.

2. **Phase 3 ada banyak repository changes** — ada potensi breaking
   call site yang sudah pakai `getAll()` tanpa parameter. Audit
   sebelum commit.

3. **Phase 4 (importer) paling rentan bug** — XML parsing edge
   case (extension prefix berbeda, namespace, malformed). Tambah
   defensive try-catch di parse loop, fallback ke "skip element"
   bukan throw.

4. **Phase 7 (MapScreen filter)** butuh refactor minor di
   `historyOverlayProvider` dan `markersProvider` supaya bisa
   accept `Set<String>? visibleDatasetIds`. Cek dulu signature
   provider yang ada sebelum commit.

5. **Phase 10 (Dashboard)** — kalau `dashboardStatsProvider` saat ini
   value provider, refactor ke family provider. Kalau StreamProvider,
   pakai `.family<T, bool>`.

6. **Roundtrip test (Phase 4 task 4.4)** adalah lockdown utama —
   pastikan ekspor PR #27 + import PR #33 = lossless. Kalau test
   ini gagal, biasanya parse extension belum tepat.

7. **Auto-cleanup empty dataset (R9)** — pastikan dipanggil di
   semua delete path: marker delete, trip delete, haul delete
   (kalau ada UI hapus haul individual). Kalau lupa di salah satu
   path, dataset row sisa walau child kosong.

8. **Drift `addColumn` dengan FK** — Drift di-generate dengan
   reference. Tapi `m.addColumn` di Drift saat ini tidak
   support FK constraint langsung (FK harus di create_all). Kalau
   migration test gagal karena FK, fallback strategy: addColumn
   tanpa FK + tambah index manual via raw SQL. Cek docs Drift
   migration kalau bermasalah.
