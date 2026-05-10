import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Side-effect surface for navigation events: TTS prompt +
/// platform haptics. Kept behind an interface so
/// `NavigationController` is testable with a no-op fake and the real
/// implementation can be swapped (e.g. to pre-generated audio tones)
/// without touching the controller.
abstract class NavigationAlertService {
  /// "Sudah sampai di {label}".
  Future<void> notifyArrived({
    required String label,
    required bool sound,
    required bool vibrate,
  });

  /// "Keluar jalur sejauh {distance} meter" (M11b).
  /// Lives here so the controller's alarm dispatch can call one
  /// interface for every alarm type.
  Future<void> notifyOffRoute({
    required double distanceMeters,
    required bool sound,
    required bool vibrate,
  });

  /// Quieter acknowledgement when the user re-enters the route
  /// (M11b). Default implementation in the real service skips TTS
  /// (anti-annoying) and fires light haptics only.
  Future<void> notifyBackOnRoute({required bool vibrate});

  /// Release platform resources (TTS engine handle). Called on
  /// provider dispose.
  Future<void> dispose();
}

/// Real implementation backed by `flutter_tts` (OS TextToSpeech) and
/// `HapticFeedback` from `flutter/services`.
///
/// Language is pinned to `id-ID` so announcements speak Indonesian on
/// devices that have the language pack installed. Speech rate is set
/// slightly below the default because TTS engines tend to enunciate
/// too fast out of the box for noisy-environment listeners.
///
/// The TTS engine is lazy-initialised on first call — instantiating
/// one up-front would block the app on startup on slower devices (the
/// underlying Android `TextToSpeech` constructor fires a cold Binder
/// call into the system TTS service).
class FlutterTtsNavigationAlertService implements NavigationAlertService {
  FlutterTtsNavigationAlertService({FlutterTts? ttsOverride})
      : _ttsOverride = ttsOverride;

  final FlutterTts? _ttsOverride;
  FlutterTts? _tts;
  bool _initialised = false;

  Future<FlutterTts> _ensureTts() async {
    if (_tts != null) return _tts!;
    final tts = _ttsOverride ?? FlutterTts();
    if (!_initialised) {
      await tts.setLanguage('id-ID');
      await tts.setSpeechRate(0.5);
      _initialised = true;
    }
    _tts = tts;
    return tts;
  }

  @override
  Future<void> notifyArrived({
    required String label,
    required bool sound,
    required bool vibrate,
  }) async {
    if (vibrate) {
      await _safeHaptic(HapticFeedback.heavyImpact);
    }
    if (sound) {
      final tts = await _ensureTts();
      await tts.speak('Sudah sampai di $label');
    }
  }

  @override
  Future<void> notifyOffRoute({
    required double distanceMeters,
    required bool sound,
    required bool vibrate,
  }) async {
    if (vibrate) {
      await _safeHaptic(HapticFeedback.heavyImpact);
    }
    if (sound) {
      final tts = await _ensureTts();
      final rounded = distanceMeters.round();
      await tts.speak('Keluar jalur sejauh $rounded meter');
    }
  }

  @override
  Future<void> notifyBackOnRoute({required bool vibrate}) async {
    if (vibrate) {
      await _safeHaptic(HapticFeedback.lightImpact);
    }
    // Intentionally no TTS for back-on-route — users reported the
    // opposite-sign alarms spamming on borderline cases during
    // prototype review. Haptic-only keeps the feedback present
    // without becoming obnoxious.
  }

  @override
  Future<void> dispose() async {
    await _tts?.stop();
    _tts = null;
    _initialised = false;
  }

  /// HapticFeedback.* throws MissingPluginException in pure-Dart unit
  /// tests. The service swallows those because an alarm failing to
  /// vibrate must never break navigation.
  Future<void> _safeHaptic(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      /* no-op — test env / disabled hardware */
    }
  }
}

/// Provider consumed by the controller. Overridable in tests with
/// a [NoopNavigationAlertService] or mocktail double.
final navigationAlertServiceProvider =
    Provider<NavigationAlertService>((ref) {
  final svc = FlutterTtsNavigationAlertService();
  ref.onDispose(svc.dispose);
  return svc;
});
