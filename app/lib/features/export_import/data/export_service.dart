import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../features/logbook/data/log_book_repository.dart';
import '../../../features/logbook/domain/entities/log_book_entry.dart';
import '../../../features/marker/data/marker_repository.dart';
import '../../../features/marker/domain/entities/marker.dart';
import '../../../features/onboarding/data/user_profile_repository.dart';
import '../../../features/onboarding/domain/entities/user_profile.dart';
import '../../../features/tracking/data/haul_repository.dart';
import '../../../features/tracking/data/track_point_repository.dart';
import '../../../features/tracking/data/trip_repository.dart';
import '../../../features/tracking/domain/entities/haul.dart';
import '../../../features/tracking/domain/entities/track_point.dart';
import '../../../features/tracking/domain/entities/trip.dart';
import '../domain/entities/export_filter.dart';
import 'gpx_exporter.dart';
import 'lsea_json_exporter.dart';

/// Available export formats.
enum ExportFormat { lseaJson, gpx }

/// Orchestrates the export pipeline:
/// 1. Fetch trip + hauls + track points + logbook from repositories
/// 2. Apply [ExportFilter] (tracks/markers/dateRange/tripIds/categories)
/// 3. Call the appropriate exporter (GPX with full metadata, or LSEA-JSON
///    via the legacy code path)
/// 4. Write to a temp file
/// 5. Return the [File] path for sharing
///
/// PR #27 R5 introduces the filter-aware [exportFiltered] entrypoint as
/// the new primary API. The legacy [exportTrip] remains for the
/// per-trip share flow (Phase 7) and internally builds an
/// [ExportFilter] targeting a single trip.
class ExportService {
  ExportService({
    required this.tripRepository,
    required this.haulRepository,
    required this.trackPointRepository,
    required this.logBookRepository,
    required this.markerRepository,
    required this.userProfileRepository,
  });

  final TripRepository tripRepository;
  final HaulRepository haulRepository;
  final TrackPointRepository trackPointRepository;
  final LogBookRepository logBookRepository;
  final MarkerRepository markerRepository;
  final UserProfileRepository userProfileRepository;

  final _gpxExporter = GpxExporter();
  final _lseaExporter = LseaJsonExporter();

  // ===========================================================================
  // PR #27 — primary filter-aware API
  // ===========================================================================

  /// Generate an export file according to [filter] and return the temp
  /// [File].
  ///
  /// Hanya format GPX yang di-support di filter path — LSEA-JSON
  /// tetap pakai jalur [exportTrip] per-trip lama (lihat note di
  /// dasar class). User-flow utama (ExportScreen) hanya pakai GPX.
  Future<File> exportFiltered({
    required ExportFilter filter,
  }) async {
    if (!filter.hasAnyContent) {
      throw ArgumentError(
        'ExportFilter tidak men-include konten apa pun '
        '(tracks=false, markers=false). Tidak ada yang bisa diekspor.',
      );
    }

    // 1. Fetch all data in parallel — small dataset di MVP, tidak
    //    perlu streaming.
    final results = await Future.wait<Object?>([
      _fetchFilteredTrips(filter),
      _fetchFilteredMarkers(filter),
      userProfileRepository.getProfile(),
    ]);
    final trips = results[0] as List<Trip>;
    final markers = results[1] as List<AppMarker>;
    final profile = results[2] as UserProfile?;

    // 2. Untuk setiap trip yang lolos filter, ambil haul + points-nya.
    final haulsByTrip = <String, List<Haul>>{};
    final pointsByHaul = <String, List<TrackPoint>>{};
    if (filter.includeTracks) {
      for (final trip in trips) {
        final hauls = await haulRepository.listByTrip(trip.id);
        haulsByTrip[trip.id] = hauls;
        for (final haul in hauls) {
          pointsByHaul[haul.id] =
              await trackPointRepository.getByHaul(haul.id);
        }
      }
    }

    // 3. Generate GPX content.
    final content = _gpxExporter.exportFiltered(
      filter: filter,
      exporter: profile,
      trips: trips,
      haulsByTripId: haulsByTrip,
      pointsByHaulId: pointsByHaul,
      markers: markers,
    );

    // 4. Write to temp file dengan nama yang mencerminkan filter.
    final tempDir = await getTemporaryDirectory();
    final fileName = '${filter.suggestFileName()}.gpx';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(content);
    return file;
  }

