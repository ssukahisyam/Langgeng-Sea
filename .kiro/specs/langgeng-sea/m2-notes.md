# M2 — Haul Tracking

Implementation notes for the M2 milestone.

## What Shipped

- **Drift database** with 3 tables (`trips`, `hauls`, `track_points`) +
  FK cascade delete so removing a trip cleans up everything beneath it.
- **Domain layer**: pure-Dart `Trip`, `Haul`, `TrackPoint`, `HaulMetrics`
  entities — no codegen dependency for the values themselves.
- **Repositories** map between Drift rows and domain entities.
- **TrackingController** (Riverpod `Notifier`) owns the full Mulai →
  Angkat lifecycle, live metric aggregation, and crash-recovery flows.
- **Live UI** on Map screen: RecordingBanner, LiveStatsPanel, colored
  polyline, red boat marker, HaulSummarySheet with editable name.
- **Crash recovery dialog** on cold start when an orphan "recording"
  haul is found.

## Architecture Highlights

### Incremental metric aggregates

Rather than recomputing every metric from the full point list on each GPS
tick, the controller holds running sums:

| Aggregate | State |
|---|---|
| Distance | `_distanceMeters += haversine(lastPoint, newPoint)` |
| Circular-mean heading | `_sumSin += sin(r)`, `_sumCos += cos(r)`, `_headingCount++` |
| Average speed | `_sumSpeedMps += speed`, `_speedCount++` |

This keeps per-tick CPU flat for 12-hour trips (~4000 points at 10 s
interval). The summary screen can recompute from raw points later if
needed (e.g. for higher-fidelity swept-area polygons in v2).

### Accuracy gate

Fixes with `accuracy > 25 m` are **persisted** (so the raw trace is
preserved) but **excluded** from the metric aggregates. This prevents a
bad fix from distorting the displayed distance/speed.

### Stop-without-ending-trip

Tapping **Angkat Trawl** stops the haul but leaves the trip active, so
the user can immediately tap **Mulai Tebar** again for the next haul of
the same trip. The summary sheet has explicit **Haul Berikutnya** /
**Akhiri Trip** CTAs to make this obvious.

### Crash recovery

On the first frame after cold start, we call
`HaulRepository.getRecording()`. If it returns a haul, we show a dialog:

- **Lanjutkan** → `resumeHaul` rebuilds aggregates from existing DB
  points and re-subscribes to the GPS stream.
- **Akhiri sekarang** → `finalizeRecoveredHaul` computes final metrics
  from whatever points are there and stamps status=completed.

## Known Limitations (handled later)

| Limitation | Fix in |
|---|---|
| No foreground service yet — tracking pauses if OS kills the app | late M2 patch / M8 |
| Log Book button in summary shows a "coming in M5" snackbar | M5 |
| No polyline simplification → long hauls may get janky to render | M8 polish |
| Swept area is linear approximation | v2 |

## Tests

| File | What it covers |
|---|---|
| `core/utils/geo_calculator_test.dart` | Haversine edge cases, circular mean across 0°/360°, swept area, m/s↔knots |
| `features/tracking/domain/haul_test.dart` | `displayName` fallback, status, `copyWith` preservation |
| `features/tracking/domain/haul_metrics_test.dart` | Empty state, `copyWith` null handling |

Drift integration tests deferred to M9 (in-memory NativeDatabase works
but noticeably slows CI; the plain-Dart DAO mappers are covered
indirectly by the entity tests).
