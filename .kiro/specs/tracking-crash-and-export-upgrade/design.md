# Design — PR #27

## 1. Akar masalah crash (R1, R2)

### 1.1 Apa yang terjadi sekarang (state HEAD pasca PR #26)

`flutter_background_tracking_service.dart` line 99-115:

```dart
@override
Future<void> start({...}) async {
  _statusController.add(BackgroundTrackingStatus.starting);

  // Request battery-optimisation exemption on Android.
  if (Platform.isAndroid) {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (e) {
      Logger.instance.warn('tracking.battery_opt_request_failed', {
        'error': e.toString(),
      });
    }
  }

  await WakelockPlus.enable();
  // ... lalu _service.startService();
}
```

Empat masalah simultan di kode di atas:

1. **`request()` bisa throw `PlatformException` di Android 14+** kalau
   activity dalam keadaan tidak attached (misal user putar layar
   pas dialog muncul, atau ROM punya activity-recreate behavior
   yang berbeda). `try/catch` ada — tapi yang ter-catch hanya
   exception synchronous; kalau exception terjadi setelah
   `await`-nya resolve (misal Android Activity result race), bisa
   bubble ke zone-level handler.

2. **Race dengan foreground service start**. Setelah dialog Allow
   ditekan, kontrol kembali ke Dart. Tapi **status object yang
   di-await belum tentu refresh**. Kemudian
   `_service.startService()` panggil
   `Context.startForegroundService(intent)` di native side. Pada
   Android 14+ (yang PixelOS user pakai), foreground service
   dengan tipe `location` butuh user grant
   `ACCESS_BACKGROUND_LOCATION` SEBELUM start, dan butuh
   notification dipost dalam 5 detik. Kalau permission flow ngulur
   waktu di sini, kena timeout → SIGABRT.

3. **`detectRecoverableHaul()` di crash recovery juga panggil
   `start()`** dengan flow sama (line 240-251 di
   `tracking_controller.dart`). Service masih running dari sesi
   yang crash → panggil startService dua kali → IllegalStateException.

4. **`activeTrip` bisa null setelah resume**. `resumeHaul` line
   214 panggil `_trips.getById(haul.tripId)` tapi tidak guard
   kalau hasilnya null. Lalu `state.activeTrip = trip` (null) →
   beberapa tempat lain di-`!`-bang dan panggil null → crash.

### 1.2 Apa yang akan kita ubah

#### Pisahkan permission battery dari hot path tracking

**Sebelum (sekarang):**
```
[MULAI] → start() → [permission dialog] → [user tap Allow]
                  → startService() → CRASH (race / timeout)
```

**Sesudah:**
```
[MULAI] → start() → startService() langsung → service running ✓
                                              (no dialog yet)
                  → SETELAH service stable, di background:
                     scheduleBatteryOptPrompt()
                     → permission dialog muncul beberapa detik kemudian
                     → user respond → no impact ke service yang sudah jalan
```

Strateginya: **service start dulu, permission dialog menyusul**.
Kalau user Allow, akurasi malam meningkat untuk haul berikutnya;
kalau Deny, haul saat ini tetap jalan (foreground service tipe
`location` tidak butuh battery exemption — exemption hanya untuk
Doze-mode duty cycle, bukan untuk service itself).

#### Tambah pre-flight check di `resumeHaul`

```
resumeHaul(haul):
  if state.isRecording: return
  trip = _trips.getById(haul.tripId)
  if trip == null:
    // Parent trip already deleted → finalize the orphan haul too,
    // tidak ada cara meaningful untuk resume.
    return finalizeRecoveredHaul(haul)
  // Existing logic...
  // Saat panggil _bgService.start, JANGAN re-request permission battery.
  await _bgService.start(skipBatteryPermission: true, ...)
```

#### Idempotent service start

```
class FlutterBackgroundTrackingService {
  Future<void> start({...}) async {
    final isAlreadyRunning = await _service.isRunning();
    if (isAlreadyRunning) {
      // Ada residue dari session yang crash — stop dulu, baru start.
      await _service.invoke('stopService');
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    // ... kemudian startService normal
  }
}
```

### 1.3 Tile Settings untuk permission battery (R3)

File baru: `lib/features/settings/presentation/widgets/battery_optimization_tile.dart`

```
StatefulWidget yang:
  - tampilkan PermissionStatus current (dengan icon hijau/abu)
  - subtitle: "Aktif" / "Belum diatur" / "Diblokir di pengaturan"
  - on tap:
      if granted → openAppSettings()
      else → Permission.ignoreBatteryOptimizations.request()
  - listen ke AppLifecycleState.resumed untuk re-check status
    setelah user balik dari Settings sistem
```

Render di SettingsScreen sebagai 1 baris di section "Pengaturan
Lanjutan" yang baru.

