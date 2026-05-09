# Langgeng Sea — Release Checklist

**Target versi:** `1.0.0` (versionCode 1)
**Channel:** Google Play Store — Internal Testing → Closed Beta → Production
**Owner rilis:** TBD (isi nama release manager)

Gunakan checklist ini sebagai single-source-of-truth sebelum menekan
"Submit for review" di Play Console. Semua item harus dicentang oleh
minimal 1 reviewer selain owner. Ketiadaan bukti di satu item =
block rilis.

Format: `[ ]` belum · `[x]` selesai · `[N/A]` tidak relevan (jelaskan).

---

## 1. Code Quality

- [ ] Branch `main` hijau di GitHub Actions (`flutter.yml`).
- [ ] Semua unit test + integration test lulus (`flutter test`).
- [ ] Migration test untuk Drift `onUpgrade` terkini lulus.
- [ ] `flutter analyze --no-fatal-infos` 0 error, 0 warning baru
      versus `main`.
- [ ] `dart format --set-exit-if-changed` bersih (CI sudah cover).
- [ ] Semua `// TODO:` yang critical-path sudah diresolusi atau dibuat
      issue-nya dengan label `v1.1`.
- [ ] Tidak ada `print()` mentah di `lib/` (gunakan
      `core/observability/logger.dart`).
- [ ] Tidak ada hardcoded secret / API key di repo
      (`git grep -i 'api_key\|secret\|password'`).

## 2. Versioning

- [ ] `app/pubspec.yaml` → `version: 1.0.0+1`.
- [ ] `versionCode` di Play Console > versi sebelumnya
      (jika bukan first release, harus monotonic naik).
- [ ] Git tag `v1.0.0` dibuat **setelah** PR rilis merge ke `main`:
      ```
      git tag -a v1.0.0 -m "Langgeng Sea 1.0.0 — MVP release"
      git push origin v1.0.0
      ```
- [ ] `CHANGELOG.md` ada entry untuk `1.0.0` dengan tanggal rilis
      final.
- [ ] README banner versi updated (`🎉 v1.0 Released`).

## 3. Android Build Configuration

- [ ] `app/android/app/build.gradle.kts` `minSdk = 26`, `targetSdk`
      mengikuti `flutter.targetSdkVersion` (latest stable).
- [ ] `isMinifyEnabled = true` + `isShrinkResources = true` di
      `release` build type.
- [ ] `proguard-rules.pro` ada dan mencakup: Drift / SQLite,
      flutter_map, flutter_map_tile_caching (ObjectBox), phosphor
      flutter, Riverpod, geolocator, permission_handler, desugar.
- [ ] `AndroidManifest.xml` `android:label` referensi
      `@string/app_name` (bukan literal).
- [ ] `values/colors.xml` + `values-night/colors.xml` ada dengan
      splash_background & primary sesuai design tokens.
- [ ] `INTERNET` dan `ACCESS_BACKGROUND_LOCATION` di-**justify** di
      Play Console Data Safety + Privacy Policy.
- [ ] App icon mipmap (`@mipmap/ic_launcher`) hadir di resolusi
      mdpi→xxxhdpi, adaptive icon (foreground + background) ada
      untuk Android 8.0+.
- [ ] Splash screen native (Android 12+ SplashScreen API) terlihat
      benar di device real Android 12, 13, 14.

## 4. Signing (MANUAL — tidak dilakukan via CI)

> **Signing key tidak di-commit ke repo** dan **tidak di-generate
> oleh CI** (lihat `.github/workflows/release.yml`). Semua langkah
> di bawah dilakukan di workstation signing holder.

- [ ] Keystore `release.keystore` sudah di-generate dengan:
      ```
      keytool -genkey -v -keystore release.keystore \
        -keyalg RSA -keysize 4096 -validity 10950 \
        -alias langgeng-sea-upload
      ```
      (validitas 30 tahun supaya tidak expired sebelum sunset app.)
- [ ] `android/key.properties` dibuat dengan `storeFile`,
      `storePassword`, `keyAlias`, `keyPassword`. File **tidak
      di-commit** (sudah di `.gitignore`).
- [ ] Keystore + password disimpan di **password manager tim**
      (1Password / Bitwarden shared vault) — bukan hanya di laptop
      satu orang.
- [ ] Backup keystore di offline storage (USB drive terenkripsi,
      safe deposit box) minimal 2 copy.
- [ ] Play App Signing (Google mengelola signing key) **diaktifkan**
      saat upload AAB pertama — upload key tetap kita pegang, Play
      Console yang sign distribution.
- [ ] SHA-256 fingerprint upload key didokumentasikan di internal
      wiki (bukan di repo publik).

## 5. Build Artefacts

- [ ] Build lokal `flutter build appbundle --release` sukses tanpa
      warning baru.
