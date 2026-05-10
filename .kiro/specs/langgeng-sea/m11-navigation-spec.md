# M11 — Navigation feature spec

Technical spec pendamping [`m11-notes.md`](m11-notes.md). Dokumen ini berfokus pada data model, arsitektur, kontrak antar-module, dan rencana PR demi PR.

---

## 0. Keputusan final (open questions → resolved)

Lima pertanyaan di versi pertama spec sudah dijawab. Dokumen ini sudah
mencerminkan keputusan tersebut; bagian ini hanya untuk catatan
reviewer yang membandingkan dengan versi pertama.

| # | Pertanyaan | Keputusan | Alasan singkat |
|---|---|---|---|
| 1 | Math cross-track: library atau sendiri? | **Tulis sendiri** di `core/utils/geo_calculator.dart` | 5-8 baris Dart per fungsi, referensi rumus stabil, tidak menambah ~200KB bundle `turf_dart`, konsisten dengan helper yang sudah ada (`haversineMeters`, `circularMeanDegrees`). Lihat § 3. |
| 2 | Debounce 3s arrived / 5s off-route? | **OK, finalize** | Tidak ada perubahan. |
| 3 | Kolom alarm di `user_profiles` atau table sendiri? | **Table `app_settings` tersendiri** | Domain separation: `user_profiles` = siapa user-nya (nama, kapal); `app_settings` = preferensi device. Kalau nanti multi-user (v2), user_profiles per user tapi app_settings tetap per device. Lihat § 6. |
| 4 | Trip follow-track: gabung polyline atau pilih haul? | **Pilih haul** via bottom sheet kalau trip punya ≥2 haul; auto-pick kalau 1 haul | Gabung polyline multi-haul awkward karena ada gap waktu + posisi antar-haul (kapal pindah lokasi baru tebar haul berikut). Lebih jelas secara mental: "ikuti Haul #3 yang hasilnya bagus kemarin", bukan "ikuti gabungan semua haul trip kemarin". Lihat § 8.4. |
| 5 | Split 2 PR (M11a + M11b)? | **OK** | Tidak ada perubahan. Lihat § 10. |

---

## 1. Arsitektur

Satu feature module baru: `features/navigation/` — mengikuti pattern Clean Architecture yang sudah dipakai di module lain (marker, tracking, dsb).

```
features/navigation/
├── domain/
│   └── entities/
│       ├── navigation_target.dart        (sealed class: Goto / FollowTrack)
│       └── navigation_progress.dart      (computed per GPS tick)
├── application/
│   ├── navigation_controller.dart        (Riverpod Notifier)
│   ├── navigation_state.dart             (mode + target + progress)
│   └── navigation_constants.dart         (threshold, debounce)
├── data/
│   └── navigation_alert_service.dart     (TTS + haptic abstraction)
└── presentation/
    ├── widgets/
    │   ├── navigation_panel.dart         (top panel saat nav aktif)
    │   ├── navigation_polyline.dart      (dashed line go-to / highlight follow-track)
    │   ├── bearing_arrow_marker.dart     (panah overlay di boat marker)
    │   ├── long_press_menu.dart          (peta long-press → "pandu ke titik ini")
    │   └── arrival_banner.dart           (snackbar "sudah sampai")
    └── screens/
        └── (tidak ada screen baru — integrasi ke map/marker/history via widget)
```

Kenapa tidak pakai provider pattern untuk state tunggal saja:
- `NavigationController` adalah Notifier yang subscribe ke `currentReadingProvider` (GPS stream), kombinasi-kan dengan target, dan expose `NavigationState` yang memang berupa one-slot state (nav aktif ATAU tidak). Pattern sama dengan `TrackingController`.
- Alert service di-wrap dalam provider supaya bisa di-mock di test — sama dengan `gpsServiceProvider`.

---

## 2. Data model

### 2.1 NavigationTarget (sealed)

```dart
// features/navigation/domain/entities/navigation_target.dart
sealed class NavigationTarget {
  const NavigationTarget();
  String get displayLabel;       // "Spot Udang", "Haul #3 (Minggu, 9 Mei)", dll
}

class GotoTarget extends NavigationTarget {
  const GotoTarget({
    required this.position,
    required this.label,
    this.sourceMarkerId,         // nullable — kalau dari marker, null kalau long-press
  });
  final LatLng position;
  final String label;
  final String? sourceMarkerId;
  @override String get displayLabel => label;
}

class FollowTrackTarget extends NavigationTarget {
  const FollowTrackTarget({
    required this.pathPoints,
    required this.label,
    required this.sourceType,    // haul | trip
    required this.sourceId,
  });
  final List<LatLng> pathPoints; // polyline referensi
  final String label;
  final FollowTrackSource sourceType;
  final String sourceId;
  @override String get displayLabel => label;
}

enum FollowTrackSource { haul, trip }
```

