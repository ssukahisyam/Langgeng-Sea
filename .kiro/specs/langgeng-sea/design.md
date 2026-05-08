# Design & Arsitektur - Langgeng Sea

**Technical Design Document**
**Versi:** 1.0 (MVP)
**Tanggal:** 8 Mei 2026

---

## 1. Prinsip Desain

1. **Offline-First** — semua fitur inti harus bekerja tanpa internet.
2. **Local-Only Data** — tidak ada server backend di MVP, semua di SQLite device.
3. **Battery-Efficient** — GPS hanya aktif saat tombol ditekan, bukan background terus.
4. **Clean Architecture** — pisahkan UI, domain, dan data agar mudah dirawat.
5. **Testable** — domain & data layer harus mudah di-unit-test.
6. **Fail-Safe** — tulis data incremental ke DB, recovery otomatis jika crash.

---

## 2. Tech Stack

### 2.1 Framework & Language
| Komponen | Pilihan | Alasan |
|---|---|---|
| Framework | **Flutter 3.24+** | Multi-platform ready (v2 iOS), dev cepat, komunitas besar |
| Bahasa | **Dart 3.5+** | Type-safe, null-safety, async/await native |
| Min SDK Android | API 26 (Android 8.0) | Coverage ~95% device aktif |
| Target SDK | API 34 (Android 14) | Compliance Play Store |

### 2.2 Dependencies Utama

| Package | Versi | Fungsi |
|---|---|---|
| `flutter_map` | ^7.0.0 | Peta OSM/OpenSeaMap |
| `flutter_map_tile_caching` | ^9.0.0 | Download & cache tile offline |
| `latlong2` | ^0.9.0 | Koordinat geografis |
| `geolocator` | ^12.0.0 | GPS tracking |
| `flutter_background_service` | ^5.0.0 | Foreground service tracking |
| `sqflite` | ^2.3.0 | Database lokal |
| `drift` | ^2.18.0 | ORM di atas SQLite (type-safe) |
| `riverpod` | ^2.5.0 | State management |
| `go_router` | ^14.0.0 | Navigation |
| `freezed` | ^2.5.0 | Immutable data classes |
| `json_annotation` | ^4.9.0 | JSON serialization |
| `intl` | ^0.19.0 | Lokalisasi & format tanggal |
| `share_plus` | ^9.0.0 | Share file |
| `file_picker` | ^8.0.0 | Import file |
| `path_provider` | ^2.1.0 | File system paths |
| `permission_handler` | ^11.3.0 | Request permissions |
| `fl_chart` | ^0.68.0 | Grafik dashboard |
| `gpx` | ^2.2.0 | Parse/generate GPX |
| `turf` (port) / custom | - | Kalkulasi geospasial (luas poligon) |

### 2.3 Dev Tools
- **State Management:** Riverpod
- **Code Gen:** `build_runner` + `freezed` + `drift_dev` + `json_serializable`
- **Linter:** `flutter_lints` + custom rules
- **Testing:** `flutter_test`, `mocktail`, `integration_test`
- **CI:** GitHub Actions (lint, test, build APK)

---

## 3. Arsitektur Tingkat Tinggi

### 3.1 Clean Architecture (3 Layer)

```
┌─────────────────────────────────────────────┐
│           PRESENTATION LAYER                │
│  (Widgets, Screens, Riverpod Providers)     │
└───────────────────┬─────────────────────────┘
                    │ depends on
                    ▼
┌─────────────────────────────────────────────┐
│              DOMAIN LAYER                   │
│  (Entities, Use Cases, Repository Interface)│
└───────────────────┬─────────────────────────┘
                    │ depends on
                    ▼
┌─────────────────────────────────────────────┐
│               DATA LAYER                    │
│  (Drift DB, GPS Service, Tile Cache, Files) │
└─────────────────────────────────────────────┘
```

### 3.2 Diagram Modul

```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│     Map      │  │   Tracking   │  │    Haul      │
│   Feature    │  │   Feature    │  │   Feature    │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │
       └────────┬────────┴────────┬────────┘
                │                 │
         ┌──────▼──────┐   ┌──────▼──────┐
         │  GPS Service │   │  Database   │
         │ (Geolocator) │   │   (Drift)   │
         └──────────────┘   └─────────────┘
```

---

## 4. Struktur Folder

