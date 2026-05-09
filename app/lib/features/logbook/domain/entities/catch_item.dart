/// Satu item tangkapan dalam log book entry.
class CatchItem {
  const CatchItem({
    required this.id,
    required this.species,
    this.weightKg,
  });

  /// Unique identifier (UUID).
  final String id;

  /// Nama jenis ikan/seafood.
  final String species;

  /// Berat dalam kilogram (opsional).
  final double? weightKg;

  CatchItem copyWith({
    String? species,
    double? weightKg,
  }) {
    return CatchItem(
      id: id,
      species: species ?? this.species,
      weightKg: weightKg ?? this.weightKg,
    );
  }
}