- [ ] Build lokal `flutter build apk --release --split-per-abi` sukses
      — produk: `app-armeabi-v7a-release.apk`,
      `app-arm64-v8a-release.apk`, `app-x86_64-release.apk`.
- [ ] Ukuran AAB ≤ 150 MB (Play limit). Typical target ≤ 40 MB.
- [ ] `bundletool` dicek: install AAB di device real pakai
      `bundletool build-apks` → `install-apks`, aplikasi boot normal.
- [ ] R8 / ProGuard tidak ngebreak runtime: install release APK,
      jalankan full happy path (tracking haul → save → ekspor GPX).

## 6. Testing — Pre-Submission

### 6.1 Automated
- [ ] Semua test lulus di CI.
- [ ] Coverage report di-review (tidak perlu 100%, tapi business
      logic ≥ 70%).

### 6.2 Manual QA (checklist lengkap: `.kiro/specs/langgeng-sea/qa-checklist.md`)
- [ ] Section A (Instalasi & Onboarding) 100% lulus.
- [ ] Section B (GPS & Peta) 100% lulus di minimal 2 device.
- [ ] Section C (Tracking Haul) 100% lulus termasuk edge case
      recovery setelah kill app / low battery.
- [ ] Section D (Offline Mode) 100% lulus dengan airplane mode aktif
      12 jam.
- [ ] Section E–H 100% lulus.
- [ ] Section I (Ekspor/Impor) round-trip GPX dan `.lsea.json`
      antar device.
- [ ] Section J (Edge Cases) — low storage, low memory, permission
      denied, GPS timeout — handled gracefully.
- [ ] Section K (Accessibility) — TalkBack jalan di alur utama,
      contrast lulus Accessibility Scanner.

### 6.3 Device Matrix
- [ ] Android 8.0 (API 26) — Xiaomi Redmi atau Samsung A-series lama.
- [ ] Android 10 — Samsung atau Xiaomi mid-range.
- [ ] Android 13 — device beta tester utama.
- [ ] Android 14 — Pixel atau flagship.
- [ ] Device dengan RAM 2 GB (low-end target).
- [ ] Device dengan baterai ≥1 tahun (simulasi kondisi riil nelayan).

### 6.4 Beta Feedback
- [ ] Beta cycle selesai sesuai
      `.kiro/specs/langgeng-sea/beta-test-plan.md`.
- [ ] 0 P0 bug dalam 7 hari terakhir.
- [ ] ≥5 positive feedback dari nelayan aktif.
- [ ] Crash rate < 1% di crash reporter (v1.0 tanpa Sentry — pantau
      manual laporan user).
- [ ] GPS accuracy median ≤ 10 m di trip nyata (diverifikasi vs
      handheld GPS).
- [ ] Baterai sisa ≥ 30% setelah trip 8 jam di device beta utama.

## 7. Store Listing — Play Console

- [ ] App name: **Langgeng Sea: GPS Trawl** (max 30 char — cek
      `store-listing/description-id.md`).
- [ ] Short description 80 char loaded (id + en).
- [ ] Full description ≤ 4000 char (id + en).
- [ ] Category: **Tools** (atau **Productivity** — final decision oleh
      product owner).
- [ ] Tags: `utilities`, `gps`, `offline`, `fishing`, `indonesia`.
- [ ] Content rating questionnaire dijawab dengan jujur (no ads,
      no user content shared, no purchases).
- [ ] Target audience: 18+ (sesuai domain nelayan komersial).
- [ ] Pricing: **Free**, tersedia di **Indonesia** (fase 1), ekspansi
      ke Malaysia / Filipina di v1.1+.

### 7.1 Graphics
- [ ] **App icon** 512 × 512 PNG (Play Store listing) uploaded.
- [ ] **Feature graphic** 1024 × 500 PNG uploaded — hindari teks
      penting di sisi bawah (crop di Play Store TV preview).
- [ ] **Screenshots** phone 5 file sesuai
      `store-listing/screenshots/README.md`.
- [ ] Screenshots tablet **tidak** disediakan (target device phone-
      only di MVP; Play Console tidak mewajibkan tablet).
- [ ] Promo video YouTube — OPTIONAL, skip di v1.0.

### 7.2 Metadata
- [ ] Website: `https://github.com/ssukahisyam/Langgeng-Sea`
      (permanent sampai punya domain resmi).
- [ ] Email contact: `hello@langgengsea.id` _(placeholder —
      configure MX record dulu, atau ganti ke Gmail team)_.
- [ ] Phone contact: optional, skip dulu.
- [ ] Privacy policy URL: serve `store-listing/privacy-policy.md`
      via GitHub Pages atau hosting equivalent. Contoh:
      `https://ssukahisyam.github.io/Langgeng-Sea/privacy.html`.

## 8. Data Safety Form (Play Console)

