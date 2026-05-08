# PRD - Langgeng Sea

**Product Requirements Document**
**Versi:** 1.0 (MVP)
**Tanggal:** 8 Mei 2026
**Status:** Draft

---

## 1. Ringkasan Eksekutif

**Langgeng Sea** adalah aplikasi mobile Android berbasis Flutter yang dirancang khusus untuk nelayan trawl di Indonesia. Aplikasi ini memungkinkan nelayan merekam jejak GPS kapal dan alat tangkap (trawl) secara akurat di tengah laut **tanpa membutuhkan koneksi internet maupun perangkat GPS eksternal**. Setiap tarikan (haul) trawl disimpan sebagai data terpisah dengan informasi luas area sapuan, jarak, durasi, kecepatan, dan arah, sehingga nelayan dapat mengevaluasi kinerja trip dan kembali ke titik produktif di kemudian hari.

### 1.1 Masalah yang Dipecahkan

1. Nelayan kesulitan mencatat titik-titik produktif karena tidak ada alat khusus atau alat GPS handheld mahal.
2. Sinyal seluler tidak tersedia di tengah laut, sehingga aplikasi peta biasa tidak dapat dipakai.
3. Data hasil tangkap dan area operasi tidak terdokumentasi, menyulitkan evaluasi.
4. Sulit berbagi titik produktif antar sesama nelayan karena tidak ada format standar.

### 1.2 Solusi

Aplikasi mobile yang:
- Merekam jejak GPS **offline** saat tombol ditekan (start tebar → stop angkat trawl).
- Menghitung otomatis luas area sapuan, jarak, durasi, kecepatan, dan arah.
- Menyimpan riwayat per-haul dengan nama kustom.
- Menampilkan peta laut offline yang sudah di-download sebelumnya.
- Menyediakan log book digital dan dashboard statistik.
- Mendukung ekspor/impor data untuk berbagi antar pengguna.

---

## 2. Target Pengguna

### 2.1 Segmen Utama

| Segmen | Deskripsi | Kebutuhan |
|---|---|---|
| **Nelayan kecil** | 1-5 ABK, kapal <10 GT, trip harian | UI sederhana, tombol besar, hemat baterai |
| **Nelayan menengah** | 5-15 ABK, kapal 10-30 GT | Multiple hauls, log book, ekspor data |
| **Nelayan industri** | >15 ABK, kapal >30 GT | Dashboard evaluasi, data detail per haul |

### 2.2 Asumsi Pengguna

- Memiliki HP Android pribadi (Android 8+).
- Literasi digital dasar (bisa pakai WhatsApp, Google Maps).
- Berada di Indonesia (WPP 571-718).
- Trip harian (berangkat pagi, pulang sore/malam).
- Alat tangkap utama: trawl (pukat hela).

---

## 3. Tujuan Produk (Objectives)

### 3.1 Business Goals

- **O1:** Menjadi aplikasi tracking nelayan #1 di Indonesia dalam 2 tahun.
- **O2:** Mencapai 10.000 user aktif dalam 6 bulan setelah rilis MVP.
- **O3:** Memiliki retention rate >60% setelah 30 hari.

### 3.2 User Goals

- **U1:** Dapat merekam jejak alat tangkap dengan akurasi ±5 meter.
- **U2:** Dapat melihat peta dan posisi sendiri saat tidak ada sinyal.
- **U3:** Dapat membandingkan hasil tangkap antar trip.
- **U4:** Dapat kembali ke titik produktif dengan mudah.

### 3.3 Success Metrics (MVP)

| Metric | Target |
|---|---|
| Akurasi GPS tracking | ±5 meter |
| Uptime app di laut | >95% (offline) |
| Crash rate | <1% |
| Durasi tracking tanpa battery drain excessive | Minimal 12 jam |
| Waktu ekspor data | <5 detik untuk 1 trip |

---

## 4. Lingkup (Scope)

### 4.1 In Scope (MVP)