```
lib/
├── main.dart
├── app.dart                        # MaterialApp + GoRouter
├── core/
│   ├── constants/
│   │   ├── app_colors.dart
│   │   ├── app_sizes.dart
│   │   └── app_strings.dart
│   ├── extensions/
│   ├── utils/
│   │   ├── geo_calculator.dart    # Jarak, luas, heading
│   │   ├── formatter.dart          # Format knot, km, durasi
│   │   └── logger.dart
│   ├── errors/
│   │   ├── exceptions.dart
│   │   └── failures.dart
│   └── router/
│       └── app_router.dart
├── features/
│   ├── onboarding/
│   │   ├── presentation/
│   │   └── data/
│   ├── map/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── tile_cache_datasource.dart
│   │   │   └── repositories/
│   │   │       └── map_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   └── usecases/
│   │   └── presentation/
│   │       ├── providers/
│   │       ├── screens/
│   │       │   └── map_screen.dart
│   │       └── widgets/
│   ├── tracking/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── gps_datasource.dart
│   │   │   │   └── tracking_local_datasource.dart
│   │   │   ├── models/
│   │   │   └── repositories/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── track_point.dart
│   │   │   │   ├── haul.dart
│   │   │   │   └── trip.dart
│   │   │   ├── repositories/
│   │   │   └── usecases/
│   │   │       ├── start_haul_usecase.dart
│   │   │       ├── stop_haul_usecase.dart
│   │   │       ├── calculate_metrics_usecase.dart
│   │   │       └── ...
│   │   └── presentation/
│   │       ├── providers/
│   │       ├── screens/
│   │       │   ├── tracking_screen.dart
│   │       │   └── haul_detail_screen.dart
│   │       └── widgets/
│   │           ├── big_start_button.dart
│   │           ├── live_stats_panel.dart
│   │           └── ...
│   ├── trip/
│   ├── haul/
│   ├── marker/
│   ├── logbook/
│   ├── dashboard/
│   ├── export_import/
│   ├── settings/
│   └── profile/
├── data/
│   ├── database/
│   │   ├── app_database.dart       # Drift database
│   │   ├── tables/
│   │   │   ├── trips_table.dart
│   │   │   ├── hauls_table.dart
│   │   │   ├── track_points_table.dart
│   │   │   ├── markers_table.dart
│   │   │   └── logbook_entries_table.dart
│   │   └── daos/
│   └── services/
│       ├── gps_service.dart
│       ├── background_tracking_service.dart
│       └── file_service.dart
└── l10n/
    └── app_id.arb                   # Bahasa Indonesia
```

---

## 5. Model Data (Entities)

### 5.1 Entity Diagram

```
┌────────────┐  1    N ┌──────────┐  1    N ┌──────────────┐
│    Trip    ├────────>│   Haul   ├────────>│  TrackPoint  │
└────────────┘         └──────────┘         └──────────────┘
       │                     │
       │                     │ 0..1
       │                     ▼
       │              ┌──────────────┐
       │              │ LogBookEntry │
       │              └──────────────┘
       │
       │ 0..1
       ▼
┌──────────────┐
│  TripLogBook │
└──────────────┘

┌────────────┐
│   Marker   │  (independent)
└────────────┘

┌────────────┐
│  UserProfile│ (singleton)
└────────────┘
```

### 5.2 Skema Database (SQLite via Drift)

