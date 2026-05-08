# Planning & Roadmap - Langgeng Sea MVP

**Implementation Plan**
**Versi:** 1.0
**Estimasi Total:** ~13 minggu (3 bulan) dari start coding

---

## Ringkasan Milestone

| # | Milestone | Durasi | Output |
|---|---|---|---|
| M0 | Setup & Foundation | 1 minggu | Flutter project siap, CI/CD jalan |
| M1 | Core Map & GPS | 2 minggu | Peta + marker posisi realtime |
| M2 | Haul Tracking | 2 minggu | Tombol start/stop, rekam track point, kalkulasi metrik |
| M3 | Trip & History | 2 minggu | Multi-haul per trip, riwayat, detail |
| M4 | Peta Offline | 1 minggu | Download & cache tile |
| M5 | Log Book & Marker | 1.5 minggu | Form log, marker kustom |
| M6 | Dashboard | 1 minggu | Statistik, grafik |
| M7 | Ekspor / Impor | 1 minggu | GPX, JSON share |
| M8 | Onboarding & Polish | 1.5 minggu | Tutorial, UI polish, a11y |
| M9 | QA & Beta | 2 minggu | Testing real-world dengan nelayan |
| M10 | Rilis MVP | 0.5 minggu | Play Store submission |

---

## M0 — Setup & Foundation (Minggu 1)

- [ ] **T0.1** Inisialisasi proyek Flutter (`flutter create langgeng_sea`)
- [ ] **T0.2** Setup struktur folder Clean Architecture (`core/`, `features/`, `data/`)
- [ ] **T0.3** Tambah dependencies utama (flutter_map, drift, riverpod, freezed, geolocator, go_router)
- [ ] **T0.4** Setup linter & analysis options (strict mode)
- [ ] **T0.5** Setup GitHub Actions CI: lint + test + build APK debug
- [ ] **T0.6** Konfigurasi AndroidManifest: permission location, foreground service, internet
- [ ] **T0.7** Setup tema app (warna, typography) — biru laut + oranye
- [ ] **T0.8** Setup GoRouter dengan 4 tab utama (Map, History, Dashboard, Settings)
- [ ] **T0.9** Setup Drift database awal (schema version 1, kosong)
- [ ] **T0.10** Setup i18n structure (`app_id.arb`)
- [ ] **T0.11** Placeholder splash screen & app icon
- [ ] **T0.12** README project: cara run, struktur, konvensi

**Definition of Done:**
- Project dapat `flutter run` di emulator Android.
- CI job hijau di PR.
- Navigasi 4 tab berfungsi.

---

## M1 — Core Map & GPS (Minggu 2-3)

### Peta
- [ ] **T1.1** Integrasi `flutter_map` dengan OSM tile layer
- [ ] **T1.2** Tambah layer OpenSeaMap (overlay nautical)
- [ ] **T1.3** Atribusi OSM + OpenSeaMap (required by ToS)
- [ ] **T1.4** Kontrol zoom in/out, compass reset
- [ ] **T1.5** Tombol "Pusatkan ke Posisi Saya"

### GPS
- [ ] **T1.6** Implementasi `GpsService` abstraksi di atas `geolocator`
- [ ] **T1.7** Request permission location (fine + background) dengan dialog penjelasan
- [ ] **T1.8** Stream posisi real-time dengan akurasi tinggi
- [ ] **T1.9** Tampilkan marker kapal (icon) di peta, rotate sesuai heading
- [ ] **T1.10** Handle error: GPS disabled, permission denied, akurasi rendah
- [ ] **T1.11** Widget indikator akurasi GPS (±X m, warna hijau/kuning/merah)

**Definition of Done:**
- Peta muncul saat online, tile ter-load.
- Icon kapal bergerak mengikuti posisi user.
- Permission location ter-handle dengan baik.

---

## M2 — Haul Tracking (Minggu 4-5)

### Database
- [ ] **T2.1** Schema `trips`, `hauls`, `track_points` di Drift
- [ ] **T2.2** DAOs + repositories (trip, haul, track_point)
- [ ] **T2.3** Unit test DAO (drift in-memory)