✅ GPS tracking offline berbasis tombol (start/stop per haul)
✅ Peta offline (download-to-use) menggunakan OpenStreetMap + OpenSeaMap
✅ Multi-haul per trip (2-5 tarikan, nama custom)
✅ Kalkulasi otomatis: luas area sapuan, jarak tarik, durasi, kecepatan rata-rata, arah
✅ Riwayat trip & haul dengan visualisasi di peta
✅ Marker/penanda lokasi penting di peta
✅ Log book digital (hasil tangkap per haul, cuaca, BBM)
✅ Dashboard statistik (mingguan, bulanan)
✅ Ekspor data (format GPX + JSON untuk share antar user)
✅ Impor data dari user lain
✅ Penyimpanan lokal (SQLite)

### 4.2 Out of Scope (Coming Soon / v2)

⏭️ Tombol SOS darurat
⏭️ Sinkronisasi cloud / backend server
⏭️ Peta laut berbayar (Navionics, C-MAP)
⏭️ Batimetri detail & sensor echo sounder
⏭️ Sensor suhu air / eksternal lain
⏭️ Geofencing (peringatan zona larangan)
⏭️ Navigasi "pulang" / return-to-home otomatis
⏭️ Fitur share lokasi ke keluarga via SMS
⏭️ Versi iOS
⏭️ Multi-bahasa (MVP hanya Bahasa Indonesia)

### 4.3 Tidak akan Dikerjakan

❌ Integrasi hardware eksternal (GPS, echo sounder, sensor)
❌ Aplikasi web / desktop
❌ E-commerce ikan

---

## 5. Functional Requirements

### FR-01: Autentikasi & Profil
- FR-01.1: Aplikasi dapat digunakan tanpa login (local-only MVP).
- FR-01.2: User mengisi profil sekali saat pertama buka: nama, nama kapal, ukuran kapal (GT), pelabuhan asal.
- FR-01.3: Profil dapat diedit kapan saja dari menu Pengaturan.

### FR-02: Peta Offline
- FR-02.1: Saat online, user dapat men-download peta suatu wilayah (pilih bounding box di peta) untuk dipakai offline.
- FR-02.2: Peta dasar: OpenStreetMap tiles.
- FR-02.3: Layer nautical: OpenSeaMap overlay.
- FR-02.4: Zoom level yang di-cache: 8 - 16.
- FR-02.5: Saat offline, peta tetap tampil dari cache lokal.
- FR-02.6: User dapat melihat daftar area yang sudah di-download dan menghapus yang tidak dipakai.
- FR-02.7: Estimasi ukuran storage ditampilkan sebelum download.

### FR-03: GPS Tracking (Per Haul)
- FR-03.1: GPS dapat berjalan tanpa koneksi internet (menggunakan hardware GPS chip HP).
- FR-03.2: User memulai rekaman dengan menekan tombol **"MULAI TEBAR"** (visual: besar, warna hijau).
- FR-03.3: User menghentikan rekaman dengan menekan tombol **"ANGKAT TRAWL"** (visual: besar, warna merah).
- FR-03.4: Interval pencatatan titik default: setiap 10 detik (dapat diatur 5-30 detik di Pengaturan).
- FR-03.5: Setiap titik menyimpan: latitude, longitude, timestamp, kecepatan (knot), arah/heading (derajat), akurasi (meter).
- FR-03.6: Saat tracking aktif, posisi kapal di-update real-time di peta dengan icon kapal.
- FR-03.7: Saat tracking aktif, statistik live ditampilkan: durasi berjalan, jarak terkumpul, kecepatan saat ini.
- FR-03.8: Tracking tetap berjalan saat HP terkunci (foreground service).
- FR-03.9: Jika akurasi GPS >20 meter, aplikasi memberi peringatan.

