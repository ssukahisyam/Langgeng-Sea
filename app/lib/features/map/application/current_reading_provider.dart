import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/gps_reading.dart';
import '../../../core/services/gps_service.dart';
import '../presentation/providers/location_permission_provider.dart';

/// Live stream of GPS readings, gated on the permission state.
///
/// Two subtle behaviours were missing from the original (which lived
/// in `gps_service.dart` and just subscribed to `watchPosition()`
/// unconditionally on construction):
///
/// 1. **Permission-reactive**. The original built the stream once at
///    app-launch. On a fresh install the user hasn't granted access
///    yet, so `getPositionStream()` either errored or went silent on
///    the platform side, and the stream never recovered — the user
///    had to kill + restart the app after tapping "Izinkan". Here we
///    `ref.watch(locationPermissionProvider)`: when the state flips
///    to `ready`, the provider rebuilds and a fresh
///    `watchPosition()` subscription is opened immediately. No
///    restart needed.
///
/// 2. **Fast first fix**. A cold GPS receiver can take 5-30 s on
///    Android to emit its first fix. The accuracy chip was spinning
///    for that entire window even on sessions where the OS still has
///    a perfectly good cached position from yesterday. We now yield
///    `getLastKnownReading()` first (instant) and *then* pipe the
///    live stream. Fresh-install sessions have no cache → null skip,
///    fall back to the stream — no regression.
///
/// The stream closes/re-opens automatically when permission flips
/// back to non-ready (e.g. user revokes in Settings while the app is
/// in the background); Riverpod will emit a loading/empty state for
/// the consumer and the GPS chip re-renders as "waiting".
final currentReadingProvider = StreamProvider<GpsReading>((ref) async* {
  final permState = ref.watch(locationPermissionProvider);
  if (permState != LocationPermissionState.ready) {
    // Don't even touch the platform channel when we know access
    // would be denied. Emits nothing; the AsyncValue stays in the
    // "loading" state which the GPS accuracy chip already handles.
    return;
  }

  final svc = ref.watch(gpsServiceProvider);

  // 1) Best-effort instant reading from the OS cache.
  final lastKnown = await svc.getLastKnownReading();
  if (lastKnown != null) {
    yield lastKnown;
  }

  // 2) Live stream from the receiver. `yield*` keeps the subscription
  //    alive for the lifetime of this provider; when the permission
  //    watch above re-triggers a rebuild, Riverpod cancels this
  //    generator and starts a fresh one, so the underlying platform
  //    subscription is cleaned up correctly.
  yield* svc.watchPosition();
});
