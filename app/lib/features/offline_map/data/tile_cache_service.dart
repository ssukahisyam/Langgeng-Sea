import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../domain/entities/offline_region.dart';

/// URL templates we download / serve from cache. Kept in sync with the
/// live [TileLayer]s on the Map screen so cached tiles match exactly.
class TileEndpoints {
  const TileEndpoints._();
  static const String osm = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String openSeaMap =
      'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png';
  static const String userAgent = 'id.co.langgengsea';

  /// Name of the FMTC store yang menampung tile OSM base layer.
  static const String osmStore = 'langgeng_sea_osm';

  /// PR #40: store kedua untuk overlay seamark (rambu navigasi laut
  /// dari OpenSeaMap). Sebelumnya layer ini pakai NetworkTileProvider
  /// default — tidak pernah di-cache, jadi rambu navigasi selalu
  /// blank saat offline. Store terpisah supaya tidak saling
  /// mempengaruhi cleanup OSM base.
  static const String seamarkStore = 'langgeng_sea_seamark';
}

/// Default zoom range yang dipakai saat user download offline region.
///
/// PR #40 — sebelumnya user pilih sendiri lewat RangeSlider 3-16.
/// Sekarang hardcode supaya selalu cocok dengan kebutuhan navigasi
/// laut.
///
/// PR #41 — max zoom diturunkan dari 18 ke **16**, dan retina +1
/// compensation dihapus. Audit menemukan default 8-18 menghasilkan
/// download ±4 GB untuk area 50×50 km, dan di-double lagi jadi
/// ±17 GB di HP retina karena retinaMode minta tile zoom +1.
/// Tidak realistis untuk mobile.
///
/// Trade-off: di display zoom > 16 saat offline, tile akan
/// **stretched** dari z=16 (mild blur 2x di z=17, 4x di z=18-20).
/// User di pelabuhan saat online tetap dapat tile sharp via
/// `MapOptions.maxZoom: 20`. Untuk 50×50 km, ukuran download
/// turun dari ±4 GB ke ±280 MB — masuk akal di koneksi 4G.
class OfflineDownloadDefaults {
  const OfflineDownloadDefaults._();
  static const int minZoom = 8;
  static const int maxZoom = 16;
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

  /// Provider OSM base layer (tile.openstreetmap.org). Pakai
  /// `cacheFirst` — tile cache di-cek dulu, fallback network kalau
  /// tidak ada. Cocok untuk live map saat user mungkin online atau
  /// offline.
  TileProvider cachedTileProvider({String? userAgentPackageName});

  /// PR #40: provider seamark layer (tiles.openseamap.org/seamark).
  /// Sebelumnya layer ini pakai NetworkTileProvider default — tidak
  /// pernah cached. Sekarang routed via FMTC store terpisah supaya
  /// rambu navigasi tetap muncul saat offline.
  TileProvider cachedSeamarkTileProvider({String? userAgentPackageName});

  /// Kick off a bulk download of every tile covering [region] between
  /// its [OfflineRegion.minZoom] and [OfflineRegion.maxZoom].
  ///
  /// PR #40 — [retina] dulu menentukan apakah perlu download tile
  /// zoom `maxZoom + 1` extra supaya match dengan retinaMode di
  /// live [TileLayer].
  ///
  /// PR #41 — kompensasi retina dihapus karena melipatgandakan
  /// ukuran download (4x lebih besar). Trade-off: di display zoom >
  /// maxZoom saat retina + offline, tile akan stretched dari maxZoom.
  /// Parameter [retina] dipertahankan untuk backward compat tapi
  /// tidak lagi mengubah zoom range.
  ///
  /// [downloadSeamark] mengontrol apakah layer rambu navigasi ikut
  /// di-cache (default true).
  ///
  /// Emits progress snapshots gabungan untuk OSM + seamark. Stream
  /// closes saat semua download selesai (success atau failure).
  Stream<TileDownloadProgress> downloadRegion(
    OfflineRegion region, {
    bool retina = false,
    bool downloadSeamark = true,
  });

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

    // Ensure both stores exist. `create` is idempotent.
    await const FMTCStore(TileEndpoints.osmStore).manage.create();
    await const FMTCStore(TileEndpoints.seamarkStore).manage.create();

