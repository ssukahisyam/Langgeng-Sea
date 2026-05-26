import 'package:flutter_test/flutter_test.dart';
import 'package:styra/features/tracking/domain/entities/haul_metrics.dart';

void main() {
  group('HaulMetrics.empty', () {
    test('starts with all zeros', () {
      const m = HaulMetrics.empty;
      expect(m.distanceMeters, 0);
      expect(m.duration, Duration.zero);
      expect(m.avgSpeedKnots, isNull);
      expect(m.avgHeadingDegrees, isNull);
      expect(m.sweptAreaM2, 0);
      expect(m.pointCount, 0);
    });
  });

  group('HaulMetrics.copyWith', () {
    test('overrides only the provided fields', () {
      const base = HaulMetrics.empty;
      final updated = base.copyWith(
        distanceMeters: 1200,
        duration: const Duration(minutes: 5),
        avgSpeedKnots: 3.2,
      );
      expect(updated.distanceMeters, 1200);
      expect(updated.duration, const Duration(minutes: 5));
      expect(updated.avgSpeedKnots, 3.2);
      expect(updated.avgHeadingDegrees, isNull);
    });

    test('allows explicit null-preservation of nullables', () {
      const base = HaulMetrics(
        distanceMeters: 100,
        duration: Duration(seconds: 30),
        avgSpeedKnots: 2,
      );
      final updated = base.copyWith(distanceMeters: 200);
      // avgSpeedKnots should persist because it's not re-specified.
      expect(updated.avgSpeedKnots, 2);
      expect(updated.distanceMeters, 200);
    });
  });
}
