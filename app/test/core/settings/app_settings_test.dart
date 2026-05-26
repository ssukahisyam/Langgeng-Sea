// Tests for the AppSettings entity + repository wired against an
// in-memory AppDatabase. Verifies the seed row, stream reactivity,
// and setter writes.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:styra/core/settings/data/app_settings_repository.dart';
import 'package:styra/core/settings/domain/entities/app_settings.dart';
import 'package:styra/data/database/app_database.dart';
import 'package:styra/features/tracking/domain/entities/tracking_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettings entity', () {
    test('defaults have alarms both enabled', () {
      final def = AppSettings.defaults;
      expect(def.alarmSoundEnabled, isTrue);
      expect(def.alarmVibrateEnabled, isTrue);
    });

    test('copyWith changes only named fields', () {
      final base = AppSettings.defaults;
      final muted = base.copyWith(alarmSoundEnabled: false);
      expect(muted.alarmSoundEnabled, isFalse);
      expect(muted.alarmVibrateEnabled, base.alarmVibrateEnabled);
    });

    test('equality compares all fields', () {
      final t = DateTime(2026, 5, 10);
      expect(
        AppSettings(
          alarmSoundEnabled: true,
          alarmVibrateEnabled: true,
          polylineWidth: 10,
          trackingMode: TrackingMode.accurate,
          updatedAt: t,
        ),
        AppSettings(
          alarmSoundEnabled: true,
          alarmVibrateEnabled: true,
          polylineWidth: 10,
          trackingMode: TrackingMode.accurate,
          updatedAt: t,
        ),
      );
    });
  });

  group('AppSettingsRepository', () {
    late AppDatabase db;
    late AppSettingsRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppSettingsRepository(db.appSettingsDao);
    });

    tearDown(() async {
      await db.close();
    });

    test('get() returns the seeded singleton with defaults', () async {
      final s = await repo.get();
      expect(s.alarmSoundEnabled, isTrue);
      expect(s.alarmVibrateEnabled, isTrue);
    });

    test('setSoundEnabled persists and read-back reflects change', () async {
      await repo.setSoundEnabled(false);
      final s = await repo.get();
      expect(s.alarmSoundEnabled, isFalse);
      // The other flag is not affected.
      expect(s.alarmVibrateEnabled, isTrue);
    });

    test('setVibrateEnabled persists independently', () async {
      await repo.setVibrateEnabled(false);
      final s = await repo.get();
      expect(s.alarmVibrateEnabled, isFalse);
      expect(s.alarmSoundEnabled, isTrue);
    });

    test('watch() emits an initial value then reacts to updates', () async {
      final values = <AppSettings>[];
      final sub = repo.watch().listen(values.add);

      // Give Drift a microtask to emit the seeded row.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(values, isNotEmpty);
      expect(values.first.alarmSoundEnabled, isTrue);

      await repo.setSoundEnabled(false);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(values.last.alarmSoundEnabled, isFalse);
      await sub.cancel();
    });
  });
}
