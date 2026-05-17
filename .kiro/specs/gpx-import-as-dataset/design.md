# Design — PR #33 GPX Import as Dataset

> Companion ke `requirements.md`. Fokus: schema migration, repository
> arsitektur, parser overhaul, UI integration di 5 surface (Settings,
> Dataset Manager, MapScreen, Riwayat, MarkersListScreen, Dashboard).

## §1 Domain entity ImportedDataset

File baru:
`app/lib/features/export_import/domain/entities/imported_dataset.dart`

```dart
class ImportedDataset {
  const ImportedDataset({
    required this.id,
    required this.fileName,
    required this.importedAt,
    required this.visible,
    required this.markerCount,
    required this.tripCount,
    required this.haulCount,
    this.exporterName,
    this.vesselName,
    this.exportedAt,
  });

  final String id;
  final String fileName;
  final String? exporterName;
  final String? vesselName;
  final DateTime? exportedAt;
  final DateTime importedAt;
  final bool visible;
  final int markerCount;
  final int tripCount;
  final int haulCount;

  String get displayLabel =>
      vesselName != null ? '$vesselName · $fileName' : fileName;

  bool get isEmpty =>
      markerCount == 0 && tripCount == 0 && haulCount == 0;

  ImportedDataset copyWith({...}) => ...;
}
```

## §2 Schema bump v9 → v10

### Tabel baru `imported_datasets`

`tables.dart`:

```dart
@DataClassName('ImportedDatasetRow')
class ImportedDatasetsTable extends Table {
  TextColumn get id => text()();
  TextColumn get fileName => text()();
  TextColumn get exporterName => text().nullable()();
  TextColumn get vesselName => text().nullable()();
  DateTimeColumn get exportedAt => dateTime().nullable()();
  DateTimeColumn get importedAt => dateTime()();
  BoolColumn get visible => boolean().withDefault(const Constant(true))();
  IntColumn get markerCount => integer().withDefault(const Constant(0))();
  IntColumn get tripCount => integer().withDefault(const Constant(0))();
  IntColumn get haulCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  String? get tableName => 'imported_datasets';
}
```

### Kolom baru di tabel existing

3 tabel tambah `dataset_id TEXT NULL` dengan FK + ON DELETE CASCADE.

`Markers` table: tambah
```dart
TextColumn get datasetId => text()
    .nullable()
    .references(ImportedDatasetsTable, #id, onDelete: KeyAction.cascade)();
```

`Trips` table: idem.
`Hauls` table: idem (denormalized — sebenarnya bisa diturunkan dari
trip, tapi denorm bikin query map filtering jauh lebih cepat).

### Migration v9 → v10

`app_database.dart` `onUpgrade`:

```dart
if (from < 10) {
  await m.createTable(importedDatasetsTable);
  await m.addColumn(markers, markers.datasetId);
  await m.addColumn(trips, trips.datasetId);
  await m.addColumn(hauls, hauls.datasetId);
}
```

`schemaVersion` bump ke 10.

Drift `addColumn` pada nullable text aman: existing rows dapat NULL,
sesuai semantik "data milik user sendiri".

### Migration test

`migration_test.dart` tambah grup baru "v9 → v10":
- `imported_datasets` table exists
- `markers.dataset_id` column exists, default NULL untuk pre-v10 rows
- `trips.dataset_id` column exists, default NULL
- `hauls.dataset_id` column exists, default NULL
- Existing trip / haul / marker rows tetap bisa di-query (NULL OK)
- FK CASCADE: insert dataset, insert marker dengan dataset_id, delete
  dataset → marker auto-deleted.

## §3 Repository

### File baru: ImportedDatasetRepository

`app/lib/features/export_import/data/imported_dataset_repository.dart`:

```dart
class ImportedDatasetRepository {
  ImportedDatasetRepository(this._dao);
  final ImportedDatasetDao _dao;

  Future<ImportedDataset> create({...}) async => ...;
  Future<List<ImportedDataset>> getAll() async => ...;
  Stream<List<ImportedDataset>> watchAll() async* => ...;
  Future<void> setVisible(String id, bool visible) async => ...;
  Future<void> delete(String id) async => ...; // CASCADE handle children
  Future<void> recountChildren(String id) async => ...; // call after child delete
  Future<void> autoCleanupIfEmpty(String id) async => ...;
}
```

`ImportedDatasetDao` di Drift dengan watch stream + raw SQL untuk
recount denormalized counters.

### Update repository existing

