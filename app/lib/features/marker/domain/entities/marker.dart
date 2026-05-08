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
  });

  final String id;
  final String name;
  final MarkerCategory category;
  final double latitude;
  final double longitude;
  final String? notes;
  final DateTime createdAt;

  /// Convenience getter for flutter_map usage.
  LatLng get latLng => LatLng(latitude, longitude);

  AppMarker copyWith({
    String? name,
    MarkerCategory? category,
    double? latitude,
    double? longitude,
    String? notes,
  }) {
    return AppMarker(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
      createdAt: createdAt,
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
