import 'package:flutter_test/flutter_test.dart';
import 'package:styra/features/onboarding/domain/entities/user_profile.dart';

void main() {
  UserProfile makeProfile({
    String name = 'Hasan',
    String vesselName = 'KM Harapan',
    double trawlWidthMeters = 20.0,
    double? vesselGt,
    String? homePort,
  }) {
    final now = DateTime(2025, 1, 1);
    return UserProfile(
      name: name,
      vesselName: vesselName,
      trawlWidthMeters: trawlWidthMeters,
      vesselGtOptional: vesselGt,
      homePortOptional: homePort,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('UserProfile.validate', () {
    test('returns null for a valid profile', () {
      expect(
        UserProfile.validate(
          name: 'Hasan',
          vesselName: 'KM Harapan',
          trawlWidthMeters: 20.0,
        ),
        isNull,
      );
    });

    test('rejects empty name', () {
      expect(
        UserProfile.validate(
          name: '   ',
          vesselName: 'KM Harapan',
          trawlWidthMeters: 20.0,
        ),
        'Nama nelayan wajib diisi',
      );
    });

    test('rejects empty vessel name', () {
      expect(
        UserProfile.validate(
          name: 'Hasan',
          vesselName: '',
          trawlWidthMeters: 20.0,
        ),
        'Nama kapal wajib diisi',
      );
    });

    test('rejects zero or negative trawl width', () {
      expect(
        UserProfile.validate(
          name: 'Hasan',
          vesselName: 'KM Harapan',
          trawlWidthMeters: 0,
        ),
        'Lebar trawl harus lebih dari 0',
      );
      expect(
        UserProfile.validate(
          name: 'Hasan',
          vesselName: 'KM Harapan',
          trawlWidthMeters: -5,
        ),
        'Lebar trawl harus lebih dari 0',
      );
    });

    test('rejects unreasonably large trawl width', () {
      expect(
        UserProfile.validate(
          name: 'Hasan',
          vesselName: 'KM Harapan',
          trawlWidthMeters: 500,
        ),
        'Lebar trawl terlalu besar (maks 200m)',
      );
    });

    test('rejects negative GT', () {
      expect(
        UserProfile.validate(
          name: 'Hasan',
          vesselName: 'KM Harapan',
          trawlWidthMeters: 20,
          vesselGt: -1,
        ),
        'GT kapal tidak boleh negatif',
      );
    });
  });

  group('UserProfile.copyWith', () {
    test('changes only the named fields', () {
      final p = makeProfile(name: 'Hasan', vesselName: 'KM A');
      final updated = p.copyWith(name: 'Budi');
      expect(updated.name, 'Budi');
      expect(updated.vesselName, 'KM A');
      expect(updated.createdAt, p.createdAt); // createdAt is immutable
    });

    test('can clear nullable vesselGtOptional explicitly', () {
      final p = makeProfile(vesselGt: 5.0);
      expect(p.vesselGtOptional, 5.0);

      final cleared = p.copyWith(vesselGtOptional: null);
      expect(cleared.vesselGtOptional, isNull);
    });

    test('without vesselGtOptional argument keeps the original value', () {
      final p = makeProfile(vesselGt: 5.0);
      final updated = p.copyWith(name: 'Budi');
      expect(updated.vesselGtOptional, 5.0);
    });

    test('can clear nullable homePortOptional explicitly', () {
      final p = makeProfile(homePort: 'Brondong');
      final cleared = p.copyWith(homePortOptional: null);
      expect(cleared.homePortOptional, isNull);
    });

    test('preserves createdAt across edits', () {
      final p = makeProfile();
      final later = DateTime(2025, 6, 1);
      final updated = p.copyWith(
        name: 'Budi',
        updatedAt: later,
      );
      expect(updated.createdAt, p.createdAt);
      expect(updated.updatedAt, later);
    });
  });

  group('UserProfile misc', () {
    test('friendlyGreeting prefixes name with Pak', () {
      expect(makeProfile(name: 'Hasan').friendlyGreeting, 'Pak Hasan');
    });

    test('equality holds for equivalent values', () {
      final now = DateTime(2025, 1, 1);
      final a = UserProfile(
        name: 'H',
        vesselName: 'K',
        trawlWidthMeters: 20,
        createdAt: now,
        updatedAt: now,
      );
      final b = UserProfile(
        name: 'H',
        vesselName: 'K',
        trawlWidthMeters: 20,
        createdAt: now,
        updatedAt: now,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('default trawl width matches PRD default (20m)', () {
      expect(UserProfile.defaultTrawlWidthMeters, 20.0);
    });
  });
}
