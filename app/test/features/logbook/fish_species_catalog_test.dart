import 'package:flutter_test/flutter_test.dart';

import 'package:styra/features/logbook/domain/fish_species_catalog.dart';

void main() {
  group('FishSpeciesCatalog', () {
    group('presets', () {
      test('contains 33 species', () {
        expect(FishSpeciesCatalog.presets.length, 33);
      });

      test('contains well-known species', () {
        expect(FishSpeciesCatalog.presets, contains('Bandeng'));
        expect(FishSpeciesCatalog.presets, contains('Tongkol'));
        expect(FishSpeciesCatalog.presets, contains('Udang Windu'));
      });
    });

    group('search', () {
      test('returns all presets when query is empty', () {
        final results = FishSpeciesCatalog.search('');
        expect(results.length, 33);
      });

      test('filters by substring match', () {
        final results = FishSpeciesCatalog.search('kakap');
        expect(results, contains('Kakap Merah'));
        expect(results, contains('Kakap Putih'));
        expect(results.length, 2);
      });

      test('is case-insensitive', () {
        final upper = FishSpeciesCatalog.search('TUNA');
        final lower = FishSpeciesCatalog.search('tuna');
        final mixed = FishSpeciesCatalog.search('TuNa');
        expect(upper, lower);
        expect(upper, mixed);
      });

      test('returns empty list for no match', () {
        final results = FishSpeciesCatalog.search('xyz_nope');
        expect(results, isEmpty);
      });

      test('matches partial names', () {
        final results = FishSpeciesCatalog.search('ung');
        // Should match Kembung, Tembang — at least Kembung
        expect(results, contains('Kembung'));
      });
    });

    group('isPreset', () {
      test('returns true for exact match', () {
        expect(FishSpeciesCatalog.isPreset('Bandeng'), isTrue);
      });

      test('is case-insensitive', () {
        expect(FishSpeciesCatalog.isPreset('bandeng'), isTrue);
        expect(FishSpeciesCatalog.isPreset('BANDENG'), isTrue);
        expect(FishSpeciesCatalog.isPreset('BaNdEnG'), isTrue);
      });

      test('returns false for non-preset', () {
        expect(FishSpeciesCatalog.isPreset('Salmon'), isFalse);
        expect(FishSpeciesCatalog.isPreset(''), isFalse);
      });

      test('returns true for multi-word species', () {
        expect(FishSpeciesCatalog.isPreset('Tuna Sirip Biru'), isTrue);
        expect(FishSpeciesCatalog.isPreset('tuna sirip biru'), isTrue);
        expect(FishSpeciesCatalog.isPreset('udang jerbung'), isTrue);
      });
    });
  });
}
