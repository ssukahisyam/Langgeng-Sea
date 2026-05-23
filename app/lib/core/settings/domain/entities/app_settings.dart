import '../../../../features/tracking/domain/entities/tracking_mode.dart';

/// Device-local application preferences.
///
/// Presently hosts the M11 navigation alarm toggles (TTS + vibrate)
/// and map polyline width. The PR #29 tracking mode toggle (Normal /
/// Akurasi) was retired in PR #40 — kolom DB `tracking_mode` tetap
/// untuk backward compat tapi runtime selalu treat sebagai
/// [TrackingMode.accurate].
///
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

  /// Mode tracking. Sejak PR #40 enum `TrackingMode` hanya punya
  /// satu nilai ([TrackingMode.accurate]) — field ini dipertahankan
  /// untuk backward compat dengan kolom DB.
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
    trackingMode: TrackingMode.accurate,
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
