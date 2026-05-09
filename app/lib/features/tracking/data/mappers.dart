import 'package:drift/drift.dart';

// Import the app_database barrel so that generated types like
// TripRow/HaulRow/TrackPointRow (defined in app_database.g.dart) and
// TripsCompanion/HaulsCompanion/TrackPointsCompanion (also generated
// into app_database.g.dart) are visible here. tables.dart alone is
// not enough — row/companion classes are generated on top of the
// tables declaration, not in the same file.
import '../../../data/database/app_database.dart';
import '../domain/entities/haul.dart';
import '../domain/entities/track_point.dart';
import '../domain/entities/trip.dart';

/// Pure mapping between Drift row classes and the domain entities.
///
/// Keeping these isolated lets the domain layer stay DB-agnostic and makes
/// the repositories short and obvious.
class TripMapper {
  const TripMapper._();

  static Trip fromRow(TripRow r) => Trip(
        id: r.id,
        name: r.name,
        startedAt: r.startedAt,
        endedAt: r.endedAt,
        status: _tripStatusFromString(r.status),
        homePort: r.homePort,
        notes: r.notes,
      );

  static TripsCompanion toInsertCompanion(Trip t) => TripsCompanion.insert(
        id: t.id,
        name: Value(t.name),
        startedAt: t.startedAt,
        endedAt: Value(t.endedAt),
        status: _tripStatusToString(t.status),
        homePort: Value(t.homePort),
        notes: Value(t.notes),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  static TripsCompanion toUpdateCompanion(Trip t) => TripsCompanion(
        name: Value(t.name),
        endedAt: Value(t.endedAt),
        status: Value(_tripStatusToString(t.status)),
        homePort: Value(t.homePort),
        notes: Value(t.notes),
        updatedAt: Value(DateTime.now()),
      );
}

TripStatus _tripStatusFromString(String s) =>
    s == 'active' ? TripStatus.active : TripStatus.completed;

String _tripStatusToString(TripStatus s) =>
    s == TripStatus.active ? 'active' : 'completed';

class HaulMapper {
  const HaulMapper._();

  static Haul fromRow(HaulRow r) => Haul(
        id: r.id,
        tripId: r.tripId,
        name: r.name,
        orderIndex: r.orderIndex,
        startedAt: r.startedAt,
        endedAt: r.endedAt,
        status: _haulStatusFromString(r.status),
        trawlWidthMeters: r.trawlWidthMeters,
        distanceMeters: r.distanceMeters,
        durationSeconds: r.durationSeconds,
        avgSpeedKnots: r.avgSpeedKnots,
        avgHeadingDegrees: r.avgHeadingDegrees,
        sweptAreaM2: r.sweptAreaM2,
        notes: r.notes,
      );

  static HaulsCompanion toInsertCompanion(Haul h) => HaulsCompanion.insert(
        id: h.id,
        tripId: h.tripId,
        orderIndex: h.orderIndex,
        startedAt: h.startedAt,
        status: _haulStatusToString(h.status),
        trawlWidthMeters: Value(h.trawlWidthMeters),
        name: Value(h.name),
        endedAt: Value(h.endedAt),
        distanceMeters: Value(h.distanceMeters),
        durationSeconds: Value(h.durationSeconds),
        avgSpeedKnots: Value(h.avgSpeedKnots),
        avgHeadingDegrees: Value(h.avgHeadingDegrees),
        sweptAreaM2: Value(h.sweptAreaM2),
        notes: Value(h.notes),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  static HaulsCompanion toUpdateCompanion(Haul h) => HaulsCompanion(
        name: Value(h.name),
        endedAt: Value(h.endedAt),
        status: Value(_haulStatusToString(h.status)),
        distanceMeters: Value(h.distanceMeters),
        durationSeconds: Value(h.durationSeconds),
        avgSpeedKnots: Value(h.avgSpeedKnots),
        avgHeadingDegrees: Value(h.avgHeadingDegrees),
        sweptAreaM2: Value(h.sweptAreaM2),
        notes: Value(h.notes),
        updatedAt: Value(DateTime.now()),
      );
}

HaulStatus _haulStatusFromString(String s) =>
    s == 'recording' ? HaulStatus.recording : HaulStatus.completed;

String _haulStatusToString(HaulStatus s) =>
    s == HaulStatus.recording ? 'recording' : 'completed';

class TrackPointMapper {
  const TrackPointMapper._();

  static TrackPoint fromRow(TrackPointRow r) => TrackPoint(
        id: r.id,
        haulId: r.haulId,
        latitude: r.latitude,
        longitude: r.longitude,
        timestamp: r.timestamp,
        speedMps: r.speedMps,
        headingDegrees: r.headingDegrees,
        accuracyMeters: r.accuracyMeters,
        altitudeMeters: r.altitudeMeters,
      );

  static TrackPointsCompanion toInsertCompanion(TrackPoint p) =>
      TrackPointsCompanion.insert(
        haulId: p.haulId,
        latitude: p.latitude,
        longitude: p.longitude,
        timestamp: p.timestamp,
        speedMps: Value(p.speedMps),
        headingDegrees: Value(p.headingDegrees),
        accuracyMeters: Value(p.accuracyMeters),
        altitudeMeters: Value(p.altitudeMeters),
      );
}
