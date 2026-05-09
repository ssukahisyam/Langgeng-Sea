# Langgeng Sea — Manual QA Checklist

**Versi:** MVP 0.1.0
**Terakhir diupdate:** M9 (QA & Beta)
**Tujuan:** Verifikasi semua jalur kritikal sebelum beta release.

## Cara Pakai

1. Pasang APK debug/beta di device Android 8+ (API 26+).
2. Kerjakan tiap bagian berurut, centang kotak bila lolos.
3. Bila ada yang gagal, catat di kolom "Notes" dengan: device, Android
   version, langkah reproduksi, dan screenshot bila memungkinkan.
4. Buka issue GitHub dengan label `bug` + prioritas (P0/P1/P2).

Prioritas:
- **P0** = blocker (crash, data loss, GPS tidak jalan)
- **P1** = fitur rusak tapi ada workaround
- **P2** = polish / UX / typo

---

## A. Instalasi & Onboarding

- [ ] APK terpasang tanpa error (tidak ada "parse error" atau "app not installed")
- [ ] Launch pertama → permission location request muncul dengan penjelasan (rasional)
- [ ] Deny permission → banner kuning di peta, tombol "Beri Izin" ke Settings
- [ ] Grant permission → 3 slide onboarding muncul
- [ ] 3 slide onboarding dapat di-swipe kiri/kanan
- [ ] Dots indicator animasi width pada slide aktif
- [ ] Tombol "Lewati" langsung ke profile form
- [ ] Tombol "Lanjut" ke slide berikutnya; di slide terakhir → "Mulai"
- [ ] Profil form: nama kosong → error "Nama nelayan wajib diisi"
- [ ] Profil form: nama kapal kosong → error "Nama kapal wajib diisi"
- [ ] Profil form: trawl width 0 → error "Lebar trawl harus lebih dari 0"
- [ ] Profil form: trawl width > 200 → error validasi
- [ ] GT negatif → error validasi
- [ ] Setelah simpan profil → landing di tab Peta (bukan di onboarding lagi)
- [ ] Restart app setelah onboarding → langsung ke Peta (tidak mengulang onboarding)

## B. GPS & Peta

- [ ] Map tile ter-load saat online (OpenStreetMap base + OpenSeaMap overlay)
- [ ] Posisi HP tampil sebagai boat marker (ikon kapal biru)
- [ ] Boat marker rotasi sesuai heading saat bergerak (>0.5 m/s)
- [ ] Akurasi chip muncul di top-right: hijau (<10m), kuning (≤20m), merah (>20m)
- [ ] Tap tombol "Center on me" (FAB bawah) → peta kembali ke posisi HP
- [ ] Pan/zoom bekerja smooth, tidak lag di zoom 16-17
- [ ] OpenSeaMap nautical overlay (kedalaman, mercusuar) tampil di atas base
- [ ] Tap attribution "© OpenStreetMap contributors" → buka browser ke osm.org

## C. Tracking Haul

- [ ] Tap MULAI TEBAR saat tidak ada trip aktif → trip baru dibuat otomatis (silent)
- [ ] Layout switch ke recording mode (tombol jadi ANGKAT TRAWL merah)
- [ ] Live stats panel muncul: jarak, durasi, kecepatan saat ini, heading
- [ ] Live stats update tiap 10 detik (durasi setiap detik)
- [ ] Polyline aktif (warna merah/oranye) bertambah di peta seiring gerakan
- [ ] Haptic feedback (vibration) saat tombol MULAI/ANGKAT ditekan
- [ ] Boat marker berubah warna (merah saat recording, biru saat idle)
- [ ] Tap ANGKAT TRAWL → bottom sheet "Ringkasan Haul" muncul
- [ ] Metrik di sheet: jarak (km), durasi (jam:menit), kecepatan avg (knot), arah (°), luas sapuan (ha / m²)
- [ ] Bisa rename haul di sheet via ikon pensil
- [ ] Tombol "Haul Berikutnya" → langsung start haul baru, orderIndex +1
- [ ] Tombol "Akhiri Trip" → trip selesai, status=completed, kembali ke peta idle
- [ ] Kill app saat recording → reopen → recovery dialog muncul

