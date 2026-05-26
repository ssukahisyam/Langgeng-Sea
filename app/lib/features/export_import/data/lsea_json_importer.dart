import 'dart:convert';

/// Preview data extracted from a .lsea.json file before importing.
class ImportPreview {
  const ImportPreview({
    required this.senderName,
    required this.vesselName,
    required this.haulCount,
    required this.totalDistanceMeters,
    required this.exportedAt,
    this.tripName,
  });

  /// Name of the person who exported the data.
  final String senderName;

  /// Vessel name from the exporter.
  final String vesselName;

  /// Number of hauls contained in the trip.
  final int haulCount;

  /// Total distance across all hauls (meters).
  final double totalDistanceMeters;

  /// When the file was originally exported.
  final DateTime exportedAt;

  /// Optional trip name.
  final String? tripName;
}

/// Parses and validates .lsea.json files, returning an [ImportPreview].
///
/// For MVP, only the preview is generated. Full database import
/// (persisting to a separate imported_data table) is deferred.
class LseaJsonImporter {
  /// Validate the JSON structure and return a preview.
  ///
  /// Throws [FormatException] if the format is invalid.
  ImportPreview parse(String jsonString) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (e) {
      throw const FormatException('File bukan JSON yang valid.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Format file tidak dikenali.');
    }

    final format = decoded['format'];
    if (format != 'langgeng-sea-v1' && format != 'styra-v1') {
      throw FormatException(
        'Format tidak dikenali: "$format". '
        'Hanya "langgeng-sea-v1" atau "styra-v1" yang bisa diimpor.',
      );
    }

    // Extract exportedBy
    final exportedBy = decoded['exportedBy'];
    if (exportedBy is! Map<String, dynamic>) {
      throw const FormatException('Field "exportedBy" tidak ditemukan.');
    }

    final senderName = (exportedBy['name'] as String?) ?? 'Tidak diketahui';
    final vesselName = (exportedBy['vessel'] as String?) ?? 'Tidak diketahui';

    // Extract exportedAt
    final exportedAtStr = decoded['exportedAt'] as String?;
    final exportedAt = exportedAtStr != null
        ? DateTime.tryParse(exportedAtStr) ?? DateTime.now()
        : DateTime.now();

    // Extract trip
    final trip = decoded['trip'];
    if (trip is! Map<String, dynamic>) {
      throw const FormatException('Field "trip" tidak ditemukan.');
    }

    final tripName = trip['name'] as String?;
    final hauls = trip['hauls'];
    if (hauls is! List) {
      throw const FormatException('Field "trip.hauls" tidak valid.');
    }

    final haulCount = hauls.length;
    var totalDistance = 0.0;

    for (final haul in hauls) {
      if (haul is Map<String, dynamic>) {
        final dist = haul['distanceMeters'];
        if (dist is num) {
          totalDistance += dist.toDouble();
        }
      }
    }

    return ImportPreview(
      senderName: senderName,
      vesselName: vesselName,
      haulCount: haulCount,
      totalDistanceMeters: totalDistance,
      exportedAt: exportedAt,
      tripName: tripName,
    );
  }
}
