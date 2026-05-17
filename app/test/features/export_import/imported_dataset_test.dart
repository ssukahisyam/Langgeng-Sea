// Unit test untuk [ImportedDataset] entity (PR #33 Phase 1).

import 'package:flutter_test/flutter_test.dart';
import 'package:langgeng_sea/features/export_import/domain/entities/imported_dataset.dart';

void main() {
  group('ImportedDataset.displayLabel', () {
    test('with vesselName: format "vessel · filename"', () {
      final d = ImportedDataset(
        id: 'd1',
        fileName: 'Trip Pak Hasan 25 Mei.gpx',
        importedAt: DateTime(2026, 5, 26, 14, 30),
        visible: true,
        markerCount: 12,
        tripCount: 3,
        haulCount: 8,
        vesselName: 'KM Sumber Rejeki',
      );
      expect(d.displayLabel, 'KM Sumber Rejeki · Trip Pak Hasan 25 Mei.gpx');
    });

    test('without vesselName: just filename', () {
      final d = ImportedDataset(
        id: 'd1',
        fileName: 'osmand_export.gpx',
        importedAt: DateTime(2026, 5, 26),
        visible: true,
        markerCount: 5,
        tripCount: 0,
        haulCount: 0,
      );
      expect(d.displayLabel, 'osmand_export.gpx');
    });

    test('empty vesselName: just filename', () {
      final d = ImportedDataset(
        id: 'd1',
        fileName: 'foo.gpx',
        importedAt: DateTime(2026, 5, 26),
        visible: true,
        markerCount: 1,
        tripCount: 0,
        haulCount: 0,
        vesselName: '',
      );
      expect(d.displayLabel, 'foo.gpx');
    });
  });

  group('ImportedDataset.isEmpty', () {
    test('true ketika semua counter 0', () {
      final d = ImportedDataset(
        id: 'd1',
        fileName: 'empty.gpx',
        importedAt: DateTime(2026),
        visible: true,
        markerCount: 0,
        tripCount: 0,
        haulCount: 0,
      );
      expect(d.isEmpty, isTrue);
    });

    test('false ketika ada marker', () {
      final d = ImportedDataset(
        id: 'd1',
        fileName: 'foo.gpx',
        importedAt: DateTime(2026),
        visible: true,
        markerCount: 1,
        tripCount: 0,
        haulCount: 0,
      );
      expect(d.isEmpty, isFalse);
    });

    test('false ketika ada trip / haul saja', () {
      final base = ImportedDataset(
        id: 'd1',
        fileName: 'foo.gpx',
        importedAt: DateTime(2026),
        visible: true,
        markerCount: 0,
        tripCount: 0,
        haulCount: 0,
      );
      expect(base.copyWith(tripCount: 1).isEmpty, isFalse);
      expect(base.copyWith(haulCount: 1).isEmpty, isFalse);
    });
  });

  group('ImportedDataset.copyWith', () {
    test('round-trip identity', () {
      final original = ImportedDataset(
        id: 'd1',
        fileName: 'foo.gpx',
        importedAt: DateTime(2026, 5, 26),
        visible: true,
        markerCount: 12,
        tripCount: 3,
        haulCount: 8,
        exporterName: 'Pak Hasan',
        vesselName: 'KM Sumber Rejeki',
        exportedAt: DateTime(2026, 5, 25),
      );
      final clone = original.copyWith();
      expect(clone, equals(original));
    });

    test('ubah satu field tidak mengubah field lain', () {
      final original = ImportedDataset(
        id: 'd1',
        fileName: 'foo.gpx',
        importedAt: DateTime(2026, 5, 26),
        visible: true,
        markerCount: 12,
        tripCount: 3,
        haulCount: 8,
      );
      final updated = original.copyWith(visible: false);
      expect(updated.visible, isFalse);
      expect(updated.id, original.id);
      expect(updated.fileName, original.fileName);
      expect(updated.markerCount, original.markerCount);
    });
  });

  group('ImportedDataset equality', () {
    test('equal kalau semua field sama', () {
      final a = ImportedDataset(
        id: 'd1',
        fileName: 'foo.gpx',
        importedAt: DateTime(2026, 5, 26),
        visible: true,
        markerCount: 1,
        tripCount: 0,
        haulCount: 0,
      );
      final b = ImportedDataset(
        id: 'd1',
        fileName: 'foo.gpx',
        importedAt: DateTime(2026, 5, 26),
        visible: true,
        markerCount: 1,
        tripCount: 0,
        haulCount: 0,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal kalau id beda', () {
      final a = ImportedDataset(
        id: 'd1',
        fileName: 'foo.gpx',
        importedAt: DateTime(2026, 5, 26),
        visible: true,
        markerCount: 0,
        tripCount: 0,
        haulCount: 0,
      );
      final b = a.copyWith(id: 'd2');
      expect(a, isNot(equals(b)));
    });
  });
}
