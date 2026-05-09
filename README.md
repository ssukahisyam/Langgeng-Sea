# Langgeng Sea 🎣🛰️

> 🎉 **v1.0 Released** — MVP siap diuji di lapangan. Lihat
> [`CHANGELOG.md`](./CHANGELOG.md) untuk daftar fitur rilis.

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

App saat ini rilis **v1.0.0 (MVP)** — semua 10 milestone selesai. Detail
fitur di [`CHANGELOG.md`](./CHANGELOG.md).

---

## 📦 Install APK

Ada 3 cara install Langgeng Sea — pilih yang paling sesuai.

### 1. Google Play Store (direkomendasikan)

🔜 **TBD** — link Play Store akan dipasang di sini setelah submission
production approved. Sementara gunakan opsi 2 atau 3.

### 2. Google Play Internal Testing (beta testers)

Beta tester terpilih dapat join program internal testing:

1. Hubungi kami lewat WhatsApp +62-xxx-xxx-xxxx _(placeholder)_ dengan
   email Gmail yang kamu pakai di Play Store.
2. Kami invite kamu ke Play Console internal testing track.
3. Install dari Play Store — auto update ikut release baru.

Lihat [`.kiro/specs/langgeng-sea/beta-test-plan.md`](./.kiro/specs/langgeng-sea/beta-test-plan.md)
untuk detail kriteria beta tester.

### 3. APK Langsung dari GitHub Releases

Untuk power user / tester yang tidak punya Gmail / tidak mau lewat Play
Store:

1. Buka [Releases](https://github.com/ssukahisyam/Langgeng-Sea/releases)
   di repo ini.
2. Download APK sesuai arsitektur HP kamu:
   - `app-arm64-v8a-release.apk` — 64-bit ARM (HP modern 2019+).
   - `app-armeabi-v7a-release.apk` — 32-bit ARM (HP lama).
   - `app-x86_64-release.apk` — emulator / Chromebook.
3. Enable **Install unknown apps** di Settings → Keamanan → izinkan
   browser / file manager kamu.
4. Tap APK file, install.

> **⚠️ Catatan signing:** APK yang di-publish di GitHub Releases
> adalah hasil CI build (lihat
> [`.github/workflows/release.yml`](./.github/workflows/release.yml))
> dan **tidak di-sign dengan Play Store upload key**. Ini cukup untuk
> sideload testing tapi bukan build yang sama dengan di Play Store.
> Lihat [`RELEASE_CHECKLIST.md`](./RELEASE_CHECKLIST.md) pasal 4 untuk
> detail signing model.

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
| M4 Peta Offline | 1 minggu | Download & cache tile | ✅ Done |
| M5 Log Book & Marker | 1.5 minggu | Form log, marker | ✅ Done |
| M6 Dashboard | 1 minggu | Statistik, grafik | ✅ Done |
| M7 Ekspor / Impor | 1 minggu | GPX + JSON share | ✅ Done |
| M8 Onboarding & Polish | 1.5 minggu | Tutorial, UI polish | ✅ Done |
| M9 QA & Beta | 2 minggu | Test real-world | ✅ Done |
| M10 Rilis MVP | 0.5 minggu | Play Store | ✅ Done |

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

---

## 🧪 Beta Testing

Aplikasi saat ini dalam fase **Beta**. Untuk bergabung sebagai beta tester:

1. Hubungi kami via WhatsApp: +62-xxx-xxx-xxxx (dummy for now)
2. Install APK beta (distribusi via Google Drive atau Play Console internal testing)
3. Gunakan saat trip melaut minimum 3 kali
4. Submit feedback via Google Form (link diberikan saat pendaftaran)

Lihat [`.kiro/specs/langgeng-sea/beta-test-plan.md`](./.kiro/specs/langgeng-sea/beta-test-plan.md) untuk detail lengkap,
termasuk kriteria rekrutmen, timeline, dan bug triage process.

Manual QA checklist (60+ scenarios): [`qa-checklist.md`](./.kiro/specs/langgeng-sea/qa-checklist.md).

Bug report / saran: buka issue di repo ini atau hubungi via WhatsApp group.
