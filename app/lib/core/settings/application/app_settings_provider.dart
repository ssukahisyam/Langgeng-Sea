import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../data/app_settings_repository.dart';
import '../domain/entities/app_settings.dart';

/// DI for [AppSettingsRepository]. Constructed once per Riverpod scope
/// so the underlying DAO subscription is shared between the
/// ProfileEditScreen switches and the navigation alert dispatcher.
final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AppSettingsRepository(db.appSettingsDao);
});

/// Reactive stream of current settings. Any writes via the repository
/// update this stream on the next Drift tick, so both the switches in
/// Edit Profil and the navigation alarm dispatch see changes
/// instantaneously without manual invalidation.
final appSettingsProvider = StreamProvider<AppSettings>((ref) {
  return ref.watch(appSettingsRepositoryProvider).watch();
});

/// Convenience provider that exposes only the polyline width as a
/// double (ready for strokeWidth usage in flutter_map). Falls back to
/// 10.0 while the DB loads. Map layers watch this instead of the full
/// [appSettingsProvider] to minimize rebuilds.
final polylineWidthProvider = Provider<double>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.asData?.value.polylineWidth.toDouble() ?? 10.0;
});

// PR #40: `trackingModeProvider` dihapus. Mode tracking sudah
// dicabut — tracking selalu pakai jalur Akurasi tanpa pilihan user.
// Caller yang dulu watch provider ini sekarang tidak perlu watch
// apapun: skipBatteryPermission ditentukan langsung di
// TrackingController (false untuk start path, true untuk resume).
