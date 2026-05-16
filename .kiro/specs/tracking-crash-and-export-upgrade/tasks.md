# Tasks — PR #27 Implementation Order

> **Untuk pelanjut konteks**: ini bisa dijalankan dari atas ke bawah,
> berurutan. Setiap task punya "definition of done" yang konkret.
> Setiap "phase" di-commit terpisah supaya easy to review per area.

## Pre-flight

- [ ] **0.1** Pastikan PR #26 (`feat/integrate-pr23-pr24`) sudah
  di-merge ke `main`. Kalau belum, koordinasi dengan user dulu —
  PR #27 ini bergantung sebagiannya pada `gpx_exporter.dart` post-
  merge yang sudah ada `XmlBuilder`.
- [ ] **0.2** Branch `feat/tracking-crash-and-export-upgrade-pr27`
  sudah ada (sudah di-create di langkah planning). Rebase ke main
  terbaru kalau ada update di main sejak branch dibuat.

---

## Phase 1 — Crash Fix Tracking (R1, R2)

> Goal: tracking jalan normal di Android 14+ pasca permission battery
> dialog, dan resume tidak crash.

- [ ] **1.1** Refactor `flutter_background_tracking_service.dart`:
  - Pisahkan permission battery flow ke method privat
    `_maybeRequestBatteryOpt()`. Method ini idempotent (cek status
    dulu, return early kalau sudah granted).
  - Tambah parameter `bool skipBatteryPermission = false` ke
    `start()`. Kalau true, skip method di atas.
  - Sebelum panggil `_service.startService()`, cek
    `await _service.isRunning()` — kalau true, panggil
    `invoke('stopService')` + delay 500ms dulu.
  - Pindahkan `_maybeRequestBatteryOpt()` SETELAH `startService()`
    sukses, dengan `unawaited(Future.delayed(2s, () =>
    _maybeRequestBatteryOpt()))` supaya tidak race dengan
    notification post timeout di Android 14+.
  - Wrap permission `request()` dengan timeout 10 detik
    (`.timeout(...)` dengan onTimeout return PermissionStatus.denied)
    supaya kalau dialog stuck tidak ngegantung.

  **Definition of done:** unit test `_maybeRequestBatteryOpt` lewat
  fake `PermissionWrapper` lulus; manual test di HP user (lihat 5.1).

- [ ] **1.2** Update `tracking_controller.dart` `resumeHaul()`:
  - Setelah `_trips.getById(haul.tripId)`, cek null. Kalau null,
    panggil `finalizeRecoveredHaul(haul)` + log warning, jangan
    lempar exception.
  - Saat panggil `_bgService.start(...)` di resume path, kasih
    `skipBatteryPermission: true` (user sebelumnya sudah respond,
    apa pun jawabannya).
  - Tambah test case: `resumeHaul` dengan trip yang sudah dihapus
    → finalize, no throw.

  **Definition of done:** test `tracking_controller_test.dart`
  ditambah case "trip-deleted → finalize", lulus.

- [ ] **1.3** Commit pertama: `fix(tracking): defer battery permission to background, guard resume path`

---

## Phase 2 — Settings Tile untuk Battery (R3)

- [ ] **2.1** Buat file
  `app/lib/features/settings/presentation/widgets/battery_optimization_tile.dart`:
  - `ConsumerStatefulWidget` (perlu lifecycle observer).
  - State: `PermissionStatus _status` (auto-refresh on resume).
  - Implements `WidgetsBindingObserver`:
    `didChangeAppLifecycleState` → kalau `AppLifecycleState.resumed`,
    re-check status.
  - Render: leading icon battery hijau (granted) / abu (denied) /
    merah (permanentlyDenied), title "Akurasi Saat Layar Mati",
    subtitle dinamis.
  - On tap: granted → `openAppSettings()`, else → `request()` +
    setState.