  /// Helper Riverpod-friendly preview computation. Dipakai
  /// `exportPreviewProvider` untuk men-tampilkan ringkasan
  /// "8 tarikan · 5 penanda · ≈ 250 KB" di footer ExportScreen.
  Future<ExportPreview> previewFiltered(ExportFilter filter) async {
    if (!filter.hasAnyContent) {
      return ExportPreview.empty;
    }

    final trips = await _fetchFilteredTrips(filter);
    final markers = await _fetchFilteredMarkers(filter);

    var haulCount = 0;
    var pointCount = 0;
    if (filter.includeTracks) {
      for (final trip in trips) {
        final hauls = await haulRepository.listByTrip(trip.id);
        haulCount += hauls.length;
        for (final haul in hauls) {
          pointCount += await trackPointRepository.countForHaul(haul.id);
        }
      }
    }

    final estimatedBytes = _estimateBytes(
      tripCount: trips.length,
      haulCount: haulCount,
      pointCount: pointCount,
      markerCount: markers.length,
    );

    return ExportPreview(
      tripCount: trips.length,
      haulCount: haulCount,
      pointCount: pointCount,
      markerCount: markers.length,
      estimatedBytes: estimatedBytes,
    );
  }

  // ===========================================================================
  // Legacy per-trip API (kept for backward compat — used by ExportSheet)
  // ===========================================================================

  /// Generate an export file for the given trip and return the temp [File].
  ///
  /// Untuk format GPX, internally delegates ke [exportFiltered] dengan
  /// `tripIds: {tripId}`, `includeTracks: true`, `includeMarkers:
  /// includeMarkers`. Untuk LSEA-JSON tetap pakai code-path lama
  /// (LSEA-JSON belum support filter umum).
  Future<File> exportTrip({
    required String tripId,
    required ExportFormat format,
    String? userName,
    String? vesselName,
    bool includeMarkers = true,
  }) async {
    final trip = await tripRepository.getById(tripId);
    if (trip == null) {
      throw ArgumentError('Trip dengan ID $tripId tidak ditemukan.');
    }

    if (format == ExportFormat.gpx) {
      // GPX path — pakai filter, supaya share-per-trip dapat metadata
      // lengkap termasuk lsea:exporter.
      return exportFiltered(
        filter: ExportFilter(
          includeTracks: true,
          includeMarkers: includeMarkers,
          tripIds: {tripId},
        ),
      );
    }

    // LSEA-JSON path — legacy.
    final hauls = await haulRepository.listByTrip(tripId);
    final pointsByHaul = <String, List<TrackPoint>>{};
    final logBookByHaul = <String, LogBookEntry>{};
    for (final haul in hauls) {
      pointsByHaul[haul.id] = await trackPointRepository.getByHaul(haul.id);
      final logBook = await logBookRepository.getByHaulId(haul.id);
      if (logBook != null) {
        logBookByHaul[haul.id] = logBook;
      }
    }
    final markers = includeMarkers ? await markerRepository.getAll() : <AppMarker>[];

    final profile = await userProfileRepository.getProfile();
    final resolvedUserName = userName ?? profile?.name ?? 'Nelayan';
    final resolvedVesselName = vesselName ?? profile?.vesselName ?? 'Kapal';

    final content = _lseaExporter.exportTrip(
      trip: trip,
      hauls: hauls,
      pointsByHaul: pointsByHaul,
      logBookByHaul: logBookByHaul,
      markers: markers,
      userName: resolvedUserName,
      vesselName: resolvedVesselName,
    );

    final tempDir = await getTemporaryDirectory();
    final datePart = trip.startedAt.toIso8601String().substring(0, 10);
    final tripName = trip.name?.replaceAll(RegExp(r'[^\w]'), '_') ?? 'trip';
    final fileName = 'langgeng_sea_${tripName}_$datePart.lsea.json';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(content);
    return file;
  }

