import '../../../../features/tracking/domain/entities/tracking_mode.dart';

/// Device-local application preferences.
///
/// Presently hosts the M11 navigation alarm toggles (TTS + vibrate),
/// map polyline width, and the PR #29 tracking mode toggle
/// (Normal / Akurasi).
/// Lives in [core/settings] — not in a feature module — because other
/// milestones may deposit cross-cutting preferences here too (theme
/// override, units, etc.) and keeping them behind one table avoids
/// sprinkling `SharedPreferences` keys.
///
/// Persisted in the `app_settings` table (schema v9) as a single row
/// with `id = 1`, so reads never need null-handling. See
/// [AppSettingsRepository] for the wire-up.
class AppSettings {
  const AppSettings({
    required this.alarmSoundEnabled,
    required this.alarmVibrateEnabled,
    required this.polylineWidth,
    required this.trackingMode,
    required this.updatedAt,
  });

  /// When true, the navigation alert service is allowed to speak TTS
  /// prompts ("sudah sampai di {label}", "keluar jalur"). Default
  /// true on first install.
  final bool alarmSoundEnabled;

  /// When true, the navigation alert service is allowed to fire
  /// haptic feedback alongside (or instead of) TTS. Default true on
  /// first install.
  final bool alarmVibrateEnabled;

  /// Width in pixels for map polylines (history tracks, active haul,
  /// navigation guides). Range 4–16, default 10.
  final int polylineWidth;

  /// Mode tracking yang dipilih user (PR #29). Default
  /// [TrackingMode.normal] di first install supaya tidak ada dialog
  /// izin yang muncul tanpa konteks. User pindah ke
  /// [TrackingMode.accurate] secara sadar dari Settings saat butuh
  /// trip panjang dengan layar mati.
  final TrackingMode trackingMode;

  /// Bookkeeping only — bumped on every mutation so future "history
  /// of setting changes" screens have a hook.
  final DateTime updatedAt;

  /// Baseline defaults used before the DB layer has loaded. Wide open
  /// so the user notices alerts immediately on first use; they can
  /// always disable from ProfileEditScreen.
  static final AppSettings defaults = AppSettings(
    alarmSoundEnabled: true,
    alarmVibrateEnabled: true,
    polylineWidth: 10,
    trackingMode: TrackingMode.normal,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  AppSettings copyWith({
    bool? alarmSoundEnabled,
    bool? alarmVibrateEnabled,
    int? polylineWidth,
    TrackingMode? trackingMode,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      alarmSoundEnabled: alarmSoundEnabled ?? this.alarmSoundEnabled,
      alarmVibrateEnabled: alarmVibrateEnabled ?? this.alarmVibrateEnabled,
      polylineWidth: polylineWidth ?? this.polylineWidth,
      trackingMode: trackingMode ?? this.trackingMode,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.alarmSoundEnabled == alarmSoundEnabled &&
        other.alarmVibrateEnabled == alarmVibrateEnabled &&
        other.polylineWidth == polylineWidth &&
        other.trackingMode == trackingMode &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        alarmSoundEnabled,
        alarmVibrateEnabled,
        polylineWidth,
        trackingMode,
        updatedAt,
      );

  @override
  String toString() =>
      'AppSettings(sound: $alarmSoundEnabled, vibrate: $alarmVibrateEnabled, '
      'polylineWidth: $polylineWidth, trackingMode: ${trackingMode.dbValue})';
}
