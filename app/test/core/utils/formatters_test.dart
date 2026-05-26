import 'package:flutter_test/flutter_test.dart';
import 'package:styra/core/utils/formatters.dart';

void main() {
  group('Formatters.distance', () {
    test('uses meters below 1km', () {
      expect(Formatters.distance(480), '480 m');
    });

    test('uses km with 2 decimals under 10km', () {
      expect(Formatters.distance(2400), '2.40 km');
    });

    test('uses km with 1 decimal above 10km', () {
      expect(Formatters.distance(12400), '12.4 km');
    });

    test('handles invalid input', () {
      expect(Formatters.distance(double.nan), contains('—'));
    });
  });

  group('Formatters.knots', () {
    test('formats with 1 decimal', () {
      expect(Formatters.knots(3.2), '3.2 kn');
    });

    test('handles null', () {
      expect(Formatters.knots(null), '— kn');
    });
  });

  group('Formatters.heading', () {
    test('pads to 3 digits', () {
      expect(Formatters.heading(45), '045°');
    });

    test('wraps at 360', () {
      expect(Formatters.heading(360), '000°');
    });

    test('handles null', () {
      expect(Formatters.heading(null), '—°');
    });
  });

  group('Formatters.duration', () {
    test('zero-pads fields', () {
      expect(
        Formatters.duration(const Duration(hours: 0, minutes: 2, seconds: 5)),
        '00:02:05',
      );
    });

    test('preserves hours', () {
      expect(
        Formatters.duration(const Duration(hours: 12, minutes: 34, seconds: 56)),
        '12:34:56',
      );
    });
  });

  group('Formatters.accuracy', () {
    test('rounds to integer meters', () {
      expect(Formatters.accuracy(4.2), '±4m');
      expect(Formatters.accuracy(20.8), '±21m');
    });

    test('handles null', () {
      expect(Formatters.accuracy(null), '±—m');
    });
  });
}
