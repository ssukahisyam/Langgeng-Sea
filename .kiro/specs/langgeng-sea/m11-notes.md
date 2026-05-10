# M11 — Navigasi & Panduan GPS

Status: **Planning** (belum dieksekusi, menunggu approval)

## Ringkasan

Menambah fitur panduan GPS untuk dua use case yang diminta user:

1. **Go-to waypoint** — pandu kapal dari posisi sekarang ke satu titik tujuan (marker / koordinat arbitrer / titik akhir haul). Panah + bearing + jarak + ETA. Notifikasi saat sampai.

2. **Follow-track** — ikuti polyline haul atau trip dari Riwayat. Highlight jalur referensi, warning saat menyimpang dari jalur. Tujuan: replay haul produktif untuk tebar trawl di jalur yang sama.

Scope MVP: **TIDAK** turn-by-turn routing (tidak relevan di laut, juga butuh routing engine berbasis jalan raya).

## User stories

### Go-to

> "Saya pernah dapat ikan bagus di Spot Udang kemarin. Sekarang saya mau balik ke sana, tapi lupa arah persisnya. Saya tap marker Spot Udang, pilih 'Pandu ke sini', peta tunjukkan panah arah + jarak. Saya atur haluan kapal ikut panah sampai sampai."

> "Cuaca memburuk, saya harus balik ke pelabuhan cepat. Long-press di peta pada titik pelabuhan, pilih 'Pandu ke titik ini'. HP getar + suara pas sampai."

### Follow-track

> "Haul #3 kemarin sangat produktif (lihat dashboard). Saya mau tebar trawl di jalur yang persis sama hari ini. Buka haul detail, tap 'Ikuti jalur tarikan ini'. Peta highlight jalur kemarin. Saya jalan. Kalau menyimpang >30m, HP alarm."

## Splitting — dua PR

User minta split supaya review aman. Masing-masing PR shipable end-to-end.

### PR M11a — Go-to waypoint + foundation

~700 LOC. Self-contained: user bisa pandu ke marker dan sampai dengan notifikasi. Semua infrastruktur navigasi (entity, controller, math, alert service, settings) lahir di PR ini. PR berikutnya tinggal tambah varian state.

### PR M11b — Follow-track

~500 LOC. Re-use foundation dari M11a. Hanya tambah `FollowTrackTarget` variant + off-route math + UI highlight. Tidak sentuh alert service atau settings lagi.

## Acceptance criteria

Setelah M11 selesai:

- [ ] Tap marker → "Pandu ke sini" → panel panduan muncul, peta overlay garis dashed ke tujuan
- [ ] Long-press peta → menu kontekstual dengan "Pandu ke titik ini"
- [ ] Haul detail → "Ikuti jalur" → polyline haul di-highlight, off-route alarm jalan
- [ ] Trip detail (≥2 haul) → "Ikuti jalur" → bottom sheet pilih haul → follow-track haul pilihan
- [ ] Trip detail (1 haul) → "Ikuti jalur" → auto-pick haul tunggal, langsung start
- [ ] Trip detail → "Pandu ke titik akhir" (titik akhir haul terakhir)
- [ ] Saat jarak ke target ≤ 15m selama 3 detik → notif "Sudah sampai" + vibrasi + suara TTS
- [ ] Saat cross-track ≥ 30m selama 5 detik → notif "Keluar jalur" + vibrasi + suara
- [ ] Settings `app_settings` table (single row, seeded default true/true): toggle suara alarm on/off, toggle getar alarm on/off
- [ ] Navigasi + tracking trawl bisa jalan bareng (dua mode independen)
- [ ] Tombol "Akhiri Pandu" selalu accessible saat nav aktif
- [ ] Crash recovery: navigasi TIDAK survive restart (state di-reset ke None saat app buka lagi — tracking survive, nav tidak, intentional karena user biasanya mulai nav setelah sudah di laut)
- [ ] Schema migration v4 → v5: CREATE TABLE app_settings + seed default row (tidak ALTER user_profiles)

## Threshold

| Event | Default | Rationale |
|---|---|---|
| Arrived (go-to) | **15m** | GPS consumer akurasi 3-5m + jitter. 15m = confidence target benar-benar sampai. |
| Off-route (follow-track) | **30m** | Drift alami kapal karena arus/angin 10-20m dari jalur persis. 30m = benar-benar keluar. |
| Arrived debounce | **3 detik** | Anti-jitter saat user hover di sekitar 15m radius. |
| Off-route debounce | **5 detik** | Hysteresis: alarm muncul saat >30m 5s terus, hilang saat kembali <30m 5s terus. |

Threshold disimpan sebagai konstanta di `NavigationConstants` — post-MVP bisa pindah ke settings.

## Non-goals (explicit)

- Turn-by-turn routing (tidak relevan di laut)
- Shared waypoint / team nav (v2)
- Background navigation saat app ditutup (pakai foreground service existing jika perlu — tidak dalam scope M11)
- Route optimization (user pilih haluan sendiri)
- Automatic re-route saat menyimpang (tidak ada konsep rute di laut)

## Risiko & mitigasi

- **TTS bundle size**: `flutter_tts` ~1MB. Acceptable (APK sekarang ~20MB arm64 release). Alternatif audio tone pre-generated kalau user complain.
- **Battery**: navigasi tidak tambah GPS poll beyond yang sudah jalan (GPS sama untuk tracking). Zero extra battery cost.
- **Confusion UI**: saat nav aktif + trawl recording + all-history on + markers on → peta bisa ramai. Mitigasi: panel nav di atas, nav polyline warna distinct (biru putus-putus go-to, kuning tebal follow-track), label target dengan ikon unique.
- **False-positive alarm**: debounce 3-5s sudah handle GPS jitter. Kalau masih noisy di real device, tune di beta.

Detail teknis lengkap lihat [`m11-navigation-spec.md`](m11-navigation-spec.md).
