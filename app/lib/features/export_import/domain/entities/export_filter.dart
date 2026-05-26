import '../../../marker/domain/entities/marker.dart';
import '../../../tracking/domain/entities/trip.dart';
import 'date_range.dart';

/// Konfigurasi filter untuk operasi ekspor (PR #27 R5).
///
/// 4 aksis filter independen:
///
/// 1. **Konten**: jalur tarikan saja / penanda saja / keduanya.
///    Disabling kedua-duanya menghasilkan filter "kosong" — UI HARUS
///    menonaktifkan tombol Ekspor pada state tersebut.
/// 2. **Rentang tanggal** (`null` = semua waktu): membatasi trip yang
///    `startedAt`-nya berada di rentang. Marker tidak terkena filter
///    rentang tanggal — mereka selalu ikut sepanjang user mengaktifkan
///    `includeMarkers`.
/// 3. **Trip subset** (`null` = semua trip yang lewat filter rentang):
///    pilih spesifik trip mana yang masuk. Override filter rentang
///    tanggal — kalau user pilih trip eksplisit, rentang tanggal
///    diabaikan.
/// 4. **Kategori penanda** (`null` = semua kategori): subset
///    kategori yang ikut keluar.
///
/// Filter ini value-equals (override `==` + `hashCode`) supaya bisa
/// dipakai sebagai key Riverpod `family` di
/// `exportPreviewProvider(filter)`.
class ExportFilter {
  const ExportFilter({
    required this.includeTracks,
    required this.includeMarkers,
    this.dateRange,
    this.tripIds,
    this.markerCategories,
  });

  /// Filter "Semua Data": jalur + penanda + tanpa pembatasan apa pun.
  static const ExportFilter allData = ExportFilter(
    includeTracks: true,
    includeMarkers: true,
  );

  /// Apakah jalur tarikan ikut diekspor.
  final bool includeTracks;

  /// Apakah penanda ikut diekspor.
  final bool includeMarkers;

  /// Rentang tanggal trip. `null` = tidak ada pembatasan.
  final DateRange? dateRange;

  /// Subset trip eksplisit. `null` = ikuti `dateRange` saja.
  /// Empty set valid — artinya user men-deselect semua trip dan
  /// hasilnya 0 jalur (tapi marker bisa tetap ikut).
  final Set<String>? tripIds;

  /// Subset kategori penanda. `null` = semua kategori. Empty set
  /// valid — artinya 0 marker.
  final Set<MarkerCategory>? markerCategories;

  /// Apakah kombinasi filter menghasilkan setidaknya satu kategori
  /// data ter-include. UI memakai ini untuk men-disable tombol
  /// Ekspor.
  bool get hasAnyContent => includeTracks || includeMarkers;

  /// Apakah trip [t] lewat filter ini.
  ///
  /// Aturan:
  /// - Kalau [tripIds] non-null → cek membership (override
  ///   [dateRange]).
  /// - Kalau [tripIds] null & [dateRange] non-null → cek
  ///   `dateRange.contains(t.startedAt)`.
  /// - Kalau dua-duanya null → semua trip lewat.
  ///
  /// Catatan: trip yang mulai dalam rentang tapi selesai di luar
  /// TETAP masuk — kita potong di [Trip.startedAt] (PR #27 R5
  /// "correctness properties").
  bool matchesTrip(Trip t) {
    final ids = tripIds;
    if (ids != null) {
      return ids.contains(t.id);
    }
    final r = dateRange;
    if (r != null) {
      return r.contains(t.startedAt);
    }
    return true;
  }

  /// Apakah marker [m] lewat filter ini.
  ///
  /// Hanya kategori yang dicek; rentang tanggal & trip subset
  /// tidak berpengaruh ke marker (marker tidak punya konsep "trip
  /// parent"; mereka global, sesuai keputusan tim).
  bool matchesMarker(AppMarker m) {
    final cats = markerCategories;
    if (cats == null) return true;
    return cats.contains(m.category);
  }