---

## 2. Format GPX baru (R4)

### 2.1 Struktur output

```xml
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Langgeng Sea"
     xmlns="http://www.topografix.com/GPX/1/1"
     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     xmlns:lsea="https://langgengsea.id/gpx/extensions/v1"
     xsi:schemaLocation="http://www.topografix.com/GPX/1/1
                         http://www.topografix.com/GPX/1/1/gpx.xsd">

  <metadata>
    <name>Data Langgeng Sea (Lengkap)</name>
    <desc>3 trip · 8 tarikan · 12.45 km · 5 penanda</desc>
    <author>
      <name>Pak Budi</name>          <!-- ownerName -->
    </author>
    <link href="https://langgengsea.id">
      <text>Langgeng Sea</text>
    </link>
    <time>2026-05-16T10:30:00.000Z</time>   <!-- exportedAt -->
    <bounds minlat="..." minlon="..." maxlat="..." maxlon="..."/>
    <extensions>
      <lsea:exporter>
        <lsea:vesselName>KM Bahari</lsea:vesselName>
        <lsea:ownerName>Pak Budi</lsea:ownerName>
        <lsea:homePort>Pelabuhan Tanjung</lsea:homePort>
        <lsea:exportedAt>2026-05-16T10:30:00.000Z</lsea:exportedAt>
        <lsea:filterDescription>Semua waktu · Semua trip · Semua kategori</lsea:filterDescription>
      </lsea:exporter>
      <lsea:summary
        tripCount="3"
        haulCount="8"
        markerCount="5"
        totalDistanceMeters="12450.50"
        totalDurationSeconds="28800"
        totalSweptAreaM2="124500.00"/>
    </extensions>
  </metadata>

  <!-- WAYPOINTS (markers) -->
  <wpt lat="-6.9" lon="110.5">
    <time>2026-05-01T08:00:00.000Z</time>
    <name>Karang Hiu</name>
    <desc>Hindari saat air pasang</desc>
    <sym>Skull and Crossbones</sym>     <!-- Garmin-compatible -->
    <type>Karang/Bahaya</type>
    <extensions>
      <lsea:marker
        id="m-uuid-1"
        category="hazard"
        categoryLabel="Karang/Bahaya"/>
    </extensions>
  </wpt>
  <!-- ... dst untuk semua marker yang kena filter ... -->

  <!-- TRACKS (hauls grouped by trip via lsea:tripId) -->
  <trk>
    <name>Tarikan #1: Spot Pagi</name>
    <desc>5.20 km · 1j 30m · 8 mil/jam · 045° · 1.04 ha</desc>
    <type>fishing-haul</type>
    <extensions>
      <lsea:trip
        id="trip-uuid-1"
        name="Trip 8 Mei 2026"
        homePort="Pelabuhan Tanjung"
        startedAt="2026-05-08T05:00:00.000Z"
        endedAt="2026-05-08T17:00:00.000Z"
        status="completed"/>
      <lsea:haul
        id="haul-uuid-1"
        orderIndex="1"
        status="completed"
        colorValue="0xFF4FC3F7"
        colorHex="#4FC3F7"
        startedAt="2026-05-08T06:00:00.000Z"
        endedAt="2026-05-08T07:30:00.000Z"
        distanceMeters="5200.00"
        durationSeconds="5400"
        avgSpeedKnots="3.62"
        avgHeadingDegrees="45.0"
        sweptAreaM2="10400.00"/>
    </extensions>
    <trkseg>
      <trkpt lat="..." lon="...">
        <time>2026-05-08T06:00:00.000Z</time>
        <speed>2.50</speed>
        <extensions>
          <lsea:trkpt headingDegrees="45.0" accuracyMeters="5.20"/>
        </extensions>
      </trkpt>
      <!-- ... -->
    </trkseg>
  </trk>
  <!-- ... 1 <trk> per haul yang kena filter ... -->

</gpx>
```

### 2.2 Mapping field user-request → output

| User minta | Lokasi di GPX |
|---|---|
| Nama nelayan | `<author><name>` + `<lsea:ownerName>` |
| Nama kapal | `<lsea:vesselName>` |
| Tanggal/waktu ekspor | `<metadata><time>` + `<lsea:exportedAt>` |
| Nama trip | `<lsea:trip name="...">` di setiap `<trk>` |
| Tanggal trip mulai/akhir | `<lsea:trip startedAt endedAt>` |
| Total jarak/durasi/sapuan trip | `<lsea:summary>` di metadata + per-trip implicit (sum dari hauls) |
| Nama tarikan + nomor | `<trk><name>Tarikan #N: nama</name>` |
| Warna jalur | `<lsea:haul colorValue colorHex>` |
| Stats per haul | `<lsea:haul distance/duration/speed/heading/area>` |
| Nama penanda | `<wpt><name>` |
| Kategori penanda | `<sym>` (Garmin) + `<lsea:marker category>` |
| Koordinat penanda | `<wpt lat lon>` |
| Catatan penanda | `<wpt><desc>` |
| Tanggal penanda dibuat | `<wpt><time>` |

