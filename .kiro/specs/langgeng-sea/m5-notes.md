# M5 — Log Book & Marker

## Shipped

Milestone M5 mengimplementasikan dua fitur utama:

### 1. Log Book Digital

- **Domain entities**: `LogBookEntry`, `CatchItem`, `FishSpeciesCatalog`
  - Log book entry bisa per-haul atau per-trip (scope enum)
  - Mencatat: hasil tangkap (jenis + kg opsional), cuaca, gelombang, BBM, biaya, kru, catatan
  - `FishSpeciesCatalog` menyediakan 33 jenis ikan preset Indonesia + search + isPreset
- **Database**: `LogBookEntries` dan `CatchItems` tables (schema v3)
  - FK cascade: hapus entry → hapus semua catch items
- **DAO**: `LogBookDao` — CRUD untuk entries dan catch items
- **Repository**: `LogBookRepository` + Riverpod providers (`logBookByHaulProvider`, `logBookByTripProvider`)
- **UI**: `LogBookFormScreen` — form ConsumerStatefulWidget
  - Dynamic catch items list (add/remove, species autocomplete dari katalog)
  - Segmented picker untuk cuaca (cerah/mendung/hujan) dan gelombang (tenang/sedang/tinggi)
  - Notes textarea
  - Semua field opsional, sesuai prinsip low-friction UX
- **Routes**: `/log-book/haul/:id` dan `/log-book/trip/:id`

### 2. Marker Kustom

- **Domain entity**: `AppMarker` dengan `MarkerCategory` enum (productive/hazard/port/other)
  - Extensions: `storageKey`, `displayLabel`
  - Top-level `filterMarkersByCategory` function
  - `latLng` getter untuk integrasi flutter_map
- **Database**: `Markers` table (schema v3)
- **DAO**: `MarkerDao` — CRUD + watchAll
- **Repository**: `MarkerRepository` + Riverpod providers (`allMarkersProvider` stream, `markerByIdProvider`)
- **UI**:
  - `MarkersListScreen` — list dengan filter chips (Semua/Produktif/Karang/Pelabuhan), empty state
  - `AddMarkerDialog` — form dialog: nama, kategori dropdown, notes opsional, koordinat readonly
- **Route**: `/markers`

### Schema Migration

- v2 → v3: creates `log_book_entries`, `catch_items`, `markers` tables

### Tests

- `fish_species_catalog_test.dart` — search filters, isPreset case-insensitive
- `marker_filter_test.dart` — filterMarkersByCategory null (all) & specific category

### Conventions Followed

- Bahasa Indonesia untuk semua UI text
- Glass Card / Ambient Background design system
- Riverpod Provider pattern matching M1–M4
- Drift DAO pattern with `part 'filename.g.dart';`
- Clean Architecture layers: domain/data/presentation
- GoRouter slide-up transitions for detail routes

## Next: M6 Dashboard

Statistik & grafik performa nelayan (mingguan/bulanan).
