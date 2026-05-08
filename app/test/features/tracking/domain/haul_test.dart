import 'package:flutter_test/flutter_test.dart';
import 'package:langgeng_sea/features/tracking/domain/entities/haul.dart';

Haul buildHaul({
  String? name,
  int orderIndex = 1,
  HaulStatus status = HaulStatus.recording,
  int durationSeconds = 0,
}) =>
    Haul(
      id: 'h1',
      tripId: 't1',
      orderIndex: orderIndex,
      startedAt: DateTime(2026, 5, 8),
      status: status,
      trawlWidthMeters: 20,
      name: name,
      durationSeconds: durationSeconds,
    );

void main() {
  group('Haul.displayName', () {
    test('falls back to "Haul #N" when name is null', () {
      expect(buildHaul(orderIndex: 3).displayName(), 'Haul #3');
    });

    test('uses user-given name when present', () {
      expect(
        buildHaul(name: 'Spot Utara Pagi').displayName(),
        'Spot Utara Pagi',
      );
    });
  });

  group('Haul.isRecording', () {
    test('true for HaulStatus.recording', () {
      expect(buildHaul(status: HaulStatus.recording).isRecording, isTrue);
    });

    test('false for HaulStatus.completed', () {
      expect(buildHaul(status: HaulStatus.completed).isRecording, isFalse);
    });
  });

  group('Haul.duration', () {
    test('reflects durationSeconds', () {
      expect(
        buildHaul(durationSeconds: 3665).duration,
        const Duration(hours: 1, minutes: 1, seconds: 5),
      );
    });
  });

  group('Haul.copyWith', () {
    test('preserves unchanged fields', () {
      final original = buildHaul(name: 'A');
      final updated =
          original.copyWith(distanceMeters: 1234, status: HaulStatus.completed);
      expect(updated.name, 'A');
      expect(updated.orderIndex, 1);
      expect(updated.tripId, 't1');
      expect(updated.distanceMeters, 1234);
      expect(updated.status, HaulStatus.completed);
    });
  });
}