### Domain
- [ ] **T2.4** Entity: `Trip`, `Haul`, `TrackPoint` (freezed)
- [ ] **T2.5** UseCase: `StartTrip`, `EndTrip`, `StartHaul`, `StopHaul`, `GetActiveTrip`
- [ ] **T2.6** UseCase: `CalculateHaulMetrics` (distance, duration, avg speed, swept area, heading)
- [ ] **T2.7** Util: `geo_calculator.dart` (haversine, circular mean)
- [ ] **T2.8** Unit test kalkulasi geospasial (dengan data fixture)

### Background Service
- [ ] **T2.9** Setup `flutter_background_service` sebagai foreground service
- [ ] **T2.10** Stream GPS → insert ke DB tiap 10 detik
- [ ] **T2.11** Notifikasi persistent: "Merekam Haul #X — X km"
- [ ] **T2.12** Handle service stop ketika user tap Angkat Trawl

### UI
- [ ] **T2.13** Widget `BigStartButton` — hijau, 80dp, teks "MULAI TEBAR"
- [ ] **T2.14** Widget `BigStopButton` — merah, 80dp, teks "ANGKAT TRAWL"
- [ ] **T2.15** Widget `LiveStatsPanel` — durasi, jarak, kecepatan, akurasi GPS
- [ ] **T2.16** Polyline rendering haul aktif di peta (realtime)
- [ ] **T2.17** Haul summary screen setelah stop — metrik + peta preview
- [ ] **T2.18** Input nama haul (dialog)

**Definition of Done:**
- User bisa tap Mulai → GPS terekam → tap Stop → lihat ringkasan.
- Haul tersimpan permanen di DB.
- Metrik akurat (diverifikasi dengan data uji).
- Tracking tetap jalan saat HP locked selama minimal 30 menit uji.

---

## M3 — Trip & History (Minggu 6-7)

### Trip Management
- [ ] **T3.1** UseCase: `StartTrip`, `EndTrip`, `GetActiveTripOrNull`
- [ ] **T3.2** Auto-create trip ketika Mulai Tebar ditekan tanpa trip aktif
- [ ] **T3.3** Auto-numbering haul per trip (order_index)
- [ ] **T3.4** Tombol "Haul Berikutnya" di summary screen
- [ ] **T3.5** Tombol "Akhiri Trip" + konfirmasi

### History Screen
- [ ] **T3.6** List trip diurutkan terbaru
- [ ] **T3.7** Item card trip: tanggal, durasi, jumlah haul, total jarak, total hasil tangkap
- [ ] **T3.8** Filter tanggal (date range picker)
- [ ] **T3.9** Screen detail trip: list haul + peta gabungan
- [ ] **T3.10** Screen detail haul: peta + metrik + log book + catatan
- [ ] **T3.11** Rename haul & trip
- [ ] **T3.12** Hapus trip (dengan konfirmasi + cascade delete haul & points)

### Crash Recovery
- [ ] **T3.13** Saat app start, cek haul status=recording → dialog recovery
- [ ] **T3.14** Opsi: "Lanjutkan" (restart tracking) / "Akhiri sekarang" (stop + calculate)

**Definition of Done:**
- 1 trip bisa berisi 5 haul, semua tersimpan rapi.
- History dapat dibuka dan di-rename.
- Recovery dialog muncul jika ada haul yang belum selesai.

---

## M4 — Peta Offline (Minggu 8)

- [ ] **T4.1** Integrasi `flutter_map_tile_caching` (FMTC)
- [ ] **T4.2** TileProvider pakai FMTC store
- [ ] **T4.3** Screen "Peta Offline" — list area yang sudah di-download
- [ ] **T4.4** Flow tambah area: pan-zoom peta → pilih bounding box → nama → estimasi size → download
- [ ] **T4.5** Progress download (persentase, tile count, pausable)
- [ ] **T4.6** Simpan metadata region di tabel `offline_map_regions`
- [ ] **T4.7** Hapus region + tile cache
- [ ] **T4.8** Peringatan total storage (misal >1 GB)
- [ ] **T4.9** Test mode pesawat: peta tetap tampil dari cache
- [ ] **T4.10** Handle gagal download (retry button)

**Definition of Done:**
- User dapat download 1 area (misal Selat Madura) sekitar 100-200 MB.
- Di mode pesawat, peta tetap tampil lengkap di area itu.
- Download bisa di-pause & resume.

---

