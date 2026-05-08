# M1 — Core Map & GPS

Implementation notes for the M1 milestone (delivered in PR #4).

## What Shipped

- **flutter_map** integrated with OSM base layer + OpenSeaMap nautical overlay.
- **GpsService** abstraction over `geolocator` with a Riverpod `StreamProvider`.
- **Permission flow** via a glass bottom sheet that explains *why* we need GPS.
- **Boat marker** that rotates with heading (when vessel is moving) and shows
  a pulsing halo; turns red when tracking (ready for M2).
- **GPS accuracy chip** with 3-tier color coding per PRD FR-03.9.
- **Error banner** surfaces service-off / permission-denied / blocked states.
- **Map controls** (center-on-me FAB) with auto-follow behavior.
- **Attribution** widget meeting OSM + OpenSeaMap ToS.
- **Formatters** utility (distance, knots, heading, duration, accuracy).

## Architecture Highlights

- `GpsService` is abstract so `FakeGpsService` can drive widget tests.
- The service is exposed through `gpsServiceProvider`, consumers only touch
  `currentReadingProvider` (stream) or the permission controller.
- `BoatMarker` is self-contained — given a `GpsReading`, it renders itself.
- `MapScreen` owns the `MapController` and follow-camera UX.

## Known Limitations (resolved in later milestones)

| Limitation | Fix in |
|---|---|
| No tile caching (fails offline) | M4 via FMTC |
| Tracking button is a placeholder | M2 |
| No compass/heading-up mode | polish (optional) |
| User-Agent not yet customized with app version | M8 polish |

## OSM Tile Usage Policy Compliance

- `userAgentPackageName` set to `id.co.langgengsea` per
  [operations.osmfoundation.org/policies/tiles/](https://operations.osmfoundation.org/policies/tiles/).
- Attribution visible on-screen.
- Tile zoom capped at 18 to avoid over-fetching.
- M4 caching will further reduce load on OSMF tile servers.

## Manual Test Plan

1. First launch with permission not granted → permission sheet appears.
2. Deny permission → error banner visible with retry CTA.
3. Grant permission → chip turns green, boat icon appears.
4. Drag map → auto-follow pauses.
5. Tap center-on-me → map recenters and resumes following.
6. Toggle airplane mode → existing tiles may stay cached briefly; new panes
   show blank (expected until M4).
