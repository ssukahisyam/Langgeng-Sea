# Design — PR #32 Marker Pick on Map

> Companion ke `requirements.md`. Fokus: state machine, widget
> arsitektur, kontrak antar layer.

## §1 State machine MapMode

`map_mode.dart` sudah ada enum `MapMode`. Tambah satu state baru:

```dart
enum MapMode {
  idle,
  tracking,
  pickMarkerLocation,    // <-- baru (PR #32)
}
```

State transitions valid:
- `idle → pickMarkerLocation`: dari long-press Add Marker button
  ATAU dari Markers list "Tambah Baru".
- `pickMarkerLocation → idle`: dari [Batal], back button, atau
  setelah konfirmasi `AddMarkerDialog` selesai (pop dialog).
- `tracking → pickMarkerLocation`: TIDAK diizinkan (R6 AC1).
- `pickMarkerLocation → tracking`: TIDAK diizinkan — startHaul
  harus tunggu user keluar dari mode pick dulu (atau cancel mode
  otomatis kalau user tap MULAI).

`map_mode_provider.dart` (existing) tambah getter `bool isPicking`
untuk widget yang perlu hide kontrol mereka.

## §2 Widget baru: PickLocationOverlay

File baru:
`app/lib/features/map/presentation/widgets/pick_location_overlay.dart`

```dart
class PickLocationOverlay extends ConsumerStatefulWidget {
  const PickLocationOverlay({
    super.key,
    required this.mapController,
    required this.onConfirm,
    required this.onCancel,
  });

  final MapController mapController;
  final void Function(LatLng coord) onConfirm;
  final VoidCallback onCancel;

  @override
  ConsumerState<PickLocationOverlay> createState() => _State();
}
```

State internal:
- `LatLng _currentCenter` — di-update via `mapController.mapEventStream`
  listener dengan throttle 100ms (NFR3).

Layout (over `Stack` di `MapScreen`):

```
┌────────────────────────────────────┐
│                                    │
│                                    │
│                                    │
│              ╋                     │  <- Crosshair fixed di tengah
│                                    │     viewport
│                                    │
│                                    │
│                                    │
├────────────────────────────────────┤
│ ┌─ GlassCard ──────────────────┐  │
│ │ Pan peta ke lokasi yang      │  │
│ │ ingin ditandai               │  │
│ │                              │  │
│ │ -7.20451, 113.40123          │  │  <- live coord
│ │                              │  │
│ │ [Batal]   [Tandai di Sini]   │  │
│ └──────────────────────────────┘  │
└────────────────────────────────────┘
```

Crosshair: simple `Icon(PhosphorIconsBold.crosshair)` 32px berwarna
primary di `Center` widget yang ditempatkan via
`Positioned.fill` + `Align.center`.

Bottom sheet: pakai `GlassCard` level 3 (sama pattern dengan
`LocationPermissionSheet`). Tidak pakai `showModalBottomSheet` —
overlay langsung di Stack supaya tidak block map gestures.

Format koordinat: `value.toStringAsFixed(5)` (sama dengan
`AddMarkerDialog` existing).

## §3 Wire-up MapScreen

`map_screen.dart` `_buildModeControls()` switch case tambah:

```dart
switch (mode) {
  case MapMode.idle:
    return IdleControls(...);
  case MapMode.tracking:
    return TrackingBottomSheet(...);
  case MapMode.pickMarkerLocation:
    return PickLocationOverlay(
      mapController: _mapController,
      onConfirm: (coord) => _onPickMarkerConfirm(coord),
      onCancel: () => _onPickMarkerCancel(),
    );
}
```

Method baru di `_MapScreenState`:

```dart
Future<void> _onPickMarkerConfirm(LatLng coord) async {
  // Reset mode dulu supaya UI bersih sebelum dialog muncul.
  ref.read(mapModeProvider.notifier).set(MapMode.idle);
  if (!mounted) return;
  final draft = await showDialog<AppMarker>(
    context: context,
    builder: (_) => AddMarkerDialog(
      latitude: coord.latitude,
      longitude: coord.longitude,
    ),
  );
  if (draft == null || !mounted) return;
  await ref.read(markerRepositoryProvider).create(
    name: draft.name,
    category: draft.category,
    latitude: draft.latitude,
    longitude: draft.longitude,
    notes: draft.notes,
  );
  if (!mounted) return;
  ref.read(markersOverlayEnabledProvider.notifier).state = true;
}

void _onPickMarkerCancel() {
  ref.read(mapModeProvider.notifier).set(MapMode.idle);
}
```

## §4 IdleControls — long-press Add Marker

`idle_controls.dart` `_AddMarkerButton` tambah callback
`onLongPress`. Saat ini button hanya punya `onTap`.

```dart
class _AddMarkerButton extends StatelessWidget {
  const _AddMarkerButton({
    required this.onTap,
    required this.onLongPress,
    required this.enabled,
  });

  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool enabled;
  ...
}
```