- [ ] **2.2** Tambah tile di `settings_screen.dart` di bagian
  "Pengaturan Lanjutan" (atau bikin section baru kalau belum ada).
  Letakkan setelah tile "Kelola Penanda".
- [ ] **2.3** Commit: `feat(settings): tile to manage battery optimization permission`

---

## Phase 3 — ExportFilter & DateRange domain (R5 fundamental)

> Tidak ada UI di phase ini — pure Dart, tested, kemudian di-konsumsi
> oleh GpxExporter & ExportScreen di phase berikutnya.

- [ ] **3.1** Buat
  `app/lib/features/export_import/domain/entities/date_range.dart`:
  - Constructor `const DateRange({required start, required end})`
  - `bool contains(DateTime t)` — `start` inclusive, `end` exclusive
  - factories `last7Days`, `last30Days`, `today`
  - `String describe(Locale)` — id_ID: "7 hari terakhir", "1 Mei – 8 Mei"
- [ ] **3.2** Buat
  `app/lib/features/export_import/domain/entities/export_filter.dart`:
  - Field per design.md §3.1
  - Method `matchesTrip(Trip t)`, `matchesMarker(AppMarker m)`
  - Method `describe()` → string untuk `<lsea:filterDescription>`
  - Method `suggestFileName()` → "langgeng_sea_lengkap_2026-05-16.gpx" dst
  - Override `==`, `hashCode` (penting untuk Riverpod family key)
- [ ] **3.3** Test
  `app/test/features/export_import/export_filter_test.dart`:
  - DateRange.contains boundary (start exact, end-1ms, before, after)
  - matchesTrip with date filter only / trip-id filter only / both
  - matchesMarker with category whitelist
  - suggestFileName for 6 representative kombinasi
  - describe() output untuk 6 representative kombinasi
- [ ] **3.4** Commit: `feat(export): add ExportFilter + DateRange domain entities`

---

## Phase 4 — GpxExporter dukung filter & user profile (R4)

- [ ] **4.1** Update `gpx_exporter.dart`:
  - Tambah signature baru:
    ```dart
    String exportFiltered({
      required ExportFilter filter,
      required UserProfile? exporter,    // null = no exporter block
      required List<Trip> trips,
      required Map<String, List<Haul>> haulsByTripId,
      required Map<String, List<TrackPoint>> pointsByHaulId,
      required List<AppMarker> markers,
    })
    ```
  - Pre-filter di Dart (caller bisa kasih sudah di-filter atau
    sentire — gunakan `filter.matchesTrip` / `matchesMarker`
    sebagai safety net inside).
  - Build `<metadata>` dengan:
    - `<author><name>` = `exporter?.ownerName ?? 'Langgeng Sea'`
    - `<extensions><lsea:exporter>` block kalau exporter non-null:
      `vesselName`, `ownerName`, `homePort`, `exportedAt`,
      `filterDescription`
    - `<extensions><lsea:summary>` block dengan total counts +
      total stats
    - `<bounds>` dari combined points + waypoints
  - Build `<wpt>` per marker yang lewat filter, dengan
    `<extensions><lsea:marker category categoryLabel/>`
  - Build `<trk>` per haul yang lewat filter (loop trips → loop
    hauls dalam trip yang lewat filter):
    - `<name>Tarikan #N: name</name>`
    - `<desc>` = human-readable stats
    - `<extensions>`:
      - `<lsea:trip ...>` (parent trip metadata)
      - `<lsea:haul ...>` (haul stats + colorValue + colorHex)
- [ ] **4.2** Refactor `exportTrip(...)` dan `exportAll(...)`:
  - Convert internal: build `ExportFilter` dari args lama → delegate
    ke `exportFiltered`.
  - Method lama tetap exposed agar code yang sudah ada tidak break.
- [ ] **4.3** Update existing tests
  `gpx_exporter_test.dart` agar tetap lulus (signature tidak
  berubah, behavior identik kecuali ada field baru di output).
