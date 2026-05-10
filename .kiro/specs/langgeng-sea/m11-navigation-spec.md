# M11 — Navigation feature spec

Technical spec pendamping [`m11-notes.md`](m11-notes.md). Dokumen ini berfokus pada data model, arsitektur, kontrak antar-module, dan rencana PR demi PR.

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

Semua tambahan adalah pure Dart function — unit-testable tanpa Flutter.

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

Referensi formula: cross-track distance spherical dari [Movable Type Scripts](https://www.movable-type.co.uk/scripts/latlong.html#cross-track).

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
  final settings = ref.read(userProfileProvider).asData?.value;

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

## 6. Settings — user toggle

### 6.1 Schema migration

Tambah 2 kolom BOOL ke `user_profiles` table (schema v4 → v5):

```sql
ALTER TABLE user_profiles ADD COLUMN alarm_sound_enabled INTEGER NOT NULL DEFAULT 1;
ALTER TABLE user_profiles ADD COLUMN alarm_vibrate_enabled INTEGER NOT NULL DEFAULT 1;
```

Migration function di `AppDatabase.onUpgrade` — pattern sama dengan migration v3→v4 yang sudah ada.

### 6.2 UserProfile entity

```dart
class UserProfile {
  // existing fields ...
  final bool alarmSoundEnabled;      // default true
  final bool alarmVibrateEnabled;    // default true
}
```

`copyWith` + validator updated.

### 6.3 UI

`ProfileEditScreen` — section baru "Alarm Navigasi":

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

Dua `SwitchListTile` pakai `Switch.adaptive`. Save langsung ke DB saat toggle.

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

### 8.4 TripDetailScreen

Similar dengan haul detail — dua tombol untuk trip:

- "Ikuti Jalur Trip" — gabungkan polyline semua haul di trip secara berurutan (by orderIndex)
- "Pandu ke Akhir Trip" — titik akhir haul terakhir

Kalau trip punya hanya 1 haul, jatuh ke perilaku "Ikuti Jalur Tarikan" yang sama.

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
- M.4: Ikuti trip multi-haul (gabung polyline)
- M.5: Navigasi + tracking trawl (dua-duanya aktif bersamaan)
- M.6: Settings: toggle suara off, toggle getar off (alarm diam saat kedua off)
- M.7: Stop nav via X di panel
- M.8: Stop nav via tombol di permission sheet kalau user revoke GPS di tengah
- M.9: Kill app saat nav aktif → buka lagi → nav TIDAK resume (by design)

---

## 10. Rencana PR

### PR M11a — Foundation + Go-to (target ~700 LOC)

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

Files modified:
- `core/utils/geo_calculator.dart` — tambah bearing + cross-track stub (crossTrack dites di M11a tapi baru dipakai di M11b — OK)
- `features/onboarding/domain/entities/user_profile.dart` — tambah 2 field alarm
- `data/database/tables.dart` + schema migration v4 → v5
- `features/onboarding/data/user_profile_repository.dart` — persist field baru
- `features/settings/presentation/profile_edit_screen.dart` — section toggle alarm
- `features/map/presentation/map_screen.dart` — long-press handler + render navigation overlay/panel
- `features/map/presentation/widgets/boat_marker.dart` — optional bearing arrow
- `features/marker/presentation/widgets/marker_info_sheet.dart` — tombol "Pandu ke sini"
- `app/pubspec.yaml` — add `flutter_tts: ^4.0.2`

Tests:
- `test/core/utils/geo_calculator_bearing_test.dart` — baru
- `test/features/navigation/navigation_controller_goto_test.dart` — baru
- `test/features/navigation/navigation_target_test.dart` — baru
- `test/features/navigation/fake_navigation_alert_service.dart` — helper

### PR M11b — Follow-track (target ~500 LOC)

Branch: `feat/m11-navigation-followtrack`

Merge setelah M11a. Reuse semua foundation.

Files baru:
- (tidak ada — `FollowTrackTarget` digabung ke sealed class yang sudah ada di M11a)

Files modified:
- `features/navigation/application/navigation_controller.dart` — cabang `startFollowTrack` + progress calc cross-track + alarm state machine offRoute
- `features/navigation/presentation/widgets/navigation_panel.dart` — varian follow-track dengan progress bar + off-route badge
- `features/navigation/presentation/widgets/navigation_polyline.dart` — cabang highlight polyline + start/end markers
- `features/history/presentation/haul_detail_screen.dart` — dua tombol (Ikuti Jalur + Pandu ke Akhir)
- `features/history/presentation/trip_detail_screen.dart` — sama untuk trip
- `core/utils/geo_calculator.dart` — finalisasi cross-track + nearestPointOnPolyline + percentAlongPolyline

Tests:
- `test/core/utils/geo_calculator_crosstrack_test.dart` — baru
- `test/features/navigation/navigation_controller_followtrack_test.dart` — baru

---

## 11. Rollout & post-MVP

- PR M11a → QA internal → merge → release alpha
- PR M11b → QA internal → merge → release
- Beta testing: share ke nelayan group (liaison koperasi), collect feedback
- Post-MVP: tune threshold dari real-device log, pertimbangkan smoothing ETA, tambah background foreground service kalau user butuh nav saat HP di saku lama

---

Comment-able sections untuk review:

- **§ 3 Math utilities** — apakah rumus cross-track OK atau lebih prefer Turf-like library?
- **§ 4.3 Alarm state machine** — debounce 3s/5s reasonable?
- **§ 6 Schema migration** — kolom ditempel di user_profiles atau bikin table settings tersendiri?
- **§ 8.4 Trip follow-track** — gabung polyline haul atau offer pilih haul tertentu?
- **§ 10 PR scope** — ada yang mau di-split lagi atau sudah nyaman?
