import 'package:flutter_test/flutter_test.dart';
import 'package:styra/features/tracking/domain/entities/trip.dart';
import 'package:styra/features/tracking/domain/entities/trip_summary.dart';

Trip _trip(DateTime startedAt) => Trip(
      id: 't1',
      startedAt: startedAt,
      status: TripStatus.completed,
    );

TripSummary _summary(DateTime startedAt) => TripSummary(
      trip: _trip(startedAt),
      haulCount: 0,
      totalDistanceMeters: 0,
      totalDurationSeconds: 0,
      totalSweptAreaM2: 0,
    );

void main() {
  group('TripSummary.sectionDay', () {
    test('normalizes to local midnight', () {
      final s = _summary(DateTime(2026, 5, 8, 14, 30, 12));
      expect(s.sectionDay, DateTime(2026, 5, 8));
    });

    test('treats two trips on the same day as the same section', () {
      final morning = _summary(DateTime(2026, 5, 8, 6, 0));
      final evening = _summary(DateTime(2026, 5, 8, 22, 0));
      expect(morning.sectionDay, evening.sectionDay);
    });

    test('separates trips across midnight', () {
      final lastNight = _summary(DateTime(2026, 5, 7, 23, 59));
      final thisMorning = _summary(DateTime(2026, 5, 8, 0, 1));
      expect(lastNight.sectionDay, isNot(thisMorning.sectionDay));
    });
  });

  group('TripSummary.totalDuration', () {
    test('converts seconds to Duration', () {
      final s = TripSummary(
        trip: _trip(DateTime(2026, 5, 8)),
        haulCount: 1,
        totalDistanceMeters: 0,
        totalDurationSeconds: 3723, // 1h 2m 3s
        totalSweptAreaM2: 0,
      );
      expect(s.totalDuration, const Duration(hours: 1, minutes: 2, seconds: 3));
    });
  });
}