### 2.3 Implementation

`gpx_exporter.dart` saat ini sudah punya struktur hampir lengkap dari
PR #25. Yang perlu ditambah:

- `<lsea:exporter>` block di metadata — perlu inject `UserProfile`
- `<lsea:summary>` block — perlu hitung total
- `<lsea:trip>` di setiap track extensions (sebelumnya hanya
  `<lsea:haul>`) — supaya receiver tahu haul ini bagian dari trip
  yang mana
- `<lsea:filterDescription>` — string human-readable filter yang
  user pakai

Approach: tambah method baru `exportFiltered(...)` yang menerima
`ExportFilter` value object + `UserProfile`, return `String`. Method
lama (`exportTrip`, `exportAll`) tetap ada untuk backward-compat tapi
delegate ke `exportFiltered` dengan filter pre-built.

---

## 3. ExportFilter & ExportScreen UI (R5)

### 3.1 ExportFilter value object

File: `lib/features/export_import/domain/entities/export_filter.dart`

```dart
class ExportFilter {
  const ExportFilter({
    required this.includeTracks,
    required this.includeMarkers,
    required this.dateRange,
    required this.tripIds,            // null = all trips in range
    required this.markerCategories,   // null = all categories
  });

  final bool includeTracks;
  final bool includeMarkers;
  final DateRange? dateRange;         // null = no date filter
  final Set<String>? tripIds;
  final Set<MarkerCategory>? markerCategories;

  bool matchesTrip(Trip t) {
    if (tripIds != null && !tripIds!.contains(t.id)) return false;
    if (dateRange != null && !dateRange!.contains(t.startedAt)) return false;
    return true;
  }

  bool matchesMarker(AppMarker m) {
    if (markerCategories != null && !markerCategories!.contains(m.category)) {
      return false;
    }
    return true;
  }

  String describe() { /* ... untuk lsea:filterDescription ... */ }
  String suggestFileName() { /* ... ekstensi .gpx ... */ }
}

class DateRange {
  const DateRange({required this.start, required this.end});
  final DateTime start;     // inclusive
  final DateTime end;       // exclusive
  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  factory DateRange.last7Days() { ... }
  factory DateRange.last30Days() { ... }
}
```

### 3.2 ExportScreen layout (revisi)

```
┌──────────────────────────────────────────┐
│ ← Ekspor Data                            │
├──────────────────────────────────────────┤
│                                          │
│ 📋 Konten yang Diekspor                  │
│   ┌──────────────────────────────────┐   │
│   │ [✓] 🛤️  Jalur Tarikan            │   │
│   │     8 tarikan dari 3 trip        │   │
│   │ [✓] 📍 Penanda                   │   │
│   │     5 penanda                    │   │
│   └──────────────────────────────────┘   │
│                                          │
│ 📅 Rentang Tanggal (jalur)               │
│   ┌──────────────────────────────────┐   │
│   │ ( ) Semua waktu                  │   │
│   │ ( ) 7 hari terakhir              │   │
│   │ (•) 30 hari terakhir             │   │
│   │ ( ) Pilih rentang…               │   │
│   └──────────────────────────────────┘   │
│                                          │
│ 🚢 Trip yang Diikutkan                   │
│   ┌──────────────────────────────────┐   │
│   │ Semua trip dalam rentang (3)  ⚙ │   │
│   └──────────────────────────────────┘   │
│   (tap ⚙ → modal pilih per-trip)        │
│                                          │
│ 🏷️ Kategori Penanda                       │
│   [✓ Produktif] [✓ Karang] [✓ Pelabuhan] │
│   [✓ Lainnya]                            │
│                                          │
│ ─────────────────────────────────        │
│ Ringkasan:                               │
│   📊 8 tarikan · 5 penanda               │
│   📦 ≈ 250 KB                            │
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ 📤 Ekspor & Bagikan                  │ │
│ └──────────────────────────────────────┘ │
└──────────────────────────────────────────┘
```

State machine:
- `_filter: ExportFilter` (Riverpod state notifier)
- `_preview: ExportPreview` (auto-rebuild saat filter berubah)
  - count hauls, points, markers
  - estimated file size

Reactive providers:
- `exportPreviewProvider(ExportFilter)` → counts dari DB

Date range picker → pakai `showDateRangePicker` Material default,
locale `id_ID`.

