import 'catch_item.dart';

/// Lingkup log book: per trip atau per haul.
enum LogBookScope { trip, haul }

/// Kondisi cuaca saat pencatatan.
enum Weather { cerah, mendung, hujan }

/// Kondisi gelombang saat pencatatan.
enum WaveCondition { tenang, sedang, tinggi }

/// Satu entri log book digital — mencatat hasil tangkap, cuaca, BBM, dsb.
class LogBookEntry {
  const LogBookEntry({
    required this.id,
    required this.scope,
    this.tripId,
    this.haulId,
    this.catches = const [],
    this.weather,
    this.wave,
    this.fuelLiters,
    this.costRupiah,
    this.crewCount,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final LogBookScope scope;
  final String? tripId;
  final String? haulId;
  final List<CatchItem> catches;
  final Weather? weather;
  final WaveCondition? wave;
  final double? fuelLiters;
  final int? costRupiah;
  final int? crewCount;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Total berat tangkapan (kg). Hanya menjumlahkan item yang punya weight.
  double get totalCatchKg {
    return catches.fold<double>(
      0,
      (sum, item) => sum + (item.weightKg ?? 0),
    );
  }

  /// Apakah ada data yang diisi (selain metadata).
  bool get hasAnyData {
    return catches.isNotEmpty ||
        weather != null ||
        wave != null ||
        fuelLiters != null ||
        costRupiah != null ||
        crewCount != null ||
        (notes != null && notes!.isNotEmpty);
  }

  LogBookEntry copyWith({
    List<CatchItem>? catches,
    Weather? weather,
    WaveCondition? wave,
    double? fuelLiters,
    int? costRupiah,
    int? crewCount,
    String? notes,
    DateTime? updatedAt,
  }) {
    return LogBookEntry(
      id: id,
      scope: scope,
      tripId: tripId,
      haulId: haulId,
      catches: catches ?? this.catches,
      weather: weather ?? this.weather,
      wave: wave ?? this.wave,
      fuelLiters: fuelLiters ?? this.fuelLiters,
      costRupiah: costRupiah ?? this.costRupiah,
      crewCount: crewCount ?? this.crewCount,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