## M5 — Log Book & Marker (Minggu 9 & separuh 10)

### Log Book
- [ ] **T5.1** Schema `logbook_entries` + `catch_items` di Drift
- [ ] **T5.2** Daftar 30+ jenis ikan umum (preset)
- [ ] **T5.3** Form log book per haul: list catches (multi-input), cuaca, gelombang, catatan
- [ ] **T5.4** Form log book per trip: BBM, biaya, jumlah kru, catatan umum
- [ ] **T5.5** Validasi input (angka positif, dll)
- [ ] **T5.6** Edit & hapus entry

### Marker Kustom
- [ ] **T5.7** Schema `markers` di Drift
- [ ] **T5.8** Long-press peta → tambah marker (dialog input)
- [ ] **T5.9** Kategori: Spot Produktif / Karang / Pelabuhan / Lainnya (icon berbeda)
- [ ] **T5.10** List marker di menu "Lokasi Saya"
- [ ] **T5.11** Toggle show/hide marker di peta
- [ ] **T5.12** Tap marker → popup info → edit/delete

**Definition of Done:**
- User dapat mengisi hasil tangkap per haul dan lihat di detail.
- User dapat menandai lokasi karang berbahaya & lihat di peta.

---

## M6 — Dashboard (Minggu 10 lanjutan)

- [ ] **T6.1** Screen Dashboard dengan periode toggle (Hari ini / 7 hari / 30 hari / Total)
- [ ] **T6.2** Card metrik: jumlah trip, haul, total jarak, total tangkap (kg), total BBM
- [ ] **T6.3** Bar chart hasil tangkap per hari (`fl_chart`)
- [ ] **T6.4** List top 5 haul terbaik (berdasarkan tangkap kg)
- [ ] **T6.5** Pie chart komposisi jenis ikan (opsional MVP)
- [ ] **T6.6** Heatmap area produktif di mini-map (nice-to-have)

**Definition of Done:**
- Statistik akurat dan update otomatis.
- Grafik readable di device 5".

---

## M7 — Ekspor / Impor (Minggu 11)

### Ekspor
- [ ] **T7.1** Service `GpxExporter` (pakai package `gpx`)
- [ ] **T7.2** Service `LseaJsonExporter` (custom format `.lsea.json`)
- [ ] **T7.3** UI: tombol ekspor di detail trip → pilih format → share sheet
- [ ] **T7.4** Ekspor per-haul atau per-trip

### Impor
- [ ] **T7.5** Service `LseaJsonImporter` — parse, validasi, simpan ke tabel `imported_data`
- [ ] **T7.6** UI: menu "Impor" → file picker → preview → konfirmasi
- [ ] **T7.7** Tab "Data Bersama" di History untuk lihat data dari user lain
- [ ] **T7.8** Tampilkan track impor di peta (warna & style beda)
- [ ] **T7.9** Impor GPX (track only)
- [ ] **T7.10** Hapus data impor

**Definition of Done:**
- File .gpx dari Langgeng Sea bisa dibuka di Google Earth.
- File .lsea.json bisa dikirim via WhatsApp, dibuka user lain, track tampil di peta.

---

## M8 — Onboarding & Polish (Minggu 12)

### Onboarding
- [ ] **T8.1** 3 slide onboarding (screenshots + ilustrasi)
- [ ] **T8.2** Form profil pertama kali: nama, nama kapal, ukuran GT, pelabuhan, lebar trawl
- [ ] **T8.3** Request permission location dengan penjelasan
- [ ] **T8.4** Prompt download peta offline awal (opsional)

### UI/UX Polish
- [ ] **T8.5** Review semua tombol besar minimal 60dp
- [ ] **T8.6** Review kontras warna (WCAG AA)
- [ ] **T8.7** Font size minimal 16sp untuk body
- [ ] **T8.8** Animasi transisi halus
- [ ] **T8.9** Empty states (tidak ada trip, tidak ada marker, dll)
- [ ] **T8.10** Error states (GPS off, permission denied)
- [ ] **T8.11** Loading states
- [ ] **T8.12** Dark mode (opsional MVP, bonus)

### Pengaturan
- [ ] **T8.13** Screen Settings: interval GPS, lebar trawl, unit (knot/kmh, km/nm)
- [ ] **T8.14** Kelola data: total storage used, hapus semua data (double confirm)
- [ ] **T8.15** Tentang app: versi, link GitHub, kredit OSM