- [ ] **4.4** Tambah test baru
  `gpx_exporter_filter_test.dart`:
  - export dengan filter empty → file valid + metadata + 0 trk + 0 wpt
  - export dengan filter date-range last 7 days → trk yang lewat
    saja
  - export dengan filter trip-ids subset → trk yang lewat saja
  - export dengan filter marker category subset → wpt yang lewat saja
  - export dengan UserProfile non-null → `<lsea:exporter>` ada
  - export dengan UserProfile null → `<lsea:exporter>` tidak ada,
    `<author><name>` fallback
  - colorValue di-encode sebagai colorHex di output
  - filterDescription string di metadata cocok dengan
    `filter.describe()`
- [ ] **4.5** Commit: `feat(export): GpxExporter.exportFiltered with full metadata`

---

## Phase 5 — ExportService support filter

- [ ] **5.1** Update `export_service.dart`:
  - Tambah method `exportFiltered({required ExportFilter filter})`
  - Inject `UserProfileRepository` ke constructor.
  - Method lama (`exportTrip` per-trip) tetap exposed, internally
    build filter dengan `tripIds: {tripId}`.
  - Update provider `exportServiceProvider` agar resolve
    `userProfileRepositoryProvider`.
- [ ] **5.2** Buat
  `app/lib/features/export_import/application/export_preview_provider.dart`:
  - `exportPreviewProvider(ExportFilter)` family Future<ExportPreview>
  - `ExportPreview { tripCount, haulCount, pointCount, markerCount, estimatedBytes }`
  - Estimated bytes ≈ 2 KB metadata + 0.4 KB / wpt + 6 KB / haul + 0.18 KB / point
- [ ] **5.3** Update `gpx_sync_service.dart` agar pakai filter "all"
  default (sama hasil dengan sebelumnya, no UI breaking).
- [ ] **5.4** Commit: `feat(export): ExportService accepts ExportFilter, add preview provider`

---

## Phase 6 — ExportScreen UI revisi (R5)

- [ ] **6.1** Buat helper widget
  `widgets/export_filter_section.dart`:
  - Section header dengan icon + title
  - Children dibungkus GlassCard
- [ ] **6.2** Buat
  `widgets/trip_multi_select_sheet.dart`:
  - Modal bottom sheet dengan list trip + checkbox per item.
  - Header: "Pilih semua / Batalkan semua" (toggle).
  - Item: nama trip + ringkasan ("3 tarikan · 12.4 km · 8 Mei").
  - Resolved value: `Set<String>?` (null = "semua dalam rentang").
