import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/offline_region_repository.dart';
import '../data/tile_cache_service.dart';
import '../domain/entities/offline_region.dart';
import '../domain/offline_tile_math.dart';

/// UI-friendly snapshot of the currently-running download.
class OfflineDownloadState {
  const OfflineDownloadState({
    this.region,
    this.progress,
    this.isCancelling = false,
  });

  /// The region being downloaded, or null when idle.
  final OfflineRegion? region;

  /// Most recent progress tick from FMTC.
  final TileDownloadProgress? progress;

  final bool isCancelling;

  bool get isActive => region != null && !isCancelling;

  OfflineDownloadState copyWith({
    OfflineRegion? region,
    TileDownloadProgress? progress,
    bool? isCancelling,
    bool clearRegion = false,
    bool clearProgress = false,
  }) =>
      OfflineDownloadState(
        region: clearRegion ? null : (region ?? this.region),
        progress: clearProgress ? null : (progress ?? this.progress),
        isCancelling: isCancelling ?? this.isCancelling,
      );
}

/// Orchestrates the full "pick bounds → download → persist metadata"
/// lifecycle. One controller instance runs at most one download at a
/// time — per-region parallelism is not needed for MVP and would
/// complicate FMTC error handling.
class OfflineDownloadController extends Notifier<OfflineDownloadState> {
  StreamSubscription<TileDownloadProgress>? _sub;
  final _uuid = const Uuid();

  @override
  OfflineDownloadState build() {
    ref.onDispose(() async {
      await _sub?.cancel();
    });
    return const OfflineDownloadState();
  }

  OfflineRegionRepository get _repo =>
      ref.read(offlineRegionRepositoryProvider);
  TileCacheService get _tiles => ref.read(tileCacheServiceProvider);

  /// Compute tile count + byte estimate for an in-progress selection.
  /// Called while the user is still dragging the bounds picker — no
  /// side effects.
  ({int tileCount, int estimatedBytes}) estimate({
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
  }) {
    final tiles = OfflineTileMath.totalTiles(bounds, minZoom, maxZoom);
    return (
      tileCount: tiles,
      estimatedBytes: OfflineTileMath.estimatedBytes(tiles),
    );
  }

  /// Queue a new region and start downloading it. The region row is
  /// persisted immediately (as `pending`) so it survives cancel/retry
  /// cycles and app restarts.
  ///
  /// PR #40 — [retina] meneruskan flag retinaMode dari live TileLayer
  /// supaya download zoom range cocok dengan apa yang nanti diminta
  /// flutter_map saat render. [downloadSeamark] mengontrol apakah
  /// layer rambu navigasi ikut di-cache (default true).
  Future<OfflineRegion> startDownload({
    required String name,
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
    bool retina = false,
    bool downloadSeamark = true,
  }) async {
    // Don't let two downloads race.
    if (state.region != null) {
      throw StateError('Another download is already running');
    }

    final estimated = OfflineTileMath.totalTiles(bounds, minZoom, maxZoom);

    final region = OfflineRegion(
      id: _uuid.v4(),
      name: name,
      bounds: bounds,
      minZoom: minZoom,
      maxZoom: maxZoom,
      status: OfflineRegionStatus.downloading,
      estimatedTileCount: estimated,
      createdAt: DateTime.now(),
    );

    await _repo.insert(region);
    state = state.copyWith(region: region);

    _sub = _tiles
        .downloadRegion(
          region,
          retina: retina,
          downloadSeamark: downloadSeamark,
        )
        .listen(
          _onProgress,
          onError: (Object e, _) => _onError(e, region),
          onDone: () => _onDone(region),
        );

    return region;
  }

  Future<void> cancelDownload() async {
    final current = state.region;
    if (current == null) return;
    state = state.copyWith(isCancelling: true);
    await _tiles.cancelDownload();
    await _sub?.cancel();
    _sub = null;

    // Keep the partial tiles in the cache (user might resume) but mark
    // the region as failed so the UI offers a retry.
    final failed = current.copyWith(
      status: OfflineRegionStatus.failed,
      lastError: 'Dibatalkan oleh pengguna',
    );
    await _repo.update(failed);

    state = const OfflineDownloadState();
  }

  /// Retry a previously-failed region. Creates a fresh download with
  /// the same bounds + zoom range.
  ///
  /// PR #40 — terima [retina] supaya retry pakai zoom range yang sama
  /// dengan first download. Caller (UI offline regions screen) pass
  /// nilai dari `RetinaMode.isHighDensity(context)`.
  Future<void> retry(
    OfflineRegion region, {
    bool retina = false,
    bool downloadSeamark = true,
  }) async {
    if (state.region != null) {
      throw StateError('Another download is already running');
    }
    final reset = region.copyWith(
      status: OfflineRegionStatus.downloading,
      lastError: null,
    );
    await _repo.update(reset);
    state = state.copyWith(region: reset);

    _sub = _tiles
        .downloadRegion(
          reset,
          retina: retina,
          downloadSeamark: downloadSeamark,
        )
        .listen(
          _onProgress,
          onError: (Object e, _) => _onError(e, reset),
          onDone: () => _onDone(reset),
        );
  }

  /// Drop the metadata row and ask the tile service to release any
  /// tiles that are only referenced by this region.
  Future<void> deleteRegion(OfflineRegion region) async {
    await _tiles.deleteRegionTiles(region);
    await _repo.delete(region.id);
  }

  // =========================================================================
  // Progress handling
  // =========================================================================

  Future<void> _onProgress(TileDownloadProgress p) async {
    final region = state.region;
    if (region == null) return;
    state = state.copyWith(progress: p);
  }

  Future<void> _onDone(OfflineRegion region) async {
    final p = state.progress;
    final updated = region.copyWith(
      status: (p?.failedTiles ?? 0) > 0 && (p?.cachedTiles ?? 0) == 0
          ? OfflineRegionStatus.failed
          : OfflineRegionStatus.completed,
      actualTileCount: p?.cachedTiles ?? 0,
      sizeBytes: p?.cachedSizeBytes ?? 0,
      lastError: (p?.failedTiles ?? 0) > 0
          ? '${p?.failedTiles} tile gagal diunduh'
          : null,
    );
    await _repo.update(updated);
    state = const OfflineDownloadState();
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _onError(Object err, OfflineRegion region) async {
    final failed = region.copyWith(
      status: OfflineRegionStatus.failed,
      lastError: err.toString(),
    );
    await _repo.update(failed);
    state = const OfflineDownloadState();
    await _sub?.cancel();
    _sub = null;
  }
}

final offlineDownloadControllerProvider =
    NotifierProvider<OfflineDownloadController, OfflineDownloadState>(
  OfflineDownloadController.new,
);