### 2.2 NavigationProgress (immutable value)

Recomputed setiap GPS tick di controller.

```dart
class NavigationProgress {
  const NavigationProgress({
    required this.distanceToTargetMeters,  // jarak ke tujuan (go-to) ATAU ke titik akhir (follow-track)
    required this.bearingDegrees,          // haluan target dari posisi user
    required this.etaSeconds,              // kalau speed > 0 dan > 0.5 knots, else null
    required this.crossTrackMeters,        // follow-track only — tegak lurus ke nearest segment; 0 untuk go-to
    required this.percentAlongPath,        // follow-track only — 0..1; 0 untuk go-to
  });
}
```

### 2.3 NavigationState

```dart
sealed class NavigationState {
  const NavigationState();
}
class NavigationIdle extends NavigationState { const NavigationIdle(); }
class NavigationActive extends NavigationState {
  const NavigationActive({
    required this.target,
    required this.startedAt,
    required this.progress,           // latest snapshot
    required this.alarmState,         // internal debounce machine
  });
  final NavigationTarget target;
  final DateTime startedAt;
  final NavigationProgress progress;
  final _AlarmState alarmState;
}
```

### 2.4 Alarm state (internal, debounce)

```dart
// private to controller
enum _AlarmState {
  normal,               // in-route, jauh dari tujuan
  arrivingCountdown,    // <15m, hitung debounce 3s
  arrived,              // udah notif — tidak spam lagi
  offRouteCountdown,    // >30m, hitung debounce 5s
  offRoute,             // udah notif — tidak spam
  // return-to-route: >30m -> <30m -> debounce 5s -> kembali ke normal
}
```

Alarm state machine jadi penting supaya alarm tidak spam. Detail transisi di § 4.3.

---

## 3. Math utilities (extend `core/utils/geo_calculator.dart`)

