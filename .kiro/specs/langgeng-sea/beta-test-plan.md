# Langgeng Sea — Beta Test Plan

**Fase:** Pre-MVP Release
**Durasi beta:** 2 minggu
**Target start:** setelah M9 merged + APK beta ter-sign
**Owner:** Product (Hasan) + 1 nelayan koordinator lapangan

---

## 1. Tujuan Beta

Beta ini **bukan** marketing/acquisition. Tujuannya tiga:

1. **Validasi akurasi GPS real-world** di atas kapal bergerak 3-5 knot,
   dengan metal hull & kabin menghalangi sky-view, dibanding GPS
   handheld (Garmin eTrex) yang jadi baseline.
2. **Validasi UX di kondisi nyata** — tangan basah, guncangan, matahari
   terik, sarung tangan. Apakah tombol MULAI TEBAR / ANGKAT TRAWL
   terjangkau dan terbaca? Apakah live stats relevan?
3. **Validasi battery drain** — tracking 8-12 jam continuous. Target:
   HP selesai trip dengan ≥30% battery (asumsi mulai 100%, HP ≥4000mAh,
   no powerbank dependency).

Non-goals: mengukur monetization, ekspor format lain, sync cloud,
multi-kapal.

---

## 2. Rekrutmen Beta Tester

### Target: 5-10 nelayan trawl aktif

### Kriteria

- Nelayan trawl (bukan pancing / jaring lain) yang melaut minimal 3×/minggu
- Punya HP Android 8+ (API 26+), storage >= 1GB free, RAM >= 2GB
- Bersedia install APK sideload (dari luar Play Store) atau join Play
  Console internal testing track
- Bersedia submit feedback minimal 1× per minggu via WhatsApp / Google Form

### Sumber rekrut

- **Koperasi Probolinggo** (target primary — ada contact point)
- **Koperasi Pekalongan** (secondary)
- **HNSI cabang kota asal** (jika koperasi gagal)
- Rekomendasi dari tester awal (snowball)

### Insentif

- Pulsa Rp 50,000 per nelayan di awal beta (biaya data tile download)
- Pulsa Rp 100,000 tambahan untuk nelayan yang complete 3 trip + 3
  feedback submission
- Nama tester masuk "Credits" di layar About MVP (opsional, on consent)

### Screening

Sebelum kirim APK, interview singkat (WhatsApp call, 10 menit):
- Konfirmasi alat tangkap trawl (tebar-tarik-angkat pattern)
- Konfirmasi HP spec (ask: "Berapa RAM? Android berapa?")
- Konfirmasi storage free (ask: "Cek Settings > Storage, sisa berapa GB?")
- Set expectation: ini masih beta, ada bug, feedback sangat dibutuhkan

---

## 3. Distribusi APK

### Pilihan primer: Play Console Internal Testing

- Upload APK ter-sign ke Play Console track "Internal testing"
- Tester diundang via email → dapat opt-in link
- Install via Play Store (tidak perlu "Unknown sources")
- **Pro:** auto-update, credibility Google, crash report gratis
- **Con:** butuh Google Play Developer account ($25), tester harus punya
  Gmail yang di-whitelist

### Pilihan sekunder: Sideload via Google Drive

- Upload APK ke Google Drive publik share link
- Kirim link via WhatsApp
- Tester perlu enable "Install from unknown sources"
- **Pro:** nol setup, instan
- **Con:** tidak ada auto-update (harus manual reinstall tiap versi)

### Versi naming

- Format: `langgeng-sea-beta-0.1.0-rc1.apk`
- Bump `rc` tiap rilis baru saat beta
- Version name di-display di Settings screen

---

## 4. Channel Support

### Grup WhatsApp "Langgeng Sea Beta"

- Admin: Hasan
- Anggota: semua beta tester + 1 dev
- Tujuan: quick Q&A, tutorial awal, pengumuman update APK
- Rule: masalah teknis → buka issue di GitHub atau submit via form,
  WhatsApp hanya untuk diskusi ringan

### Escalation

- Masalah P0 (blocker / data loss) → DM langsung ke dev, target first
  response 12 jam, fix 24 jam
