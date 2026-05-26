/// Domain entity untuk dataset hasil import GPX (PR #33).
///
/// Setiap file GPX yang user impor jadi satu `ImportedDataset` row
/// dengan FK ke marker / trip / haul / trackpoint child rows. User
/// dapat:
/// - Lihat semua dataset di Dataset Manager screen (Settings)
/// - Toggle visibility per dataset (mempengaruhi MapScreen filter)
/// - Hapus dataset utuh (cascade delete semua child)
/// - Filter MapScreen per file dengan checkbox di overlay panel
/// - Delete imported trip individual dari Riwayat (auto-cleanup
///   empty dataset saat child terakhir dihapus)
///
/// Persisted di tabel `imported_datasets` (schema v10) sebagai 1 row
/// per file impor. Field `marker_count` / `trip_count` / `haul_count`
/// di-denormalized untuk query cepat di Dataset Manager — di-update
/// via `ImportedDatasetRepository.recountChildren()` saat user delete
/// child individual.
class ImportedDataset {
  const ImportedDataset({
    required this.id,
    required this.fileName,
    required this.importedAt,
    required this.visible,
    required this.markerCount,
    required this.tripCount,
    required this.haulCount,
    this.exporterName,
    this.vesselName,
    this.exportedAt,
  });

  /// Unique id, di-generate saat import (UUID).
  final String id;

  /// Nama file asli (mis. "Trip Pak Hasan 25 Mei.gpx").
  final String fileName;

  /// Nama nelayan yang ekspor file (dari `<lsea:exporter><ownerName>`).
  /// Null kalau file dari aplikasi GPX lain (OsmAnd, dsb).
  final String? exporterName;

  /// Nama kapal (dari `<lsea:exporter><vesselName>`). Null untuk file
  /// dari aplikasi non-Styra.
  final String? vesselName;

  /// Timestamp ekspor (dari `<lsea:exporter><exportedAt>`). Null untuk
  /// file dari aplikasi lain.
  final DateTime? exportedAt;

  /// Saat user import file ini di device ini.
  final DateTime importedAt;

  /// Toggle visibility — kalau false, semua child (marker, trip,
  /// haul) dari dataset ini di-hide dari MapScreen, MarkersList, dan
  /// (kalau Dashboard toggle off juga) Dashboard stats.
  final bool visible;

  /// Jumlah marker yang berasal dari dataset ini. Denormalized supaya
  /// Dataset Manager card bisa tampilkan counter tanpa query terpisah.
  final int markerCount;

  /// Jumlah trip yang berasal dari dataset ini.
  final int tripCount;

  /// Jumlah haul yang berasal dari dataset ini (denormalized dari
  /// trip — sebenarnya bisa diturunkan dari trip, tapi simpan
  /// langsung supaya counter tampil tanpa join).
  final int haulCount;

  /// Label untuk header card di Dataset Manager. Kalau ada vessel
  /// name, format "{Vessel} · {filename}", else cuma filename.
  String get displayLabel =>
      vesselName != null && vesselName!.isNotEmpty
          ? '$vesselName · $fileName'
          : fileName;

  /// True kalau semua counter 0. Dipakai oleh
  /// `ImportedDatasetRepository.autoCleanupIfEmpty` untuk decide
  /// apakah dataset row harus auto-deleted setelah user hapus child
  /// terakhir.
  bool get isEmpty =>
      markerCount == 0 && tripCount == 0 && haulCount == 0;

  ImportedDataset copyWith({
    String? id,
    String? fileName,
    String? exporterName,
    String? vesselName,
    DateTime? exportedAt,
    DateTime? importedAt,
    bool? visible,
    int? markerCount,
    int? tripCount,
    int? haulCount,
  }) {
    return ImportedDataset(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      exporterName: exporterName ?? this.exporterName,
      vesselName: vesselName ?? this.vesselName,
      exportedAt: exportedAt ?? this.exportedAt,
      importedAt: importedAt ?? this.importedAt,
      visible: visible ?? this.visible,
      markerCount: markerCount ?? this.markerCount,
      tripCount: tripCount ?? this.tripCount,
      haulCount: haulCount ?? this.haulCount,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ImportedDataset &&
        other.id == id &&
        other.fileName == fileName &&
        other.exporterName == exporterName &&
        other.vesselName == vesselName &&
        other.exportedAt == exportedAt &&
        other.importedAt == importedAt &&
        other.visible == visible &&
        other.markerCount == markerCount &&
        other.tripCount == tripCount &&
        other.haulCount == haulCount;
  }

  @override
  int get hashCode => Object.hash(
        id,
        fileName,
        exporterName,
        vesselName,
        exportedAt,
        importedAt,
        visible,
        markerCount,
        tripCount,
        haulCount,
      );

  @override
  String toString() =>
      'ImportedDataset(id: $id, fileName: $fileName, '
      'visible: $visible, markers: $markerCount, '
      'trips: $tripCount, hauls: $haulCount)';
}