- [ ] Data collected: **Tidak ada** (lihat Privacy Policy pasal 2).
- [ ] Data shared: **Tidak ada**.
- [ ] Data encrypted in transit: N/A (tidak ada transmisi data user).
- [ ] Data deletable oleh user: ya — uninstall atau Clear App Data.
- [ ] Security practices: commit ke Play Console bahwa app mengikuti
      OWASP Mobile Top 10 dasar (encrypted storage opsional, no
      plaintext credentials).
- [ ] Independent security review: N/A untuk v1.0 (catat sebagai
      roadmap v2).

## 9. Legal & Compliance

- [ ] `store-listing/privacy-policy.md` di-publish dan URL
      dimasukkan ke Play Console.
- [ ] `LICENSE` file di repo (target: MIT atau Apache 2.0 — final
      decision oleh owner).
- [ ] Semua dependency di `pubspec.yaml` lisensinya compatible
      (cek via `flutter pub deps --style=list` + manual audit BSD/
      MIT/Apache semuanya OK; no GPL yang mencemari).
- [ ] Attribution map tiles (OSM + OpenSeaMap) tampil di layar
      **About** aplikasi, bukan hanya di README.
- [ ] Attribution phosphor icons tampil di **About**.
- [ ] Font Inter (Google Fonts) — Open Font License compliance dicek
      (masuk **About**).
- [ ] Terms of Service: OPSIONAL untuk v1.0. Kalau tidak ada,
      jelaskan di **About** bahwa aplikasi gratis "as-is" tanpa
      warranty.
- [ ] Disclaimer navigasi: **"Langgeng Sea bukan aplikasi navigasi
      resmi untuk menjamin keselamatan jiwa. Jangan gunakan sebagai
      satu-satunya alat navigasi."** Wajib tampil di onboarding
      terakhir dan di About.

## 10. Release Notes (What's New)

- [ ] Play Console "What's new" field (≤ 500 char) diisi dengan
      extract dari `CHANGELOG.md` versi terkini.
- [ ] Bahasa Indonesia (primary).
- [ ] Bahasa Inggris (secondary — opsional untuk v1.0, wajib untuk
      listing en).

## 11. Submission

- [ ] Internal testing track upload pertama → invite ≥ 5 internal
      tester → smoke test 24 jam.
- [ ] Tidak ada crash baru di internal testing.
- [ ] Closed beta track upload → 20+ beta tester → minimum 1 minggu
      di lapangan.
- [ ] Semua P0/P1 bug dari beta sudah fix atau ditunda dengan
      justifikasi (file issue `v1.1`).
- [ ] Production rollout: start **staged rollout 10%** → 25% setelah
      3 hari tanpa regressi → 50% → 100% dalam 1–2 minggu.
- [ ] Play Console review lulus (biasanya 1–7 hari).

## 12. Post-Launch

### 12.1 Minggu 1
- [ ] Monitor Play Console **Vitals**: ANR rate < 0.47%, crash rate
      < 1.09%.
- [ ] Monitor Play Console **reviews** harian, balas dalam 24 jam.
- [ ] Rollback plan siap: kalau crash rate > 3% dalam 24 jam
      post-launch, halt staged rollout dan publish hotfix.

### 12.2 Minggu 2–4
- [ ] Kumpulkan feedback user riil dalam dokumen
      `.kiro/specs/langgeng-sea/v1.0-postmortem.md` (buat setelah
      minggu 2).
- [ ] Identifikasi 3 top complaint untuk v1.0.x patch.
- [ ] Prioritisasi backlog v1.1 berdasarkan usage pattern riil.

### 12.3 Governance
- [ ] Bikin issue di GitHub untuk semua TODO ditunda (`v1.1` label).
- [ ] Update `README.md` roadmap: M10 ✅ Done, tambahkan section
      **v1.1 planning**.
- [ ] Arsipkan branch `feat/m10-release` setelah merge (jangan
      delete — history audit Play Store submission).
- [ ] Share handoff doc ke next release owner kalau ada rotasi.

---

## 🆘 Emergency Rollback

Kalau production hotfix diperlukan:

1. Upload AAB dengan `versionCode` naik 1 (tidak bisa re-use).
2. Di Play Console, **Halt** staged rollout versi bermasalah.
3. Submit versi hotfix ke track **Internal** → smoke test 2 jam →
   promote ke Production dengan `full rollout` (skip staged kalau
   severity P0).
4. Post-mortem dalam 48 jam.

Play Console **tidak punya** rollback otomatis ke versi lama. Versi
bermasalah tetap di-serve user yang sudah download sampai mereka
update manual. Jadi hotfix harus cepat.

---

**Last review:** _(isi tanggal review sebelum submission)_
**Reviewer:** _(isi nama + signature GPG commit kalau ada)_