## D. Offline Mode

- [ ] Matikan wifi + data seluler
- [ ] Tile yang sudah di-cache sebelumnya tetap tampil (area familiar)
- [ ] Tile area baru yang belum ter-cache tampil kosong/abu-abu (expected)
- [ ] GPS tetap jalan (hardware, tidak butuh network)
- [ ] Polyline tetap ter-record walau offline
- [ ] Stop haul saat offline → data tersimpan ke DB lokal
- [ ] Mode pesawat → GPS masih bisa aktif (toggle Location manual di Settings)
- [ ] Reconnect → tile baru load tanpa restart app

## E. Riwayat

- [ ] List trip urut newest first
- [ ] Section header per-hari dalam Bahasa Indonesia ("Hari ini", "Kemarin", "Senin, 3 Feb 2025")
- [ ] Empty state saat belum ada trip: ilustrasi + pesan ramah
- [ ] Tap trip card → TripDetail screen
- [ ] TripDetail menampilkan: tanggal, durasi total, jumlah haul, distance total, swept area total
- [ ] Multi-haul map auto-fit bounds (seluruh haul visible)
- [ ] Setiap haul punya warna polyline berbeda di multi-haul map
- [ ] Tap haul tile → HaulDetail screen
- [ ] HaulDetail menampilkan: polyline, metrik lengkap, start/end waktu, log book (bila ada)
- [ ] Rename trip via menu ⋮ → dialog, simpan, list update
- [ ] Rename haul via menu ⋮ di HaulDetail
- [ ] Delete trip via menu ⋮ → konfirmasi dialog → hauls + track points ikut terhapus (cascade)
- [ ] Delete haul → track points ikut terhapus, haul lain di trip masih ada

## F. Peta Offline

- [ ] FAB "Tambah Area" di regions screen
- [ ] Region picker: selection rectangle update saat pan/zoom peta
- [ ] Estimate MB & tile count live update saat bounds/zoom berubah
- [ ] Warning muncul bila estimate > 100MB (peringatan storage)
- [ ] Download progress bar terlihat (0-100%)
- [ ] Background download tidak blocking UI (bisa navigate ke tab lain)
- [ ] Cancel download → status "failed", sisa partial terhapus
- [ ] Retry download → resume dari awal (clean slate, MVP)
- [ ] Delete region → tile ikut terhapus dari FMTC store
- [ ] Region name editable via menu ⋮
- [ ] Status label: Pending / Downloading / Completed / Failed

## G. Log Book & Marker

- [ ] Log book per haul: tombol "Tambah Catatan" di HaulDetail
- [ ] Tambah catch item: pilih species dari dropdown (catalog ikan)
- [ ] Input kg dengan keyboard numeric (decimal)
- [ ] Multiple catch items bisa ditambahkan (tuna + cumi + udang)
- [ ] Cuaca: segmented picker (cerah / mendung / hujan)
- [ ] Gelombang: segmented picker (tenang / sedang / tinggi)
- [ ] BBM (liter), biaya (Rp), kru (jumlah) - semua opsional
- [ ] Notes free-text
- [ ] Simpan log → persisted, HaulDetail menampilkan summary log
- [ ] Edit log existing → field pre-filled
- [ ] Long-press peta → dialog "Tambah Marker" muncul
- [ ] Marker form: nama, kategori (spot/karang/pelabuhan/lainnya), notes
- [ ] Marker tampil di peta dengan ikon sesuai kategori
- [ ] Tap marker → popup dengan detail + tombol edit/delete
- [ ] Markers list screen → list semua marker
- [ ] Filter kategori di markers list → hanya kategori terpilih yang muncul
- [ ] Tap marker di list → peta center ke marker tersebut

## H. Dashboard

