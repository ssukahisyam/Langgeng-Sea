import 'package:langgeng_sea/features/navigation/data/navigation_alert_service.dart';

/// In-memory alert service for tests. Records calls rather than
/// hitting flutter_tts + HapticFeedback platform channels.
class FakeNavigationAlertService implements NavigationAlertService {
  final List<_Call> calls = [];

  @override
  Future<void> notifyArrived({
    required String label,
    required bool sound,
    required bool vibrate,
  }) async {
    calls.add(
      _Call('arrived', label: label, sound: sound, vibrate: vibrate),
    );
  }

  @override
  Future<void> notifyOffRoute({
    required double distanceMeters,
    required bool sound,
    required bool vibrate,
  }) async {
    calls.add(
      _Call(
        'offRoute',
        sound: sound,
        vibrate: vibrate,
        distance: distanceMeters,
      ),
    );
  }

  @override
  Future<void> notifyBackOnRoute({required bool vibrate}) async {
    calls.add(_Call('backOnRoute', vibrate: vibrate));
  }

  @override
  Future<void> dispose() async {}

  /// How many times the given alert kind fired.
  int countOf(String kind) => calls.where((c) => c.kind == kind).length;

  /// Last recorded call matching `kind`, or null if none.
  _Call? lastOf(String kind) {
    for (final c in calls.reversed) {
      if (c.kind == kind) return c;
    }
    return null;
  }
}

class _Call {
  _Call(
    this.kind, {
    this.label,
    this.sound,
    this.vibrate,
    this.distance,
  });

  final String kind;
  final String? label;
  final bool? sound;
  final bool? vibrate;
  final double? distance;
}
