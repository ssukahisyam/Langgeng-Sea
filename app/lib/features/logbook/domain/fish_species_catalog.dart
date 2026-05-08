/// Katalog jenis ikan umum tangkapan trawl Indonesia.
///
/// Digunakan sebagai saran autocomplete di form log book.
class FishSpeciesCatalog {
  FishSpeciesCatalog._();

  /// 33 nama ikan/seafood umum hasil tangkapan trawl Indonesia.
  static const List<String> presets = [
    'Bandeng',
    'Baronang',
    'Belanak',
    'Cakalang',
    'Cumi-cumi',
    'Gurita',
    'Julung-julung',
    'Kakap Merah',
    'Kakap Putih',
    'Kembung',
    'Kerapu',
    'Kerong-kerong',
    'Layang',
    'Layur',
    'Lemadang',
    'Madidihang',
    'Manyung',
    'Pari',
    'Peperek',
    'Rajungan',
    'Selar',
    'Sebelah',
    'Sotong',
    'Talang-talang',
    'Tembang',
    'Tenggiri',
    'Tengkek',
    'Teri',
    'Tongkol',
    'Tuna Sirip Biru',
    'Tuna Sirip Kuning',
    'Udang Jerbung',
    'Udang Windu',
  ];

  /// Cari jenis ikan berdasarkan query (case-insensitive, substring match).
  /// Mengembalikan semua preset yang mengandung [query].
  static List<String> search(String query) {
    if (query.isEmpty) return presets;
    final lower = query.toLowerCase();
    return presets
        .where((species) => species.toLowerCase().contains(lower))
        .toList();
  }

  /// Apakah [name] adalah salah satu preset (case-insensitive).
  static bool isPreset(String name) {
    final lower = name.toLowerCase();
    return presets.any((species) => species.toLowerCase() == lower);
  }
}
