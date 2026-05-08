import 'package:flutter_test/flutter_test.dart';
import 'package:langgeng_sea/features/history/presentation/history_grouping.dart';
import 'package:langgeng_sea/features/tracking/domain/entities/trip.dart';
import 'package:langgeng_sea/features/tracking/domain/entities/trip_summary.dart';

TripSummary _summary(DateTime startedAt, {String id = 't'}) => TripSummary(
      trip: Trip(
        id: id,
        startedAt: startedAt,
        status: TripStatus.completed,
      ),
      haulCount: 0,
      totalDistanceMeters: 0,
      totalDurationSeconds: 0,
      totalSweptAreaM2: 0,
    );

void main() {
  group('groupTripsByDay', () {
    test('returns empty list for empty input', () {
      expect(groupTripsByDay(const []), isEmpty);
    });

    test('emits exactly one header for a single trip', () {
      final rows = groupTripsByDay([
        _summary(DateTime(2026, 5, 8, 9, 0)),
      ]);
      expect(rows, hasLength(2));
      expect(rows[0], isA<HistorySectionHeader>());
      expect(rows[1], isA<HistoryTripItem>());
    });

    test('groups trips from the same day under one header', () {
      final rows = groupTripsByDay([
        _summary(DateTime(2026, 5, 8, 14, 0), id: 'afternoon'),
        _summary(DateTime(2026, 5, 8, 6, 0), id: 'morning'),
      ]);
      // 1 header + 2 items = 3 rows
      expect(rows, hasLength(3));
      expect(rows[0], isA<HistorySectionHeader>());
      expect(rows[1], isA<HistoryTripItem>());
      expect(rows[2], isA<HistoryTripItem>());
      expect(
        (rows[0] as HistorySectionHeader).day,
        DateTime(2026, 5, 8),
      );
    });

    test('emits separate headers per distinct day', () {
      final rows = groupTripsByDay([
        _summary(DateTime(2026, 5, 8, 9, 0), id: 'thu'),
        _summary(DateTime(2026, 5, 7, 9, 0), id: 'wed'),
        _summary(DateTime(2026, 5, 6, 9, 0), id: 'tue'),
      ]);
      // 3 headers + 3 items
      expect(rows, hasLength(6));

      final headers = rows.whereType<HistorySectionHeader>().toList();
      expect(headers.map((h) => h.day), [
        DateTime(2026, 5, 8),
        DateTime(2026, 5, 7),
        DateTime(2026, 5, 6),
      ]);
    });

    test('preserves input order (does not re-sort)', () {
      // groupTripsByDay assumes callers already sorted newest-first.
      // This test documents that contract.
      final rows = groupTripsByDay([
        _summary(DateTime(2026, 5, 8, 20, 0), id: 'late'),
        _summary(DateTime(2026, 5, 8, 6, 0), id: 'early'),
      ]);
      final items = rows.whereType<HistoryTripItem>().toList();
      expect(items[0].summary.trip.id, 'late');
      expect(items[1].summary.trip.id, 'early');
    });

    test('handles trips straddling midnight correctly', () {
      final rows = groupTripsByDay([
        _summary(DateTime(2026, 5, 8, 0, 5), id: 'after-midnight'),
        _summary(DateTime(2026, 5, 7, 23, 55), id: 'before-midnight'),
      ]);
      // Two separate day sections expected.
      expect(rows.whereType<HistorySectionHeader>(), hasLength(2));
    });
  });
}
