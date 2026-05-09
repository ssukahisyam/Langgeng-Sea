# M10 — v1.0 Release Prep

**Status:** ✅ Done (code-side). Manual post-merge steps tracked in
`RELEASE_CHECKLIST.md`.
**Branch:** `feat/m10-release`

M10 is "get to Play Store" with no new end-user features. We harden the
Android release pipeline, author the store-listing copy, and publish a
checklist that an owner (possibly not the original developer) can walk
through to submit v1.0 confidently.

---

## Apa yang Dikirim (Code + Docs)

### Version bump
- `app/pubspec.yaml` → `version: 1.0.0+1`.
  `versionCode=1` reserved for first Play Store upload; subsequent
  uploads will bump the build number (`+2`, `+3`, …).

### Android release build config
- `app/android/app/build.gradle.kts` rewritten:
  - Loads signing credentials from `android/key.properties` if present,
    otherwise falls back to **debug signing** so CI can still produce
    installable artefacts.
  - `release` build type: `isMinifyEnabled = true`,
    `isShrinkResources = true`, R8 optimisation enabled, `proguard-
    android-optimize.txt` + our custom `proguard-rules.pro` applied.
  - Imports `java.util.Properties` + `FileInputStream` at the top so the
    property-file read works in Kotlin DSL without buildscript classpath
    changes.

- `app/android/app/proguard-rules.pro` authored with keeps for:
  - Flutter engine + embedding,
  - Kotlin / coroutines,
  - Drift + sqlite3_flutter_libs (tekartik + org.sqlite JNI),
  - flutter_map (pure Dart; added dontwarn for safety),
  - flutter_map_tile_caching (ObjectBox native entities + annotation
    keep),
  - phosphor_flutter,
  - Riverpod (annotation-generated classes),
  - geolocator + permission_handler (`com.baseflow.*`),
  - flutter_background_service + flutter_local_notifications,
  - Gson-style annotation reflection,
  - `EnclosingMethod,InnerClasses,SourceFile,LineNumberTable` preserved
    for readable post-obfuscation stacktraces,
  - desugar library dontwarn.

### Android manifest / resources
- `AndroidManifest.xml` `android:label` now references
  `@string/app_name` instead of a string literal — required for
  localisation and cleaner Play Console display.
