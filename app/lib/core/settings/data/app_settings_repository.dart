import '../../../data/database/app_database.dart';
import '../../../features/tracking/domain/entities/tracking_mode.dart';
import '../domain/entities/app_settings.dart';

/// Thin adapter: [AppSettingsDao] rows ↔ [AppSettings] entity.
///
/// Kept deliberately boring — the DAO already guarantees the single
/// row exists (seeded by migration + defensive `ensureSeeded`), so
/// this layer just maps columns to entity fields.
class AppSettingsRepository {
  AppSettingsRepository(this._dao);

  final AppSettingsDao _dao;

  Future<AppSettings> get() async => _fromRow(await _dao.getSingle());

  /// Reactive read. UI (ProfileEditScreen switches) + domain layer
  /// (NavigationController's alarm dispatch) both subscribe via the
  /// Riverpod provider below.
  Stream<AppSettings> watch() => _dao.watchSingle().map(_fromRow);

  Future<void> setSoundEnabled(bool value) => _dao.updateSoundEnabled(value);

  Future<void> setVibrateEnabled(bool value) =>
      _dao.updateVibrateEnabled(value);

  Future<void> setPolylineWidth(int width) => _dao.setPolylineWidth(width);

  // PR #40: `setTrackingMode` dihapus. Mode tracking sudah dicabut —
  // tidak ada UI yang lagi mengubah field ini. Kolom DB `tracking_mode`
  // tetap dipertahankan untuk backward compat tapi semua row di-update
  // ke 'accurate' lewat migrasi v11.

  AppSettings _fromRow(AppSettingsRow r) => AppSettings(
        alarmSoundEnabled: r.alarmSoundEnabled,
        alarmVibrateEnabled: r.alarmVibrateEnabled,
        polylineWidth: r.polylineWidth,
        trackingMode: TrackingMode.fromDbValue(r.trackingMode),
        updatedAt: r.updatedAt,
      );
}
