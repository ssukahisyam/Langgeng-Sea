import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';

/// Pure tile-math helpers used to size an offline-map download **before**
/// we commit to fetching anything.
///
/// Uses the standard XYZ tile pyramid (Web Mercator) — same scheme OSM
/// serves, and what FMTC requests by default.
class OfflineTileMath {
  OfflineTileMath._();

  /// XYZ tile X coordinate for [lng] at [zoom].
  static int lonToTileX(double lng, int zoom) {
    final n = math.pow(2, zoom).toDouble();
    return ((lng + 180.0) / 360.0 * n).floor();
  }

  /// XYZ tile Y coordinate for [lat] at [zoom]. Clamped to the Mercator
  /// range so poles don't overflow.
  static int latToTileY(double lat, int zoom) {
    final clamped = lat.clamp(-85.05112878, 85.05112878);
    final latRad = clamped * math.pi / 180.0;
    final n = math.pow(2, zoom).toDouble();
    return ((1.0 -
                math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
            2.0 *
            n)
        .floor();
  }

  /// Tile count for a single zoom level across [bounds].
  ///
  /// Includes both endpoints, so a bounds that happens to fall on a
  /// single tile returns 1 — not 0.
  static int tilesForLevel(LatLngBounds bounds, int zoom) {
    final x1 = lonToTileX(bounds.west, zoom);
    final x2 = lonToTileX(bounds.east, zoom);
    // Tile Y grows southward (lower latitude → higher tile index).
    final y1 = latToTileY(bounds.north, zoom);
    final y2 = latToTileY(bounds.south, zoom);
    final nx = (x2 - x1).abs() + 1;
    final ny = (y2 - y1).abs() + 1;
    return nx * ny;
  }

  /// Sum of tiles across every zoom in `[minZoom, maxZoom]`.
  /// Returns 0 if the range is invalid (min > max).
  static int totalTiles(LatLngBounds bounds, int minZoom, int maxZoom) {
    if (minZoom > maxZoom) return 0;
    var total = 0;
    for (var z = minZoom; z <= maxZoom; z++) {
      total += tilesForLevel(bounds, z);
    }
    return total;
  }

  /// Rough size estimate for [totalTiles] OSM-style PNG tiles. 20 KiB
  /// per tile is the conservative average we've seen for mixed land/sea
  /// coverage on osm.org — open sea averages much less, dense coastal
  /// towns can be 30-40 KiB. Good enough for a "≈ 248 MB" preview.
  static int estimatedBytes(int tileCount, {int avgTileBytes = 20 * 1024}) {
    if (tileCount <= 0) return 0;
    return tileCount * avgTileBytes;
  }
}