    _initialised = true;
  }

  @override
  TileProvider cachedTileProvider({String? userAgentPackageName}) {
    // PR #40: forward user-agent ke FMTC supaya request OSM tidak
    // ditolak rate-limiter. Sebelumnya parameter diterima tapi tidak
    // pernah dipasang ke header request.
    return const FMTCStore(TileEndpoints.osmStore).getTileProvider(
      settings: FMTCTileProviderSettings(
        behavior: CacheBehavior.cacheFirst,
      ),
      headers: {
        if (userAgentPackageName != null) 'User-Agent': userAgentPackageName,
      },
    );
  }

  @override
  TileProvider cachedSeamarkTileProvider({String? userAgentPackageName}) {
    return const FMTCStore(TileEndpoints.seamarkStore).getTileProvider(
      settings: FMTCTileProviderSettings(
        behavior: CacheBehavior.cacheFirst,
      ),
      headers: {
        if (userAgentPackageName != null) 'User-Agent': userAgentPackageName,
      },
    );
  }

  @override
  Stream<TileDownloadProgress> downloadRegion(
    OfflineRegion region, {
    bool retina = false,
    bool downloadSeamark = true,
  }) async* {
    // PR #41 — drop retina +1 compensation. Sebelumnya:
    //   final effectiveMaxZoom = retina ? region.maxZoom + 1 : ...;
    // Itu melipatgandakan ukuran download 4x untuk gain marginal
    // (tile sharp hanya di display zoom == download max). Sekarang
    // semua user dapat zoom range identik sesuai region.maxZoom.
    final effectiveMaxZoom = region.maxZoom;

    // PR #40 — inflate bounds 1 tile margin di max zoom supaya
    // keepBuffer/panBuffer di live layer tidak melewati area
    // download. Tanpa ini user yang berhenti tepat di pinggir bounds
    // dapat blank tile saat pan kecil.
    final inflatedBounds = _inflateBounds(region.bounds, effectiveMaxZoom);

    // Step 1: download base OSM layer.
    final osmStore = const FMTCStore(TileEndpoints.osmStore);
    final osmRect = RectangleRegion(inflatedBounds).toDownloadable(
      minZoom: region.minZoom,
      maxZoom: effectiveMaxZoom,
      options: TileLayer(
        urlTemplate: TileEndpoints.osm,
        userAgentPackageName: TileEndpoints.userAgent,
      ),
    );

    int osmCached = 0;
    int osmFailed = 0;
    int osmAttempted = 0;
    int osmMax = 0;
    int osmSize = 0;

    final osmStream = osmStore.download.startForeground(region: osmRect);
    await for (final p in osmStream) {
      osmCached = p.cachedTiles;
      osmFailed = p.failedTiles;
      osmAttempted = p.attemptedTiles;
      osmMax = p.maxTiles;
      osmSize = (p.cachedSize * 1024).round();

      yield TileDownloadProgress(
        attemptedTiles: osmAttempted,
        cachedTiles: osmCached,
        failedTiles: osmFailed,
        maxTiles: downloadSeamark ? osmMax * 2 : osmMax,
        cachedSizeBytes: osmSize,
      );
    }

    if (!downloadSeamark) return;

    // Step 2: download seamark overlay layer ke store terpisah.
    // Pakai zoom range yang sama (no retina compensation sejak PR #41).
    final seamarkStore = const FMTCStore(TileEndpoints.seamarkStore);
    final seamarkRect = RectangleRegion(inflatedBounds).toDownloadable(
      minZoom: region.minZoom,
      maxZoom: effectiveMaxZoom,
      options: TileLayer(
        urlTemplate: TileEndpoints.openSeaMap,
        userAgentPackageName: TileEndpoints.userAgent,
      ),
    );

    int seamarkCached = 0;
    int seamarkFailed = 0;
    int seamarkAttempted = 0;
    int seamarkSize = 0;

    final seamarkStream =
        seamarkStore.download.startForeground(region: seamarkRect);
    await for (final p in seamarkStream) {
      seamarkCached = p.cachedTiles;
      seamarkFailed = p.failedTiles;
      seamarkAttempted = p.attemptedTiles;
      seamarkSize = (p.cachedSize * 1024).round();

      yield TileDownloadProgress(
        attemptedTiles: osmAttempted + seamarkAttempted,
        cachedTiles: osmCached + seamarkCached,
        failedTiles: osmFailed + seamarkFailed,
        maxTiles: osmMax + p.maxTiles,
        cachedSizeBytes: osmSize + seamarkSize,
      );
    }
  }

  @override
  Future<void> cancelDownload() async {
    // Kedua store mungkin sedang download. cancel best-effort.
    try {
      await const FMTCStore(TileEndpoints.osmStore).download.cancel();
    } catch (_) {/* ignore */}
    try {
      await const FMTCStore(TileEndpoints.seamarkStore).download.cancel();
    } catch (_) {/* ignore */}
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
    final osm = await const FMTCStore(TileEndpoints.osmStore).stats.all;
    final seamark = await const FMTCStore(TileEndpoints.seamarkStore).stats.all;
    return ((osm.size + seamark.size) * 1024).round();
  }

  /// Inflate bounds dengan satu tile margin di [zoom] level.
  /// Dipakai supaya download menutup area sedikit lebih luas
  /// dari yang user pilih, mengkompensasi keepBuffer / panBuffer
  /// di live TileLayer yang prefetch tile sekitar viewport.
  static LatLngBounds _inflateBounds(LatLngBounds bounds, int zoom) {
    // Approx ukuran satu tile di zoom Z dalam derajat:
    // longitude: 360 / 2^Z
    // latitude: tergantung lintang, tapi untuk margin kecil bisa
    // diperkirakan dengan cos(lat) * 360 / 2^Z. Kita pakai pendekatan
    // sederhana: ambil 1 tile longitude width sebagai margin di
    // semua sisi. Cukup untuk panBuffer 1-2 di live layer.
    final tileWidth = 360.0 / math.pow(2, zoom);
    return LatLngBounds(
      LatLng(
        (bounds.south - tileWidth).clamp(-85.0, 85.0),
        (bounds.west - tileWidth).clamp(-180.0, 180.0),
      ),
      LatLng(
        (bounds.north + tileWidth).clamp(-85.0, 85.0),
        (bounds.east + tileWidth).clamp(-180.0, 180.0),
      ),
    );
  }
}

/// Riverpod binding for [TileCacheService]. Swap this in tests via
/// `tileCacheServiceProvider.overrideWithValue(FakeTileCacheService())`.
final tileCacheServiceProvider = Provider<TileCacheService>((ref) {
  return FmtcTileCacheService();
});