  /// String human-readable yang dimasukkan ke
  /// `<lsea:filterDescription>` di metadata GPX, supaya penerima
  /// tahu file ini hasil filter mana.
  String describe() {
    final parts = <String>[];

    // Konten.
    if (includeTracks && includeMarkers) {
      parts.add('Jalur + Penanda');
    } else if (includeTracks) {
      parts.add('Jalur saja');
    } else if (includeMarkers) {
      parts.add('Penanda saja');
    } else {
      parts.add('Tidak ada konten');
    }

    // Rentang tanggal — hanya disebut kalau user belum pilih trip
    // eksplisit (karena tripIds override).
    if (tripIds != null) {
      parts.add('${tripIds!.length} trip dipilih');
    } else if (dateRange != null) {
      parts.add(dateRange!.describeIndonesian());
    } else {
      parts.add('Semua waktu');
    }

    // Kategori penanda.
    if (includeMarkers) {
      if (markerCategories == null) {
        parts.add('Semua kategori');
      } else {
        final labels = markerCategories!
            .map((c) => c.displayLabel)
            .toList()
          ..sort();
        parts.add(labels.isEmpty ? 'Tanpa kategori' : labels.join(', '));
      }
    }

    return parts.join(' · ');
  }

  /// Saran nama file (tanpa direktori, tanpa ekstensi).
  ///
  /// Kombinasi filter umum diberi label pendek; sisanya pakai prefix
  /// `styra_` + tanggal hari ini.
  String suggestFileName({DateTime? now}) {
    final ref = now ?? DateTime.now();
    final today = _isoDate(ref);

    String contentSlug;
    if (includeTracks && includeMarkers) {
      contentSlug = 'lengkap';
    } else if (includeTracks) {
      contentSlug = 'jalur';
    } else if (includeMarkers) {
      contentSlug = 'penanda';
    } else {
      contentSlug = 'kosong';
    }

    String? rangeSlug;
    if (tripIds != null) {
      rangeSlug = '${tripIds!.length}trip';
    } else if (dateRange != null) {
      // Rentang custom ke notasi tanggal "from-to".
      final inclusiveEnd =
          dateRange!.end.subtract(const Duration(milliseconds: 1));
      final s = _isoDate(dateRange!.start);
      final e = _isoDate(inclusiveEnd);
      // Heuristik untuk preset 7 hari / 30 hari / hari ini.
      final spanDays = dateRange!.end
          .difference(dateRange!.start)
          .inDays;
      if (spanDays == 1 && _sameDay(dateRange!.start, ref)) {
        rangeSlug = 'hari-ini';
      } else if (spanDays == 7) {
        rangeSlug = '7hari';
      } else if (spanDays == 30) {
        rangeSlug = '30hari';
      } else {
        rangeSlug = '${s}_$e';
      }
    }

    final pieces = <String>['styra', contentSlug];
    if (rangeSlug != null) pieces.add(rangeSlug);
    pieces.add(today);
    return pieces.join('_');
  }

  static String _isoDate(DateTime t) {
    final y = t.year.toString().padLeft(4, '0');
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  ExportFilter copyWith({
    bool? includeTracks,
    bool? includeMarkers,
    DateRange? dateRange,
    Set<String>? tripIds,
    Set<MarkerCategory>? markerCategories,
    bool clearDateRange = false,
    bool clearTripIds = false,
    bool clearMarkerCategories = false,
  }) {
    return ExportFilter(
      includeTracks: includeTracks ?? this.includeTracks,
      includeMarkers: includeMarkers ?? this.includeMarkers,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      tripIds: clearTripIds ? null : (tripIds ?? this.tripIds),
      markerCategories: clearMarkerCategories
          ? null
          : (markerCategories ?? this.markerCategories),
    );
  }

  // ===========================================================================
  // Equality (penting untuk Riverpod family caching).
  // ===========================================================================

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ExportFilter) return false;
    return includeTracks == other.includeTracks &&
        includeMarkers == other.includeMarkers &&
        dateRange == other.dateRange &&
        _setEquals(tripIds, other.tripIds) &&
        _setEquals(markerCategories, other.markerCategories);
  }

  @override
  int get hashCode => Object.hash(
        includeTracks,
        includeMarkers,
        dateRange,
        tripIds == null
            ? null
            : Object.hashAllUnordered(tripIds!),
        markerCategories == null
            ? null
            : Object.hashAllUnordered(markerCategories!),
      );

  static bool _setEquals<T>(Set<T>? a, Set<T>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final x in a) {
      if (!b.contains(x)) return false;
    }
    return true;
  }

  @override
  String toString() => 'ExportFilter(${describe()})';
}
