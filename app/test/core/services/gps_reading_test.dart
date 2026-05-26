import 'package:flutter_test/flutter_test.dart';
import 'package:styra/core/services/gps_reading.dart';

void main() {
  GpsReading make({
    double? accuracy,
    double? speed,
    double? heading,
  }) =>
      GpsReading(
        latitude: -7.2,
        longitude: 113.4,
        timestamp: DateTime(2026, 5, 8),
        accuracyMeters: accuracy,
        speedMps: speed,
        headingDegrees: heading,
      );

  group('GpsReading', () {
    test('converts m/s to knots', () {
      final r = make(speed: 1.5); // 1.5 m/s ~ 2.91 knots
      expect(r.speedKnots!, closeTo(2.915, 0.01));
    });

    test('converts m/s to km/h', () {
      final r = make(speed: 10); // 36 km/h
      expect(r.speedKmh!, closeTo(36.0, 0.01));
    });

    test('hasReliableHeading is false when vessel is stationary', () {
      final r = make(speed: 0.2, heading: 90);
      expect(r.hasReliableHeading, isFalse);
    });

    test('hasReliableHeading is true when moving above threshold', () {
      final r = make(speed: 2.0, heading: 90);
      expect(r.hasReliableHeading, isTrue);
    });

    test('hasReliableHeading requires non-null heading', () {
      final r = make(speed: 5.0);
      expect(r.hasReliableHeading, isFalse);
    });
  });

  group('GpsAccuracyTier', () {
    test('unknown when reading is null', () {
      const GpsReading? r = null;
      expect(r.accuracyTier, GpsAccuracyTier.unknown);
    });

    test('unknown when accuracy is null', () {
      expect(make().accuracyTier, GpsAccuracyTier.unknown);
    });

    test('good when accuracy <= 10m', () {
      expect(make(accuracy: 4).accuracyTier, GpsAccuracyTier.good);
      expect(make(accuracy: 10).accuracyTier, GpsAccuracyTier.good);
    });

    test('medium when 10m < accuracy <= 20m', () {
      expect(make(accuracy: 15).accuracyTier, GpsAccuracyTier.medium);
      expect(make(accuracy: 20).accuracyTier, GpsAccuracyTier.medium);
    });

    test('poor when accuracy > 20m', () {
      expect(make(accuracy: 25).accuracyTier, GpsAccuracyTier.poor);
      expect(make(accuracy: 100).accuracyTier, GpsAccuracyTier.poor);
    });
  });
}
