/// Device-local application preferences.
///
/// Presently hosts the M11 navigation alarm toggles (TTS + vibrate).
/// Lives in [core/settings] — not in a feature module — because other
/// milestones may deposit cross-cutting preferences here too (theme
/// override, units, etc.) and keeping them behind one table avoids
/// sprinkling `SharedPreferences` keys.
///
/// Persisted in the `app_settings` table (schema v6) as a single row
/// with `id = 1`, so reads never need null-handling. See
/// [AppSettingsRepository] for the wire-up.
class AppSettings {
  const AppSettings({
    required this.alarmSoundEnabled,
    required this.alarmVibrateEnabled,
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

  /// Bookkeeping only — bumped on every mutation so future "history
  /// of setting changes" screens have a hook.
  final DateTime updatedAt;

  /// Baseline defaults used before the DB layer has loaded. Wide open
  /// so the user notices alerts immediately on first use; they can
  /// always disable from ProfileEditScreen.
  static final AppSettings defaults = AppSettings(
    alarmSoundEnabled: true,
    alarmVibrateEnabled: true,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  AppSettings copyWith({
    bool? alarmSoundEnabled,
    bool? alarmVibrateEnabled,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      alarmSoundEnabled: alarmSoundEnabled ?? this.alarmSoundEnabled,
      alarmVibrateEnabled: alarmVibrateEnabled ?? this.alarmVibrateEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.alarmSoundEnabled == alarmSoundEnabled &&
        other.alarmVibrateEnabled == alarmVibrateEnabled &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode =>
      Object.hash(alarmSoundEnabled, alarmVibrateEnabled, updatedAt);

  @override
  String toString() =>
      'AppSettings(sound: $alarmSoundEnabled, vibrate: $alarmVibrateEnabled)';
}
