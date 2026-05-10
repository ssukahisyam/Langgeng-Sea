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
