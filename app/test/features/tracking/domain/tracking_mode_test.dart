// Unit tests untuk enum [TrackingMode] (PR #40 single-value form).
//
// Sejak PR #40 mode tracking dicabut. Enum dipertahankan dengan
// satu nilai [TrackingMode.accurate] untuk backward compat dengan
// kolom DB. Test memastikan mapping legacy `'normal'` dari row
// pre-v11 yang mungkin belum kena migrasi tetap di-treat sebagai
// `accurate`.

import 'package:flutter_test/flutter_test.dart';
import 'package:langgeng_sea/features/tracking/domain/entities/tracking_mode.dart';

void main() {
  group('TrackingMode (single-value sejak PR #40)', () {
    test('hanya punya satu nilai: accurate', () {
      expect(TrackingMode.values, [TrackingMode.accurate]);
    });

    test('dbValue selalu accurate', () {
      expect(TrackingMode.accurate.dbValue, 'accurate');
    });
  });

  group('TrackingMode.fromDbValue', () {
    test('memetakan apapun ke accurate', () {
      // Migrasi v11 sudah update semua row ke 'accurate', tapi
      // device yang DB-nya restored dari backup pre-v11 mungkin
      // masih punya 'normal' atau nilai lain — semua harus di-treat
      // sebagai accurate untuk konsistensi runtime.
      expect(TrackingMode.fromDbValue('accurate'), TrackingMode.accurate);
      expect(TrackingMode.fromDbValue('normal'), TrackingMode.accurate);
      expect(TrackingMode.fromDbValue(null), TrackingMode.accurate);
      expect(TrackingMode.fromDbValue(''), TrackingMode.accurate);
      expect(TrackingMode.fromDbValue('foobar'), TrackingMode.accurate);
    });

    test('round-trip dbValue identity', () {
      for (final mode in TrackingMode.values) {
        expect(TrackingMode.fromDbValue(mode.dbValue), mode);
      }
    });
  });
}