- `res/values/strings.xml` defines `app_name = "Langgeng Sea"`.
- `res/values/colors.xml` + `res/values-night/colors.xml` define
  `splash_background` (#F4F8FB light / #050B18 dark) and `primary`
  (#0277BD light / #4FC3F7 dark) — matches Clean Liquid Glass design
  tokens from M0.

### .gitignore (root)
- Root `.gitignore` created (previously only `app/.gitignore` existed)
  covering:
  - OS junk (`.DS_Store`, `Thumbs.db`, `*~`, `*.swp`),
  - Editor / IDE (`.idea/`, `.vscode/`, `*.iml`),
  - **Release signing:** `key.properties` (both root and **/),
    `*.keystore`, `*.jks`,
  - Captured screenshots (`store-listing/screenshots/*.png`) — the
    `README.md` in that folder is whitelisted,
  - Local env files.

### CI/CD — release workflow
- `.github/workflows/release.yml` triggered on tag `v*.*.*`:
  - Setup JDK 17 (temurin) + Flutter 3.24.x (subosito action),
  - `flutter pub get` → `build_runner build` → `analyze` → `test`,
  - `flutter build apk --release --split-per-abi` (armeabi-v7a +
    arm64-v8a + x86_64),
  - `flutter build appbundle --release`,
  - Upload artefacts to workflow run retention (30d) AND to a GitHub
    Release created with `softprops/action-gh-release@v2`.
  - Release body documents the unsigned-CI-build caveat and points to
    CHANGELOG + RELEASE_CHECKLIST.

### Store listing
- `store-listing/privacy-policy.md` — **Indonesia-first** privacy
  policy with:
  - TL;DR ("we collect nothing"),
  - Per-permission justification (location with foreground-service
    semantics, notifications, internet-only-for-map-tiles, storage),
  - Explicit "no analytics / no ads / no third-party tracking in
    v1.0" statement,
  - Children's data section (N/A, app targets adult fishers),
  - Policy change process,
  - English summary at bottom (non-authoritative, but sufficient for
    Play Store policy reviewers).
- `store-listing/description-id.md`:
  - App title (30 char), short description (78 char), full description
    ≤ 4000 char,
  - Feature bullets with emoji + plain Indonesian,
  - Use-case narrative ("di pelabuhan → tebar → angkat → tebar lagi →
    pulang"),
  - Why-Langgeng-Sea differentiation pillars,
  - Device requirements,
  - Honest "not yet" section (SOS, cloud, iOS, geofencing) linked to
    roadmap,
  - Credits (OSM + OpenSeaMap),
  - Contact placeholders,
  - Keyword block.
- `store-listing/description-en.md` — English mirror for policy review.
- `store-listing/screenshots/README.md` — instructions for capturing
  the 5 required screenshots (Map+tracking, Haul summary, History list,
  Dashboard dark, Offline map), with exact state setup, theme mapping,
  caption suggestions, ADB demo-mode commands for emulator capture,
  and a pre-upload checklist. Actual PNG files are `.gitignore`d (the
  README itself is whitelisted).

### Release checklist (root)
- `RELEASE_CHECKLIST.md` — 12-section actionable checklist:
  1. Code Quality (CI green, analyze clean, no print() / secrets),
  2. Versioning (pubspec, tag, changelog),
  3. Android Build Configuration,
  4. **Signing** — fully manual, documented key generation +
     key.properties setup + Play App Signing enrolment, keystore
     backup policy (password manager + offline 2x copies),
  5. Build Artefacts (AAB ≤ 150 MB, bundletool verification),
  6. Testing (automated + manual QA 60+ scenarios + device matrix +
     beta feedback gates — reuse M9 artefacts),
  7. Store Listing (all Play Console fields + graphics + metadata),
  8. Data Safety Form (all "no" except user-deletable yes),
  9. Legal & Compliance (privacy policy URL, LICENSE file, dependency
     licenses audited, attribution inside app About screen, nav
     disclaimer wajib),
  10. Release Notes (Play Console "What's new"),
  11. Submission (internal → closed beta → staged rollout 10% → 25% →
      50% → 100%),
  12. Post-Launch (Vitals monitoring, review replies, rollback plan).
  Ends with an emergency rollback runbook (versionCode bump +
  halt-staged-rollout, no automatic revert).

### Changelog
- `CHANGELOG.md` — Keep-a-Changelog format, `[1.0.0]` entry lists all
  10 milestones with 1-paragraph summary each (matches M0–M9 scope
  as captured in their respective `mN-notes.md`), Highlights, Key
  Features bullet, Roadmap (v1.1 / v1.2 / v2.0), Technical Details
  (Flutter 3.24, Android SDK 26+, Clean Architecture), Known
  Limitations (unsigned CI artefacts, no crash reporter in v1.0, no
  on-device integration tests yet, no iOS).

### README updates
- Banner `🎉 v1.0 Released` at top, linking to CHANGELOG.
- Roadmap table: M10 row now ✅ Done.
- New **📦 Install APK** section with 3 options:
  - Play Store (link TBD),
  - Internal testing (beta program),
  - Direct APK from GitHub Releases (split-per-abi guidance +
    unsigned-CI-build caveat).
- "App saat ini di M0 Foundation" paragraph replaced with "App saat
  ini rilis v1.0.0 (MVP) — semua 10 milestone selesai".

---

## Keputusan Teknis

| Keputusan | Alasan |
|---|---|
| Signing key **tidak** di-generate / tidak di-commit / tidak di CI | Upload-key exposure = permanent Play Store account compromise. Manual-only keystore management is standard industry practice. CI artefacts are explicitly labeled as unsigned in both workflow output and GitHub Release body |
| Release APK fallback to debug signing when `key.properties` absent | Lets CI still produce installable-for-sideload-testing artefacts without secrets, while developers with the keystore can do local Play-ready builds via the exact same Gradle path. Alternative (hard-fail when key.properties missing) would make CI useless for smoke testing |
| R8 + shrinkResources enabled in v1.0 (not deferred) | Catches proguard rule gaps early in beta rather than at v1.0 production. APK size savings (~40% on typical Flutter app) material for users on limited data |
| ProGuard keeps listed explicitly per dependency (not just `-keep class **`) | Maintains shrinking benefit. A blanket keep-all defeats the point of minification. Each entry justified in inline comment so v1.1 devs can prune safely |
| Privacy policy in Bahasa Indonesia as authoritative, English as summary | Primary listing is Indonesia. Play Store policy team mainly reviews English for compliance, so an English summary is included but the legal doc stays in Indonesian to match the listing language and user expectations |
| `store-listing/` at repo root (not inside `app/`) | The Flutter app is in `app/` but the store listing is project-level, relevant for cross-platform expansion (iOS / Web) in future. Keeping it outside `app/` means the iOS project won't inherit Android-specific listing docs |
| Screenshot PNGs `.gitignore`d | Binary blobs with capture-date freshness — should not live in git history. Screenshots are a release artefact regenerated each submission. README in the folder stays as source of truth |
| Release workflow produces BOTH split APK and AAB | AAB = Play Store upload. Split APKs = GitHub Releases sideload for non-Play users. Building both in same workflow = one source of truth per tag |
| GitHub Release created by CI, not manually | Removes the "forgot to create release" failure mode. Manual post-tag steps stay in RELEASE_CHECKLIST; CI handles mechanical work |
| M10 notes follow same narrative style as M9 notes | Consistency for next release owner reading `.kiro/specs/langgeng-sea/*-notes.md` in sequence |

---

## Manual Steps Remaining (Gated by Release Workflow, Not Code)

These **cannot** be automated or committed to the repo — each is a
human action documented in `RELEASE_CHECKLIST.md`:

1. **Generate upload keystore** via `keytool -genkey` with RSA 4096,
   30-year validity. Store in password manager + 2 offline backups.
2. **Create `android/key.properties`** on the signing workstation
   pointing at the keystore. File is already `.gitignore`d.
3. **Enroll in Play App Signing** at first AAB upload — keeps Google
   managing distribution signing while we hold the upload key.
4. **Play Console account setup** — $25 one-time developer fee,
   business verification, bank account for the (non-existent) future
   paid apps, Data Safety form completion.
5. **Feature graphic** (1024 × 500) + **app icon** (512 × 512) — design
   task, not covered here. Store in `store-listing/graphics/` when
   designed.
6. **Screenshot capture** (5 files) per
   `store-listing/screenshots/README.md`. Requires real device trip
   data or seed dataset — the latter is a small v1.0.x TODO.
7. **Privacy policy hosting** — publish `privacy-policy.md` via GitHub
   Pages or equivalent, get stable URL, paste into Play Console.
8. **Contact email** `hello@langgengsea.id` / `privacy@langgengsea.id`
   need real mailboxes. Until domain is owned, fall back to a shared
   Gmail.
9. **Attribution screen** inside app (`/about`) — OSM + OpenSeaMap +
   phosphor + Inter font credits. Cross-reference in RELEASE_CHECKLIST
   pasal 9. Implementation deferred to v1.0.1 patch if not ready by
   production gate.
10. **Nav disclaimer** on last onboarding screen and in About — exact
    copy already in RELEASE_CHECKLIST pasal 9. Need to verify it's
    actually present in the M8-shipped onboarding.

---

## Roadmap to v1.1 (Out-of-Scope for MVP per PRD)

Features intentionally deferred from v1.0, tracked here so v1.1
planning has a starting point:

### v1.1 (target ~4–6 weeks post-MVP)

- **🆘 Tombol SOS darurat** — prominent red button, sends WhatsApp /
  SMS with current position to preconfigured family contact. Works
  offline via SMS fallback. PRD out-of-scope item promoted to v1.1.
- **Sentry integration** — real crash reporter replacing NoopCrashReporter
  from M9 observability scaffolding. Requires Play Console account
  first (for DSN provisioning separate from signing).
- **Attribution / About screen** if deferred from v1.0 production.
- **Beta feedback top-3 fix** — driven by actual user reports from
  staged rollout weeks 1–4.
- **Integration test on real emulator** under `integration_test/` with
  `reactivecircus/android-emulator-runner@v2` in CI — cover background
  service lifecycle and battery optimisation whitelist prompts.
- **drift_dev schema dump** with proper v1→v2→v3→v4→v5 migration tests
  (when v5 arrives).

### v1.2 (target ~3 months post-MVP)

- **☁️ Cloud sync / device-to-device backup** — user-owned cloud
  (Google Drive via Files API? self-hosted via .lsea.json upload?
  design decision pending). PRD out-of-scope item.
- **🛟 Geofencing & zona terlarang** — alarm when entering protected
  marine areas (data source: KKP zona konservasi). Requires offline
  polygon database + in-app alarm UX. PRD out-of-scope item.
- **Multi-vessel / multi-crew** — one app install for a koperasi with
  several kapal, per-vessel filtering on dashboard.

### v2.0 (target 6+ months post-MVP)

- **🍎 iOS version** — Flutter codebase already cross-platform; open
  questions are background location behaviour on iOS (much stricter
  than Android), App Store review for fishing / tracking apps, and
  icon / launch screen for iOS.
- **Premium paid maps** — high-res bathymetry tiles via a commercial
  provider (e.g. Navionics). Revenue model + licensing discussion
  needed.
- **English + regional language support** (Javanese, Buginese
  variants).

---

## Yang Belum Diimplementasi di M10 (Ditunda ke v1.0.1)

- **Seed dataset** `app/assets/seeds/demo.lsea.json` untuk screenshot
  capture — placeholder referenced in `store-listing/screenshots/
  README.md`. Small 1-day task; not blocking signing-key generation.
- **Feature graphic + 512px icon asset** — design task. RELEASE_CHECKLIST
  pasal 7.1 captures this as an explicit gate.
- **In-app About screen** with attribution. Might already exist from M8;
  needs verification. Added to RELEASE_CHECKLIST pasal 9 as gate.
- **GitHub Pages hosting** of privacy policy. One-liner workflow or
  manual `gh-pages` branch. Gate in RELEASE_CHECKLIST pasal 7.2.
- **`LICENSE` file** at repo root — final license choice (MIT / Apache
  2.0) is owner's decision. Gate in RELEASE_CHECKLIST pasal 9.