### FR-04: Haul Management
- FR-04.1: Setiap haul dalam satu trip diberi nomor urut otomatis (Haul #1, #2, dst).
- FR-04.2: User dapat mengubah nama haul (contoh: "Tarikan Utara", "Spot Karang").
- FR-04.3: Dalam satu trip bisa ada 1-10 haul (target umum 2-5).
- FR-04.4: User menandai "Mulai Trip" saat berangkat dan "Akhiri Trip" saat pulang. Haul hanya bisa direkam saat trip aktif.
- FR-04.5: Haul yang sudah selesai tidak dapat diedit datanya (immutable), hanya nama & catatan.

### FR-05: Kalkulasi Metrik Haul
- FR-05.1: **Jarak tarik** = total panjang polyline haul (meter/km).
- FR-05.2: **Durasi tarik** = selisih waktu start-stop (jam:menit:detik).
- FR-05.3: **Kecepatan rata-rata** = jarak / durasi (knot).
- FR-05.4: **Luas area sapuan** = dihitung dari panjang tarik × lebar bukaan trawl (user input lebar trawl di profil, default 20m).
- FR-05.5: **Arah dominan** = heading rata-rata dari semua titik.
- FR-05.6: Semua metrik di-update real-time selama tracking.

### FR-06: Visualisasi di Peta
- FR-06.1: Jejak haul ditampilkan sebagai polyline berwarna di peta.
- FR-06.2: Warna polyline berbeda per haul dalam satu trip.
- FR-06.3: Titik awal (tebar) dan titik akhir (angkat) masing-masing punya marker berbeda.
- FR-06.4: Tap polyline untuk melihat detail haul.
- FR-06.5: Toggle show/hide tiap haul di peta.

### FR-07: Marker / Penanda Lokasi
- FR-07.1: User dapat menambah marker kustom di peta (long-press atau tombol +).
- FR-07.2: Marker menyimpan: nama, kategori (Spot Produktif / Karang / Pelabuhan / Lainnya), catatan, koordinat, waktu dibuat.
- FR-07.3: Marker tersimpan independen dari haul/trip.
- FR-07.4: Marker dapat diedit dan dihapus.
- FR-07.5: Daftar marker dapat dilihat di menu "Lokasi Saya".

### FR-08: Log Book Digital
- FR-08.1: Setiap haul dapat diisi form log book: hasil tangkap (kg per jenis ikan), cuaca (cerah/mendung/hujan), gelombang (tenang/sedang/tinggi), catatan bebas.
- FR-08.2: Setiap trip dapat diisi form trip: BBM terpakai (liter), biaya operasional (Rp), catatan umum, kru yang ikut.
- FR-08.3: Log book dapat diedit kapan saja.
- FR-08.4: Jenis ikan dipilih dari daftar preset (minimal 30 spesies umum Indonesia) + opsi custom.

### FR-09: Riwayat Trip
- FR-09.1: Daftar trip diurutkan dari yang terbaru.
- FR-09.2: Setiap item menampilkan: tanggal, durasi, jumlah haul, total hasil tangkap, total jarak.
- FR-09.3: Tap trip untuk lihat detail + peta.
- FR-09.4: Filter trip berdasarkan rentang tanggal.
- FR-09.5: Trip dapat dihapus (dengan konfirmasi).

### FR-10: Dashboard Statistik
- FR-10.1: Ringkasan periode (Hari ini / 7 hari / 30 hari / Total).
- FR-10.2: Metrik ditampilkan: jumlah trip, jumlah haul, total jarak tarik, total hasil tangkap (kg), total BBM, area tersapu.
- FR-10.3: Grafik sederhana: hasil tangkap per hari (bar chart), top 5 spot produktif (list).
- FR-10.4: Peta heatmap area produktif (opsional MVP, nice-to-have).

### FR-11: Ekspor & Impor Data
- FR-11.1: User dapat mengekspor data trip dalam format **GPX** (standar universal) untuk dibuka di Google Earth atau app tracking lain.
- FR-11.2: User dapat mengekspor dalam format **JSON khusus Langgeng Sea** (termasuk log book & metadata) untuk di-share ke user lain.
- FR-11.3: File ekspor disimpan di folder Downloads / dapat di-share via WhatsApp / Email.
- FR-11.4: User dapat mengimpor file `.lsea.json` dari user lain → data masuk ke tab "Data Bersama" (tidak tercampur dengan data sendiri).
- FR-11.5: Impor GPX juga didukung (hanya track, tanpa log book).

### FR-12: Pengaturan (Settings)
- FR-12.1: Interval GPS (5 / 10 / 15 / 30 detik).
- FR-12.2: Lebar bukaan trawl (default 20m).
- FR-12.3: Unit kecepatan (knot/km-h).
- FR-12.4: Unit jarak (km/nautical mile).
- FR-12.5: Kelola peta offline (lihat, download, hapus).
- FR-12.6: Kelola data (total storage, hapus semua data, backup & restore lokal).

---

## 6. Non-Functional Requirements

### NFR-01: Performa
- Aplikasi dapat tracking minimal **12 jam** tanpa mati (cocok untuk trip harian).
- Konsumsi baterai <15% per jam saat tracking aktif.
- App size <50 MB (excl. peta offline).
- Peta offline satu WPP (Wilayah Pengelolaan Perikanan) <500 MB.

### NFR-02: Reliabilitas
- Data tidak boleh hilang jika aplikasi crash atau HP mati — tulis titik GPS ke SQLite secara incremental.
- Recovery otomatis: jika tracking terputus karena crash, muncul dialog "Lanjutkan haul sebelumnya?".

### NFR-03: Usability
- Tombol utama minimal 60dp × 60dp (mudah ditekan di kapal yang berguncang).
- Kontras tinggi (mode terang default, mode gelap opsional).
- Font minimal 16sp untuk body text.
- Semua teks dalam Bahasa Indonesia yang mudah dipahami (hindari istilah teknis).
- Onboarding tutorial 3 langkah saat pertama install.

### NFR-04: Kompatibilitas
- Android minimum: **Android 8.0 (API 26)**.
- Target: Android 14 (API 34).
- Mendukung layar 4.7" - 7".
- Orientasi: Portrait utama (landscape opsional untuk peta).

### NFR-05: Privasi & Keamanan
- Semua data disimpan lokal di device user, tidak ada server.
- Tidak mengumpulkan analytics tanpa persetujuan.
- Permission minimal: Location (foreground + background), Storage (untuk ekspor/impor & peta offline).

### NFR-06: Maintainability
- Kode mengikuti Flutter/Dart style guide resmi.
- Arsitektur: Clean Architecture (presentation / domain / data layers).
- Coverage unit test minimal 60% untuk domain & data layer.

### NFR-07: Lokalisasi
- MVP: hanya Bahasa Indonesia.
- Struktur i18n sudah disiapkan untuk Bahasa Inggris di v2.

---

## 7. User Stories Kunci

### Epic 1: Tracking Trawl
- **US-01:** Sebagai nelayan, saya ingin memulai perekaman jejak trawl dengan satu tombol besar, supaya mudah dilakukan di atas kapal yang berguncang.
- **US-02:** Sebagai nelayan, saya ingin melihat posisi kapal saya di peta walaupun sedang tidak ada sinyal seluler.
- **US-03:** Sebagai nelayan, saya ingin tahu kecepatan dan arah kapal saat menarik trawl.
- **US-04:** Sebagai nelayan, saya ingin mengetahui berapa luas area yang sudah saya sapu dengan trawl.

### Epic 2: Multi-Haul
- **US-05:** Sebagai nelayan, saya ingin merekam beberapa tarikan (haul) dalam satu trip harian (2-5 kali) sebagai data terpisah.
- **US-06:** Sebagai nelayan, saya ingin memberi nama pada setiap haul agar mudah saya ingat lokasinya.

### Epic 3: Riwayat & Evaluasi
- **US-07:** Sebagai nelayan, saya ingin melihat daftar trip sebelumnya dan kembali ke spot produktif.
- **US-08:** Sebagai nelayan, saya ingin melihat statistik total hasil tangkap saya per bulan.
- **US-09:** Sebagai nelayan, saya ingin mencatat jumlah dan jenis ikan yang tertangkap per haul.

### Epic 4: Berbagi Data
- **US-10:** Sebagai nelayan, saya ingin berbagi lokasi produktif dengan teman sesama pengguna aplikasi via WhatsApp.
- **US-11:** Sebagai nelayan, saya ingin menerima data dari teman dan melihat spotnya di peta saya.

### Epic 5: Peta Offline
- **US-12:** Sebagai nelayan, saya ingin men-download peta wilayah saya sekali di darat, lalu pakai gratis di laut.

---

## 8. Acceptance Criteria Utama (MVP)

Aplikasi siap rilis ketika:

1. ✅ User dapat menyelesaikan 1 trip (1 haul) end-to-end tanpa koneksi internet.
2. ✅ Jarak tarik, durasi, kecepatan, dan luas sapuan terhitung akurat (diverifikasi dengan tools standar).
3. ✅ Data tidak hilang setelah restart aplikasi atau HP.
4. ✅ Peta offline dapat di-download dan ditampilkan di mode pesawat.
5. ✅ Ekspor GPX menghasilkan file yang dapat dibuka di Google Earth.
6. ✅ User dapat mengimpor file dari user lain dan melihat track-nya di peta.
7. ✅ Aplikasi tidak crash selama 12 jam tracking berkelanjutan.
8. ✅ UI responsif di device target (min Android 8, layar 5").
9. ✅ Onboarding & tutorial pertama kali berjalan lancar.
10. ✅ Log book dapat diisi untuk tiap haul.

---

## 9. Asumsi & Dependensi

### Asumsi
- User memiliki akses wifi/data seluler saat di darat untuk download peta.
- HP user memiliki chip GPS (hampir semua Android sejak 2015).
- User mengizinkan permission Location (Always Allow).

### Dependensi Eksternal
- **OpenStreetMap** tile server (free, comply dengan ToS: maks 1000 tiles/day per user).
- **OpenSeaMap** tile server (free).
- Google Play Store untuk distribusi (atau APK direct).

### Risiko
| Risiko | Mitigasi |
|---|---|
| Battery drain berlebihan | Foreground service optimized, user bawa power bank |
| Akurasi GPS <±5m tidak tercapai di HP murah | Set warning saat akurasi rendah, pakai sensor fusion |
| OSM tile server rate limit terkena | Gunakan caching agresif, pertimbangkan Stadia free tier |
| User bingung dengan tombol mulai/stop | Onboarding + tooltip kontekstual |

---

## 10. Timeline Tingkat Tinggi

| Fase | Durasi | Deliverable |
|---|---|---|
| **Discovery** | ✅ Selesai | PRD, Design, Tasks |
| **Setup & Foundation** | 1 minggu | Flutter project, CI/CD, arsitektur dasar |
| **Sprint 1: Core Tracking** | 2 minggu | Peta, GPS tracking, start/stop button |
| **Sprint 2: Haul & Trip** | 2 minggu | Multi-haul, metrik, visualisasi |
| **Sprint 3: Peta Offline** | 1 minggu | Download tile, cache |
| **Sprint 4: Log Book & Dashboard** | 2 minggu | Form log, statistik |
| **Sprint 5: Ekspor/Impor** | 1 minggu | GPX, JSON format |
| **Sprint 6: Polish & QA** | 2 minggu | Onboarding, UI polish, bug fixing |
| **Beta Test** | 2 minggu | Testing dengan nelayan nyata |
| **Rilis MVP** | - | Play Store submission |

**Total estimasi:** ~13 minggu (~3 bulan) dari mulai coding.

---

## 11. Keputusan Desain (Closed Questions)

1. ✅ **Nama kapal pengirim** disertakan saat ekspor → field `exportedBy.name` dan `exportedBy.vessel` di format `.lsea.json`, ditampilkan saat user mengimpor data ("Dikirim oleh: Pak Budi - KM Jaya").
2. ✅ **Satuan hasil tangkap = kg saja**, dan **field opsional** (boleh dikosongkan). Tidak wajib diisi per haul/trip.
3. ✅ **Branding:** Biru Laut `#0277BD` (primary) + Oranye Matahari Terbit `#FF6F00` (accent). Tema gaya "Clean Liquid Glass" dengan mode terang & gelap.
4. ✅ **Tombol "Mulai Tebar" tidak dibatasi** oleh kecepatan kapal — user bisa tekan kapan saja, termasuk saat kapal diam.

---

## 12. Glosarium

- **Trawl (Pukat Hela):** Alat tangkap jaring yang ditarik di belakang kapal.
- **Haul:** Satu siklus tebar-tarik-angkat trawl.
- **Trip:** Satu perjalanan melaut dari pelabuhan sampai kembali ke pelabuhan.
- **GT (Gross Tonnage):** Ukuran kapasitas kapal.
- **WPP:** Wilayah Pengelolaan Perikanan Indonesia (571-718).
- **GPX:** GPS Exchange Format, standar file tracking GPS.
- **OSM:** OpenStreetMap.
- **Knot:** Satuan kecepatan laut (1 knot = 1.852 km/jam).
