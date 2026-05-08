import '../../tracking/domain/entities/trip_summary.dart';

/// A row in the history list — either a section header (one per day) or a
/// trip summary. Flattening sections into the same list lets us use a
/// single [ListView] / [SliverList] without nested scrollables.
sealed class HistoryRow {
  const HistoryRow();
}

class HistorySectionHeader extends HistoryRow {
  const HistorySectionHeader(this.day);
  final DateTime day; // local midnight
}

class HistoryTripItem extends HistoryRow {
  const HistoryTripItem(this.summary);
  final TripSummary summary;
}

/// Group trips by local day into a flat list of [HistoryRow]s.
///
/// Input is assumed to be sorted newest-first (as [TripRepository.listSummaries]
/// returns it). Output preserves that order and inserts one header per
/// distinct day.
List<HistoryRow> groupTripsByDay(List<TripSummary> summaries) {
  if (summaries.isEmpty) return const [];
  final rows = <HistoryRow>[];
  DateTime? currentDay;
  for (final s in summaries) {
    final day = s.sectionDay;
    if (currentDay == null || day != currentDay) {
      rows.add(HistorySectionHeader(day));
      currentDay = day;
    }
    rows.add(HistoryTripItem(s));
  }
  return rows;
}
