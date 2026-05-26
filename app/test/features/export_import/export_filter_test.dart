// Unit tests untuk ExportFilter & DateRange (PR #27 R5).
//
// Pure-Dart tests — tidak perlu Flutter binding atau database.

import 'package:flutter_test/flutter_test.dart';
import 'package:styra/features/export_import/domain/entities/date_range.dart';
import 'package:styra/features/export_import/domain/entities/export_filter.dart';
import 'package:styra/features/marker/domain/entities/marker.dart';
import 'package:styra/features/tracking/domain/entities/trip.dart';

void main() {
  // ---------------------------------------------------------------------------
  // DateRange
  // ---------------------------------------------------------------------------

  group('DateRange.contains', () {
    final r = DateRange(
      start: DateTime(2026, 5, 1),
      end: DateTime(2026, 5, 8),
    );

    test('start is inclusive', () {
      expect(r.contains(DateTime(2026, 5, 1)), isTrue);
    });

    test('end is exclusive (one millisecond before still in)', () {
      expect(
        r.contains(DateTime(2026, 5, 7, 23, 59, 59, 999)),
        isTrue,
      );
      expect(r.contains(DateTime(2026, 5, 8)), isFalse);
    });

    test('outside range returns false', () {
      expect(r.contains(DateTime(2026, 4, 30, 23, 59, 59)), isFalse);
      expect(r.contains(DateTime(2026, 5, 8, 0, 0, 1)), isFalse);
    });

    test('empty range (start >= end) is false for everything', () {
      final empty = DateRange(
        start: DateTime(2026, 5, 8),
        end: DateTime(2026, 5, 1),
      );
      expect(empty.contains(DateTime(2026, 5, 5)), isFalse);
      expect(empty.isEmpty, isTrue);
    });
  });

  group('DateRange factories', () {
    test('last7Days spans 7 calendar days ending tomorrow-start', () {
      final now = DateTime(2026, 5, 16, 14, 30); // mid-day
      final r = DateRange.last7Days(now: now);

      // end = besok pagi (start of next day)
      expect(r.end, DateTime(2026, 5, 17));
      // start = end - 7 days
      expect(r.start, DateTime(2026, 5, 10));
      // span tepat 7 hari
      expect(r.end.difference(r.start).inDays, 7);
      // hari ini ikut masuk
      expect(r.contains(now), isTrue);
    });

    test('last30Days spans 30 calendar days', () {
      final now = DateTime(2026, 5, 16);
      final r = DateRange.last30Days(now: now);
      expect(r.end.difference(r.start).inDays, 30);
      expect(r.contains(DateTime(2026, 4, 17)), isTrue);
      expect(r.contains(DateTime(2026, 4, 16, 23, 59)), isFalse);
    });

    test('today covers 00:00 to next-day 00:00 local', () {
      final now = DateTime(2026, 5, 16, 14, 30);
      final r = DateRange.today(now: now);
      expect(r.start, DateTime(2026, 5, 16));
      expect(r.end, DateTime(2026, 5, 17));
      expect(r.contains(DateTime(2026, 5, 16, 0)), isTrue);
      expect(r.contains(DateTime(2026, 5, 16, 23, 59, 59, 999)), isTrue);
      expect(r.contains(DateTime(2026, 5, 17)), isFalse);
    });

    test('fromDates normalises to whole-day boundaries (inclusive end-of-day)',
        () {
      // user pilih "1 Mei – 7 Mei"
      final r = DateRange.fromDates(
        from: DateTime(2026, 5, 1, 12), // jam-jam tidak penting
        to: DateTime(2026, 5, 7, 8),
      );
      expect(r.start, DateTime(2026, 5, 1));
      expect(r.end, DateTime(2026, 5, 8));
      // 7 Mei akhir hari masih masuk
      expect(r.contains(DateTime(2026, 5, 7, 23, 59)), isTrue);
      // 8 Mei tidak ikut
      expect(r.contains(DateTime(2026, 5, 8)), isFalse);
    });
  });

  group('DateRange.describeIndonesian', () {
    test('different years included on both sides', () {
      final r = DateRange.fromDates(
        from: DateTime(2025, 12, 30),
        to: DateTime(2026, 1, 5),
      );
      // 30 Des 2025 – 5 Jan 2026 (label end-1ms)
      expect(r.describeIndonesian(), '30 Des 2025 – 5 Jan 2026');
    });

    test('same year omits start year', () {
      final r = DateRange.fromDates(
        from: DateTime(2026, 5, 1),
        to: DateTime(2026, 5, 7),
      );
      expect(r.describeIndonesian(), '1 Mei – 7 Mei 2026');
    });

    test('single-day range collapses to single label', () {
      final r = DateRange.fromDates(
        from: DateTime(2026, 5, 16),
        to: DateTime(2026, 5, 16),
      );
      expect(r.describeIndonesian(), '16 Mei 2026');
    });
  });

  group('DateRange equality', () {
    test('value equality on start+end', () {
      final a = DateRange(
        start: DateTime(2026, 5, 1),
        end: DateTime(2026, 5, 8),
      );
      final b = DateRange(
        start: DateTime(2026, 5, 1),
        end: DateTime(2026, 5, 8),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  // ---------------------------------------------------------------------------
  // ExportFilter — matchers
  // ---------------------------------------------------------------------------

  Trip trip(String id, DateTime startedAt) => Trip(
        id: id,
        startedAt: startedAt,
        status: TripStatus.completed,
      );

  AppMarker marker(String id, MarkerCategory cat) => AppMarker(
        id: id,
        name: 'm-$id',
        category: cat,
        latitude: -6.9,
        longitude: 110.5,
        createdAt: DateTime(2026, 5, 1),
      );

  group('ExportFilter.matchesTrip', () {
    test('null filters → all trips pass', () {
      final f = ExportFilter.allData;
      expect(f.matchesTrip(trip('a', DateTime(2026, 5, 1))), isTrue);
      expect(f.matchesTrip(trip('b', DateTime(2020, 1, 1))), isTrue);
    });

    test('dateRange filter — startedAt determines inclusion', () {
      final f = ExportFilter(
        includeTracks: true,
        includeMarkers: false,
        dateRange: DateRange(
          start: DateTime(2026, 5, 1),
          end: DateTime(2026, 5, 8),
        ),
      );
      expect(f.matchesTrip(trip('in', DateTime(2026, 5, 5))), isTrue);
      expect(f.matchesTrip(trip('before', DateTime(2026, 4, 30))), isFalse);
      expect(f.matchesTrip(trip('after', DateTime(2026, 5, 8))), isFalse);
    });

    test('tripIds filter — only listed ids pass', () {
      final f = ExportFilter(
        includeTracks: true,
        includeMarkers: false,
        tripIds: {'a', 'c'},
      );
      expect(f.matchesTrip(trip('a', DateTime(2026, 5, 1))), isTrue);
      expect(f.matchesTrip(trip('b', DateTime(2026, 5, 1))), isFalse);
      expect(f.matchesTrip(trip('c', DateTime(2026, 5, 1))), isTrue);
    });

    test('tripIds overrides dateRange', () {
      // Trip 'a' di luar rentang tanggal tetap masuk karena disebut
      // di tripIds eksplisit.
      final f = ExportFilter(
        includeTracks: true,
        includeMarkers: false,
        dateRange: DateRange(
          start: DateTime(2026, 5, 1),
          end: DateTime(2026, 5, 8),
        ),
        tripIds: {'a'},
      );
      expect(f.matchesTrip(trip('a', DateTime(2020, 1, 1))), isTrue);
      expect(f.matchesTrip(trip('b', DateTime(2026, 5, 5))), isFalse);
    });

    test('empty tripIds → no trip passes', () {
      final f = ExportFilter(
        includeTracks: true,
        includeMarkers: false,
        tripIds: const {},
      );
      expect(f.matchesTrip(trip('a', DateTime(2026, 5, 1))), isFalse);
    });
  });

  group('ExportFilter.matchesMarker', () {
    test('null categories → all marker pass', () {
      final f = ExportFilter.allData;
      for (final cat in MarkerCategory.values) {
        expect(f.matchesMarker(marker('1', cat)), isTrue);
      }
    });

    test('subset categories — only listed kategori pass', () {
      final f = ExportFilter(
        includeTracks: false,
        includeMarkers: true,
        markerCategories: {MarkerCategory.productive, MarkerCategory.port},
      );
      expect(
        f.matchesMarker(marker('1', MarkerCategory.productive)),
        isTrue,
      );
      expect(
        f.matchesMarker(marker('2', MarkerCategory.hazard)),
        isFalse,
      );
      expect(
        f.matchesMarker(marker('3', MarkerCategory.port)),
        isTrue,
      );
    });

    test('empty kategori set → no marker pass', () {
      final f = ExportFilter(
        includeTracks: false,
        includeMarkers: true,
        markerCategories: const {},
      );
      expect(f.matchesMarker(marker('1', MarkerCategory.productive)), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // ExportFilter — describe / suggestFileName
  // ---------------------------------------------------------------------------

  group('ExportFilter.describe', () {
    test('all-data filter', () {
      expect(
        ExportFilter.allData.describe(),
        contains('Jalur + Penanda'),
      );
      expect(
        ExportFilter.allData.describe(),
        contains('Semua waktu'),
      );
    });

    test('jalur saja, 7 hari', () {
      final r = DateRange.last7Days(now: DateTime(2026, 5, 16));
      final f = ExportFilter(
        includeTracks: true,
        includeMarkers: false,
        dateRange: r,
      );
      final desc = f.describe();
      expect(desc, contains('Jalur saja'));
      expect(desc, isNot(contains('Semua kategori')));
    });

    test('penanda saja, kategori subset', () {
      final f = ExportFilter(
        includeTracks: false,
        includeMarkers: true,
        markerCategories: {MarkerCategory.hazard, MarkerCategory.port},
      );
      final desc = f.describe();
      expect(desc, contains('Penanda saja'));
      expect(desc, contains('Karang/Bahaya'));
      expect(desc, contains('Pelabuhan'));
      expect(desc, isNot(contains('Produktif')));
    });

    test('trip subset overrides date range mention', () {
      final f = ExportFilter(
        includeTracks: true,
        includeMarkers: true,
        dateRange: DateRange(
          start: DateTime(2026, 5, 1),
          end: DateTime(2026, 5, 8),
        ),
        tripIds: {'a', 'b'},
      );
      final desc = f.describe();
      expect(desc, contains('2 trip dipilih'));
      expect(desc, isNot(contains('Mei')));
    });

    test('zero content state', () {
      final f = ExportFilter(includeTracks: false, includeMarkers: false);
      expect(f.hasAnyContent, isFalse);
      expect(f.describe(), contains('Tidak ada konten'));
    });
  });

  group('ExportFilter.suggestFileName', () {
    final now = DateTime(2026, 5, 16);

    test('all-data → langgeng_sea_lengkap_<today>', () {
      expect(
        ExportFilter.allData.suggestFileName(now: now),
        'langgeng_sea_lengkap_2026-05-16',
      );
    });

    test('jalur saja, 7 hari → has 7hari slug', () {
      final f = ExportFilter(
        includeTracks: true,
        includeMarkers: false,
        dateRange: DateRange.last7Days(now: now),
      );
      expect(f.suggestFileName(now: now), 'langgeng_sea_jalur_7hari_2026-05-16');
    });

    test('jalur saja, 30 hari → has 30hari slug', () {
      final f = ExportFilter(
        includeTracks: true,
        includeMarkers: false,
        dateRange: DateRange.last30Days(now: now),
      );
      expect(
        f.suggestFileName(now: now),
        'langgeng_sea_jalur_30hari_2026-05-16',
      );
    });

    test('penanda saja → langgeng_sea_penanda_<today>', () {
      final f = ExportFilter(includeTracks: false, includeMarkers: true);
      expect(
        f.suggestFileName(now: now),
        'langgeng_sea_penanda_2026-05-16',
      );
    });

    test('rentang custom → from_to slugs', () {
      final f = ExportFilter(
        includeTracks: true,
        includeMarkers: false,
        dateRange: DateRange.fromDates(
          from: DateTime(2026, 4, 1),
          to: DateTime(2026, 4, 15),
        ),
      );
      expect(
        f.suggestFileName(now: now),
        'langgeng_sea_jalur_2026-04-01_2026-04-15_2026-05-16',
      );
    });

    test('trip subset → Ntrip slug', () {
      final f = ExportFilter(
        includeTracks: true,
        includeMarkers: true,
        tripIds: {'a', 'b', 'c'},
      );
      expect(
        f.suggestFileName(now: now),
        'langgeng_sea_lengkap_3trip_2026-05-16',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // ExportFilter — equality (Riverpod family caching)
  // ---------------------------------------------------------------------------

  group('ExportFilter equality', () {
    test('value equals across all aksis', () {
      final a = ExportFilter(
        includeTracks: true,
        includeMarkers: true,
        dateRange: DateRange.fromDates(
          from: DateTime(2026, 5, 1),
          to: DateTime(2026, 5, 7),
        ),
        tripIds: {'a', 'b'},
        markerCategories: {MarkerCategory.productive, MarkerCategory.port},
      );
      final b = ExportFilter(
        includeTracks: true,
        includeMarkers: true,
        dateRange: DateRange.fromDates(
          from: DateTime(2026, 5, 1),
          to: DateTime(2026, 5, 7),
        ),
        tripIds: {'b', 'a'}, // urutan berbeda — set unordered
        markerCategories: {MarkerCategory.port, MarkerCategory.productive},
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different tripIds → not equal', () {
      final a = ExportFilter(
        includeTracks: true,
        includeMarkers: false,
        tripIds: {'a'},
      );
      final b = ExportFilter(
        includeTracks: true,
        includeMarkers: false,
        tripIds: {'b'},
      );
      expect(a, isNot(equals(b)));
    });

    test('null vs empty set are different', () {
      final nullSet = ExportFilter(
        includeTracks: true,
        includeMarkers: false,
      );
      final emptySet = ExportFilter(
        includeTracks: true,
        includeMarkers: false,
        tripIds: const {},
      );
      expect(nullSet, isNot(equals(emptySet)));
    });
  });

  // ---------------------------------------------------------------------------
  // ExportFilter — copyWith (clear flags)
  // ---------------------------------------------------------------------------

  group('ExportFilter.copyWith', () {
    test('clear flags wipe to null', () {
      final f = ExportFilter(
        includeTracks: true,
        includeMarkers: true,
        dateRange: DateRange.fromDates(
          from: DateTime(2026, 5, 1),
          to: DateTime(2026, 5, 7),
        ),
        tripIds: {'a'},
        markerCategories: {MarkerCategory.productive},
      );

      final cleared = f.copyWith(
        clearDateRange: true,
        clearTripIds: true,
        clearMarkerCategories: true,
      );
      expect(cleared.dateRange, isNull);
      expect(cleared.tripIds, isNull);
      expect(cleared.markerCategories, isNull);
      expect(cleared.includeTracks, isTrue);
      expect(cleared.includeMarkers, isTrue);
    });
  });
}