- [ ] Period switcher: Hari ini / Minggu ini / Bulan ini / Semua
- [ ] Stats cards: total trip, total haul, total jarak, total tangkapan (kg)
- [ ] Bar chart tampil bar count tangkapan harian (7 hari)
- [ ] Top 5 spots berdasarkan total catch kg (dari log book)
- [ ] Empty state saat belum ada data periode tersebut
- [ ] Period switch → stats re-calculate instan

## I. Ekspor / Impor

- [ ] Ekspor GPX dari TripDetail → file tersimpan di Downloads
- [ ] File GPX dapat dibuka di Google Earth / Komoot / lainnya
- [ ] Ekspor `.lsea.json` dari TripDetail → berisi trip + hauls + points + log book
- [ ] Share via WhatsApp → file terlampir, kirim ke kontak berhasil
- [ ] Share via Gmail → attachment valid
- [ ] Import screen: tombol "Pilih File" → file picker muncul
- [ ] Pilih `.lsea.json` valid → preview tampil (nama pengirim, jumlah trip/haul/point)
- [ ] Pilih `.lsea.json` invalid → error "Format tidak dikenali"
- [ ] Konfirmasi import → data masuk ke DB, muncul di Riwayat
- [ ] Import file berisi trip yang sudah ada → duplicate handling (skip atau overwrite - by design)

## J. Edge Cases (stress test)

- [ ] Kill app saat recording → reopen → recovery dialog muncul
- [ ] Recovery: "Lanjutkan" → haul melanjutkan, metrik dibangun ulang dari DB
- [ ] Recovery: "Akhiri sekarang" → haul di-finalize dengan data yang ada
- [ ] Tracking 2 jam continuous (baseline test) — tidak crash, polyline kontinu
- [ ] Tracking 12 jam continuous (beta scenario) — monitor battery & memory
- [ ] HP locked saat tracking → masih merekam (foreground service notif visible)
- [ ] Buka aplikasi lain saat tracking → kembali ke app, polyline masih update
- [ ] Rotasi device — portrait only enforced (landscape tidak berubah layout)
- [ ] GPS lemah (akurasi >50m) → chip merah, warning banner "Akurasi rendah"
- [ ] GPS tidak dapat fix setelah 30 detik → banner "Menunggu sinyal GPS"
- [ ] Device low storage (<100MB) → graceful warning sebelum download tile
- [ ] Profile edit saat ada trip aktif → perubahan trawl width **TIDAK** merubah history haul (width captured on start)
- [ ] Delete trip saat ada haul recording → dicegah (harus stop haul dulu)
- [ ] Import file sangat besar (>10MB) → progress indicator, tidak freeze UI
- [ ] Jam sistem di-advance → timestamp tetap dicatat apa adanya (user responsibility)

## K. Accessibility & UX

- [ ] Semua tombol utama ≥60dp (cek dengan Accessibility Scanner / manual measure)
- [ ] Tombol MULAI TEBAR / ANGKAT TRAWL ≥72dp (PRD NFR-03)
- [ ] Kontras text di glass card ≥ 4.5:1 (terbaca di bawah sinar matahari)
- [ ] TalkBack screen reader dapat navigasi semua control utama
- [ ] Semantics label ada di: Mulai Tebar, Angkat Trawl, FAB center, marker
- [ ] Font scale 130% (Android setting) → layout tidak terpotong / overflow
- [ ] Font scale 200% → critical controls tetap reachable
- [ ] Dark mode: semua element visible, kontras terjaga
- [ ] Light mode: glass card tidak "hilang" di background cerah
- [ ] Warna polyline tidak mengandalkan hue saja (juga thickness / pattern)
- [ ] Bahasa Indonesia konsisten (tidak ada campuran English mid-screen)

---

## Laporan QA

**Device yang diuji:**

| Device | Android | Versi APK | Penguji | Tanggal | Catatan |
|---|---|---|---|---|---|
|  |  |  |  |  |  |

**Ringkasan hasil:**

- Total scenarios: 60+
- Pass: __
- Fail (P0): __
- Fail (P1): __
- Fail (P2): __

**Bug list:** dicatat di GitHub issues dengan label `qa-m9`.
