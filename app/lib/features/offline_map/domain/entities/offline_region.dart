import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Lifecycle state of a downloaded (or in-progress) offline map region.
enum OfflineRegionStatus {
  /// Region row exists but no tiles are in the cache yet.
  pending,

  /// Download is currently running. Progress is tracked live by the
  /// tracking controller, not persisted per-tick.
  downloading,

  /// All tiles for the configured zoom range are cached.
  completed,

  /// Download failed partway through. The user can retry.
  failed,
}

/// One saved offline map region.
///
/// Owned by FMTC for the actual tile bytes; the metadata row here
/// mirrors what the user sees in "Peta Offline" so we can show size,
/// name, and download date without re-walking the tile store.
class OfflineRegion {
  const OfflineRegion({
    required this.id,
    required this.name,
    required this.bounds,
    required this.minZoom,
    required this.maxZoom,
    required this.status,
    required this.createdAt,
    this.estimatedTileCount = 0,
    this.actualTileCount = 0,
    this.sizeBytes = 0,
    this.lastError,
  });

  final String id;
  final String name;

  /// Rectangular bounding box covered by the region.
  final LatLngBounds bounds;

  final int minZoom;
  final int maxZoom;

  final OfflineRegionStatus status;

  /// Best-effort tile count based on the formula in [OfflineTileMath].
  /// Displayed before the user confirms the download.
  final int estimatedTileCount;

  /// Reported by FMTC once the download settles.
  final int actualTileCount;

  /// Cached tile storage footprint in bytes. 0 until the download
  /// completes. Shown as KB / MB / GB per [humanReadableSize].
  final int sizeBytes;

  final DateTime createdAt;
  final String? lastError;

  bool get isReady => status == OfflineRegionStatus.completed;
  bool get isInProgress => status == OfflineRegionStatus.downloading;

  OfflineRegion copyWith({
    String? name,
    OfflineRegionStatus? status,
    int? estimatedTileCount,
    int? actualTileCount,
    int? sizeBytes,
    String? lastError,
  }) {
    return OfflineRegion(
      id: id,
      name: name ?? this.name,
      bounds: bounds,
      minZoom: minZoom,
      maxZoom: maxZoom,
      status: status ?? this.status,
      createdAt: createdAt,
      estimatedTileCount: estimatedTileCount ?? this.estimatedTileCount,
      actualTileCount: actualTileCount ?? this.actualTileCount,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      lastError: lastError ?? this.lastError,
    );
  }

  /// Human-readable size suffix. Returns "— MB" when [sizeBytes] is 0.
  String humanReadableSize() {
    if (sizeBytes <= 0) return '— MB';
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Center of the region, used as the initial camera when reviewing.
  LatLng get center => LatLng(
        (bounds.north + bounds.south) / 2,
        (bounds.east + bounds.west) / 2,
      );
}
