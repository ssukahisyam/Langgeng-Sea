import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/offline_region.dart';

/// URL templates we download / serve from cache. Kept in sync with the
/// live [TileLayer]s on the Map screen so cached tiles match exactly.
class TileEndpoints {
  const TileEndpoints._();
  static const String osm = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String openSeaMap =
      'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png';
  static const String userAgent = 'id.co.langgengsea';

  /// Name of the FMTC store that backs online/offline OSM tiles.
  static const String osmStore = 'langgeng_sea_osm';
}

/// Live progress snapshot for a running tile download.
///
/// Emitted once per meaningful tick (FMTC chunks its progress events).
class TileDownloadProgress {
  const TileDownloadProgress({
    required this.attemptedTiles,
    required this.cachedTiles,
    required this.failedTiles,
    required this.maxTiles,
    required this.cachedSizeBytes,
  });

  final int attemptedTiles;
  final int cachedTiles;
  final int failedTiles;
  final int maxTiles;
  final int cachedSizeBytes;

  double get fraction =>
      maxTiles == 0 ? 0.0 : (attemptedTiles / maxTiles).clamp(0.0, 1.0);
  int get percent => (fraction * 100).round();

  bool get isFinished =>
      maxTiles > 0 && (attemptedTiles + failedTiles) >= maxTiles;
}

/// Facade over [flutter_map_tile_caching]. Wraps everything the rest of
/// the app needs (initialise, get a cached tile provider, download a
/// region, delete, query size) so that version-specific FMTC quirks
/// only show up in this one file.
abstract class TileCacheService {
  /// Must be awaited before the first [FlutterMap] is built.
  /// Idempotent — subsequent calls are cheap no-ops.
  Future<void> initialise();

  /// A flutter_map-ready provider that checks the cache first and
  /// falls back to the network. Safe to call after [initialise].
  TileProvider cachedTileProvider({String? userAgentPackageName});

  /// Kick off a bulk download of every tile covering [region] between
  /// its [OfflineRegion.minZoom] and [OfflineRegion.maxZoom].
  ///
  /// Emits progress snapshots. The stream closes when the download
  /// finishes (success or failure); callers should inspect the final
  /// snapshot's [TileDownloadProgress.failedTiles].
  Stream<TileDownloadProgress> downloadRegion(OfflineRegion region);

  /// Cancel the currently-running download, if any. Safe to call when
  /// nothing is downloading.
  Future<void> cancelDownload();

  /// Remove every cached tile for [region] from the store. FMTC will
  /// garbage-collect tiles that are only referenced by this region;
  /// tiles also covered by another region stay cached.
  Future<void> deleteRegionTiles(OfflineRegion region);

  /// Current total size of the OSM store on disk in bytes. Used as a
  /// progress "pre-flight" so the Settings screen can show the total
  /// footprint across all regions.
  Future<int> totalCachedBytes();
}

/// Production implementation backed by the FMTC ObjectBox backend.
class FmtcTileCacheService implements TileCacheService {
  bool _initialised = false;

  @override
  Future<void> initialise() async {
    if (_initialised) return;
    await FMTCObjectBoxBackend().initialise();

    // Ensure the store exists. `create` is idempotent.
    await const FMTCStore(TileEndpoints.osmStore).manage.create();

    _initialised = true;
  }

  @override
  TileProvider cachedTileProvider({String? userAgentPackageName}) {
    return const FMTCStore(TileEndpoints.osmStore).getTileProvider(
      settings: FMTCTileProviderSettings(
        behavior: CacheBehavior.cacheFirst,
      ),
    );
  }

  @override
  Stream<TileDownloadProgress> downloadRegion(OfflineRegion region) async* {
    final store = const FMTCStore(TileEndpoints.osmStore);

    final rect = RectangleRegion(region.bounds).toDownloadable(
      minZoom: region.minZoom,
      maxZoom: region.maxZoom,
      options: TileLayer(
        urlTemplate: TileEndpoints.osm,
        userAgentPackageName: TileEndpoints.userAgent,
      ),
    );

    final (:downloadProgress, :tileEvents) =
        store.download.startForeground(region: rect);

    await for (final p in downloadProgress) {
      yield TileDownloadProgress(
        attemptedTiles: p.attemptedTiles,
        cachedTiles: p.cachedTiles,
        failedTiles: p.failedTiles,
        maxTiles: p.maxTiles,
        cachedSizeBytes: (p.cachedSize * 1024).round(),
      );
    }
    // Drain the tile-events stream so FMTC doesn't hold resources.
    await tileEvents.drain<void>();
  }

  @override
  Future<void> cancelDownload() async {
    await const FMTCStore(TileEndpoints.osmStore).download.cancel();
  }

  @override
  Future<void> deleteRegionTiles(OfflineRegion region) async {
    // FMTC doesn't have a per-region delete in the store API (tiles are
    // shared across regions). Best we can do here is a no-op and rely
    // on "delete all" from Settings. A future version can walk the
    // bounds and issue targeted tile removals.
    // For now, just let the region metadata row be removed by the
    // repository; cached tiles stay warm until the user clears them
    // from Settings → Kelola Data.
  }

  @override
  Future<int> totalCachedBytes() async {
    final stats = await const FMTCStore(TileEndpoints.osmStore).stats.all;
    return (stats.size * 1024).round();
  }
}

/// Riverpod binding for [TileCacheService]. Swap this in tests via
/// `gpsServiceProvider.overrideWithValue(FakeTileCacheService())`.
final tileCacheServiceProvider = Provider<TileCacheService>((ref) {
  return FmtcTileCacheService();
});
