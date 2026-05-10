import 'package:latlong2/latlong.dart';

/// Sealed hierarchy of things the user can be navigating to.
///
/// M11a ships the [GotoTarget] branch (static waypoint). M11b adds
/// [FollowTrackTarget] (polyline to ikuti). The enum
/// [FollowTrackSource] is declared here already so the schema is
/// stable and the data class in M11a compiles with forward-looking
/// tests.
sealed class NavigationTarget {
  const NavigationTarget();

  /// Human-facing label. Used in the navigation panel title and in
  /// TTS alerts (e.g. "Sudah sampai di Spot Udang").
  String get displayLabel;
}

/// A fixed coordinate: a marker tap, a long-press on the map, or the
/// "pandu ke akhir haul/trip" shortcut.
class GotoTarget extends NavigationTarget {
  const GotoTarget({
    required this.position,
    required this.label,
    this.sourceMarkerId,
  });

  /// Tujuan (lat/lng).
  final LatLng position;

  /// Label muncul di panel + TTS. Wajib non-empty per UI contract.
  final String label;

  /// Optional breadcrumb: if the target came from a tap on a marker,
  /// this is that marker's id. Enables M11b "back to marker on
  /// arrival" niceties without rewalking the sheet flow. Null for
  /// long-press / haul-end variants.
  final String? sourceMarkerId;

  @override
  String get displayLabel => label;

  @override
  bool operator ==(Object other) {
    return other is GotoTarget &&
        other.position == position &&
        other.label == label &&
        other.sourceMarkerId == sourceMarkerId;
  }

  @override
  int get hashCode => Object.hash(position, label, sourceMarkerId);

  @override
  String toString() =>
      'GotoTarget($label @ ${position.latitude},${position.longitude})';
}

/// Follow a reference polyline. Populated in M11b; the class lives
/// here already so tests, serialization, and Navigation state machine
/// can be written in one pass.
class FollowTrackTarget extends NavigationTarget {
  const FollowTrackTarget({
    required this.pathPoints,
    required this.label,
    required this.sourceType,
    required this.sourceId,
  });

  /// Reference polyline — ordered list of LatLng.
  final List<LatLng> pathPoints;

  /// Label for panel + TTS ("Haul #3, Minggu 9 Mei").
  final String label;

  /// Origin of the polyline — haul or trip.
  final FollowTrackSource sourceType;

  /// Id of the haul / trip the polyline came from (for navigating back
  /// to detail screens from the panel).
  final String sourceId;

  @override
  String get displayLabel => label;

  @override
  bool operator ==(Object other) {
    return other is FollowTrackTarget &&
        other.label == label &&
        other.sourceType == sourceType &&
        other.sourceId == sourceId &&
        _listEquals(other.pathPoints, pathPoints);
  }

  @override
  int get hashCode => Object.hash(
        label,
        sourceType,
        sourceId,
        Object.hashAll(pathPoints),
      );

  @override
  String toString() =>
      'FollowTrackTarget($label, ${pathPoints.length} pts, '
      'source=$sourceType:$sourceId)';
}

/// Origin of a [FollowTrackTarget]'s polyline.
///
/// `haul` = single haul polyline. `trip` is reserved for future "follow
/// a whole trip" (v2) — currently FollowHaulPickerSheet pulls one haul
/// out of a trip so the active variant is always `haul`, but keeping
/// the enum stable avoids a rename during M11b.
enum FollowTrackSource { haul, trip }

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
