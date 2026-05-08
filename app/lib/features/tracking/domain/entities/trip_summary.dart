import 'trip.dart';

/// Aggregated view of a [Trip] with its hauls' roll-ups.
///
/// Used by the History list so items can render distance/duration/haul
/// count without a second query per row.
class TripSummary {
  const TripSummary({
    required this.trip,
    required this.haulCount,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.totalSweptAreaM2,
  });

  final Trip trip;
  final int haulCount;
  final double totalDistanceMeters;
  final int totalDurationSeconds;
  final double totalSweptAreaM2;

  Duration get totalDuration => Duration(seconds: totalDurationSeconds);

  /// Date-only key used by the history section grouper. A DateTime at
  /// local midnight so two trips on the same day compare equal.
  DateTime get sectionDay {
    final d = trip.startedAt.toLocal();
    return DateTime(d.year, d.month, d.day);
  }
}
