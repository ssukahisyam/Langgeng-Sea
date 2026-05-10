// Equality, hash, and display contract for NavigationTarget sealed class.

import 'package:flutter_test/flutter_test.dart';
import 'package:langgeng_sea/features/navigation/domain/entities/navigation_target.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('GotoTarget', () {
    test('displayLabel returns the configured label', () {
      const target = GotoTarget(
        position: LatLng(-7.2, 113.4),
        label: 'Spot Udang',
      );
      expect(target.displayLabel, 'Spot Udang');
    });

    test('two targets with the same fields are equal', () {
      const a = GotoTarget(
        position: LatLng(-7.2, 113.4),
        label: 'A',
        sourceMarkerId: 'm1',
      );
      const b = GotoTarget(
        position: LatLng(-7.2, 113.4),
        label: 'A',
        sourceMarkerId: 'm1',
      );
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('differing sourceMarkerId breaks equality', () {
      const a = GotoTarget(
        position: LatLng(-7.2, 113.4),
        label: 'A',
        sourceMarkerId: 'm1',
      );
      const b = GotoTarget(
        position: LatLng(-7.2, 113.4),
        label: 'A',
      );
      expect(a == b, isFalse);
    });
  });

  group('FollowTrackTarget', () {
    test('displayLabel returns the configured label', () {
      const target = FollowTrackTarget(
        pathPoints: [LatLng(0, 0), LatLng(0, 0.1)],
        label: 'Haul #3',
        sourceType: FollowTrackSource.haul,
        sourceId: 'h-1',
      );
      expect(target.displayLabel, 'Haul #3');
    });

    test('equality compares pathPoints element-wise', () {
      const a = FollowTrackTarget(
        pathPoints: [LatLng(0, 0), LatLng(0, 0.1)],
        label: 'X',
        sourceType: FollowTrackSource.haul,
        sourceId: 'h-1',
      );
      const b = FollowTrackTarget(
        pathPoints: [LatLng(0, 0), LatLng(0, 0.1)],
        label: 'X',
        sourceType: FollowTrackSource.haul,
        sourceId: 'h-1',
      );
      expect(a == b, isTrue);
    });

    test('different pathPoints length breaks equality', () {
      const a = FollowTrackTarget(
        pathPoints: [LatLng(0, 0), LatLng(0, 0.1)],
        label: 'X',
        sourceType: FollowTrackSource.haul,
        sourceId: 'h-1',
      );
      const b = FollowTrackTarget(
        pathPoints: [LatLng(0, 0)],
        label: 'X',
        sourceType: FollowTrackSource.haul,
        sourceId: 'h-1',
      );
      expect(a == b, isFalse);
    });
  });

  test('sealed hierarchy accepts both branches', () {
    // Smoke test — doubles as a compile-time check that the two
    // classes both extend NavigationTarget correctly.
    const NavigationTarget goto = GotoTarget(
      position: LatLng(0, 0),
      label: 'X',
    );
    const NavigationTarget follow = FollowTrackTarget(
      pathPoints: [LatLng(0, 0), LatLng(0, 0.1)],
      label: 'Y',
      sourceType: FollowTrackSource.trip,
      sourceId: 't-1',
    );
    expect(goto, isA<GotoTarget>());
    expect(follow, isA<FollowTrackTarget>());
  });
}
