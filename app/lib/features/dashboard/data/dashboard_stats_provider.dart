import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';

/// Period filter for the dashboard aggregation.
enum DashboardPeriod { today, week7, month30, total }

/// Daily catch data point for bar chart.
class DailyCatch {
  const DailyCatch({required this.date, required this.kg});
  final DateTime date;
  final double kg;
}

/// Aggregated stats for the selected period.
class DashboardStats {
  const DashboardStats({
    this.tripCount = 0,
    this.haulCount = 0,
    this.totalDistanceMeters = 0,
    this.totalDurationSeconds = 0,
    this.totalSweptAreaM2 = 0,
    this.totalCatchKg = 0,
    this.totalFuelLiters = 0,
    this.dailyCatches = const [],
    this.topSpots = const [],
  });

  final int tripCount;
  final int haulCount;
  final double totalDistanceMeters;
  final int totalDurationSeconds;
  final double totalSweptAreaM2;
  final double totalCatchKg;
  final double totalFuelLiters;
  final List<DailyCatch> dailyCatches;
  final List<TopSpot> topSpots;

  bool get isEmpty => tripCount == 0 && haulCount == 0;
}

/// A ranked spot (haul name + total catch kg).
class TopSpot {
  const TopSpot({required this.name, required this.catchKg});
  final String name;
  final double catchKg;
}

/// Currently selected period for the dashboard.
final dashboardPeriodProvider = StateProvider<DashboardPeriod>(
  (ref) => DashboardPeriod.week7,
);

/// Aggregates trip/haul/logbook data for the selected period.
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final period = ref.watch(dashboardPeriodProvider);
  final db = ref.watch(appDatabaseProvider);

  final now = DateTime.now();
  final DateTime? since = switch (period) {
    DashboardPeriod.today => DateTime(now.year, now.month, now.day),
    DashboardPeriod.week7 => now.subtract(const Duration(days: 7)),
    DashboardPeriod.month30 => now.subtract(const Duration(days: 30)),
    DashboardPeriod.total => null,
  };

  // Query trips in period
  final tripQuery = db.select(db.trips);
  if (since != null) {
    tripQuery.where((t) => t.startedAt.isBiggerOrEqualValue(since));
  }
  final trips = await tripQuery.get();
  final tripIds = trips.map((t) => t.id).toSet();

  if (tripIds.isEmpty) {
    return const DashboardStats();
  }

  // Query hauls belonging to those trips
  final haulQuery = db.select(db.hauls)
    ..where((h) => h.tripId.isIn(tripIds));
  final hauls = await haulQuery.get();

  // Aggregate haul metrics
  double totalDistance = 0;
  int totalDuration = 0;
  double totalSwept = 0;
  for (final haul in hauls) {
    totalDistance += haul.distanceMeters;
    totalDuration += haul.durationSeconds;
    totalSwept += haul.sweptAreaM2;
  }

  // Query log book entries for fuel
  final logQuery = db.select(db.logBookEntries)
    ..where((e) => e.tripId.isIn(tripIds));
  final logEntries = await logQuery.get();
  double totalFuel = 0;
  final logEntryIds = <String>[];
  for (final entry in logEntries) {
    totalFuel += entry.fuelLiters ?? 0;
    logEntryIds.add(entry.id);
  }

  // Query catch items for total kg
  double totalCatch = 0;
  final Map<DateTime, double> dailyMap = {};
  if (logEntryIds.isNotEmpty) {
    final catchQuery = db.select(db.catchItems)
      ..where((c) => c.logBookEntryId.isIn(logEntryIds));
    final catchItems = await catchQuery.get();

    // Build a mapping from logBookEntryId -> tripStartedAt date
    final entryToDate = <String, DateTime>{};
    for (final entry in logEntries) {
      // Find the trip's start date for grouping daily catches
      final trip = trips.firstWhere(
        (t) => t.id == entry.tripId,
        orElse: () => trips.first,
      );
      final date = DateTime(
        trip.startedAt.year,
        trip.startedAt.month,
        trip.startedAt.day,
      );
      entryToDate[entry.id] = date;
    }

    for (final item in catchItems) {
      final kg = item.weightKg ?? 0;
      totalCatch += kg;
      final date = entryToDate[item.logBookEntryId];
      if (date != null) {
        dailyMap[date] = (dailyMap[date] ?? 0) + kg;
      }
    }
  }

  // Build daily catches list sorted by date
  final dailyCatches = dailyMap.entries
      .map((e) => DailyCatch(date: e.key, kg: e.value))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  // Top 5 spots — haul name (or "Haul #N") ranked by catch from that haul
  final haulCatch = <String, double>{}; // haulId -> total kg
  final haulNames = <String, String>{}; // haulId -> display name
  for (final haul in hauls) {
    haulNames[haul.id] = haul.name ?? 'Haul #${haul.orderIndex}';
  }
  // Map log entries by haulId to get catch per haul
  for (final entry in logEntries) {
    if (entry.haulId == null) continue;
    final catchQuery = db.select(db.catchItems)
      ..where((c) => c.logBookEntryId.equals(entry.id));
    final items = await catchQuery.get();
    double haulKg = 0;
    for (final item in items) {
      haulKg += item.weightKg ?? 0;
    }
    haulCatch[entry.haulId!] = (haulCatch[entry.haulId!] ?? 0) + haulKg;
  }

  final topSpots = haulCatch.entries
      .where((e) => e.value > 0)
      .map((e) => TopSpot(
            name: haulNames[e.key] ?? 'Haul',
            catchKg: e.value,
          ))
      .toList()
    ..sort((a, b) => b.catchKg.compareTo(a.catchKg));

  return DashboardStats(
    tripCount: trips.length,
    haulCount: hauls.length,
    totalDistanceMeters: totalDistance,
    totalDurationSeconds: totalDuration,
    totalSweptAreaM2: totalSwept,
    totalCatchKg: totalCatch,
    totalFuelLiters: totalFuel,
    dailyCatches: dailyCatches,
    topSpots: topSpots.take(5).toList(),
  );
});
