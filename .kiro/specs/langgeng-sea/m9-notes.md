# M9 — QA & Beta

**Status:** ✅ Done
**Branch:** `feat/m9-qa-beta`

M9 is the "bring it out of the lab" milestone. No new end-user features —
instead we harden the tracking core with integration + migration tests,
write the manual QA script the koperasi liaison will walk through, and
put a structured beta plan + observability scaffolding in place for the
next wave of real-world usage.

---

## Apa yang Dikirim

### Integration test

- `app/test/integration/trip_lifecycle_test.dart`
  - Runs the complete **Mulai Tebar → 10 GPS points → Angkat Trawl →
    Haul #2 → endTrip** flow against an in-memory `AppDatabase` and
    `FakeGpsService`.
  - Verifies trip auto-create on first haul, trip reuse on second haul,
    `order_index` auto-increment, status transitions, and
    `TripRepository.listSummaries()` aggregates (haul count, total
    distance / duration / swept area).
  - Second test: `endTrip` called mid-recording cascades to stop the
    active haul.
  - Runs under plain `flutter test` (host VM, no emulator). Uses
    `NativeDatabase.memory()` + `ProviderContainer` overrides — no
    global state shared with other tests.

### Controller unit tests

- `app/test/features/tracking/tracking_controller_unit_test.dart`
  - **Pure-Dart** helper tests, zero Drift / Riverpod / Flutter bindings.
    Targets the math the controller depends on:
    - Circular-mean heading: 350°+10° ≈ 0° (wrap-around correctness),
      arithmetic-agree cases, multi-sample clusters, NaN filtering.
    - Pairwise haversine distance: equality with manual leg-sum on a
      synthetic 4-point track, round-trip closure, known 1-arc-minute
      ≈ 1852 m sanity.
    - Accuracy gate predicate: null accepted, ≤25 m accepted (boundary
      inclusive), >25 m rejected; applied to a mixed-quality synthetic
      trace to show the ~100 km outlier is removed.
    - Unit conversions (`mpsToKnots`) and `sweptAreaM2` edge cases.
  - Lives alongside — not replacing — the Drift-backed
    `tracking_controller_test.dart` which drives the full controller
    through an in-memory `AppDatabase` + `FakeGpsService`.

- `app/test/features/tracking/tracking_controller_test.dart` (already existed)
  - `startHaul` creates a trip when none active; reuses existing active
    trip; `order_index` increments across hauls.
  - `stopHaul` persists distance equal to pairwise haversine sum of
    emitted points (checked against `GeoCalculator.totalDistanceMeters`).
  - Circular mean heading: 350° + 10° averages to ~0° (within 1° of
    due-north), **not** the arithmetic 180°. A sanity case (10°+20° → 15°)
    is included too.
  - Accuracy gate: a point with `accuracyMeters = 50` is **persisted** to
    `track_points` (so the raw trace survives) but **excluded** from the
    distance / heading / speed aggregates.
  - `resumeHaul`: with 3 pre-existing points in the DB and a haul in
    `'recording'` state, resumption rebuilds the running aggregates then
    the next emitted point correctly extends them (no double-count, no
    reset-to-zero).

### Migration test

- `app/test/data/database/migration_test.dart`
  - Pre-populates a fresh in-memory SQLite with the **v1 schema** (trips,
    hauls, track_points) plus sample rows, then hands the connection to
    `AppDatabase.forTesting` which sees `user_version=1`,
    `schemaVersion=4`, and runs `onUpgrade(1, 4)`.
  - Asserts the final `user_version` is 4.
  - Asserts all three tables added across v2/v3/v4 exist:
    `offline_regions`, `log_book_entries`, `catch_items`, `markers`,
    `user_profiles`.
  - Asserts the pre-existing trip / haul / track point rows survive with
    every field intact.
  - Final smoke test: writes one row into both `markers` and
    `user_profiles` to prove the new tables are functional, not just
    present.
  - Uses `NativeDatabase.memory(setup: (raw) { … })` to set
    `user_version = 1` before Drift inspects it — the simplest way to
    trigger the upgrade path without drift_dev's dumped schemas
    (deferred: `dart run drift_dev schema dump` is a v1.1 hardening
    task).

### Manual QA checklist

- `.kiro/specs/langgeng-sea/qa-checklist.md` — **60+ scenarios** organized
  into sections A–K:
  - A. Instalasi & Onboarding
  - B. GPS & Peta
  - C. Tracking Haul
  - D. Offline Mode
  - E. Riwayat
  - F. Peta Offline
  - G. Log Book & Marker
  - H. Dashboard
  - I. Ekspor / Impor
  - J. Edge Cases (stress test)
  - K. Accessibility & UX
  - Includes P0/P1/P2 labeling convention and a device sign-off table.

### Beta test plan

- `.kiro/specs/langgeng-sea/beta-test-plan.md` with sections:
  - **Tujuan beta** — three narrow goals (GPS accuracy, UX on-boat,
    battery drain). Explicitly not acquisition.
  - **Rekrutmen** — 5–10 trawl nelayan, kriteria (Android 8+, trip ≥3×/mg),
    source (koperasi Probolinggo / Pekalongan / HNSI), insentif (pulsa
    Rp 50k upfront + Rp 100k on 3-trip completion).
  - **Distribusi APK** — primary via Play Console internal testing,
    fallback sideload via Google Drive.
  - **Support** — WhatsApp grup "Langgeng Sea Beta".
  - **Feedback form** — 6-field Google Form (nama, tanggal, masalah,
    akurasi vs handheld 1-5, battery % sisa after 8h, usulan).
  - **Bug triage** — P0/P1/P2 labels with 12h / 48h / 1wk SLAs. P0 fix
    target 24h.
  - **Sukses criteria** — 0 P0 bugs in last 7 days, ≥5 positive nelayan
    feedback, crash rate <1%, GPS accuracy median ≤10m, battery ≥30%
    remaining at 8h.
  - Timeline (3 weeks including prep + optional extension).