`MarkerRepository`:
- `getAll({bool includeImported = true, Set<String>? visibleDatasetIds})`
  — kalau parameter ada, filter dengan `dataset_id IN (...)` atau
  `dataset_id IS NULL` (untuk own).
- `getOwnOnly()` shortcut.
- `getByDataset(String datasetId)`.
- `createForDataset({...})` — wrapper `create` yang isi `dataset_id`.

`TripRepository`:
- `listAll({bool includeImported = true, Set<String>? visibleDatasetIds})`.
- `getOwnOnly()`.
- `getByDataset(String datasetId)`.

`HaulRepository`:
- `listAllCompleted({bool includeImported = true, Set<String>? visibleDatasetIds})`.

## §4 GpxImporter overhaul

`gpx_importer.dart` overhaul untuk handle ekstensi `lsea`. Strategi:
satu pass parsing, kumpulkan data ke struct intermediate, lalu di
`import()` insert dataset row dulu lalu children dengan FK.

```dart
class GpxImportPreview {
  final String fileName;
  final String? exporterName;
  final String? vesselName;
  final DateTime? exportedAt;
  final List<_PendingWaypoint> waypoints;
  final List<_PendingTrack> tracks;
  ...
}

class _PendingWaypoint {
  final String name;
  final double latitude;
  final double longitude;
  final String? description;
  final MarkerCategory category;  // <-- baru
}

class _PendingTrack {
  final String? tripName;          // dari <lsea:trip name>
  final int? tripColorValue;       // dari <lsea:trip colorValue>
  final String? haulName;          // dari <trk><name>
  final int? haulColorValue;       // dari <lsea:haul colorValue>
  final List<_PendingTrackPoint> points;
}

extension MarkerCategoryGpxParse on MarkerCategory {
  static MarkerCategory fromGpxValue(String? value) =>
      switch (value) {
        'produktif' => MarkerCategory.productive,
        'pelabuhan' => MarkerCategory.port,
        'bahaya' => MarkerCategory.hazard,
        _ => MarkerCategory.other,
      };
}
```

`import()` flow:

```dart
Future<int> import(GpxImportPreview preview) async {
  final datasetRepo = _ref.read(importedDatasetRepositoryProvider);
  final markerRepo = _ref.read(markerRepositoryProvider);
  final tripRepo = _ref.read(tripRepositoryProvider);
  final haulRepo = _ref.read(haulRepositoryProvider);
  final pointRepo = _ref.read(trackPointRepositoryProvider);

  // 1. Buat dataset row
  final dataset = await datasetRepo.create(
    fileName: preview.fileName,
    exporterName: preview.exporterName,
    vesselName: preview.vesselName,
    exportedAt: preview.exportedAt,
  );

  // 2. Insert markers
  for (final wp in preview.waypoints) {
    await markerRepo.createForDataset(
      datasetId: dataset.id,
      name: wp.name,
      category: wp.category,
      ...
    );
  }

  // 3. Group tracks by tripName
  final tracksByTrip = groupBy(preview.tracks, (t) => t.tripName ?? 'default');
  for (final entry in tracksByTrip.entries) {
    final trip = await tripRepo.createForDataset(
      datasetId: dataset.id,
      name: entry.key == 'default'
          ? 'Impor: ${preview.fileName}'
          : entry.key,
      colorValue: entry.value.first.tripColorValue,
    );
    for (final track in entry.value) {
      final haul = await haulRepo.createForDataset(
        datasetId: dataset.id,
        tripId: trip.id,
        name: track.haulName,
        colorValue: track.haulColorValue,
      );
      for (final pt in track.points) {
        await pointRepo.appendImportedPoint(
          haulId: haul.id,
          ...,
        );
      }
      // Recompute haul stats
      await haulRepo.recomputeStats(haul.id);
    }
  }

  // 4. Update denorm counters
  await datasetRepo.recountChildren(dataset.id);

  return preview.waypoints.length +
      preview.tracks.fold(0, (a, t) => a + t.points.length);
}
```

## §5 UI: ImportedDatasetsScreen

File baru:
`app/lib/features/export_import/presentation/imported_datasets_screen.dart`

`ConsumerWidget` watch `importedDatasetsProvider` (stream).

Layout: AmbientBackground + ListView dengan card per dataset:

```
┌─ GlassCard ───────────────────────┐
│ ☑  📁 Trip Pak Hasan 25 Mei.gpx   │
│     KM Sumber Rejeki · 25 Mei 2026│
│     12 marker · 3 trip · 8 tarikan│
│     Diimpor 26 Mei 2026, 14:30    │
│                          [🗑]      │
└────────────────────────────────────┘
```