Semua tambahan adalah **pure Dart function tanpa library eksternal** —
konsisten dengan helper yang sudah ada (`haversineMeters`,
`circularMeanDegrees`, `sweptAreaM2`). Setiap fungsi ~5-10 baris. Tiap
fungsi menyimpan URL referensi rumus di docstring supaya reviewer bisa
verify independently; lihat [Movable Type Scripts — Latitude/Longitude
calculations](https://www.movable-type.co.uk/scripts/latlong.html)
untuk cross-track, bearing, dst.

Kenapa tidak pakai `turf_dart` atau library sejenis: bundle size
tambahan ~200KB untuk ratusan fungsi yang tidak kita pakai; APK arm64
release sekarang sudah 20MB, tidak perlu tambah 1% untuk tiga fungsi.
Kalau M12/M13 nanti butuh geofencing / convex hull, pertimbangan ulang.

```dart
/// Initial compass bearing dari (lat1,lon1) ke (lat2,lon2).
/// Return degrees 0..360 (0=utara, 90=timur).
double bearingDegrees(LatLng from, LatLng to) { ... }

/// Jarak tegak lurus dari titik ke segment polyline (line AB).
/// Pakai rumus cross-track distance di bola (spherical).
/// Return meters. Negatif kalau titik di kiri line, positif kanan
/// — tapi untuk kita absolute value cukup.
double crossTrackDistanceMeters(LatLng point, LatLng segStart, LatLng segEnd) { ... }

/// Jarak minimum dari titik ke polyline keseluruhan — iterate semua segments,
/// return minimum. Juga return info segment terdekat (index) supaya
/// percentAlongPath bisa dihitung.
({double distanceMeters, int nearestSegmentIndex}) nearestPointOnPolyline(
  LatLng point,
  List<LatLng> polyline,
) { ... }

/// Panjang total polyline — sum haversine antar-pair.
double polylineLengthMeters(List<LatLng> polyline) { ... }

/// Progres sepanjang polyline: distance-from-start-to-projection / total-length.
/// Range 0..1.
double percentAlongPolyline(
  LatLng point,
  List<LatLng> polyline, {
  int? nearestSegmentIndex,  // hint dari nearestPointOnPolyline supaya tidak iterate lagi
}) { ... }
```

Referensi formula cross-track spherical: bagian "Cross-track distance"
di Movable Type Scripts link di atas.

### Testing — unit tests wajib

- `bearingDegrees` cardinal directions: utara→0, timur→90, dst
- `bearingDegrees` seam 359→0 dan equator wrap
- `crossTrackDistance` titik di atas line = 0
- `crossTrackDistance` titik tegak lurus 100m di equator = ~100m
- `nearestPointOnPolyline` dengan polyline 3 segment, titik dekat segment tengah → return index 1
- `percentAlongPolyline` dengan polyline lurus, titik di tengah → 0.5

---

## 4. Navigation controller

### 4.1 Lifecycle

```dart
final navigationControllerProvider =
    NotifierProvider<NavigationController, NavigationState>(
  NavigationController.new,
);

class NavigationController extends Notifier<NavigationState> {
  @override
  NavigationState build() {
    // Subscribe ke GPS. Setiap emit, update progress + evaluasi alarm state.
    ref.listen(currentReadingProvider, (_, next) {
      next.whenData(_onGpsReading);
    });
    return const NavigationIdle();
  }

  void startGoto(GotoTarget target) { ... }
  void startFollowTrack(FollowTrackTarget target) { ... }
  void stop() { state = const NavigationIdle(); }

  void _onGpsReading(GpsReading reading) {
    final s = state;
    if (s is! NavigationActive) return;
    final progress = _computeProgress(s.target, reading);
    final nextAlarm = _advanceAlarmStateMachine(s.alarmState, progress, s.target);
    state = NavigationActive(
      target: s.target,
      startedAt: s.startedAt,
      progress: progress,
      alarmState: nextAlarm,
    );
    _dispatchAlarmIfStateChanged(s.alarmState, nextAlarm, s.target, progress);
  }
}
```

### 4.2 Progress calculation

```dart
NavigationProgress _computeProgress(NavigationTarget target, GpsReading r) {
  final userPos = r.latLng;
  return switch (target) {
    GotoTarget(position: final p, label: _) =>
      NavigationProgress(
        distanceToTargetMeters: haversineMeters(userPos, p),
        bearingDegrees: bearingDegrees(userPos, p),
        etaSeconds: _etaSecondsToDistance(haversineMeters(userPos, p), r.speedMps),
        crossTrackMeters: 0,
        percentAlongPath: 0,
      ),
    FollowTrackTarget(pathPoints: final path, ...) => () {
      final near = nearestPointOnPolyline(userPos, path);
      final endPos = path.last;
      return NavigationProgress(
        distanceToTargetMeters: haversineMeters(userPos, endPos),
        bearingDegrees: bearingDegrees(userPos, endPos),
        etaSeconds: _etaSecondsToDistance(remainingLength, r.speedMps),
        crossTrackMeters: near.distanceMeters,
        percentAlongPath: percentAlongPolyline(
          userPos, path, nearestSegmentIndex: near.nearestSegmentIndex,
        ),
      );
    }(),
  };
}

double? _etaSecondsToDistance(double meters, double? speedMps) {
  if (speedMps == null || speedMps < 0.25) return null; // < 0.5 knots ≈ diam
  return meters / speedMps;
}
```

ETA pakai speed instantaneous dari GPS reading. Alternatif (smoothing window 60s) di post-MVP kalau ETA fluktuatif di real device.

### 4.3 Alarm state machine

State transition table:

| From | Condition | To | Side-effect |
|---|---|---|---|
| normal | go-to & distance ≤ 15m | arrivingCountdown | start 3s timer |
| arrivingCountdown | distance > 15m | normal | cancel timer |
| arrivingCountdown | timer elapsed | arrived | dispatch arrived alarm |
| arrived | — | arrived (stuck) | user harus stop manual |
| normal | follow-track & crossTrack > 30m | offRouteCountdown | start 5s timer |
| offRouteCountdown | crossTrack ≤ 30m | normal | cancel timer |
| offRouteCountdown | timer elapsed | offRoute | dispatch off-route alarm |
| offRoute | crossTrack ≤ 30m | returnCountdown | start 5s timer (return-to-route) |
| returnCountdown | crossTrack > 30m | offRoute | cancel |
| returnCountdown | timer elapsed | normal | dispatch back-on-route notice (quieter — vibration only?) |

Debounce pakai `Timer` internal di controller — bukan based on wall-clock GPS timestamps, karena GPS tick rate variable (1Hz sometimes, 0.5Hz lain). Timer restart saat kondisi berubah.

### 4.4 Alarm dispatch

```dart
void _dispatchAlarmIfStateChanged(
  _AlarmState prev,
  _AlarmState next,
  NavigationTarget target,
  NavigationProgress progress,
) {
  if (prev == next) return;
  final alertSvc = ref.read(navigationAlertServiceProvider);
  final settings = ref.read(appSettingsProvider).asData?.value;

  switch (next) {
    case _AlarmState.arrived:
      alertSvc.notifyArrived(
        label: target.displayLabel,
        sound: settings?.alarmSoundEnabled ?? true,
        vibrate: settings?.alarmVibrateEnabled ?? true,
      );
    case _AlarmState.offRoute:
      alertSvc.notifyOffRoute(
        distanceMeters: progress.crossTrackMeters,
        sound: settings?.alarmSoundEnabled ?? true,
        vibrate: settings?.alarmVibrateEnabled ?? true,
      );
    case _ when prev == _AlarmState.offRoute && next == _AlarmState.normal:
      alertSvc.notifyBackOnRoute(
        vibrate: settings?.alarmVibrateEnabled ?? true,
        // back-on-route = vibrasi saja, tidak ada TTS untuk anti-annoying
      );
    default:
      // no-op
  }
}
```

---

## 5. Alert service

```dart
abstract class NavigationAlertService {
  Future<void> notifyArrived({
    required String label, required bool sound, required bool vibrate,
  });
  Future<void> notifyOffRoute({
    required double distanceMeters, required bool sound, required bool vibrate,
  });
  Future<void> notifyBackOnRoute({required bool vibrate});
  Future<void> dispose();
}

class FlutterTtsNavigationAlertService implements NavigationAlertService {
  late final FlutterTts _tts = FlutterTts()..setLanguage('id-ID')..setSpeechRate(0.5);

  @override
  Future<void> notifyArrived({...}) async {
    if (vibrate) await HapticFeedback.heavyImpact();
    if (sound) await _tts.speak('Sudah sampai di $label');
  }
  // ...
}

final navigationAlertServiceProvider = Provider<NavigationAlertService>((ref) {
  final svc = FlutterTtsNavigationAlertService();
  ref.onDispose(svc.dispose);
  return svc;
});
```

Test impl: `NoopNavigationAlertService` — record method calls tanpa side-effect.

### Dependency pubspec

```yaml
dependencies:
  flutter_tts: ^4.0.2
```

---

## 6. Settings — table `app_settings` tersendiri

Domain separation: `user_profiles` jawab "siapa user-nya" (nama,
kapal, trawl width). `app_settings` jawab "preferensi aplikasi di
device ini" (alarm, theme nanti kalau dipindah dari SharedPreferences,
dll). Kalau nanti multi-user (v2 roadmap), user_profiles per user tapi
app_settings tetap per-device.

