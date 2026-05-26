import 'package:flutter_test/flutter_test.dart';
import 'package:styra/core/utils/formatters.dart';

void main() {
  group('Formatters.sectionDate', () {
    test('formats weekday + full date in Indonesian', () {
      // 8 May 2026 is a Friday.
      final d = DateTime(2026, 5, 8);
      expect(Formatters.sectionDate(d), 'Jumat, 8 Mei 2026');
    });

    test('handles every month', () {
      for (var m = 1; m <= 12; m++) {
        final out = Formatters.sectionDate(DateTime(2026, m, 1));
        // Should not contain placeholder empty string.
        expect(out, isNot(contains(', 1  ')));
      }
    });
  });

  group('Formatters.compactDuration', () {
    test('shows hours + zero-padded minutes above 1h', () {
      expect(
        Formatters.compactDuration(const Duration(hours: 8, minutes: 5)),
        '8j 05m',
      );
    });

    test('shows hours + minutes for typical trip durations', () {
      expect(
        Formatters.compactDuration(const Duration(hours: 8, minutes: 50)),
        '8j 50m',
      );
    });

    test('falls back to minutes + seconds below 1h', () {
      expect(
        Formatters.compactDuration(const Duration(minutes: 42, seconds: 18)),
        '42m 18d',
      );
    });

    test('falls back to seconds below 1m', () {
      expect(
        Formatters.compactDuration(const Duration(seconds: 30)),
        '30d',
      );
    });
  });

  group('Formatters.wallClock', () {
    test('zero-pads hour and minute', () {
      expect(Formatters.wallClock(DateTime(2026, 5, 8, 5, 30)), '05:30');
      expect(Formatters.wallClock(DateTime(2026, 5, 8, 14, 5)), '14:05');
    });

    test('midnight is 00:00', () {
      expect(Formatters.wallClock(DateTime(2026, 5, 8)), '00:00');
    });
  });
}