- P1 → diskusi di grup, fix di rilis rc berikutnya (cadence 3-4 hari)
- P2 → list, backlog untuk post-MVP

---

## 5. Feedback Form

**Google Form link:** `https://forms.gle/<TBD>` (buat sebelum kickoff beta)

Submit 1× per trip (jadi 3× minimum per tester).

### Struktur pertanyaan (minimalis — 6 field)

1. **Nama & nama kapal** (required, teks)
2. **Tanggal melaut** (required, date picker)
3. **Masalah yang dihadapi** (opsional, paragraf bebas)
   Contoh: "GPS hilang sinyal di zona X", "Tombol ANGKAT tidak respon",
   "Battery tinggal 20% setelah 6 jam"
4. **Akurasi GPS dibanding handheld** (required, skala 1-5)
   - 1: jauh meleset (>50m off)
   - 3: lumayan, sesekali off tapi bisa dipakai
   - 5: persis seperti Garmin
5. **Baterai habis di % berapa setelah 8 jam tracking**
   (required, angka 0-100)
6. **Usulan fitur / perbaikan** (opsional, paragraf bebas)

### Analisis

- Setiap akhir minggu, data form di-export CSV → diskusi tim
- Akurasi GPS rata-rata → target ≥4.0 untuk release
- Battery median → target ≥30% remaining at 8h

---

## 6. Bug Triage

### Labeling (GitHub issues)

- `P0 blocker` — crash on start, data loss, tracking tidak jalan
- `P1 critical` — fitur broken tapi ada workaround (rename rusak, import
  gagal)
- `P2 polish` — UX issue, typo, warna, overflow kecil
- `beta` — untuk filter saat sprint planning

### SLA

| Prioritas | Response | Fix target |
|---|---|---|
| P0 | 12 jam | 24 jam |
| P1 | 48 jam | 3-4 hari (next rc) |
| P2 | 1 minggu | post-MVP backlog |

### Rilis cadence

- `rc1` → start beta
- `rc2+` → setiap 3-4 hari bila ada P0/P1 fix
- Notifikasi via grup WhatsApp + changelog singkat

---

## 7. Sukses Criteria untuk Rilis MVP

MVP boleh rilis ke Play Store production track bila semua tercapai:

- [ ] **0 P0 bugs** terbuka selama 7 hari terakhir beta
- [ ] Feedback positif dari **≥5 nelayan** (skor GPS ≥4, "akan pakai
      lagi" = yes)
- [ ] **Crash rate < 1%** (crash / total sessions, via Play Console
      vitals — membutuhkan internal testing channel)
- [ ] **Akurasi GPS median ≤10m** di kondisi langit terbuka (dari
      feedback form self-report vs handheld)
- [ ] **Battery drain** median ≥30% remaining setelah trip 8 jam
- [ ] Tidak ada laporan data loss (trip/haul hilang tanpa user action)

### Kriteria TIDAK rilis (showstopper)

- Trip atau haul hilang sendiri di DB (data integrity issue)
- Crash saat startHaul / stopHaul yang tidak bisa di-recover
- Tracking terputus sendiri tanpa user stop (foreground service killed)
- Akurasi median >20m di kondisi normal

---

## 8. Timeline

| Minggu | Kegiatan |
|---|---|
| Week 0 (persiapan) | Build APK rc1, upload Drive + Play Console internal, buat Google Form, pendaftaran tester |
| Week 1 | Kickoff beta, tester trip pertama, daily check-in WhatsApp, rc2 bila perlu |
| Week 2 | Trip 2-3 per tester, collect feedback form, analisa, fix P0/P1 |
| Week 3 | Eval exit criteria, diskusi tim, GO / NO-GO rilis MVP |

Bila NO-GO: beta diperpanjang 1 minggu dengan fokus pada isu terbesar,
kemudian re-eval.

---

## 9. Dokumen Terkait

- [`qa-checklist.md`](./qa-checklist.md) — Manual QA 60+ scenarios
- [`tasks.md`](./tasks.md) — Implementation plan lengkap
- [`m9-notes.md`](./m9-notes.md) — What shipped in M9