Lokasi file: `core/settings/` — bukan di `features/navigation/` karena
table ini general, tidak hanya untuk navigasi.

### 6.1 Schema migration (v4 → v5)

Table baru dengan single-row pattern (id=1 sentinel), mirip
`user_profiles`:

```sql
CREATE TABLE app_settings (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  alarm_sound_enabled INTEGER NOT NULL DEFAULT 1,
  alarm_vibrate_enabled INTEGER NOT NULL DEFAULT 1,
  updated_at INTEGER NOT NULL  -- unix millis
);

-- Insert default row saat migration jalan, supaya query selalu
-- menemukan row (tidak perlu null-handling di repo).
INSERT OR IGNORE INTO app_settings
  (id, alarm_sound_enabled, alarm_vibrate_enabled, updated_at)
VALUES (1, 1, 1, strftime('%s','now') * 1000);
```

Migration step di `AppDatabase.onUpgrade` — pattern sama dengan
migration v3→v4 (user_profiles) yang sudah ada. Existing users yang
upgrade: table dibuat + seeded default true/true. Fresh install:
`onCreate` bikin table sekaligus.

### 6.2 Entity & repository

```dart
// core/settings/domain/entities/app_settings.dart
class AppSettings {
  const AppSettings({
    required this.alarmSoundEnabled,
    required this.alarmVibrateEnabled,
    required this.updatedAt,
  });
  final bool alarmSoundEnabled;     // default true
  final bool alarmVibrateEnabled;   // default true
  final DateTime updatedAt;

  AppSettings copyWith({...});

  static const defaults = AppSettings(
    alarmSoundEnabled: true,
    alarmVibrateEnabled: true,
    updatedAt: /* epoch */ ...,
  );
}

// core/settings/data/app_settings_repository.dart
class AppSettingsRepository {
  AppSettingsRepository(this._dao);
  final AppSettingsDao _dao;

  Stream<AppSettings> watch() => _dao.watchSingle().map(_fromRow);
  Future<AppSettings> get() async => _fromRow(await _dao.getSingle());
  Future<void> setSoundEnabled(bool v) => _dao.updateSoundEnabled(v);
  Future<void> setVibrateEnabled(bool v) => _dao.updateVibrateEnabled(v);
}

// Providers
final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AppSettingsRepository(db.appSettingsDao);
});

final appSettingsProvider = StreamProvider<AppSettings>((ref) {
  final repo = ref.watch(appSettingsRepositoryProvider);
  return repo.watch();
});
```

`UserProfile` entity **tidak disentuh** — keputusan ini membatalkan §
6.2 versi pertama (`UserProfile` dengan field alarm). User profile
tetap domain "siapa".