Saat `onLongPress`:
1. `HapticFeedback.lightImpact()` (NFR2)
2. Set `MapMode.pickMarkerLocation`

Implementasi pakai `GestureDetector` wrap `Material` button supaya
long-press teregister.

`Semantics.label` (R2 AC3):
```
'Tandai lokasi saya. Tekan lama untuk pilih lokasi di peta.'
```

## §5 First-time tooltip

File baru:
`app/lib/features/map/presentation/widgets/marker_pick_tooltip.dart`

Pakai pattern in-house yang ringan: `OverlayEntry` di-trigger saat
`MapScreen.initState()` membaca flag `seen_marker_pick_tooltip` di
`SharedPreferences` (atau di tabel `app_settings` kolom baru).

Pilih `SharedPreferences` untuk menghindari schema bump v10 hanya
untuk satu flag tooltip — tooltip flag = device-state, bukan domain
data, jadi cocok di SharedPreferences.

```dart
class MarkerPickTooltip {
  static const _kSeenKey = 'seen_marker_pick_tooltip_v1';

  static Future<bool> hasBeenShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSeenKey) ?? false;
  }

  static Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeenKey, true);
  }

  static OverlayEntry buildOverlay({
    required BuildContext context,
    required GlobalKey targetKey, // key di _AddMarkerButton
    required VoidCallback onDismiss,
  }) {
    // Position tooltip di atas target.
    // Render: arrow pointing down + bubble dengan teks +
    // tombol kecil "Mengerti".
  }
}
```

Tooltip self-dismiss setelah 5 detik (Timer di-start saat insert).

## §6 Pubspec impact

Cek `pubspec.yaml`. `shared_preferences` perlu ditambahkan kalau
belum ada. Saat planning, saya cek dulu — kalau sudah ada, tidak
butuh change.

(Setelah cek: TODO update `tasks.md` Phase 1 dengan info ini.)

## §7 MarkersListScreen "+"

`markers_list_screen.dart` saat ini placeholder lat/lon = 0
(line 128-129). Ganti tombol/handler:

- Tombol `FloatingActionButton.extended` di kanan bawah dengan
  icon `+` dan label "Tambah".
- Tap → pop screen (`Navigator.pop`) → set
  `mapModeProvider = pickMarkerLocation`.
- Karena Markers list ada di tab terpisah, perlu juga switch tab
  ke MapScreen. Sudah ada `appShellProvider` atau tab controller
  di `app_shell.dart` — cek dan reuse.

Alternatif: Markers list cukup pop kembali ke caller, dan kalau
caller adalah MapScreen tab, otomatis user kembali ke tab Map dengan
mode pick aktif. Kalau caller adalah Settings, perlu navigation
explicit ke `/` (Map tab) dulu.

Approach: pakai `context.go('/')` (go_router) lalu set mode di
provider via `Future.microtask`. Detail di `tasks.md` Phase 5.

## §8 Edge cases

- **User pan keluar dari area peta yang ada tile**: koordinat tetap
  tercatat (tidak dibatasi). Tile hilang tampilan (perilaku natural
  flutter_map).
- **User pan ke lat = 0 tepat**: confirm dialog masih muncul.
  Tradeoff: koordinat (0,0) di laut Atlantik valid secara teknis,
  user yang mendarat di sana bisa real. Tidak validasi.
- **User pan ke posisi GPS sekarang**: tidak ada deduplication.
  Marker baru tetap dibuat di koordinat itu walau identik dengan
  GPS reading. UX: marker baru = explicit user action, jadi OK.
- **Mode pick aktif lalu app di-background → kembali**: reset ke
  idle untuk safety. Map state restored, tapi mode reset.
- **Tracking start saat mode pick aktif**: blok di
  `TrackingController.startHaul` — kalau mode != idle, tampilkan
  snackbar "Selesaikan pilih lokasi dulu". Tradeoff: edge case
  langka, tapi worth defensive.

## §9 Decision points yang sudah final

| Topic | Decision |
|---|---|
| Crosshair fixed vs draggable pin | Fixed di tengah, user pan peta |
| Storage tooltip flag | SharedPreferences (bukan DB) |
| Markers list "+" landing | Pop ke MapScreen + set mode pick |
| Tracking aktif + long-press button | Blok dengan snackbar |
| Live coordinate update throttle | 100ms via mapEventStream listener |

## §10 Test strategy

### Unit
- `marker_pick_tooltip_test.dart` — flag persist round-trip
- `map_mode_test.dart` (kalau ada) — transitions valid

### Widget
- `pick_location_overlay_test.dart` — render crosshair + bottom
  sheet + button presses fire callbacks
- `add_marker_button_test.dart` — long-press fires onLongPress

### Integration
Manual saja (di device): pan peta, tap [Tandai], dialog muncul
dengan koordinat benar.
