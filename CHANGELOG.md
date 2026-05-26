# Changelog

Semua perubahan penting pada proyek **Styra** dicatat di sini.

Format mengikuti [Keep a Changelog](https://keepachangelog.com/id/1.1.0/).
Proyek ini menggunakan [Semantic Versioning](https://semver.org/lang/id/).

---

## [1.1.0] — 2026-05-26

### Changed

- **Rebrand**: Aplikasi diubah nama dari **Langgeng Sea** menjadi **Styra**.
  - Display name di launcher: `Langgeng Sea` → `Styra`
  - Android `applicationId`: `id.co.langgengsea` → `com.styra`
  - Database file: `langgeng_sea.sqlite` → `styra.sqlite` (data lokal lama tidak ter-migrate; user perlu mulai fresh)
  - FMTC tile cache stores: `langgeng_sea_osm` / `langgeng_sea_seamark` → `styra_osm` / `styra_seamark`
  - GPX namespace: `https://langgengsea.id/gpx/extensions/v1` → `https://styra.app/gpx/extensions/v1`
  - GPX prefix di element baru: `lsea:` → `styra:`
  - Domain & email: `langgengsea.id` → `styra.app`

### Backward Compatibility

- **GPX importer**: tetap menerima both `lsea:` (legacy Langgeng Sea pre-rebrand) dan `styra:` (new). File GPX dari versi app lama tetap bisa di-import tanpa migrasi.
- **LSEA-JSON importer**: menerima both format `langgeng-sea-v1` (legacy) dan `styra-v1` (reserved untuk future).

### Notes

- Karena `applicationId` berubah, user existing tidak akan dapat update otomatis via Play Store (tidak applicable saat ini — app belum di-release ke Play Store sebelum rebrand).
- Database lokal di-rename, jadi user dengan APK lama yang upgrade ke versi ini akan mulai dengan database kosong.

---



**Tanggal rilis final:** _TBD_ (akan diisi saat tag `v1.0.0` di-push
ke `main`)
**Target:** Google Play Store — Internal Testing → Closed Beta →
Production.

### Highlights

Rilis perdana Styra. MVP lengkap dari M0 sampai M10 —
offline-first GPS tracking untuk nelayan trawl Indonesia. Data 100%
lokal, tanpa server, tanpa akun, tanpa iklan, 100% Bahasa Indonesia.

### Milestones Completed

- **M0 — Setup & Foundation** ✅
  Project scaffold, CI/CD (GitHub Actions Flutter analyze/test),
  Clean Architecture layout (presentation / domain / data), Riverpod +
  go_router bootstrapped, Material 3 theme dengan design tokens
  **Clean Liquid Glass**, Light + Dark mode.

- **M1 — Core Map & GPS** ✅
  `flutter_map` integration dengan OpenStreetMap base + OpenSeaMap
  nautical overlay. `geolocator` + custom `GpsService` dengan
  foreground service untuk tracking di latar belakang. Permission
  flow Bahasa Indonesia. Position marker dengan smooth animation.

- **M2 — Haul Tracking** ✅
  Tombol besar "Mulai Tebar" / "Angkat Trawl" dengan kontras tinggi
  untuk kondisi laut. Controller menghitung incremental aggregates:
  jarak pairwise haversine, heading circular-mean, average speed,
  swept area. Accuracy gate (≥25m excluded). Resume after app kill.

- **M3 — Trip & History** ✅
  Multi-haul per trip (2–5 tarikan), haul diberi nama custom. Trip
  auto-create saat haul pertama, auto-reuse untuk haul berikutnya.
  History screen dengan trip list + haul breakdown. Drift schema
  v1 (trips, hauls, track_points).

- **M4 — Peta Offline** ✅
  `flutter_map_tile_caching` (FMTC) integration. Download bounding
  box di darat saat WiFi, pakai gratis di laut selamanya. Progress UI
  dengan estimasi ukuran + jumlah tile. Storage management + delete
  region. Drift schema v2 (offline_regions).

- **M5 — Log Book & Marker** ✅
  Form log book per trip: hasil tangkap (kg per jenis, opsional),
  pemakaian BBM, cuaca, ombak, kru. Marker kustom untuk tandai spot
  karang / pelabuhan / titik produktif, bisa di-share via file.
  Drift schema v3 (log_book_entries, catch_items, markers).

- **M6 — Dashboard** ✅
  Statistik per minggu / bulan / custom range. `fl_chart` untuk grafik
  bar (haul per minggu) + line (trend BBM). Top-3 spot produktif.
  Ringkasan angka: total trip, total haul, total jam, total km, total
  kg. Filter by date range.

- **M7 — Ekspor / Impor** ✅
  Format **GPX** (universal — kompatibel dengan semua GPS software).
  Format native **`.lsea.json`** dengan metadata lengkap untuk
  share antar pengguna Styra, termasuk nama pengirim. Round-
  trip import preserves ID stabil. Share via Android intent.

- **M8 — Onboarding & Polish** ✅
  Tutorial 5-screen saat first-launch (Selamat Datang, Izin,
  Peta Offline, Tombol Besar, Siap Melaut). Profil kapal (nama,
  pemilik, kota base) saat onboarding — Drift schema v4
  (user_profiles). UI polish: glass-morphism cards, ambient
  background, status chips, primary action buttons dengan haptic.
  Accessibility: semantic labels, touch target ≥48dp, contrast ≥4.5:1.

- **M9 — QA & Beta** ✅
  Integration test end-to-end (Mulai Tebar → 10 titik GPS → Angkat
  Trawl → Haul #2 → endTrip). Controller unit test (circular-mean,
  pairwise haversine, accuracy gate, resume). Migration test untuk
  Drift v1→v4. Manual QA checklist 60+ scenarios (sections A–K).
  Beta test plan dengan rekrutmen, distribusi APK, feedback form,
  bug triage P0/P1/P2. Observability scaffolding: `CrashReporter`
  interface (no-op di MVP, Sentry di v1.1), logger dengan level
  filter via `kReleaseMode`.

- **M10 — Release Prep** ✅
  Versi bumped ke `1.0.0+1`. Signing config dengan fallback debug.
  ProGuard rules untuk Drift, flutter_map, FMTC/ObjectBox, phosphor,
  Riverpod, geolocator, permission_handler. Splash color resources
  light/dark. Release workflow GitHub Actions yang build APK
  split-per-abi + AAB pada tag push `v*.*.*`. Privacy policy,
  description id+en, screenshots guide, release checklist 12 section.

### Key Features (user-facing summary)

- 🛰️ Offline GPS tracking (tidak butuh internet di laut).
- 🎯 Multi-haul per trip (2–5 tarikan).
- 📏 Kalkulasi otomatis: jarak, durasi, kecepatan, arah, luas
  sapuan.
- 🗺️ Peta offline (OSM + OpenSeaMap) — download sekali di darat.
- 📓 Log book digital: hasil tangkap, BBM, cuaca, kru.
- 📊 Dashboard statistik per minggu / bulan.
- 📍 Marker spot produktif dengan share antar pengguna.
- 📤 Ekspor/impor GPX + `.lsea.json` native.
- 🔒 100% data lokal, tanpa akun, tanpa server, tanpa iklan.
- 🇮🇩 100% Bahasa Indonesia.
- 🔓 Open source (GitHub).

### Not Included in 1.0 (Roadmap)

- 🆘 Tombol SOS darurat → planned **v1.1**.
- ☁️ Sync antar HP / cloud backup → planned **v1.2**.
- 🛟 Geofencing & alarm zona terlarang → planned **v1.2**.
- 🍎 Versi iOS → planned **v2.0**.
- 💎 Premium paid maps (resolusi tinggi) → to be evaluated **v2.0**.

### Technical Details

- Flutter 3.24.x / Dart 3.5+
- Android min SDK 26 (Android 8.0), target SDK latest stable
- Riverpod 2.5 + go_router 14 + Drift 2.20 + flutter_map 7
- Clean Architecture 3-layer (presentation / domain / data)
- Signed dengan RSA 4096 upload key, Play App Signing enabled

### Known Limitations

- CI workflow (`release.yml`) menghasilkan artefak **unsigned**
  (fallback ke debug signing saat `key.properties` tidak ada). Play-
  Store-ready AAB di-build manual di workstation signing holder.
  Lihat `RELEASE_CHECKLIST.md` pasal 4.
- Tidak ada crash reporter pihak ketiga di v1.0 — akan ditambahkan di
  v1.1 (Sentry atau Firebase Crashlytics) dengan explicit opt-in.
- Belum ada on-device integration test di `integration_test/` — masih
  controller-level saja. Prioritas v1.1.
- iOS build belum di-test / di-ship.

---

[1.1.0]: https://github.com/ssukahisyam/Langgeng-Sea/releases/tag/v1.1.0
[1.0.0]: https://github.com/ssukahisyam/Langgeng-Sea/releases/tag/v1.0.0
