# M3 — Trip & History

Implementation notes for the M3 milestone.

## What Shipped

- **History tab populated** — reactive list of every trip (newest first),
  grouped into per-day sections with Indonesian headers ("Kamis, 8 Mei
  2026").
- **Trip Detail screen** — hero card, multi-haul map with a distinct
  colored polyline per haul, totals strip (distance / duration / swept
  area), tappable haul list, log-book placeholder pointing to M5.
- **Haul Detail screen** — focused single-haul map + the same 5 metric
  tiles the post-recording summary sheet shows, plus a catch-list
  placeholder (M5).
- **Rename & Delete** — Options bottom sheet → Rename dialog or
  destructive confirm, wired for both trips and hauls. Still-recording
  hauls can't be edited (gentle snackbar points to the Angkat Trawl
  button).
- **Route upgrades** — detail screens sit above the shell so the bottom
  nav hides and back gestures feel native.

## Architecture Highlights

### Summary aggregation lives in the repository

`TripRepository.listSummaries()` does one `findAll()` on trips then
issues a per-trip `findByTripId()` on the haul DAO and folds the
results in-memory. At MVP scale (a few trips per day) this is way
cheaper than building a hand-written SQL `GROUP BY`, and it keeps the
repo's public surface narrow — the UI just consumes
`TripSummary` values.

### Reactive updates, cheaply

`watchSummaries()` piggybacks on the trips table stream:

```dart
_dao.watchAll().asyncMap((_) => listSummaries());
```

Haul-only edits (rename/delete) also touch the hauls table but not the
trips table, so the reactive stream only re-fires on trip-level writes.
The detail screens get freshness from their own `haulsByTripProvider`
/ `trackPointsByHaulProvider` streams, so stale list metrics never
persist on screen for long.

### Section grouping is a pure function

`groupTripsByDay()` takes a sorted list of `TripSummary` and produces a
flat `List<HistoryRow>` that `ListView` can render without nested
scrollables. Keeping it pure lets us test edge cases (midnight
straddle, same-day clustering, input-order preservation) without
touching any UI code.

### Detail routes sit at the root navigator

Moving `/trip/:id` and `/haul/:id` out of the `ShellRoute` does two
things at once: the bottom nav hides (expected on drill-down screens)
and pops restore the user to History, not Map. A custom `_slideUp`
page transition gives the Liquid Glass feel without the platform's
default swoosh.

## Known Limitations (deferred)

| Limitation | Fix in |
|---|---|
| Filter button on History is a noop | M8 polish |
| Log Book / Catch sections are placeholders | M5 |
| Share button on Trip Detail AppBar is not wired | M7 |
| Haul polylines are un-simplified (may lag for very long hauls) | M8 |

## Tests

| File | What it covers |
|---|---|
| `core/utils/formatters_m3_test.dart` | `sectionDate`, `compactDuration`, `wallClock` — zero-pad, weekday mapping, boundary cases |
| `core/utils/latlng_bounds_util_test.dart` | null for empty input, single-point inflation, every-point enclosure |
| `features/tracking/domain/trip_summary_test.dart` | `sectionDay` local-midnight normalization + midnight-straddle separation |
| `features/history/history_grouping_test.dart` | empty input, single/multi-day grouping, header-per-distinct-day, order preservation |

Drift integration tests still deferred to M9 — the value-per-ms ratio
doesn't justify the in-memory DB setup this early. The pure-Dart
coverage catches every regression we'd realistically introduce.
