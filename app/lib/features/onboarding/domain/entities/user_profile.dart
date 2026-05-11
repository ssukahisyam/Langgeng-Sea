/// Profil pengguna — nelayan + kapalnya.
///
/// Dibuat saat onboarding pertama, bisa diedit dari Pengaturan. Nilai-nilai
/// ini dibaca oleh fitur lain (misal: [trawlWidthMeters] dipakai
/// `TrackingController.startHaul` sebagai default, [vesselName] muncul di
/// top bar peta, [name] muncul di header "Pak {name}").
///
/// MVP hanya ada satu profil (single-row di database). Multi-kapal ditunda
/// ke v2.
class UserProfile {
  const UserProfile({
    required this.name,
    required this.vesselName,
    required this.trawlWidthMeters,
    required this.createdAt,
    required this.updatedAt,
    this.vesselGtOptional,
    this.homePortOptional,
  });

  /// Nama nelayan (misal: "Pak Hasan").
  final String name;

  /// Nama kapal (misal: "KM Harapan Jaya").
  final String vesselName;

  /// Gross Tonnage kapal (opsional — banyak kapal kecil tidak punya sertifikat).
  final double? vesselGtOptional;

  /// Pelabuhan asal (opsional — misal: "Brondong", "Muncar").
  final String? homePortOptional;

  /// Lebar bukaan trawl dalam meter. Default 20m (dari PRD §FR-05).
  final double trawlWidthMeters;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Default untuk field [trawlWidthMeters] bila user tidak mengubahnya.
  static const double defaultTrawlWidthMeters = 20.0;

  /// Validasi: nama & vessel wajib, trawl width harus > 0 dan < 200m.
  /// Mengembalikan null bila valid, atau pesan error Bahasa Indonesia.
  static String? validate({
    required String name,
    required String vesselName,
    required double trawlWidthMeters,
    double? vesselGt,
  }) {
    if (name.trim().isEmpty) return 'Nama nelayan wajib diisi';
    if (vesselName.trim().isEmpty) return 'Nama kapal wajib diisi';
    if (trawlWidthMeters <= 0) return 'Lebar trawl harus lebih dari 0';
    if (trawlWidthMeters > 200) return 'Lebar trawl terlalu besar (maks 200m)';
    if (vesselGt != null && vesselGt < 0) return 'GT kapal tidak boleh negatif';
    return null;
  }

  UserProfile copyWith({
    String? name,
    String? vesselName,
    double? trawlWidthMeters,
    DateTime? updatedAt,
    Object? vesselGtOptional = _sentinel,
    Object? homePortOptional = _sentinel,
  }) {
    return UserProfile(
      name: name ?? this.name,
      vesselName: vesselName ?? this.vesselName,
      trawlWidthMeters: trawlWidthMeters ?? this.trawlWidthMeters,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      vesselGtOptional: identical(vesselGtOptional, _sentinel)
          ? this.vesselGtOptional
          : vesselGtOptional as double?,
      homePortOptional: identical(homePortOptional, _sentinel)
          ? this.homePortOptional
          : homePortOptional as String?,
    );
  }

  /// Header friendly.
  String get friendlyGreeting => name;

  @override
  bool operator ==(Object other) {
    return other is UserProfile &&
        other.name == name &&
        other.vesselName == vesselName &&
        other.vesselGtOptional == vesselGtOptional &&
        other.homePortOptional == homePortOptional &&
        other.trawlWidthMeters == trawlWidthMeters &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        name,
        vesselName,
        vesselGtOptional,
        homePortOptional,
        trawlWidthMeters,
        createdAt,
        updatedAt,
      );
}

/// Sentinel so `copyWith(vesselGtOptional: null)` genuinely clears the field
/// instead of being treated as "no change".
const Object _sentinel = Object();