```dart
// UserProfile (singleton, row id=1)
Table user_profiles {
  id INTEGER PK
  name TEXT NOT NULL
  vessel_name TEXT
  vessel_gt REAL
  home_port TEXT
  trawl_width_meters REAL DEFAULT 20.0
  created_at INTEGER
  updated_at INTEGER
}

Table trips {
  id TEXT PK (UUID)
  name TEXT
  started_at INTEGER NOT NULL
  ended_at INTEGER
  status TEXT (active|completed)
  home_port TEXT
  notes TEXT
  created_at INTEGER
  updated_at INTEGER
}

Table hauls {
  id TEXT PK (UUID)
  trip_id TEXT FK -> trips.id
  name TEXT
  order_index INTEGER
  started_at INTEGER NOT NULL
  ended_at INTEGER
  status TEXT (recording|completed)
  distance_meters REAL
  duration_seconds INTEGER
  avg_speed_knots REAL
  avg_heading_degrees REAL
  swept_area_m2 REAL
  trawl_width_meters REAL
  notes TEXT
  color TEXT (hex)
  created_at INTEGER
  updated_at INTEGER
}

Table track_points {
  id INTEGER PK AUTOINCREMENT
  haul_id TEXT FK -> hauls.id
  latitude REAL
  longitude REAL
  altitude REAL
  speed_mps REAL
  heading_degrees REAL
  accuracy_meters REAL
  timestamp INTEGER
  INDEX (haul_id, timestamp)
}

Table markers {
  id TEXT PK (UUID)
  name TEXT NOT NULL
  category TEXT (productive|reef|port|other)
  latitude REAL
  longitude REAL
  notes TEXT
  color TEXT
  icon TEXT
  created_at INTEGER
}

Table logbook_entries {
  id TEXT PK (UUID)
  haul_id TEXT FK NULL -> hauls.id  // NULL if trip-level
  trip_id TEXT FK NULL -> trips.id
  weather TEXT
  wave_condition TEXT
  fuel_liters REAL
  cost_rupiah INTEGER
  crew_count INTEGER
  notes TEXT
  created_at INTEGER
}

Table catch_items {
  id TEXT PK (UUID)
  logbook_entry_id TEXT FK -> logbook_entries.id
  fish_species TEXT
  weight_kg REAL
  count_pieces INTEGER
  price_per_kg INTEGER
}

Table imported_data {
  id TEXT PK (UUID)
  source_name TEXT  // nama pengirim
  file_name TEXT
  imported_at INTEGER
  payload TEXT  // JSON blob tracks + markers
}

Table offline_map_regions {
  id TEXT PK (UUID)
  name TEXT
  min_lat REAL
  max_lat REAL
  min_lng REAL
  max_lng REAL
  min_zoom INTEGER
  max_zoom INTEGER
  size_bytes INTEGER
  tile_count INTEGER
  downloaded_at INTEGER
}
```

---

## 6. Komponen Kunci

### 6.1 GPS Tracking Flow

```
USER: tap "MULAI TEBAR"
   │
   ▼
StartHaulUseCase
   │
   ├─> TripRepository.getActiveTripOrCreate()
   │
   ├─> HaulRepository.create(trip_id, order_index)
   │
   ├─> BackgroundTrackingService.start(haulId)
   │     │
   │     └─> Geolocator.getPositionStream(
   │           accuracy: high,
   │           distanceFilter: 0,
   │           interval: 10s
   │         ).listen((pos) {
   │            TrackPointRepo.insert(haulId, pos);
   │            _updateLiveStats();
   │         });
   │
   └─> UI: switch to "tracking mode"
       - big red "ANGKAT TRAWL" button
       - live stats panel
       - boat icon on map
```

```
USER: tap "ANGKAT TRAWL"
   │
   ▼
StopHaulUseCase
   │
   ├─> BackgroundTrackingService.stop()
   │
   ├─> CalculateMetricsUseCase.execute(haulId)
   │     │
   │     ├─> fetch all track_points
   │     ├─> distance = sum of haversine(p[i], p[i+1])
   │     ├─> duration = last.ts - first.ts
   │     ├─> avg_speed = distance / duration
   │     ├─> swept_area = distance × trawl_width
   │     └─> avg_heading = circular mean of headings
   │
   ├─> HaulRepository.update(metrics, status=completed)
   │
   └─> UI: show haul summary screen
       - polyline on map
       - metrics card
       - button "Isi Log Book" / "Haul Berikutnya" / "Akhiri Trip"
```

### 6.2 Kalkulasi Geospasial

**Jarak (Haversine):**
```dart
double haversine(LatLng a, LatLng b) {
  const R = 6371000.0; // meter
  final dLat = _toRad(b.lat - a.lat);
  final dLon = _toRad(b.lng - a.lng);
  final lat1 = _toRad(a.lat);
  final lat2 = _toRad(b.lat);

  final h = sin(dLat/2) * sin(dLat/2) +
            cos(lat1) * cos(lat2) * sin(dLon/2) * sin(dLon/2);
  return 2 * R * asin(sqrt(h));
}
```

**Luas sapuan trawl (pendekatan):**
```
swept_area = total_distance × trawl_width
```
Pendekatan ini akurat untuk trawl yang ditarik lurus. Untuk presisi lebih tinggi (track melengkung) dapat pakai buffer polygon + simplify.