### Aksesibilitas
- [ ] **T8.16** Semantic labels untuk screen reader
- [ ] **T8.17** Large text support

**Definition of Done:**
- App terasa polished, tidak ada placeholder tersisa.
- Onboarding pertama kali lancar dari 0 → siap tracking.

---

## M9 — QA & Beta Testing (Minggu 13-14)

- [ ] **T9.1** Internal QA: checklist 50+ skenario (install, trip lengkap, offline, dll)
- [ ] **T9.2** Unit test minimum coverage 60% domain layer
- [ ] **T9.3** Integration test flow utama (start trip → haul → stop → log → end)
- [ ] **T9.4** Test perangkat variasi: Android 8, 10, 13; layar 5" - 6.7"; chip GPS lemah vs kuat
- [ ] **T9.5** Stress test: tracking 12 jam kontinyu, 10.000+ track points
- [ ] **T9.6** Battery benchmark: konsumsi per jam tracking
- [ ] **T9.7** Beta closed: rekrut 5-10 nelayan (saran: komunitas trawl Probolinggo/Pekalongan)
- [ ] **T9.8** Form feedback + Telegram/WA group untuk bug report
- [ ] **T9.9** Iterasi bug fixing & usability improvements
- [ ] **T9.10** Hardening: Crashlytics (self-hosted Sentry opsional) — MVP opsional karena local-only

**Definition of Done:**
- 0 crash pada 10 trip beta.
- Feedback positif dari minimal 5 nelayan.
- Tidak ada blocker bug.

---

## M10 — Rilis MVP (Minggu 15)

- [ ] **T10.1** Play Store listing: nama, deskripsi (ID), screenshots (min 4), banner, ikon hi-res
- [ ] **T10.2** Privacy policy (required) — template lokal-only, no tracking
- [ ] **T10.3** Build release APK/AAB signed
- [ ] **T10.4** Upload ke Play Console, track internal testing
- [ ] **T10.5** Track closed testing (ke grup beta)
- [ ] **T10.6** Submit ke production
- [ ] **T10.7** Landing page sederhana (GitHub Pages) + link download
- [ ] **T10.8** Komunikasi rilis (grup nelayan, koperasi, KKP)

**Definition of Done:**
- App live di Play Store.
- Minimal 100 user instal dalam 2 minggu pertama (target).

---

## Cross-Cutting / Ongoing Tasks

- [ ] **CC.1** Setiap PR minimal 1 review sebelum merge
- [ ] **CC.2** Conventional commits (`feat:`, `fix:`, `docs:`)
- [ ] **CC.3** Update dokumentasi saat ada perubahan desain
- [ ] **CC.4** Logging yang informatif (tidak mem-PII)

---

## Resource & Capacity

**Tim minimum yang disarankan:**
- 1 Flutter dev (full-time) — bisa kerja sendiri untuk MVP
- 1 QA / tester (part-time, ikut pada M9)
- 1 UI/UX designer (part-time, ikut M0-M1 & M8)
- 1 PM / PO (Anda) — koordinasi & validasi user

Jika 1 orang (solo dev), timeline akan molor ~1.5x → estimasi 4-5 bulan.

---

## Risiko Jadwal

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Battery drain lebih boros dari target | Medium | Optimasi di M2, benchmark di M9 |
| FMTC API breaking | Medium | Pin versi, siapkan fallback manual tile download |
| OSM tile rate limit saat download besar | High | Throttle download, pakai Stadia Maps free tier cadangan |
| Nelayan beta susah dikoordinir | Medium | Kerja sama koperasi lokal, insentif kecil |
| Regulasi KKP (misal wajib VMS) mengubah scope | Low | Tetap fokus MVP, v2 pertimbangkan integrasi |

---

## Acceptance Kriteria MVP (Go/No-Go Rilis)

✅ Semua task M0-M8 completed
✅ 0 blocker bug
✅ Unit test passing
✅ Beta test feedback positif (minimal 5 nelayan)
✅ App size <50 MB (excl peta offline)
✅ Tidak crash selama 12 jam tracking kontinyu
✅ Play Store listing lengkap & approved