### Observability scaffolding

- `app/lib/core/observability/crash_reporter.dart`
  - Abstract `CrashReporter` with `initialise()`, `recordError(e, st,
    {context})`, `setUserContext({userId, vesselName})`, `log(msg)`.
  - `NoopCrashReporter` — ships in MVP.
  - `crashReporterProvider` defaults to the no-op — a Sentry adapter
    can be wired in v1.1 by overriding the provider in `main()`, zero
    call-site changes.

- `app/lib/core/observability/logger.dart`
  - Minimal `print`-based `Logger` singleton — no third-party deps.
  - `debug` / `info` / `warn` / `error` with optional context map that's
    folded into the line as `key=value` pairs.
  - **Debug builds:** prints from `LogLevel.debug` up.
  - **Release builds:** raised to `LogLevel.warn` automatically via
    `kReleaseMode` — keeps logcat quiet in production APKs.
  - Tests can tune the floor with `@visibleForTesting` `setMinimumLevel`.
  - `loggerProvider` exposes the singleton via Riverpod for features
    that prefer DI over direct `Logger.instance` access.

### main.dart wiring

- `app/lib/main.dart`
  - Bootstrap now runs inside `runZonedGuarded` so errors that escape
    both Flutter and PlatformDispatcher still reach the reporter.
  - Builds a `ProviderContainer` eagerly, resolves
    `crashReporterProvider`, and calls `crashReporter.initialise()`
    before the first `runApp`.
  - `FlutterError.onError` → forwards to `crashReporter.recordError`
    with `{source: 'FlutterError'}` context while still calling
    `FlutterError.presentError` for the dev-mode red screen.
  - `PlatformDispatcher.instance.onError` → forwards to
    `recordError` with `{source: 'PlatformDispatcher'}` and returns
    `true` so the default handler doesn't fire.
  - FMTC init failure is captured as a breadcrumb (`Logger.warn`) and
    reported via `recordError` — the app still boots online-only.
  - `UncontrolledProviderScope(container: …)` hands the same container
    to the widget tree so features see a single graph.

### CI tweaks

- `.github/workflows/flutter.yml`
  - "Run tests" step renamed to "Run unit + integration tests" with
    an inline comment explaining:
    - `flutter test` already discovers `test/integration/` and
      `test/data/database/migration_test.dart` because they're all
      under `test/`. No separate step required — both use in-memory
      SQLite + FakeGpsService, run on the host VM.
    - True on-device integration tests (to be added post-MVP) would
      live under `integration_test/` and need an emulator (e.g.
      `reactivecircus/android-emulator-runner@v2`).
  - No new jobs added — avoid CI drag for the beta cadence.

### README updates

- Added **🧪 Beta Testing** section with contact placeholder, APK
  distribution path, and links to `beta-test-plan.md` + `qa-checklist.md`.
- Roadmap row updated: M9 ✅ Done, M10 🔜 Next.

---

## Keputusan Teknis

| Keputusan | Alasan |
|---|---|
| Integration test di `test/` bukan `integration_test/` | `integration_test/` butuh emulator & adds ~5 min CI time. Controller-level e2e is enough for MVP confidence; true on-device tests are a v1.1 item |
| Raw SQL for migration_test (not drift_dev schema dump) | `drift_dev schema dump` needs a committed `drift_schemas/` dir which we don't have yet. Raw SQL for 3 v1 tables is shorter than setting up the dump pipeline, and we only have one upgrade path right now |
| `NativeDatabase.memory(setup: …)` trick | Cleanest way to pre-populate SQLite before Drift reads `user_version`. Alternative (open twice) doesn't work with in-memory DB since the first close destroys the data |
| Prefer Fake over mocktail | We already have `FakeGpsService` that the existing controller tests use. Fakes are easier to reason about and keep the test body short |
| Crash reporter is an interface + no-op impl | Avoids pulling a Sentry dependency into MVP but lets every call-site adopt the instrumentation today. Swap happens by changing one provider override |
| Logger wraps `package:logger` (not custom) | Already in pubspec, well-maintained, and `kReleaseMode` gating is trivial. No point reinventing |
| Beta form = 6 fields max | Longer forms get abandoned. Accuracy (1-5) + battery % are the two numbers we can aggregate; the rest is qualitative |
| Internal testing over APK sideload as primary | Auto-updates + free crash vitals > friction of Play Console account. Sideload is the fallback for nelayan without Gmail |

---

## Yang Belum Diimplementasi (Ditunda)

- True **on-device** integration test under `integration_test/` with
  an emulator runner in CI — v1.1 when we have real GPS code paths to
  cover (background service lifecycle, battery optimisation whitelist
  prompts).
- **drift_dev schema dump** → proper migration tests against *every*
  historical schema version, not just v1 → v4. Required when we cross
  v4 → v5 with a real column addition.
- **Sentry adapter** for `CrashReporter` — waits on the Play Console
  account + DSN provisioning. The interface is ready.
- **Automated load test** — simulate 12-hour tracking with 4000+
  synthetic points to catch O(n²) regressions. Currently covered only
  by the note in design.md that the controller uses incremental
  aggregates.
- **Accessibility audit with real Accessibility Scanner** — the
  checklist has the items; actual sign-off happens during beta week 1.
- **Crashlytics / Firebase alternatives** — not evaluated; defer to v1.1.