**Circular mean heading** (rata-rata arah yang benar secara trigonometri):
```dart
double circularMean(List<double> degrees) {
  double sumSin = 0, sumCos = 0;
  for (final d in degrees) {
    sumSin += sin(_toRad(d));
    sumCos += cos(_toRad(d));
  }
  final avg = atan2(sumSin, sumCos);
  return (_toDeg(avg) + 360) % 360;
}
```

### 6.3 Peta Offline (Tile Caching)

Pakai `flutter_map_tile_caching` (FMTC).

**Flow Download:**
```
User buka "Peta Offline" > "Tambah Area"
  │
  ▼
User pan-zoom peta ke area yang dibutuhkan
  │
  ▼
Tap "Pilih Area Ini"
  │
  ▼
Dialog:
  - Nama area: "Selat Madura"
  - Zoom: 8 - 16 (default)
  - Estimasi: 250 MB, 12.000 tiles
  - [Download] / [Batal]
  │
  ▼
FMTC.download(region, minZoom, maxZoom)
  → progress bar, dapat di-pause
  │
  ▼
Saved to local storage, listed di "Peta Offline"
```

**Flow Gunakan:**
Saat `TileLayer` di-setup dengan `FMTCStore('mapStore').getTileProvider()`, tile otomatis di-serve dari cache tanpa request HTTP.

**Sumber Tile (Free):**
- OSM: `https://tile.openstreetmap.org/{z}/{x}/{y}.png` (wajib attribution + respect usage policy)
- OpenSeaMap overlay: `https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png`
- Alternatif: Stadia Maps free tier, CartoDB.

### 6.4 Background Service (Foreground Service)

Android membutuhkan **Foreground Service** agar GPS terus jalan saat app di-background / HP locked.

```dart
// android/app/src/main/AndroidManifest.xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

Notifikasi persistent saat tracking aktif:
> "Langgeng Sea sedang merekam Haul #2 - 1.2 km, 00:45:12"

### 6.5 Format Ekspor

**GPX (track only):**
```xml
<gpx version="1.1" creator="Langgeng Sea">
  <trk>
    <name>Trip 2026-05-08 - Haul #1 "Spot Utara"</name>
    <trkseg>
      <trkpt lat="-6.123" lon="112.456">
        <time>2026-05-08T06:00:00Z</time>
        <speed>2.5</speed>
      </trkpt>
      ...
    </trkseg>
  </trk>
</gpx>
```

**Langgeng Sea JSON (`.lsea.json`):**
```json
{
  "format": "langgeng-sea-v1",
  "exportedAt": "2026-05-08T18:00:00Z",
  "exportedBy": { "name": "Pak Budi", "vessel": "KM Jaya" },
  "trip": {
    "id": "uuid",
    "name": "Trip 8 Mei",
    "startedAt": "...",
    "endedAt": "...",
    "hauls": [
      {
        "id": "uuid",
        "name": "Spot Utara",
        "orderIndex": 1,
        "metrics": { "distanceMeters": 1234, "sweptAreaM2": 24680, ... },
        "trackPoints": [ { "lat": ..., "lng": ..., "ts": ..., "speed": ... } ],
        "logBook": { "catches": [...], "weather": "cerah" }
      }
    ]
  },
  "markers": [ ... ]
}
```

### 6.6 State Management (Riverpod)

Contoh:
```dart
// Active trip state
@riverpod
class ActiveTrip extends _$ActiveTrip {
  @override
  Future<Trip?> build() async {
    return ref.read(tripRepoProvider).getActiveTrip();
  }

  Future<void> startTrip() async { ... }
  Future<void> endTrip() async { ... }
}

// Active haul tracking state (real-time)
@riverpod
class TrackingController extends _$TrackingController {
  @override
  TrackingState build() => TrackingState.idle();

  Future<void> startHaul() async {
    final haul = await ref.read(startHaulUseCaseProvider)();
    state = TrackingState.recording(haul);
    _listenToGps();
  }

  void _listenToGps() {
    _sub = ref.read(gpsServiceProvider).positionStream.listen((pos) {
      // insert track point, recompute live stats
      state = state.copyWith(liveMetrics: ...);
    });
  }
}
```

---

## 7. UX Flow Utama

### 7.1 First-Time Launch
```
Splash → Onboarding (3 slide) → Form Profil (nama, kapal, pelabuhan, lebar trawl)
       → Permission Location → Dashboard Home