Trip multi-select → bottom sheet baru
`TripMultiSelectSheet`, list trip dengan checkbox + ringkasan
distance/haul, semua selected by default, ada
"Pilih semua / Batalkan semua" header.

---

## 4. Per-trip share (R6)

`ExportSheet` (file lama) tetap ada. Cukup:
- Update `_handleExport` agar pass `UserProfile` ke
  `gpxExporter.exportTrip(...)` (sekarang belum)
- `gpxExporter.exportTrip` internally bangun `ExportFilter` dengan
  `tripIds: {thisTripId}`, lalu delegate ke `exportFiltered`

Tidak ada UI change untuk ExportSheet.

---

## 5. File yang akan disentuh

### Modified
- `app/lib/features/tracking/data/flutter_background_tracking_service.dart`
  - tambah param `skipBatteryPermission` di `start()`
  - pisahkan permission flow ke method terpisah `_maybeRequestBatteryOpt()`
  - call permission HANYA setelah service stable, di
    background (fire-and-forget unawaited)
  - guard `_service.isRunning()` sebelum `startService()`
- `app/lib/features/tracking/application/tracking_controller.dart`
  - di `resumeHaul`: kalau trip null → finalize haul, jangan crash
  - di `resumeHaul`: panggil `_bgService.start(skipBatteryPermission: true)`
- `app/lib/features/export_import/data/gpx_exporter.dart`
  - tambah method `exportFiltered(ExportFilter, UserProfile, ...)`
  - tambah `<lsea:exporter>`, `<lsea:summary>`, `<lsea:trip>`
    elements
  - refactor `exportTrip` & `exportAll` agar delegate ke
    `exportFiltered`
- `app/lib/features/export_import/data/export_service.dart`
  - support `ExportFilter` di method export
  - inject `UserProfileRepository`
- `app/lib/features/export_import/presentation/export_screen.dart`
  - revisi total layout sesuai 3.2
- `app/lib/features/export_import/presentation/export_sheet.dart`
  - pass UserProfile ke exporter
- `app/lib/features/settings/presentation/settings_screen.dart`
  - tambah tile "Akurasi Saat Layar Mati" di section Pengaturan
    Lanjutan

### New files
- `app/lib/features/export_import/domain/entities/export_filter.dart`
- `app/lib/features/export_import/domain/entities/date_range.dart`
- `app/lib/features/export_import/application/export_preview_provider.dart`
- `app/lib/features/export_import/presentation/widgets/trip_multi_select_sheet.dart`
- `app/lib/features/export_import/presentation/widgets/export_filter_section.dart` (helper widgets)
- `app/lib/features/settings/presentation/widgets/battery_optimization_tile.dart`

### Tests
- `app/test/features/export_import/export_filter_test.dart`
  - matchesTrip, matchesMarker, describe(), suggestFileName()
  - DateRange.last7Days/last30Days boundary
- `app/test/features/export_import/gpx_exporter_filter_test.dart`
  - filter combinations produce correct GPX
  - exporter info block includes user profile
  - empty filter result still produces valid (non-self-closing) GPX
- (tracking crash fix: hard to unit-test the actual crash scenario
  without integration test on Android — rely on manual QA + logging)

---

## 6. Risiko & mitigasi

| Risiko | Mitigasi |
|---|---|
| Permission flow async timing tetap problematic di Android 14+ | Pakai `unawaited()` + 2-3 detik delay sebelum request, tambah kill-switch via SharedPreferences kalau crash terdeteksi |
| `_service.isRunning()` belum tentu reliable di semua versi flutter_background_service | Tambah backup: try/catch di startService; kalau IllegalState, sleep 1s lalu retry |
| File GPX dengan banyak trip+haul jadi puluhan MB | Stream-write ke file alih-alih build full string (deferred untuk PR follow-up; data sekarang masih kecil) |
| Date range filter pakai locale id_ID belum tentu di-include di Flutter SDK | Kalau iya, tambah `flutter_localizations` ke pubspec |
| User pilih kombinasi filter aneh yang menghasilkan trip kosong tapi marker ada | Test case eksplisit; UI tampilkan "0 tarikan, N penanda" |

---

## 7. Migration / breaking changes

**Tidak ada DB migration** di PR ini — semua data sudah ada di skema
v8. Cuma pembacaan data dengan filter di-memori.

**Breaking di internal API**:
- `ExportService.exportTrip` ganti signature (tambah optional
  `UserProfile?`). Default null untuk backward-compat → kalau null,
  exporter tidak tulis `<lsea:exporter>` block.
- `GpxExporter.exportAll` deprecate, panggilan masuk via
  `exportFiltered`. Implementasi delegate.

External (file format): non-breaking. `<lsea:*>` extensions
abaikan oleh GPX reader pihak ketiga.
