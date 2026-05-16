// Unit tests untuk enum [TrackingMode].
//
// Fokus: round-trip mapping DB <-> enum, label / subtitle untuk UI,
// dan defensive fallback untuk nilai yang tidak dikenal.

import 'package:flutter_test/flutter_test.dart';
import 'package:langgeng_sea/features/tracking/domain/entities/tracking_mode.dart';

void main() {
  group('TrackingMode.fromDbValue', () {
    test('parses canonical values', () {
      expect(TrackingMode.fromDbValue('normal'), TrackingMode.normal);
      expect(TrackingMode.fromDbValue('accurate'), TrackingMode.accurate);
    });

    test('falls back to normal for unknown / null / empty', () {
      // Defensive: data corrupt atau kolom kosong sebelum migrasi
      // terkonfirmasi tidak boleh meng-crash app.
      expect(TrackingMode.fromDbValue(null), TrackingMode.normal);
      expect(TrackingMode.fromDbValue(''), TrackingMode.normal);
      expect(TrackingMode.fromDbValue('foobar'), TrackingMode.normal);
      expect(TrackingMode.fromDbValue('NORMAL'), TrackingMode.normal,
          reason: 'casing matters — DB selalu lowercase');
    });

    test('round-trip dbValue -> fromDbValue identity', () {
      for (final mode in TrackingMode.values) {
        expect(TrackingMode.fromDbValue(mode.dbValue), mode);
      }
    });
  });

  group('TrackingMode.dbValue', () {
    test('uses lowercase enum name', () {
      expect(TrackingMode.normal.dbValue, 'normal');
      expect(TrackingMode.accurate.dbValue, 'accurate');
    });
  });

  group('TrackingMode.displayLabel', () {
    test('Bahasa Indonesia label per mode', () {
      expect(TrackingMode.normal.displayLabel, 'Normal');
      expect(TrackingMode.accurate.displayLabel, 'Akurasi');
    });
  });

  group('TrackingMode.subtitle', () {
    test('Normal subtitle menjelaskan foreground-only behavior', () {
      final s = TrackingMode.normal.subtitle;
      expect(s, contains('aplikasi terbuka'));
      expect(s.toLowerCase(), contains('hemat baterai'));
    });

    test('Akurasi subtitle menjelaskan foreground service behavior', () {
      final s = TrackingMode.accurate.subtitle;
      expect(s.toLowerCase(), contains('layar mati'));
      expect(s.toLowerCase(), contains('notifikasi'));
    });
  });
}
