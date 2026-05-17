import 'package:latlong2/latlong.dart';

/// Kategori marker kustom.
enum MarkerCategory {
  productive,
  hazard,
  port,
  other;

  /// Key yang disimpan di database.
  String get storageKey => name;

  /// Label yang ditampilkan di UI (Bahasa Indonesia).
  String get displayLabel => switch (this) {
        MarkerCategory.productive => 'Produktif',
        MarkerCategory.hazard => 'Karang/Bahaya',
        MarkerCategory.port => 'Pelabuhan',
        MarkerCategory.other => 'Lainnya',
      };

  /// Parse dari storage key.
  static MarkerCategory fromStorageKey(String key) {
    return MarkerCategory.values.firstWhere(
      (c) => c.storageKey == key,
      orElse: () => MarkerCategory.other,
    );
  }

  /// Parse dari nilai kategori di GPX `<lsea:marker category>` (PR #33).
  ///
  /// File ekspor PR #27 pakai value Bahasa Indonesia
  /// (`'produktif'`, `'pelabuhan'`, `'bahaya'`, `'lainnya'`) supaya
  /// human-readable kalau user buka di text editor. Saat import,
  /// kita map balik ke enum.
  ///
  /// Fallback ke [MarkerCategory.other] kalau:
  /// - File dari aplikasi GPX lain (OsmAnd, dsb) tanpa extension
  /// - Value tidak dikenal (versi Langgeng-Sea masa depan
  ///   tambah kategori baru, atau kategori sudah deprecated)
  /// - Null / empty string
  static MarkerCategory fromGpxValue(String? value) {
    if (value == null || value.isEmpty) return MarkerCategory.other;
    return switch (value.toLowerCase()) {
      'produktif' => MarkerCategory.productive,
      'pelabuhan' => MarkerCategory.port,
      'bahaya' => MarkerCategory.hazard,
      'karang' => MarkerCategory.hazard, // legacy alias
      'productive' => MarkerCategory.productive, // English fallback
      'port' => MarkerCategory.port,
      'hazard' => MarkerCategory.hazard,
      _ => MarkerCategory.other,
    };
  }
}

/// Marker kustom yang ditandai nelayan di peta.
class AppMarker {
  const AppMarker({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.notes,
    required this.createdAt,
    this.datasetId,
  });

  final String id;
  final String name;
  final MarkerCategory category;
  final double latitude;
  final double longitude;
  final String? notes;
  final DateTime createdAt;

  /// FK ke `imported_datasets.id` (PR #33). `null` = marker dibuat
  /// user sendiri di device ini. Non-null = marker hasil import.
  /// UI block tombol Edit kalau non-null; tombol Hapus tetap aktif
  /// dengan auto-cleanup empty dataset.
  final String? datasetId;

  /// True kalau marker berasal dari import GPX (bukan user sendiri).
  bool get isImported => datasetId != null;

  /// Convenience getter for flutter_map usage.
  LatLng get latLng => LatLng(latitude, longitude);

  AppMarker copyWith({
    String? name,
    MarkerCategory? category,
    double? latitude,
    double? longitude,
    String? notes,
    String? datasetId,
  }) {
    return AppMarker(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      datasetId: datasetId ?? this.datasetId,
    );
  }
}

/// Filter marker berdasarkan kategori. Jika [category] null, kembalikan semua.
List<AppMarker> filterMarkersByCategory(
  List<AppMarker> markers,
  MarkerCategory? category,
) {
  if (category == null) return markers;
  return markers.where((m) => m.category == category).toList();
}
