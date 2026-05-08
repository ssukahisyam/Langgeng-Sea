# Product Context - Langgeng Sea

## Apa itu Langgeng Sea?

Langgeng Sea adalah aplikasi mobile Android (Flutter) untuk nelayan trawl di Indonesia.
Aplikasi ini memungkinkan nelayan merekam jejak GPS kapal dan alat tangkap (trawl)
secara **offline** (tanpa internet, bahkan di mode pesawat) dengan akurasi ±5 meter
menggunakan chip GPS HP tanpa alat eksternal.

## Value Proposition

1. **GPS Tracking Offline** — bekerja di tengah laut tanpa sinyal.
2. **Manual Start/Stop** — tombol besar untuk tandai mulai tebar & angkat trawl.
3. **Multi-Haul Per Trip** — 2-5 tarikan dalam satu trip harian, masing-masing terpisah & dapat dinamai kustom.
4. **Kalkulasi Otomatis** — jarak tarik, durasi, kecepatan, arah, luas sapuan trawl.
5. **Peta Offline** — download sekali di darat, pakai gratis di laut (OSM + OpenSeaMap).
6. **Log Book Digital** — hasil tangkap per haul, BBM, cuaca, kru.
7. **Share Antar Nelayan** — ekspor/impor GPX & format khusus.
8. **Dashboard Statistik** — evaluasi performa mingguan/bulanan.

## Target User

- Nelayan trawl Indonesia: kecil, menengah, industri.
- Trip harian (berangkat pagi, pulang sore).
- Punya HP Android 8+.

## Prinsip Desain

- **Offline-first** — semua fitur inti harus jalan tanpa internet.
- **Local-only** — data di SQLite device, tidak ada server (MVP).
- **Hemat baterai** — GPS hanya aktif saat tombol ditekan.
- **UI besar & kontras tinggi** — cocok untuk kondisi kapal berguncang & panas matahari.
- **Bahasa Indonesia** yang mudah dipahami.

## Scope MVP (In)

GPS tracking manual, peta offline, multi-haul, kalkulasi metrik, riwayat,
log book, dashboard, ekspor/impor GPX & JSON khusus, penyimpanan lokal.

## Out of Scope (v2)

SOS darurat, sync cloud, peta batimetri berbayar, sensor eksternal,
geofencing, iOS, multi-bahasa, return-to-home navigation.

## Tech Stack Ringkas

- **Flutter 3.24+** (Dart 3.5+)
- **Android only (MVP)**, min API 26
- **flutter_map** + **OpenStreetMap** + **OpenSeaMap** + **FMTC** (cache)
- **Drift (SQLite)** untuk data lokal
- **Riverpod** state management
- **Geolocator** + **flutter_background_service** untuk GPS

## Referensi Dokumentasi

- PRD: `.kiro/specs/langgeng-sea/requirements.md`
- Design: `.kiro/specs/langgeng-sea/design.md`
- Tasks & roadmap: `.kiro/specs/langgeng-sea/tasks.md`