Empty state: "Belum ada data impor. Tap Impor Data di Settings untuk
memulai."

Confirmation dialog hapus pakai `AlertDialog` standar.

## §6 UI: MapScreen overlay filter

Section baru di overlay control panel (tempat ada toggle markers /
history). Render conditional: hanya kalau `importedDatasetsProvider`
return non-empty list.

Layout:
```
═════ Data Impor ══════════════════════
☑ Trip Pak Hasan 25 Mei.gpx
☑ Spot Pak Budi.gpx
☐ Pelabuhan Surabaya.gpx
═════════════════════════════════════
```

Setiap checkbox toggle `visible` flag via repository.

## §7 UI: Settings tile

`settings_screen.dart` tambah tile setelah "Impor Data (GPX)":

```dart
_SettingsTile(
  iconColor: ...,
  iconBg: ...,
  icon: PhosphorIconsBold.filesFolderOpen,
  title: 'Kelola Data Impor',
  subtitle: '$count dataset diimpor',
  onTap: () => context.push(AppRoutes.importedDatasets),
),
```

`AppRoutes.importedDatasets` = `/imported-datasets`. Daftarkan di
`app_router.dart`.

## §8 UI: Riwayat badge

`history_screen.dart` `TripCard` (atau `_TripCard`) tambah Badge:

```dart
if (trip.datasetId != null)
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: tokens.accentSoft,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text('Impor', style: text.labelSmall),
  ),
```

`trip_detail_screen.dart`:
- Tombol Edit: `enabled: trip.datasetId == null`
- Tombol Hapus: tetap aktif. Setelah delete:
  ```dart
  if (trip.datasetId != null) {
    await ref.read(importedDatasetRepositoryProvider)
      .recountChildren(trip.datasetId!);
    await ref.read(importedDatasetRepositoryProvider)
      .autoCleanupIfEmpty(trip.datasetId!);
  }
  ```

## §9 UI: MarkersListScreen badge + filter

`markers_list_screen.dart`:

- Tile marker tambah badge "Impor" kalau `marker.datasetId != null`
- Filter dropdown di app bar: "Semua / Saya / {dataset name}"
- Tombol Edit per marker disabled jika imported, Hapus tetap aktif

## §10 UI: Dashboard toggle

`dashboard_screen.dart`:
- Header tambah `SwitchListTile` "Sertakan data impor"
- State `bool _includeImported` di-load dari SharedPreferences key
  `dashboard_include_imported_v1`, default false
- `dashboardStatsProvider` parameter family (perlu refactor kalau
  current pakai value provider) accept `includeImported: bool`

## §11 Edit/delete guards

### Repository level (defense in depth)

```dart
class MarkerRepository {
  Future<void> update(AppMarker marker) async {
    if (marker.datasetId != null) {
      throw const StateError(
        'Marker dari data impor tidak bisa diedit. Hapus dataset utuh.',
      );
    }
    ...
  }
}
```

### UI level

Hide / disable tombol Edit kalau `datasetId != null`.

## §12 Stream invalidation strategy

Beberapa provider yang perlu auto-refresh saat dataset visible
flag berubah:
- `markersProvider` di MapScreen
- `historyOverlayProvider`
- `markersListProvider` di MarkersListScreen
- `dashboardStatsProvider`

Pakai `appDatabaseProvider.watch(...)` Drift stream untuk invalidate
otomatis. Riverpod `.select` untuk minimize rebuild.

## §13 Decision points yang sudah final

| Topic | Decision |
|---|---|
| Storage konsep dataset | Drift table `imported_datasets` v10 |
| FK | ON DELETE CASCADE di 3 child table |
| Auto-cleanup empty dataset | Ya, otomatis setelah child delete |
| Roundtrip with own export | Lossless untuk kategori + warna |
| Map filter granularity | Per-file checkbox di MapScreen overlay |
| Riwayat imported trip | Tampil dengan badge, edit disabled, delete enabled |
| Dashboard imported | Toggle "Sertakan data impor" default off |
| MarkersList badge | Tampilkan + filter dropdown source |

## §14 Test strategy

- `imported_dataset_test.dart` — entity helpers
- `imported_dataset_repository_test.dart` — CRUD + cascade delete
- `gpx_importer_v2_test.dart` — parse `<lsea:marker>`, `<lsea:trip>`,
  `<lsea:haul>` with golden GPX strings
- `gpx_roundtrip_test.dart` — export → import lossless verify
- `migration_test.dart` v9 → v10 — kolom baru, FK CASCADE
