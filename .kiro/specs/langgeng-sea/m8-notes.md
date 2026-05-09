# M8 — Onboarding & UI Polish

**Status:** ✅ Done
**Branch:** `feat/m8-onboarding-polish`

---

## Apa yang Dikirim

### Fitur Baru

1. **UserProfile entity** (`features/onboarding/domain/entities/user_profile.dart`)
   - Fields: `name`, `vesselName`, `vesselGtOptional`, `homePortOptional`,
     `trawlWidthMeters` (default 20m), `createdAt`, `updatedAt`
   - `UserProfile.validate(...)` returns Bahasa Indonesia error string or null
   - `copyWith` uses a sentinel so callers can genuinely clear nullable
     fields (`vesselGtOptional: null` vs "no change")
   - `friendlyGreeting` → "Pak {name}" shown in map top bar

2. **`user_profiles` table + DAO** (schema v4)
   - Single-row invariant (id fixed to `UserProfileDao.kProfileRowId = 1`)
   - `getProfile()`, `watchProfile()` (reactive), `upsertProfile()`,
     `deleteProfile()`
   - Migration v3 → v4 simply runs `createTable(userProfiles)` — nothing
     in the old schema needs rewriting

3. **UserProfileRepository + providers**
   - `userProfileProvider` (StreamProvider) — drives UI reactivity
   - `userProfileFutureProvider` — one-shot variant for boot gating
   - Write path: `saveProfile(...)` preserves `createdAt`, always updates
     `updatedAt`, normalizes empty strings to `null` for home port

4. **Onboarding screen** (`onboarding_screen.dart`)
   - 3-slide PageView matching prototype screen 08
   - Slide 1: "Jejak Setia di Lautan" welcome
   - Slide 2: "Tracking Offline" value prop
   - Slide 3: "Multi-Haul Per Trip" differentiator
   - Dots indicator animates width on active slide
   - Skip jumps straight to profile form
   - Ambient background with soft radial blobs (matches Glass theme)

5. **ProfileFormScreen** (first-run) + **ProfileEditScreen** (from Settings)
   - Share a single `ProfileForm` widget to guarantee identical behavior
   - Fields: name*, vessel name*, GT (opt), trawl width (default 20),
     home port (opt)
   - "Simpan & Mulai" navigates to map on first-run; "Simpan Perubahan"
     pops on edit
   - Validation surfaced via snackbar + per-field `TextFormField.validator`

6. **Settings profile card** — now tappable, shows real data:
   - Title: vesselName (or "Profil Belum Diisi")
   - Subtitle: "Pak {name} • GT X • Home Port"
   - Trawl width tile also reads from profile and is tappable

7. **MapScreen top bar**
   - Replaces hardcoded "KM Belum Diisi" with `profile.vesselName`
   - Subtitle is `profile.friendlyGreeting` ("Pak {name}")
   - Fallback to placeholder if profile somehow null

8. **TrackingController.startHaul**
   - `MapScreen` now reads `trawlWidthMeters` from `userProfileProvider`
     before calling `startHaul(trawlWidthMeters: ...)`
   - Controller signature unchanged (keeps existing unit tests valid)

9. **Onboarding redirect gate**
   - Implemented inside `appRouterProvider` via GoRouter's
     `refreshListenable` + `redirect` hook (no nested Navigators)
   - Profile null → force to `/onboarding`
   - Profile present → redirect away from `/onboarding` and `/onboarding/profile`
   - Initial load (AsyncLoading) → stay put so the splash doesn't flicker

### Infrastruktur

- **Router** converted from a top-level `final appRouter` to
  `appRouterProvider` so redirects can watch Riverpod state
- **Routes added:** `/onboarding`, `/onboarding/profile`, `/profile/edit`
- **`app.dart`** now does `ref.watch(appRouterProvider)`
- All imports cleaned up; no circular dependencies

### Polish Checklist

| NFR / Requirement | Status | Notes |
|---|---|---|
| NFR-03 buttons ≥ 60dp | ✅ | `PrimaryActionButton` already enforces 60–72dp |
| a11y Semantics labels | ✅ | Added to onboarding Lewati/Lanjut, all form fields, Settings profile card |
| Body text ≥ 16sp | ✅ | `bodyLarge` is 16sp; onboarding body uses `bodyLarge` |
| Empty states | ✅ | History + Markers already had empty states (kept as-is) |
| Bahasa Indonesia copy | ✅ | All user-visible strings in Bahasa Indonesia |

### Unit Tests

- `test/features/onboarding/user_profile_test.dart` — 13 tests:
  - `validate()` happy path + all error branches
  - `copyWith` changes named fields, preserves createdAt
  - `copyWith(vesselGtOptional: null)` genuinely clears (sentinel)
  - `copyWith(homePortOptional: null)` genuinely clears
  - `friendlyGreeting` format
  - Equality / hashCode
  - Default trawl width constant

---

## Keputusan Teknis

| Keputusan | Alasan |
|---|---|
| Single-row table (id = 1) | MVP hanya mendukung satu profil. Memulai dengan satu baris adalah invariant terkuat — onboarding tidak bisa "race" dan bikin dua row |
| Sentinel object di `copyWith` untuk nullable | Dart tidak bisa bedakan `copyWith(gt: null)` (clear) vs tidak disebut sama sekali. Sentinel adalah pattern standar |
| Redirect gate via GoRouter (bukan nested Navigator) | Menjaga semua navigasi tetap di satu router; no context collision antara "sudah onboarding" dan "belum" |
| `ProfileForm` shared widget | Sama-sama dipakai first-run dan edit. Perubahan validasi/label cukup di satu tempat |
| Trawl width ke profil (bukan hardcoded di controller) | Read-at-call-site di `MapScreen` agar `TrackingController` tetap pure (tes tidak perlu mock profile) |

---

## Yang Belum Diimplementasi (Ditunda)

- Multi-kapal / multi-profil (v2: perlu selector + migration ke primary
  key baru)
- Avatar / foto kapal (v2)
- Reset onboarding dari UI (hanya lewat uninstall; debug-only path di
  repo `deleteProfile()` sudah ada)
- Validasi GT terhadap nomor registrasi (v2: butuh integrasi KKP)
