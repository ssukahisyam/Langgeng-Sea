import 'package:drift/drift.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/database/tables.dart';
import '../domain/entities/offline_region.dart';

/// Pure Drift-row ↔ [OfflineRegion] mapping. Isolated so the domain
/// layer stays DB-agnostic.
class OfflineRegionMapper {
  const OfflineRegionMapper._();

  static OfflineRegion fromRow(OfflineRegionRow r) => OfflineRegion(
        id: r.id,
        name: r.name,
        bounds: LatLngBounds(
          LatLng(r.south, r.west),
          LatLng(r.north, r.east),
        ),
        minZoom: r.minZoom,
        maxZoom: r.maxZoom,
        status: _statusFromString(r.status),
        createdAt: r.createdAt,
        estimatedTileCount: r.estimatedTileCount,
        actualTileCount: r.actualTileCount,
        sizeBytes: r.sizeBytes,
        lastError: r.lastError,
      );

  static OfflineRegionsCompanion toInsertCompanion(OfflineRegion r) =>
      OfflineRegionsCompanion.insert(
        id: r.id,
        name: r.name,
        north: r.bounds.north,
        south: r.bounds.south,
        east: r.bounds.east,
        west: r.bounds.west,
        minZoom: r.minZoom,
        maxZoom: r.maxZoom,
        status: _statusToString(r.status),
        estimatedTileCount: Value(r.estimatedTileCount),
        actualTileCount: Value(r.actualTileCount),
        sizeBytes: Value(r.sizeBytes),
        lastError: Value(r.lastError),
        createdAt: r.createdAt,
        updatedAt: DateTime.now(),
      );

  static OfflineRegionsCompanion toUpdateCompanion(OfflineRegion r) =>
      OfflineRegionsCompanion(
        name: Value(r.name),
        status: Value(_statusToString(r.status)),
        estimatedTileCount: Value(r.estimatedTileCount),
        actualTileCount: Value(r.actualTileCount),
        sizeBytes: Value(r.sizeBytes),
        lastError: Value(r.lastError),
        updatedAt: Value(DateTime.now()),
      );
}

OfflineRegionStatus _statusFromString(String s) {
  switch (s) {
    case 'downloading':
      return OfflineRegionStatus.downloading;
    case 'completed':
      return OfflineRegionStatus.completed;
    case 'failed':
      return OfflineRegionStatus.failed;
    case 'pending':
    default:
      return OfflineRegionStatus.pending;
  }
}

String _statusToString(OfflineRegionStatus s) {
  switch (s) {
    case OfflineRegionStatus.pending:
      return 'pending';
    case OfflineRegionStatus.downloading:
      return 'downloading';
    case OfflineRegionStatus.completed:
      return 'completed';
    case OfflineRegionStatus.failed:
      return 'failed';
  }
}
