# PR #21 — Tracking UX Improvements (Planning)

**Branch:** `feat/ux-tracking-improvements-pr21` → `main`
**Tipe:** Spec / Planning only (belum ada perubahan kode)
**Status:** Draft — fase Requirements selesai, Design & Tasks menyusul

## Ringkasan

PR ini menambahkan dokumen **requirements** untuk batch perbaikan UX tracking, peta, marker, dan manajemen penanda berdasarkan temuan uji lapangan. Belum ada perubahan kode aplikasi — baru dokumen planning di `.kiro/specs/tracking-ux-improvements/`.

## Lima Area yang Dicakup

1. **Background tracking andal** — Fix bug rekaman GPS jadi garis lurus saat layar mati / app di background. Requirement mendefinisikan foreground service wajib, interval sampling ≤ 5 detik (≤ 30 detik saat Doze Mode), jarak antar titik ≤ 50 m pada kecepatan hingga 15 knot, alur permission `ACCESS_BACKGROUND_LOCATION`, dan restart eksponensial.
2. **Zoom & pan bebas di mode "Jejak Kaki"** — Fit bounds hanya dipicu sekali di awal + ditambah tombol eksplisit "Paskan semua". User gesture tidak di-override oleh refresh data overlay.
3. **Polyline/Marker kontras + tap-to-label + navigasi** — Polyline solid dengan kontras ≥ 4.5:1, strokeWidth ≥ 4 px, tap memunculkan popup nama tracking + tombol "Navigasi ke sini" yang memanggil `NavigationController.startFollowTrack` dari M11.
4. **Peta adaptif per Map_Mode** — Empat mode: `Idle`, `Tracking`, `Navigating`, `ViewingHistory`. Tombol Mulai/Berhenti dan kartu info hanya muncul sesuai konteks. Transisi visual ≤ 250 ms, prioritas `Navigating > Tracking > ViewingHistory > Idle`.
5. **Kustomisasi warna Track + edit Marker Category + jump-to-location** — Color picker per Trip/Haul (8 preset + custom hex), edit kategori marker lewat menu konteks, single-tap di "Kelola Penanda" → Map Screen dengan center + zoom ≥ 15 + popup.

## Apa yang Sudah Ada di PR Ini

- `.kiro/specs/tracking-ux-improvements/.config.kiro` — config workflow
- `.kiro/specs/tracking-ux-improvements/requirements.md` — dokumen requirements lengkap (5 Requirement, format EARS, Bahasa Indonesia, dengan acceptance criteria detail + correctness properties untuk property-based testing)

## Yang Belum (Menyusul dalam PR ini)

- `design.md` — arsitektur Background_Service, state machine Map_Mode, skema UI adaptif, tambahan kolom `colorValue` di repo, router entry jump-to-location
- `tasks.md` — breakdown implementasi per requirement
- Implementasi kode aktual

## Cara Review

1. Buka `.kiro/specs/tracking-ux-improvements/requirements.md`
2. Cek tiap Requirement: user story, acceptance criteria (EARS), dan correctness properties
3. Beri feedback di PR sebelum kita lanjut ke fase Design

## Catatan Teknis

- Requirements mengacu ke Milestone M11 (Navigation) yang sudah ada — `FollowTrackTarget` akan dipakai untuk "Navigasi ke sini" dari popup tracking.
- Tidak ada breaking change DB skema di fase ini; penambahan `colorValue` pada Trip/Haul akan didesain di fase berikutnya.
- Target perangkat: Android 8.0 (API 26) – 14 (API 34) sesuai manifest eksisting.