- [ ] **6.3** Tulis ulang `export_screen.dart`:
  - State: `ExportFilter _filter` (mutable via setState atau
    StateNotifier — pilih StateNotifier supaya provider preview
    auto-refresh).
  - Section 1: Konten (2 checkbox tile besar)
  - Section 2: Rentang tanggal (4 RadioListTile + DateRangePicker)
  - Section 3: Trip yang Diikutkan (tile dengan tombol "Pilih
    trip…" → buka multi-select sheet)
  - Section 4: Kategori penanda (4 ChoiceChip)
  - Footer: ringkasan dari `exportPreviewProvider(_filter)` (loading
    spinner saat compute, lalu count + estimated KB)
  - Tombol Ekspor & Bagikan (disabled kalau preview kosong)
- [ ] **6.4** Update `import_screen.dart` (kalau ada label
  yang perlu update karena alur ekspor jadi lebih lengkap — biasanya
  text saja).
- [ ] **6.5** Commit: `feat(export): ExportScreen with full filter UI`

---

## Phase 7 — Per-trip share path (R6)

- [ ] **7.1** Update `export_sheet.dart` `_handleExport()`:
  - Build `ExportFilter` dengan `tripIds: {widget.trip.id}`,
    `dateRange: null`, `markerCategories: null`,
    `includeTracks: true`, `includeMarkers: true`.
  - Panggil `exportService.exportFiltered(filter)`.
- [ ] **7.2** Update sheet UI: tampilkan ringkasan trip + 1 toggle
  kecil "Sertakan penanda dalam area trip" (default ON).
- [ ] **7.3** Commit: `feat(export): per-trip share uses ExportFilter`

---

## Phase 8 — Wire-up final & polish

- [ ] **8.1** Update `app_router.dart`: tidak ada route baru, cuma
  pastikan `/export` masih route ke ExportScreen yang baru.
- [ ] **8.2** Smoke test via Python script (sandbox-only):
  - Update `.kiro/scripts/gpx_smoketest.py` agar tambah test untuk
    struktur `<lsea:exporter>` + `<lsea:summary>`.
  - Jalankan, pastikan lulus.
- [ ] **8.3** Manual verification list (untuk user):
  ```
  [ ] HP redmi note 10 pro pixelos: tekan MULAI, allow battery → no crash
  [ ] Force-kill app saat tracking → buka lagi → Lanjutkan → no crash
  [ ] Force-kill app saat tracking → buka lagi → Tutup → haul finalized
  [ ] Settings → Akurasi Saat Layar Mati: status update saat back from sysmsetting
  [ ] Settings → Ekspor Data: filter "7 hari" produces correct subset
  [ ] Settings → Ekspor Data: pilih trip subset → file hanya berisi itu
  [ ] Settings → Ekspor Data: hanya kategori Produktif → wpt hanya productive
  [ ] Trip detail → Bagikan: file GPX berisi 1 trip + bounding markers
  [ ] Buka file di Google Earth / OsmAnd → tracks + markers terlihat
  [ ] Buka file di Notepad: ada <lsea:exporter><lsea:vesselName>...
  ```
- [ ] **8.4** Commit terakhir: `chore(qa): smoke-test script + manual checklist for PR27`

---

## Phase 9 — Push & PR

- [ ] **9.1** `git push origin feat/tracking-crash-and-export-upgrade-pr27`
- [ ] **9.2** Buat PR ke `main` dengan description yang reuse
  konten dari `requirements.md` ringkas + checklist manual
  verification dari 8.3.
- [ ] **9.3** Tutup PR #23 dan PR #24 dengan komen "subsumed by
  #26 + #27" kalau belum ditutup user.
- [ ] **9.4** Tunggu user review + manual test di HP, address
  feedback per `/kiro fix` style.

---

## Estimasi waktu

- Phase 1-2: 1-2 jam (crash fix + settings tile)
- Phase 3-5: 2-3 jam (filter domain + GPX upgrade + service)
- Phase 6-7: 2-3 jam (ExportScreen UI + sheet)
- Phase 8-9: 1 jam (smoke test + PR)

Total ≈ 6-9 jam dev time. Karena sandbox tidak punya Flutter
toolchain, smoke testing terbatas ke pure-Dart asserts + Python
mirror untuk struktur XML.

---

## Catatan untuk pelanjut konteks

Kalau Anda mulai dari sini fresh:

1. **Baca `requirements.md` dulu** — paham apa yang user mau, jangan
   skip.
2. **Baca `design.md`** — pahami struktur GPX baru terutama §2.1
   (template output), itu kontrak yang harus tepat.
3. **Mulai dari Phase 1** — crash fix paling kritis dan paling
   simpel. Setelah selesai + commit, user bisa langsung test APK
   sambil kita lanjut phase lain.
4. **Phase 3 (domain) sebelum Phase 4 (exporter)** karena exporter
   pakai domain object.
5. **Phase 4 (exporter) sebelum Phase 5 (service)** karena service
   delegate ke exporter.
6. **Phase 6 (UI) terakhir** karena tergantung semua infrastruktur
   di bawah.

Penting: **jangan lupa test setelah tiap phase**. Sandbox tidak punya
Flutter, tapi pure-Dart unit test bisa di-eyeball dengan Python
script mirror di `.kiro/scripts/`. Kalau bingung struktur XML, cek
`.kiro/scripts/gpx_smoketest.py` dari PR #25 sebagai template.
