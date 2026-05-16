import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Streams the device's magnetic heading in degrees (0–360, north = 0).
///
/// Used by [BoatMarker] to rotate the boat icon when GPS speed is too
/// low for a reliable course heading (< 1.5 m/s). At sea speed the GPS
/// heading is far more accurate, so callers should prefer GPS heading
/// when `speedMps >= 1.5`.
///
/// Returns `null` on devices without a magnetometer or when the sensor
/// hasn't emitted yet — callers fall back to GPS heading in that case.
final compassHeadingProvider = StreamProvider.autoDispose<double?>((ref) {
  final stream = FlutterCompass.events;
  if (stream == null) {
    // Device has no magnetometer.
    return const Stream.empty();
  }
  return stream.map((event) => event.heading);
});
