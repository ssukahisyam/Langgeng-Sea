# Screenshots — Panduan Capture

Play Store membutuhkan minimal **2** dan maksimal **8** screenshot
(phone). Kami ship **5** screenshot inti yang menggambarkan alur
utama Langgeng Sea. Folder ini menjadi sumber kebenaran; hasil capture
aktual **tidak di-commit** (lihat `.gitignore`) — upload langsung ke
Play Console.

---

## 📐 Spesifikasi Teknis

| Atribut | Nilai |
|---|---|
| Format | PNG (tanpa alpha / background putih ok, tanpa transparansi) |
| Resolusi | **1080 × 1920** px (portrait) |
| Aspect ratio | 9:16 |
| Ukuran file | ≤ 8 MB per gambar |
| DPI | 320–480 (xxhdpi / xxxhdpi) |
| Bahasa UI | Indonesia |
| Theme | Mix: 3 light + 2 dark (lihat mapping di bawah) |

Play Console akan menolak gambar dengan watermark pihak ketiga, logo
kompetitor, atau UI emulator yang jelas terlihat (navigation bar
emulator, dsb).

---

## 🖼️ 5 Screenshot Wajib

Urutan ini harus dipertahankan saat upload — user scrolling listing
membacanya sebagai "tour".

### 1. `01-map-tracking.png` — Map + Tracking Aktif

- **Layar:** `/map` (home)
- **State aplikasi:**
  - Haul dalam status **recording** (sedang merekam).
  - Tombol bawah menampilkan "**ANGKAT TRAWL**" (bukan "Mulai Tebar").
  - Peta berisi polyline jejak ~1–2 km (tidak kosong).
  - Chip di atas: kecepatan ~3 knot, durasi berjalan (misal `00:12:34`),
    jarak berjalan (misal `1.2 km`).
  - Status GPS chip: "GPS OK · ±5m".
- **Theme:** light (F4F8FB background, aksen biru 0277BD).
- **Caption overlay (opsional):**
  > "Rekam jejak trawl tanpa sinyal."
- **Tujuan:** feature-screenshot pertama = "ini aplikasinya ngapain".

### 2. `02-haul-summary.png` — Ringkasan Haul

- **Layar:** `/haul/:id/summary` (tampil setelah user tekan Angkat
  Trawl).
- **State aplikasi:**
  - Haul baru saja selesai. Tampilkan data realistis:
    - Durasi: `1j 23m`
    - Jarak: `4.8 km`
    - Kecepatan rata-rata: `3.2 knot`
    - Arah: `278° (Barat)`
    - Luas sapuan trawl: `~48,000 m²`
  - Peta di atas menampilkan jejak lengkap haul yang baru selesai
    (polyline hijau / track warna aktif).
- **Theme:** light.
- **Caption:**
  > "Jarak, durasi, luas sapuan — hitung otomatis."

### 3. `03-history-list.png` — Riwayat Trip

- **Layar:** `/history`
- **State aplikasi:**
  - Minimal **3 trip** tampil di list (bukan single item).
  - Setiap card tampilkan: tanggal, jumlah haul, total jarak,
    thumbnail peta mini.
  - Tampilkan satu trip yang di-expand dengan multi-haul breakdown
    agar fitur multi-haul terlihat.
- **Theme:** light.
- **Caption:**
  > "Riwayat lengkap. Multi-haul per trip."

### 4. `04-dashboard.png` — Dashboard Statistik

- **Layar:** `/dashboard`
- **State aplikasi:**
  - Filter: **Bulan Ini**.
  - Grafik bar: jumlah haul per minggu (4–5 bar).
  - Angka ringkasan: total trip, total haul, total jam, total km,
    total hasil tangkap kg (sample ~240 kg).
  - Spot produktif top-3 dalam list.
- **Theme:** **dark** (050B18 background, aksen cyan 4FC3F7). Dashboard
  terlihat paling menarik di dark mode.
- **Caption:**
  > "Evaluasi performa per minggu / bulan."

### 5. `05-offline-map.png` — Peta Offline / Download

- **Layar:** `/settings/offline-map` (atau equivalent).
- **State aplikasi:**
  - Menunjukkan area Indonesia (misalnya fokus ke Probolinggo / Selat
    Madura) dengan bounding box download yang dipilih.
  - Status bar: "**125 MB · 3.200 tile**" siap download.
  - Tombol aksi: "Download Peta Area Ini".
  - Indikator OFFLINE / ONLINE terlihat.
- **Theme:** dark (opsional light — pilih yang paling kontras dengan
  #4).
- **Caption:**
  > "Download sekali di darat, pakai gratis di laut."

---

## 🎨 Rekomendasi Overlay Caption

Opsional tapi direkomendasikan: tambahkan caption teks besar di atas
screenshot (margin atas ~180px) dengan font Inter Bold 48pt putih +
shadow. Gunakan Figma template seragam agar 5 screenshot terlihat
sebagai satu set.

File template Figma: **TBD** (tugas desainer — placeholder). Saat
template siap, simpan source-nya di `store-listing/screenshots/source/`
dan export ke PNG di direktori ini.

---

## 🛠️ Cara Capture

### Opsi A: Perangkat Fisik

1. Set theme sesuai mapping di atas (Settings → Tampilan → Mode Terang /
   Gelap).
2. Buka aplikasi, navigate ke layar target.
3. Siapkan **sample data realistis**:
   - Untuk `01-map-tracking.png`: jalan outdoor 10–15 menit dengan
     tracking aktif agar ada jejak visible.
   - Untuk `02`, `03`, `04`: gunakan dataset seed dari
     `app/assets/seeds/demo.lsea.json` _(TBD — bikin sebelum submission)_.
4. Matikan notifikasi yang mengganggu (WhatsApp, email). Status bar
   sebaiknya bersih kecuali indikator tracking.
5. Screenshot: tekan **Power + Volume Down**.
6. Transfer ke laptop, rename sesuai konvensi `NN-name.png`.
7. Resize jika perlu ke 1080 × 1920 (gunakan ImageMagick atau
   preview app):
   ```
   magick input.png -resize 1080x1920^ -gravity center \
     -extent 1080x1920 01-map-tracking.png
   ```

### Opsi B: Android Emulator

1. Buat AVD dengan profile **Pixel 5** (1080 × 2340, set density
   xxhdpi).
2. Crop hasil screenshot ke 1080 × 1920 di bagian tengah-atas agar
   bezel emulator tidak terlihat.
3. Pastikan demo mode status bar aktif:
   ```
   adb shell settings put global sysui_demo_allowed 1
   adb shell am broadcast -a com.android.systemui.demo -e command enter
   adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0930
   adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
   adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4
   adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
   ```

---

## ✅ Checklist Sebelum Upload

- [ ] Semua 5 file PNG ada dengan nama persis seperti di atas.
- [ ] Resolusi 1080 × 1920 exact (cek via `identify *.png`).
- [ ] Tidak ada PII nelayan (nama asli kru, nomor HP, dsb).
- [ ] Tidak ada bug visual (widget terpotong, teks clipping).
- [ ] Mix theme sesuai mapping (3 light + 2 dark).
- [ ] Caption overlay konsisten (kalau dipakai).
- [ ] Screenshot preview di 2 ukuran zoom (mobile Play Store + web
      Play Store) tetap readable.
- [ ] Feature graphic (1024 × 500) terpisah — tidak di folder ini,
      tapi wajib juga untuk Play Console. Spec ada di
      `RELEASE_CHECKLIST.md`.
