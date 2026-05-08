# M4 — Peta Offline

Implementation notes for the M4 milestone.

## What Shipped

- **Tile caching** via `flutter_map_tile_caching` (FMTC) — the Map
  screen's OSM layer now serves from disk first, falls back to network
  second. New tiles the user browses to online are also cached.
- **"Peta Offline" screen** accessible from Settings → Peta Offline.
- **Region picker** with a framed selection overlay: user pans / zooms
  a live map underneath a fixed-inset rectangle, hits Lanjut, names
  the area and picks a zoom range, then downloads.
- **Progress UI**: per-region inline `LinearProgressIndicator` while
  the download runs; failed downloads show the error and a Retry.
- **Delete flow** reusing the existing confirm dialog.
- **Drift schema v1 → v2**: new `offline_regions` metadata table with
  `onUpgrade` migration — existing users' trips survive the bump.

## Architecture Highlights

### FMTC behind a facade

FMTC's public API has drifted between minor versions (stores, backends,
tile-provider settings have all moved). Rather than letting that churn
leak into widgets, everything goes through `TileCacheService`:

```dart
abstract class TileCacheService {
  Future<void> initialise();
  TileProvider cachedTileProvider(...);
  Stream<TileDownloadProgress> downloadRegion(OfflineRegion r);
  Future<void> cancelDownload();
  Future<int> totalCachedBytes();
}
```

The production implementation (`FmtcTileCacheService`) keeps its FMTC
imports hidden behind this interface, and consumers (map screen,
download controller) only see domain types. Swapping FMTC for another
caching library later is one-file surgery.

The service is initialised in `main()` inside a `try { ... } catch`
block so a plugin failure never blocks the app — the map still works
online, just without disk caching.

### Selection UX is framing, not handles

The prototype (Screen 13) showed a selection rectangle with visible
corner brackets. We kept the bracket visuals but **don't** let the user
drag them — instead the rectangle is a fixed inset of the viewport
(32 px horizontal, 96 px top, 300 px bottom), and the user frames the
area by panning / zooming the map under it. This is much more
forgiving on a boat that's pitching (no precise-drag targets) and
matches what apps like Organic Maps do.

Bounds are recomputed on every `onMapEvent` via `camera.pointToLatLng`
so the estimate stays live while the user pans.

### Pre-flight estimation without network calls

`OfflineTileMath.totalTiles` walks XYZ tile math for every zoom level
in the range and sums the rectangular tile counts. No FMTC dry-run,
no network — a pure Dart function the user can see the result of
**before** committing to a multi-minute download.

`estimatedBytes` assumes 20 KiB/tile. That's the average we've
observed for mixed coastal OSM PNGs; open sea averages lower (~10
KiB) and dense coastal towns push 35+ KiB. Good enough for a "≈ 250
MB" pre-flight hint; FMTC's final `cachedSize` supersedes it.

### Download lifecycle ownership

`OfflineDownloadController` is a Riverpod `Notifier<OfflineDownloadState>`
that owns:

1. Creating the `OfflineRegion` row (status: downloading) before
   FMTC starts.
2. Subscribing to the FMTC progress stream.
3. Updating the row on each meaningful tick (currently only
   on-finish, to avoid a write storm — FMTC emits up to 20 Hz).
4. Flipping status to `completed` / `failed` and persisting
   `actualTileCount` + `sizeBytes` on `onDone`.

Cancel and retry are first-class operations: partial tiles stay in
the cache (so a retry effectively resumes) and the row is marked
`failed` with a human-readable reason.

### Schema migration

Drift's `MigrationStrategy.onUpgrade` runs `m.createTable(offlineRegions)`
for users coming from v1. Since no old data needs transformation this
is a one-line migration — but bumping the version number is critical
so existing installs actually run it on first launch after update.

## Known Limitations

| Limitation | Fix in |
|---|---|
| `deleteRegionTiles` is a no-op — tiles stay in the shared FMTC store until the user clears all data from Settings | v2 (needs per-region tile tagging, which FMTC supports but adds download-time overhead) |
| Progress updates only hit the DB on-finish; the visible progress bar is driven by the in-memory controller, so a cold restart mid-download loses the progress state | M8 polish |
| Selection rectangle is fixed-aspect, fixed-size on screen. Power users can't pick a narrow strip | keep for MVP — "frame and zoom" is simpler for the target user |
| 20 KiB/tile estimate is heuristic | validate during M9 beta with real downloads |

## OSM Tile Usage Policy

A bulk download of ~14k tiles at zoom 8-14 for Selat Madura brushes up
against [OSMF's Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/).
The picker caps the maximum zoom at 16 (the policy's "heavy use"
threshold starts around z17) and the download sheet shows a "unduh
via wifi" hint. A v2 item is to swap the tile source to a dedicated
CDN (Stadia Maps, Protomaps, or self-hosted) once user count grows
past a few hundred.

## Tests

| File | What it covers |
|---|---|
| `offline_map/offline_tile_math_test.dart` | XYZ tile arithmetic (lon/lat → tile, per-level counts, total across zoom range, polar clamping, byte estimate) |
| `offline_map/offline_region_test.dart` | `humanReadableSize` bucket thresholds, status flags, `center`, `copyWith` preservation |

FMTC integration is not unit-tested — the surface is mocked in widget
tests by overriding `tileCacheServiceProvider`. Real-device smoke
testing lives in M9.