### 6.3 UI

`ProfileEditScreen` → section baru "Alarm Navigasi" (atau bisa
dipindah ke halaman Pengaturan umum nanti — untuk M11a tetap di profil
supaya user gampang temu). Membaca dari `appSettingsProvider`, tulis
via `appSettingsRepositoryProvider`:

```
┌─────────────────────────────────┐
│  Alarm Navigasi                 │
│  ─────────────────              │
│  Suara (TTS)        [●─ ] ON    │
│  Getar              [●─ ] ON    │
│                                 │
│  Alarm berbunyi saat sudah      │
│  sampai ke tujuan atau keluar   │
│  jalur saat ikuti haul.         │
└─────────────────────────────────┘
```

Dua `SwitchListTile.adaptive`. Toggle langsung panggil
`repo.setSoundEnabled(v)` / `setVibrateEnabled(v)` — tidak perlu save
button, update langsung disimpan (pattern "setting toggle = direct
write" yang user expect di mobile).

---

## 7. UI — `NavigationPanel`

Muncul di peta saat `NavigationState is NavigationActive`. Posisi: antara top panel (idle app bar / recording banner) dan live stats panel. Glass level 2.

### 7.1 Layout

```
┌───────────────────────────────────────────┐
│  🎯 Spot Udang                      [ X ] │
│  ───────────────                          │
│  1.2 km • ↗ 045° (Timur Laut) • ETA 8 min │
│                                           │
│  [████████░░░░░░░]  45%                   │  ← progress bar, follow-track only
└───────────────────────────────────────────┘
```

Content berubah per mode:

**Go-to**:
- Row 1: ikon target (📍) + displayLabel + tombol X (stop)
- Row 2: "distance • bearing angle (compass direction) • ETA" — null-safe untuk ETA (hide kalau null)

**Follow-track**:
- Row 1: ikon footprints (👣) + displayLabel + X
- Row 2: "distance to end • bearing to end • ETA"
- Row 3: progress bar 0..100% + persen
- Badge warning "Keluar jalur X m" saat `_AlarmState.offRoute` — overlay di kanan bawah panel, warna danger

### 7.2 Bearing arrow — overlay di peta

Panah kecil (16dp) yang ditambah ke BoatMarker — rotate ke bearing target. Warna biru terang (berbeda dari kapal heading). Compose-kan dengan `BoatMarker` existing lewat `navigationTarget` parameter — kalau null, tidak draw panah.

### 7.3 NavigationPolyline

Layer flutter_map baru (extend atau sibling dari ActiveHaulPolyline):

**Go-to mode**: Polyline dari posisi user → target. `strokeWidth: 3`, `color: primary`, `isDotted: true`. Lebih natural menggunakan `Polyline` dengan dash pattern jika library dukung; kalau tidak, compose dari series of small segments (trivial).

**Follow-track mode**: Polyline dari target.pathPoints. `strokeWidth: 6` (lebih tebal dari history), `color: warning` (kuning distinct), `borderColor: white, borderStrokeWidth: 1`. Highlighted. Tambah marker titik start (green dot) dan end (red dot) untuk orientasi.

---

## 8. Integrasi ke screen existing

### 8.1 MarkerInfoSheet

Di bawah tombol "Hapus" / "Tutup" existing, tambah satu tombol lagi:

```dart
// ... existing actions
const SizedBox(height: AppSizes.sp2),
PrimaryActionButton(
  label: 'Pandu ke sini',
  icon: PhosphorIconsBold.navigationArrow,
  variant: ActionButtonVariant.primary,
  onPressed: () {
    ref.read(navigationControllerProvider.notifier).startGoto(
      GotoTarget(
        position: marker.latLng,
        label: marker.name,
        sourceMarkerId: marker.id,
      ),
    );
    Navigator.of(context).pop();
  },
),
```

### 8.2 MapScreen

Tiga perubahan:

**A. Long-press handler**:

```dart
MapOptions(
  onLongPress: (tapPos, latLng) => _showLongPressMenu(latLng),
  // ... existing
)

void _showLongPressMenu(LatLng point) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: false,
    builder: (_) => LongPressMenu(
      coord: point,
      onNavigate: () {
        Navigator.pop(context);
        ref.read(navigationControllerProvider.notifier).startGoto(
          GotoTarget(position: point, label: 'Titik Peta'),
        );
      },
      onMark: () {
        Navigator.pop(context);
        _showAddMarkerDialog(point);
      },
    ),
  );
}
```

Menu sheet simple: dua tombol — "Pandu ke titik ini" dan "Tambah penanda di sini".

**B. Watch navigation state + render overlay**:

```dart
final navState = ref.watch(navigationControllerProvider);
// ...
if (navState is NavigationActive) ...[
  // Polyline layer (render SEBELUM active haul polyline supaya ActiveHaulPolyline di atas)
  NavigationPolyline(state: navState),
  // Panel di top
  NavigationPanel(state: navState, onStop: () => controller.stop()),
],
```

**C. BoatMarker enhancement**:

```dart
BoatMarker(
  reading: reading,
  isTracking: isRecording,
  bearingToTarget: navState is NavigationActive
      ? navState.progress.bearingDegrees
      : null,
)
```

BoatMarker render panah kecil (bearing arrow) kalau `bearingToTarget != null`.

### 8.3 HaulDetailScreen

Di bawah action row (logbook + rename + delete), tambah:

```dart
if (points.isNotEmpty) ...[
  const SizedBox(height: AppSizes.sp2),
  Row(children: [
    Expanded(
      child: OutlinedButton.icon(
        icon: Icon(PhosphorIconsBold.footprints),
        label: Text('Ikuti Jalur'),
        onPressed: () {
          ref.read(navigationControllerProvider.notifier).startFollowTrack(
            FollowTrackTarget(
              pathPoints: points.map((p) => p.latLng).toList(),
              label: haul.displayName(),
              sourceType: FollowTrackSource.haul,
              sourceId: haul.id,
            ),
          );
          context.go(AppRoutes.map);
        },
      ),
    ),
    const SizedBox(width: AppSizes.sp2),
    Expanded(
      child: OutlinedButton.icon(
        icon: Icon(PhosphorIconsBold.navigationArrow),
        label: Text('Pandu ke Akhir'),
        onPressed: () {
          final end = points.last.latLng;
          ref.read(navigationControllerProvider.notifier).startGoto(
            GotoTarget(position: end, label: '${haul.displayName()} (akhir)'),
          );
          context.go(AppRoutes.map);
        },
      ),
    ),
  ]),
],
```

### 8.4 TripDetailScreen — pilih haul, bukan gabung polyline

Keputusan di § 0: follow-track untuk trip = pilih SATU haul dari trip,
bukan gabungkan polyline semua haul. Alasan:

- Polyline gabungan multi-haul punya **gap spasial** antar-haul (kapal
  pindah lokasi beberapa km untuk tebar haul berikut). Jalur "ikuti"
  yang punya lompatan posisi confusing — user bingung "saya lagi di
  segment mana, kenapa ada lompatan tiba-tiba".
- Mental model "ikuti Haul #3 yang hasilnya bagus kemarin" lebih jelas
  daripada "ikuti gabungan semua haul kemarin".
- Logbook per-haul → user punya data per-haul untuk pilih yang mau
  di-replay ("Haul #3 dapat 80 kg tenggiri → replay").

#### UX flow

1. User buka TripDetailScreen.
2. Kalau trip **1 haul**: tombol "Ikuti Jalur Tarikan" langsung start
   follow-track dengan polyline haul tsb. Perilaku sama dengan tombol
   di HaulDetailScreen.
3. Kalau trip **≥ 2 haul**: tombol "Ikuti Jalur Tarikan" → show bottom
   sheet (`FollowHaulPickerSheet`) dengan daftar haul di trip, user
   pilih satu, baru start follow-track.

Tombol kedua "Pandu ke Akhir Trip" tetap ada (go-to titik akhir haul
terakhir di trip, urut by orderIndex).

#### FollowHaulPickerSheet

Bottom sheet glass-3 dengan list haul dalam trip:

```
┌────────────────────────────────────┐
│  Pilih Tarikan untuk Ikuti Jalur   │
│  ─────────────────────────         │
│                                    │
│  ┌──────────────────────────────┐  │
│  │ Tarikan #1  •  05:30 - 07:15 │  │
│  │ 2.3 km  •  45 menit          │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │ Tarikan #2  •  08:00 - 10:20 │  │
│  │ 3.1 km  •  2 jam 20 menit    │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │ Tarikan #3  •  11:00 - 13:45 │  │
│  │ 4.2 km  •  2 jam 45 menit    │  │
│  │  ● 80 kg tenggiri, udang     │  │  ← kalau haul punya logbook
│  └──────────────────────────────┘  │
│                                    │
│              [ Batal ]              │
└────────────────────────────────────┘
```

Setiap haul card tappable: tap → pop sheet + start follow-track +
navigate ke `/` (map).

Bonus kalau gampang: tiap card tampil summary logbook catch kalau ada
(dari M5 entities) supaya user gampang pilih "yang hasilnya paling
banyak". Ini nice-to-have, kalau scope M11b membengkak bisa drop.

#### Code snippet — tombol di TripDetailScreen

```dart
if (hauls.isNotEmpty) ...[
  const SizedBox(height: AppSizes.sp2),
  Row(children: [
    Expanded(
      child: OutlinedButton.icon(
        icon: Icon(PhosphorIconsBold.footprints),
        label: Text('Ikuti Jalur Tarikan'),
        onPressed: () async {
          final picked = hauls.length == 1
              ? hauls.first
              : await FollowHaulPickerSheet.show(context, hauls: hauls);
          if (picked == null || !context.mounted) return;
          final points = await ref.read(
            trackPointsByHaulProvider(picked.id).future,
          );
          if (!context.mounted) return;
          ref.read(navigationControllerProvider.notifier).startFollowTrack(
            FollowTrackTarget(
              pathPoints: points.map((p) => p.latLng).toList(),
              label: picked.displayName(),
              sourceType: FollowTrackSource.haul, // haul dari trip
              sourceId: picked.id,
            ),
          );
          context.go(AppRoutes.map);
        },
      ),
    ),
    const SizedBox(width: AppSizes.sp2),
    Expanded(
      child: OutlinedButton.icon(
        icon: Icon(PhosphorIconsBold.navigationArrow),
        label: Text('Pandu ke Akhir'),
        onPressed: () async {
          final lastHaul = hauls.last; // sorted by orderIndex di provider
          final points = await ref.read(
            trackPointsByHaulProvider(lastHaul.id).future,
          );
          if (points.isEmpty || !context.mounted) return;
          ref.read(navigationControllerProvider.notifier).startGoto(
            GotoTarget(
              position: points.last.latLng,
              label: '${_tripTitle(trip)} (akhir)',
            ),
          );
          context.go(AppRoutes.map);
        },
      ),
    ),
  ]),
],
```

Catatan: `FollowTrackSource.trip` sebenarnya tidak terpakai lagi
karena follow-track per-haul — tapi varian enum saya retain (dead-code
tolerant) supaya PR M11b bisa refactor ke `FollowTrackSource { haul,
trip }` kalau nanti ada use case "follow satu trip utuh" (v2).

---

## 9. Testing strategy

### 9.1 Unit tests (jalan di CI, pure Dart)

- `geo_calculator_test.dart` — tambah 15+ tes untuk bearing + crossTrack + nearest + percent
- `navigation_target_test.dart` — sealed class equality + display labels
- `navigation_progress_test.dart` — ETA null handling, edge cases (speed = 0)
- `navigation_controller_test.dart` — state transitions:
  - Idle → startGoto → Active (goto)
  - Idle → startFollowTrack → Active (followTrack)
  - Active → GPS emit close to target → arrivingCountdown (fake timer 3s) → arrived + alarm dispatched
  - Active (followTrack) → GPS emit far from path → offRouteCountdown → offRoute + alarm
  - Active → user comes back to route → normal + backOnRoute alarm
  - stop() resets to Idle di semua state

### 9.2 Widget tests

- `NavigationPanel` render dengan GotoTarget — assert label, distance, bearing text
- `NavigationPanel` render dengan FollowTrackTarget — assert progress bar
- `NavigationPanel` — offRoute warning badge muncul saat `alarmState = offRoute`

### 9.3 Integration tests

Skip. Pattern sama dengan fitur lain — integration via manual QA checklist.

### 9.4 QA scenarios (tambah ke `qa-checklist.md`)

Section baru "M. Navigasi":

- M.1: Pandu ke marker (tap marker → sampai → notif + TTS + vibrasi)
- M.2: Pandu via long-press (peta long-press → menu → pandu → sampai)
- M.3: Ikuti haul (haul detail → ikuti → on-route → off-route > 30m 5s → alarm)
- M.4: Ikuti haul dari trip multi-haul (trip detail → tombol Ikuti → bottom sheet pilih haul → start)
- M.4b: Ikuti haul dari trip single-haul (trip detail → tombol Ikuti → langsung start tanpa sheet)
- M.5: Navigasi + tracking trawl (dua-duanya aktif bersamaan)
- M.6: Settings: toggle suara off, toggle getar off (alarm diam saat kedua off)
- M.7: Stop nav via X di panel
- M.8: Stop nav via tombol di permission sheet kalau user revoke GPS di tengah
- M.9: Kill app saat nav aktif → buka lagi → nav TIDAK resume (by design)
- M.10: Fresh install → upgrade dari v4 → app_settings di-seed default true/true

---

## 10. Rencana PR

### PR M11a — Foundation + Go-to (target ~750 LOC)

Branch: `feat/m11-navigation-goto`

Files baru:
- `features/navigation/domain/entities/navigation_target.dart`
- `features/navigation/domain/entities/navigation_progress.dart`
- `features/navigation/application/navigation_state.dart`
- `features/navigation/application/navigation_controller.dart`
- `features/navigation/application/navigation_constants.dart`
- `features/navigation/data/navigation_alert_service.dart`
- `features/navigation/presentation/widgets/navigation_panel.dart`
- `features/navigation/presentation/widgets/navigation_polyline.dart`
- `features/navigation/presentation/widgets/bearing_arrow.dart`
- `features/navigation/presentation/widgets/long_press_menu.dart`
- `core/settings/domain/entities/app_settings.dart`         ← NEW (§6)
- `core/settings/data/app_settings_dao.dart`                ← NEW (§6)
- `core/settings/data/app_settings_repository.dart`         ← NEW (§6)
- `core/settings/application/app_settings_provider.dart`    ← NEW (§6)

Files modified:
- `core/utils/geo_calculator.dart` — tambah bearing + cross-track stub
  (crossTrack dites di M11a tapi baru dipakai di M11b — OK).
- `data/database/tables.dart` — tambah class `AppSettings` drift
  table + schema migration v4 → v5 (CREATE TABLE + INSERT default
  row).
- `data/database/app_database.dart` — register DAO, bump
  `schemaVersion` ke 5, tambah migration step.
- `features/settings/presentation/profile_edit_screen.dart` — section
  "Alarm Navigasi" dengan dua SwitchListTile yang read/write
  `appSettingsProvider` (bukan `userProfile` lagi).
- `features/map/presentation/map_screen.dart` — long-press handler +
  render navigation overlay/panel + bearing arrow.
- `features/map/presentation/widgets/boat_marker.dart` — optional
  bearingToTarget parameter + overlay panah.
- `features/marker/presentation/widgets/marker_info_sheet.dart` —
  tombol "Pandu ke sini".
- `app/pubspec.yaml` — add `flutter_tts: ^4.0.2`.

**Catatan**: `UserProfile` entity + `user_profile_repository` TIDAK
disentuh di M11a (keputusan § 0.3). Tidak ada migration pada kolom
user_profiles; migration v4→v5 adalah CREATE TABLE app_settings baru
saja.

Tests:
- `test/core/utils/geo_calculator_bearing_test.dart` — baru
- `test/core/settings/app_settings_test.dart` — baru (entity + repo)
- `test/features/navigation/navigation_controller_goto_test.dart` — baru
- `test/features/navigation/navigation_target_test.dart` — baru
- `test/features/navigation/fake_navigation_alert_service.dart` — helper
- `test/data/database/migration_test.dart` — extend: v4→v5 app_settings
  created + seeded default row.

### PR M11b — Follow-track (target ~550 LOC)

Branch: `feat/m11-navigation-followtrack`

Merge setelah M11a. Reuse semua foundation.

Files baru:
- `features/history/presentation/widgets/follow_haul_picker_sheet.dart` ← NEW (§8.4)

Files modified:
- `features/navigation/application/navigation_controller.dart` —
  cabang `startFollowTrack` + progress calc cross-track + alarm state
  machine offRoute.
- `features/navigation/presentation/widgets/navigation_panel.dart` —
  varian follow-track dengan progress bar + off-route badge.
- `features/navigation/presentation/widgets/navigation_polyline.dart`
  — cabang highlight polyline + start/end markers.
- `features/history/presentation/haul_detail_screen.dart` — dua
  tombol (Ikuti Jalur + Pandu ke Akhir).
- `features/history/presentation/trip_detail_screen.dart` — dua
  tombol; kalau hauls.length >= 2, "Ikuti Jalur" buka
  `FollowHaulPickerSheet` dulu sebelum start.
- `core/utils/geo_calculator.dart` — finalisasi cross-track +
  nearestPointOnPolyline + percentAlongPolyline.

Tests:
- `test/core/utils/geo_calculator_crosstrack_test.dart` — baru
- `test/features/navigation/navigation_controller_followtrack_test.dart` — baru
- `test/features/history/follow_haul_picker_sheet_test.dart` — baru
  (widget test: tap haul → sheet pop dengan selected haul)

---

## 11. Rollout & post-MVP

- PR M11a → QA internal → merge → release alpha
- PR M11b → QA internal → merge → release
- Beta testing: share ke nelayan group (liaison koperasi), collect feedback
- Post-MVP: tune threshold dari real-device log, pertimbangkan
  smoothing ETA, tambah background foreground service kalau user butuh
  nav saat HP di saku lama, pindah setting ke halaman "Pengaturan"
  umum (tidak lagi di ProfileEditScreen) kalau ada setting lain yang
  nongkrong di `app_settings`.

---

Semua open questions (§ 0) sudah resolved. Spec ini siap dijadikan
kontrak eksekusi M11a. Kalau reviewer setuju, saya mulai koding PR
M11a berikutnya.