```

### 7.2 Daily Flow (Core)
```
Home → [Mulai Trip Baru] → Map Screen
     → [Mulai Tebar Haul] → tracking...
     → [Angkat Trawl] → Haul Summary → [Isi Log Book?]
     → [Haul Berikutnya] (loop 2-5x)
     → [Akhiri Trip] → Trip Summary → Home
```

### 7.3 Navigasi Utama (Bottom Nav)
- 🗺️ **Peta** (default)
- 📋 **Riwayat** (list trip)
- 📊 **Dashboard** (statistik)
- ⚙️ **Pengaturan**

---

## 8. Alur Data (Data Flow)

### 8.1 Track Point Write Path (Critical)

```
GPS Sensor
   │ (10s interval)
   ▼
geolocator.getPositionStream
   │
   ▼
BackgroundTrackingService
   │
   ▼
TrackPointRepository.insert()  ← SQLite WRITE (sync)
   │
   ▼
StateNotifier emits update
   │
   ▼
UI re-renders (live stats, polyline)
```

**Keamanan data:** tiap titik langsung di-commit ke DB → jika HP mati, data tidak hilang.

### 8.2 Recovery pada Crash

Saat app restart, cek:
```sql
SELECT * FROM hauls WHERE status = 'recording' LIMIT 1;
```
Jika ada → dialog: "Haul #2 terdeteksi belum selesai. Lanjutkan?" [Lanjut] / [Akhiri]

---

## 9. Testing Strategy

| Layer | Jenis Test | Tools |
|---|---|---|
| Utils (geo_calculator) | Unit test | `flutter_test` |
| Use Cases | Unit test + mock repo | `mocktail` |
| Repositories | Integration test | `drift` in-memory |
| GPS Service | Fake stream | mock Geolocator |
| Widgets | Widget test | `flutter_test` |
| End-to-end | Integration test | `integration_test` package |

**Target coverage:** domain 80%, data 70%, presentation 40%.

---

## 10. Performa & Optimisasi

### 10.1 Battery
- GPS hanya aktif saat tracking. Idle → GPS off.
- Foreground service notifikasi rendah-prioritas.
- Disable animasi yang tidak perlu saat tracking.
- WakeLock hanya saat benar-benar butuh.

### 10.2 Memory
- Polyline decimation (simplifikasi titik jika >1000 titik per haul) saat rendering di peta — tidak mengubah data tersimpan.
- Paginasi history trip.

### 10.3 Storage
- Peta offline per wilayah dibatasi (warning jika >500 MB).
- Auto-cleanup tile yang tidak dipakai >6 bulan (opsional).
- Track point binary packing untuk ekspor >10k titik.

---

## 11. Keamanan & Privasi

- Semua data lokal di internal storage app (tidak di shared storage).
- Permission Location: request Just-in-time dengan penjelasan.
- Tidak ada network request kecuali untuk download tile peta.
- User dapat menghapus seluruh data di menu Pengaturan → Hapus Semua Data.

---

## 12. Branding (Usulan Awal)

- **Warna utama:** Biru Laut `#0277BD`
- **Warna aksen:** Oranye Matahari Terbit `#FF6F00`
- **Typography:** Inter / Plus Jakarta Sans
- **Logo:** Jangkar + gelombang + kompas (usulan)
- **Tagline:** "Jejak Setia di Lautan"

---

## 13. Roadmap Post-MVP (Referensi)

| Versi | Fitur Utama |
|---|---|
| v1.0 (MVP) | Tracking, haul, peta offline, log book, dashboard, export/import |
| v1.1 | SOS darurat via SMS, share lokasi ke keluarga |
| v1.2 | Sync cloud, akun user, backup online |
| v1.3 | Geofencing, peringatan zona larangan (MPA) |
| v1.4 | iOS release |
| v1.5 | Integrasi peta batimetri (bayar) |
| v2.0 | Multi-alat tangkap (pancing, gillnet), komunitas fishermen |

---

## 14. Referensi

- [Flutter Clean Architecture](https://resocoder.com/flutter-clean-architecture-tdd/)
- [flutter_map documentation](https://docs.fleaflet.dev/)
- [FMTC docs](https://fmtc.jaffaketchup.dev/)
- [OSM Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/)
- [GPX 1.1 Schema](https://www.topografix.com/GPX/1/1/)
- [Geolocator package](https://pub.dev/packages/geolocator)
