import 'package:flutter_test/flutter_test.dart';
import 'package:langgeng_sea/features/dashboard/data/dashboard_stats_provider.dart';

void main() {
  group('DashboardStats', () {
    test('default/empty values are all zero', () {
      const stats = DashboardStats();

      expect(stats.tripCount, 0);
      expect(stats.haulCount, 0);
      expect(stats.totalDistanceMeters, 0);
      expect(stats.totalDurationSeconds, 0);
      expect(stats.totalSweptAreaM2, 0);
      expect(stats.totalCatchKg, 0);
      expect(stats.totalFuelLiters, 0);
      expect(stats.dailyCatches, isEmpty);
      expect(stats.topSpots, isEmpty);
      expect(stats.isEmpty, isTrue);
    });

    test('isEmpty is false when tripCount > 0', () {
      const stats = DashboardStats(tripCount: 1);
      expect(stats.isEmpty, isFalse);
    });

    test('isEmpty is false when haulCount > 0', () {
      const stats = DashboardStats(haulCount: 2);
      expect(stats.isEmpty, isFalse);
    });
  });

  group('DashboardPeriod', () {
    test('has exactly 4 values', () {
      expect(DashboardPeriod.values.length, 4);
    });

    test('contains today, week7, month30, total', () {
      expect(DashboardPeriod.values, containsAll([
        DashboardPeriod.today,
        DashboardPeriod.week7,
        DashboardPeriod.month30,
        DashboardPeriod.total,
      ]));
    });
  });

  group('DailyCatch', () {
    test('holds date and kg', () {
      final date = DateTime(2025, 1, 15);
      final dc = DailyCatch(date: date, kg: 42.5);

      expect(dc.date, date);
      expect(dc.kg, 42.5);
    });
  });

  group('TopSpot', () {
    test('holds name and catchKg', () {
      const spot = TopSpot(name: 'Haul #1', catchKg: 100.0);

      expect(spot.name, 'Haul #1');
      expect(spot.catchKg, 100.0);
    });
  });
}