  // ===========================================================================
  // Private helpers
  // ===========================================================================

  Future<List<Trip>> _fetchFilteredTrips(ExportFilter filter) async {
    if (!filter.includeTracks) return const [];

    final summaries = await tripRepository.listSummaries();
    final allTrips = summaries.map((s) => s.trip).toList();
    return allTrips.where(filter.matchesTrip).toList();
  }

  Future<List<AppMarker>> _fetchFilteredMarkers(ExportFilter filter) async {
    if (!filter.includeMarkers) return const [];
    final all = await markerRepository.getAll();
    return all.where(filter.matchesMarker).toList();
  }

  /// Estimasi ukuran file GPX dalam byte.
  ///
  /// Heuristik kasar (cukup untuk UI yang menampilkan "≈ 250 KB"):
  /// - Header + metadata (root tag, namespaces, exporter block,
  ///   summary): ≈ 2 KB.
  /// - Tiap waypoint (`<wpt>` lengkap dengan `<sym>`, `<type>`,
  ///   `<extensions>`): ≈ 0.4 KB.
  /// - Tiap haul (`<trk>` dengan `<extensions>` parent trip + haul):
  ///   ≈ 6 KB overhead struktural.
  /// - Tiap track point: ≈ 0.18 KB rata-rata (lat/lon + time +
  ///   speed + extensions).
  ///
  /// Dipotong di 8 byte minimum supaya UI tidak kasih "0 B" pada
  /// preview kosong tapi tetap tunjukkan label "≈ X KB".
  static int _estimateBytes({
    required int tripCount,
    required int haulCount,
    required int pointCount,
    required int markerCount,
  }) {
    if (tripCount == 0 && haulCount == 0 && pointCount == 0 && markerCount == 0) {
      return 0;
    }
    const baseBytes = 2048;
    final markerBytes = markerCount * 410;
    final haulBytes = haulCount * 6144;
    final pointBytes = (pointCount * 184).round();
    return baseBytes + markerBytes + haulBytes + pointBytes;
  }
}

/// Snapshot of "what would the export contain?" untuk UI preview.
///
/// `estimatedBytes` adalah heuristik kasar — file sebenarnya bisa
/// ±30% dari nilai ini. Cukup untuk UI yang menampilkan "≈ 250 KB"
/// sebagai sinyal proporsi (jangan dipakai untuk validasi quota).
class ExportPreview {
  const ExportPreview({
    required this.tripCount,
    required this.haulCount,
    required this.pointCount,
    required this.markerCount,
    required this.estimatedBytes,
  });

  final int tripCount;
  final int haulCount;
  final int pointCount;
  final int markerCount;
  final int estimatedBytes;

  static const ExportPreview empty = ExportPreview(
    tripCount: 0,
    haulCount: 0,
    pointCount: 0,
    markerCount: 0,
    estimatedBytes: 0,
  );

  bool get isEmpty => haulCount == 0 && markerCount == 0;

  /// Format estimasi ukuran file dalam unit terbaca manusia.
  /// "0 B" untuk empty preview; "12 KB" / "1.4 MB" untuk lainnya.
  String formatEstimatedSize() {
    final b = estimatedBytes;
    if (b <= 0) return '0 B';
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).round()} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

// =============================================================================
// Riverpod Provider
// =============================================================================

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(
    tripRepository: ref.watch(tripRepositoryProvider),
    haulRepository: ref.watch(haulRepositoryProvider),
    trackPointRepository: ref.watch(trackPointRepositoryProvider),
    logBookRepository: ref.watch(logBookRepositoryProvider),
    markerRepository: ref.watch(markerRepositoryProvider),
    userProfileRepository: ref.watch(userProfileRepositoryProvider),
  );
});
