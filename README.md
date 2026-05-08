# Langgeng Sea 🎣🛰️

> **Jejak Setia di Lautan** — Aplikasi tracking GPS khusus nelayan trawl Indonesia.

Langgeng Sea adalah aplikasi mobile Android (Flutter) yang membantu nelayan
trawl mencatat jejak alat tangkap secara **offline** — tanpa internet,
bahkan di mode pesawat — menggunakan chip GPS HP tanpa perangkat tambahan.

## ✨ Fitur Utama (MVP)

- 🛰️ **GPS Tracking Offline** — rekam jejak kapal & trawl di tengah laut tanpa sinyal.
- 🎯 **Akurasi ±5 meter** — cukup untuk kebutuhan trawl, pakai HP saja.
- 🔘 **Manual Start/Stop** — tombol besar "Mulai Tebar" & "Angkat Trawl".
- 🎣 **Multi-Haul Per Trip** — 2-5 tarikan per trip, tersimpan terpisah, bisa diberi nama kustom.
- 📏 **Kalkulasi Otomatis** — jarak, durasi, kecepatan, arah, luas sapuan trawl.
- 🗺️ **Peta Offline** — download sekali di darat, pakai gratis di laut (OpenStreetMap + OpenSeaMap).
- 📓 **Log Book Digital** — catat hasil tangkap (kg, opsional), BBM, cuaca, kru.
- 📊 **Dashboard Statistik** — evaluasi performa mingguan / bulanan.
- 📍 **Marker Kustom** — tandai spot produktif, karang, pelabuhan.
- 📤 **Ekspor / Impor** — GPX (universal) & `.lsea.json` (share antar pengguna, dengan nama pengirim).

**Coming Soon (v2):** SOS darurat, sync cloud, peta berbayar, iOS, geofencing.

---

## 🧱 Tech Stack

| Layer | Pilihan |
|---|---|
| Framework | Flutter 3.24+ (Dart 3.5+) |
| Platform (MVP) | Android 8.0+ (API 26+) |
| Peta | `flutter_map` + OpenStreetMap + OpenSeaMap |
| Cache Tile | `flutter_map_tile_caching` (FMTC) |
| GPS | `geolocator` + foreground service |
| Database | SQLite via `drift` |
| State Management | Riverpod |
| Arsitektur | Clean Architecture (presentation / domain / data) |

---

## 🚀 Getting Started

Source Flutter project berada di folder [`app/`](./app). Detail instruksi run:
[`app/README.md`](./app/README.md).

**Quick start:**

```bash
# Prasyarat: Flutter 3.24+ & JDK 17
flutter --version

# Clone & setup
git clone https://github.com/ssukahisyam/Langgeng-Sea.git
cd Langgeng-Sea/app

flutter pub get
flutter run
```

App saat ini di **M0 Foundation**. GPS tracking & peta offline diimplementasikan di M1.

---

## 📂 Dokumentasi Proyek

Dokumentasi spec lengkap ada di `.kiro/specs/langgeng-sea/`:

| File | Isi |
|---|---|
| [`requirements.md`](./.kiro/specs/langgeng-sea/requirements.md) | PRD — Product Requirements Document |
| [`design.md`](./.kiro/specs/langgeng-sea/design.md) | Technical Design & Architecture |
| [`ui-ux-design.md`](./.kiro/specs/langgeng-sea/ui-ux-design.md) | UI/UX Design System (Clean Liquid Glass) |
| [`tasks.md`](./.kiro/specs/langgeng-sea/tasks.md) | Implementation Plan & Roadmap |
| [`prototype/`](./.kiro/specs/langgeng-sea/prototype/) | Interactive HTML Prototype (15 screens) |

---

## 📅 Roadmap MVP

Estimasi total: **~13 minggu (3 bulan)** dari mulai coding.

| Milestone | Durasi | Output | Status |
|---|---|---|---|
| M0 Setup & Foundation | 1 minggu | Project siap, CI/CD, theme, skeleton | ✅ Done |
| M1 Core Map & GPS | 2 minggu | Peta + posisi realtime | ✅ Done |
| M2 Haul Tracking | 2 minggu | Start/stop + rekam + metrik | ✅ Done |
| M3 Trip & History | 2 minggu | Multi-haul, riwayat | ✅ Done |
| M4 Peta Offline | 1 minggu | Download & cache tile | 🔜 Next |
| M5 Log Book & Marker | 1.5 minggu | Form log, marker | ⏳ |
| M6 Dashboard | 1 minggu | Statistik, grafik | ⏳ |
| M7 Ekspor / Impor | 1 minggu | GPX + JSON share | ⏳ |
| M8 Onboarding & Polish | 1.5 minggu | Tutorial, UI polish | ⏳ |
| M9 QA & Beta | 2 minggu | Test real-world | ⏳ |
| M10 Rilis MVP | 0.5 minggu | Play Store | ⏳ |

Detail lengkap: [`tasks.md`](./.kiro/specs/langgeng-sea/tasks.md)

---

## 🧭 Prinsip Desain

1. **Offline-First** — semua fitur inti bekerja tanpa internet.
2. **Local-Only Data** — MVP tidak punya server, data di HP user.
3. **Battery-Efficient** — GPS hanya aktif saat tombol ditekan.
4. **UI Besar & Kontras Tinggi** — cocok untuk kapal berguncang & matahari terik.
5. **Bahasa Indonesia** — mudah dipahami semua level literasi digital.

---

## 🛡️ Privasi

- Seluruh data tersimpan di perangkat Anda (SQLite lokal).
- Tidak ada server, tidak ada akun, tidak ada tracking analitik.
- Permission yang diminta: **Location** (wajib), **Storage** (untuk ekspor & peta).
- Satu-satunya koneksi internet terjadi saat download peta offline.

---

## 🗣️ Kredit Peta

Peta dasar oleh [OpenStreetMap contributors](https://www.openstreetmap.org/copyright).
Layer nautical oleh [OpenSeaMap](https://www.openseamap.org/).
