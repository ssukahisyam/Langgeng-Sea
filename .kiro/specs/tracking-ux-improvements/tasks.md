# Implementation Plan: Tracking UX Improvements (PR #21)

Convert the feature design into a series of prompts for a code-generation LLM that will implement each step with incremental progress. Make sure that each prompt builds on the previous prompts, and ends with wiring things together. There should be no hanging or orphaned code that isn't integrated into a previous step. Focus ONLY on tasks that involve writing, modifying, or testing code.

## Overview

Implementasi di-layer dari bawah ke atas: foundation utilities (pure functions & enums) dahulu, lalu `MapCameraController`, lalu infrastruktur background tracking (service + permission + TrackingController), lalu layer rendering polyline + popup, lalu adaptive UI per `MapMode`, lalu kustomisasi warna + edit kategori + jump-to-location. Setiap correctness property di design dipetakan satu-persatu ke sub-task test (ditandai `*`) yang berdampingan dengan implementasinya agar regresi tertangkap sedini mungkin. Bahasa implementasi: Dart 3 + Flutter (sesuai arsitektur eksisting). Property-based tests memakai `package:glados`.

## Tasks

- [x] 1. Foundation utilities dan abstraksi bersama
  - [x] 1.1 Buat enum `MapMode` dan fungsi murni `deriveMapMode`
    - File baru: `app/lib/features/map/application/map_mode.dart`
    - Define `enum MapMode { idle, tracking, navigating, viewingHistory }`
    - Implement `MapMode deriveMapMode({required bool tracking, required bool navigating, required bool historyOverlayActive})` dengan urutan prioritas `navigating > tracking > viewingHistory > idle`
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.12_

  - [ ]* 1.2 Property test untuk `deriveMapMode`
    - **Property 13: Map_Mode adalah fungsi deterministik dari (tracking, navigating, historyOn)**
    - **Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.12**
    - File baru: `app/test/features/map/application/map_mode_test.dart`
    - Gunakan `package:glados` dengan seed 42; enumerasi semua 2³ = 8 kombinasi boolean dan verifikasi prioritas

  - [x] 1.3 Buat `mapModeProvider` yang menggabungkan state TrackingController, NavigationController, dan `allHistoryVisibleProvider`
    - File baru: `app/lib/features/map/application/map_mode_provider.dart`
    - Export `Provider<MapMode> mapModeProvider` yang `watch` tiga sumber state dan memanggil `deriveMapMode`
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.12_

  - [x] 1.4 Buat helper `trackDisplayLabel`
    - File baru: `app/lib/features/map/presentation/widgets/track_display_label.dart`
    - Pure function `String trackDisplayLabel({String? storedName, required DateTime startedAt})` dengan format `yyyy-MM-dd HH:mm` via `package:intl`
    - _Requirements: 3.3, 3.3a, 3.7_

  - [ ]* 1.5 Unit test untuk `trackDisplayLabel`
    - **Property 10: Track display label memilih nama tersimpan atau format tanggal**
    - **Validates: Requirements 3.3, 3.3a, 3.7**
    - File baru: `app/test/features/map/presentation/widgets/track_display_label_test.dart`
    - Property test `glados` untuk `(storedName, startedAt)` ∈ `(String?, DateTime)`

  - [x] 1.6 Buat utility WCAG contrast ratio
    - File baru: `app/lib/core/utils/contrast_ratio.dart`
    - Implement `double relativeLuminance(Color c)` (formula WCAG 2.1) dan `double contrastRatio(Color a, Color b)` yang mengembalikan `(L1 + 0.05) / (L2 + 0.05)` dengan `L1 >= L2`
    - _Requirements: 3.1, 3.2, 3.6_

  - [ ]* 1.7 Property test untuk contrast ratio terhadap `AppColors.pickablePalette` × {light, dark}
    - **Property 9: Contrast ratio polyline ≥ 4.5:1 pada semua (warna, tema)**
    - **Validates: Requirements 3.1, 3.2, 3.6**
    - File baru: `app/test/core/utils/contrast_ratio_test.dart`
    - Hitung rasio kontras compound (stroke + border) terhadap tile OSM reference `#F2EFE9` (light) dan `#1B1B1B` (dark); assert `>= 4.5`

  - [x] 1.8 Perluas typedef `HaulTrackRender` dengan `storedName` dan `startedAt`
    - File: `app/lib/features/map/application/history_overlay_providers.dart`
    - Tambah field `String? storedName` dan `DateTime startedAt` pada record `HaulTrackRender`
    - Update `allHistoryRenderProvider` dan `tripRenderProvider` untuk mengisi kedua field dari row `haul`/`trip` yang sudah di-fetch
    - _Requirements: 3.3, 3.7_

- [ ] 2. `MapCameraController` dan integrasinya ke MapScreen
  - [x] 2.1 Implement class `MapCameraController`
    - File baru: `app/lib/features/map/application/map_camera_controller.dart`
    - Enkapsulasi `MapController` dan dua latch: `_initialFitDone`, `_userLatched`
    - API: `activate(Object overlayKey)`, `deactivate()`, `maybeInitialFit(LatLngBounds bounds)`, `fitCameraExplicit(LatLngBounds bounds)`, `onUserGesture()`
    - _Requirements: 2.1, 2.3, 2.4, 2.5, 2.6, 2.7_

  - [ ]* 2.2 Property test untuk invariant single-initial-fit
    - **Property 7: History overlay melakukan tepat satu auto-fit per siklus aktivasi**
    - **Validates: Requirements 2.1, 2.3, 2.4, 2.5, 2.7**
    - File baru: `app/test/features/map/application/map_camera_controller_single_fit_test.dart`
    - Generator urutan event `[activate, gesture×M, dataRefresh×N, explicitFit×K]`; assert jumlah auto-fit tepat 1 jika bounds non-null dan tidak ada explicitFit sebelum data emit pertama

  - [ ]* 2.3 Property test untuk round-trip toggle reset
    - **Property 8: Toggle History_Overlay me-reset camera state**
    - **Validates: Requirements 2.6**
    - File baru: `app/test/features/map/application/map_camera_controller_toggle_reset_test.dart`
    - Bandingkan perilaku siklus 2 (setelah deactivate → activate) dengan fresh controller; jumlah auto-fit di siklus 2 tetap 1

  - [-] 2.4 Integrasi `MapCameraController` ke `MapScreen` dan hook gesture
    - File: `app/lib/features/map/presentation/map_screen.dart`
    - Hapus state lama `_fittedOverlayKey`, helper `_fitAllHistoryBounds`, `_fitOverlayBounds`
    - Instansiasi `MapCameraController(_mapController)` di `initState`
    - Pada `onPositionChanged(position, hasGesture)`: jika `hasGesture`, panggil `_camera.onUserGesture()`
    - Saat `allHistoryVisibleProvider` transisi `false → true`: panggil `_camera.activate(newOverlayKey)`; `true → false`: `_camera.deactivate()`
    - Dalam `allHistoryRenderProvider.whenData((render) { ... })`: panggil `_camera.maybeInitialFit(render.bounds!)` bila bounds non-null
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.6, 2.7_

- [~] 3. Checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 4. Infrastruktur background tracking
  - [x] 4.1 Perbarui `AndroidManifest.xml` untuk foreground service type dan permission
    - File: `app/android/app/src/main/AndroidManifest.xml`
    - Tambahkan atribut `android:foregroundServiceType="location"` pada service declaration `flutter_background_service_android`
    - Pastikan permission `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS` sudah terdeklarasi
    - Pastikan `minSdkVersion 26` dan `targetSdkVersion 34` konsisten di `build.gradle.kts`
    - _Requirements: 1.1, 1.10_

  - [x] 4.2 Definisikan abstract class `BackgroundTrackingService` dan enum status
    - File baru: `app/lib/features/tracking/data/background_tracking_service.dart`
    - Abstract API: `start({required String haulId, required String notificationTitle, required String notificationBody})`, `stop()`, `Stream<BackgroundTrackingStatus> watchStatus()`
    - Define `enum BackgroundTrackingStatus { stopped, starting, running, restarting, failed }`
    - Expose top-level `onBackgroundStart(ServiceInstance service)` signature
    - _Requirements: 1.1, 1.7, 1.8_

  - [-] 4.3 Implement `FlutterBackgroundTrackingService` menggunakan `flutter_background_service`
    - File baru: `app/lib/features/tracking/data/flutter_background_tracking_service.dart`
    - Delegasikan ke `FlutterBackgroundService`; konfigurasi `AndroidConfiguration` dengan `onStart: onBackgroundStart`, `foregroundServiceNotificationId`, `initialNotificationTitle`
    - Top-level `onBackgroundStart` entrypoint menginstansiasi `GeolocatorGpsService`, `AppDatabase` isolate-lokal, `TrackPointRepository`; subscribe `_gps.watchPosition(distanceFilterMeters: 2)` dan persist Track_Point dengan filter `accuracyMeters == null || accuracyMeters <= 50.0`
    - Persistent notification via `flutter_local_notifications` dengan `ongoing: true`, `autoCancel: false`, menampilkan nama Haul
    - Emit status lifecycle melalui `service.on('status')` → `StreamController<BackgroundTrackingStatus>`
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.8, 1.9_

  - [ ]* 4.4 Property test: background persistence sebagai order-preserving filter
    - **Property 1: Background tracking adalah order-preserving filter**
    - **Validates: Requirements 1.2, 1.9**
    - File baru: `app/test/features/tracking/data/background_tracking_property_1_test.dart`
    - Generator `arbGpsStream` (sequence reading dengan accuracy random); jalankan melalui fake isolate path; assert Track_Point tersimpan = filter(stream, accuracy ≤ 50) dan timestamps non-descending

  - [ ]* 4.5 Property test: spatial gap dibatasi kecepatan kapal
    - **Property 2: Spasial gap antar Track_Point dibatasi kecepatan kapal**
    - **Validates: Requirements 1.3**
    - File baru: `app/test/features/tracking/data/background_tracking_property_2_test.dart`
    - Generator stream dengan `speedMps <= 7.717` dan interval ≤ 5s; assert haversine gap setiap pasang berurutan ≤ 50m + 10m toleransi

  - [ ]* 4.6 Property test: restart recovery tanpa kehilangan atau duplikat
    - **Property 3: Restart recovery mempertahankan Track_Point tanpa duplikat**
    - **Validates: Requirements 1.7, 1.9**
    - File baru: `app/test/features/tracking/data/background_tracking_property_3_test.dart`
    - Skenario: isi `S` → stop service → start service → tambahkan reading baru; assert `S ⊆ S'` dan `(haulId, timestamp)` unik

  - [ ]* 4.7 Property test: path length foreground vs background ≤ 10%
    - **Property 4: Path length foreground vs background berjarak ≤ 10%**
    - **Validates: Requirements 1 (metamorphic foreground-vs-background)**
    - File baru: `app/test/features/tracking/data/background_tracking_property_4_test.dart`
    - Jalankan stream sintetis identik via jalur foreground `TrackingController._onReading` dan jalur `FakeBackgroundTrackingService`; assert `|len_fg − len_bg| / max(len_fg, len_bg) <= 0.10`

- [x] 5. Permission flow helper
  - [x] 5.1 Implement `ensureTrackingPermissions`
    - File baru: `app/lib/features/tracking/application/tracking_permission_flow.dart`
    - Define sealed `TrackingPermissionResult { Granted, GrantedForegroundOnly, Denied }`
    - Implement `Future<TrackingPermissionResult> ensureTrackingPermissions({required GpsService gps, required PermissionHandler handler, required void Function(String explanationId) showRationale})`
    - Alur: check `ACCESS_FINE_LOCATION` → request bila perlu; bila Android 10+ lanjutkan ke `ACCESS_BACKGROUND_LOCATION` (show rationale dulu); Android 13+ request `POST_NOTIFICATIONS`
    - _Requirements: 1.5, 1.6_

  - [ ]* 5.2 Property test untuk permission flow
    - **Property 5: Permission flow menghasilkan result deterministik**
    - **Validates: Requirements 1.5, 1.6**
    - File baru: `app/test/features/tracking/application/tracking_permission_flow_test.dart`
    - Glados generator `PermissionStatus`; verifikasi mapping ke result dan assertion bahwa `showRationale` dipanggil tepat ketika `p ∈ {grantedForegroundOnly, denied}`

- [ ] 6. Integrasi `TrackingController` dengan background service dan retry
  - [-] 6.1 Modifikasi `TrackingController.startHaul` untuk memakai permission flow dan mendelegasi ke background service
    - File: `app/lib/features/tracking/application/tracking_controller.dart`
    - Panggil `ensureTrackingPermissions` sebelum memulai; pada `GrantedForegroundOnly` tampilkan warning non-blocking dan SKIP background service; pada `Denied` abort dan tampilkan banner
    - Pada `Granted` panggil `backgroundTrackingService.start(haulId: haul.id, notificationTitle: ..., notificationBody: ...)`
    - Hentikan subscription langsung ke `_gps.watchPosition` untuk menulis Track_Point (dipindah ke isolate)
    - _Requirements: 1.1, 1.5, 1.6, 1.9_

  - [~] 6.2 Ganti sumber live metrics foreground ke `trackPointRepository.watchByHaul`
    - File: `app/lib/features/tracking/application/tracking_controller.dart`
    - Subscribe `_trackPointRepo.watchByHaul(haulId)` untuk mendapat stream Track_Point yang masuk dari isolate background
    - Rekomputasi metric (duration, cumulative distance, last speed) dari diff antar snapshot Track_Point
    - _Requirements: 1.9_

  - [~] 6.3 Implement exponential-backoff retry saat background service stop
    - File: `app/lib/features/tracking/application/tracking_controller.dart`
    - Subscribe `backgroundTrackingService.watchStatus()`; pada transisi `running → stopped` sementara `state.isRecording == true`, jadwalkan retry `_restart()` dengan jeda `[1s, 2s, 4s]`
    - Setelah attempt ke-4 gagal, set state `failed` dan Log melalui `Logger`
    - _Requirements: 1.7_

  - [ ]* 6.4 Property test untuk retry schedule dan konservasi data
    - **Property 6: Retry eksponensial menghormati jadwal dan konservasi data**
    - **Validates: Requirements 1.7**
    - File baru: `app/test/features/tracking/application/tracking_controller_retry_test.dart`
    - Gunakan `fake_async`; generator pola sukses/gagal `[a_1..a_4]`; assert attempts ≤ 4, berhenti pada sukses pertama, jeda sesuai `[1s, 2s, 4s]`, dan count Track_Point tidak berkurang

  - [~] 6.5 Modifikasi `stopHaul` dan `resumeHaul` untuk memicu background service
    - File: `app/lib/features/tracking/application/tracking_controller.dart`
    - `stopHaul`: panggil `backgroundTrackingService.stop()` lalu bersihkan live metric subscription
    - `resumeHaul`: setelah `detectRecoverableHaul` sukses, panggil `backgroundTrackingService.start(...)` dengan haul yang sama
    - _Requirements: 1.1, 1.8_

- [~] 7. Checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 8. Rendering polyline kontras dan popup Track
  - [-] 8.1 Implement `HistoryPolylineLayer` dengan compound stroke dan hit overlay
    - File baru: `app/lib/features/map/presentation/widgets/history_polyline_layer.dart`
    - `PolylineLayer<HaulTrackRender>` dengan `hitNotifier: ValueNotifier<LayerHitResult<HaulTrackRender>?>(null)`
    - Per-Track buat tiga `Polyline`: (a) outer transparan `strokeWidth: 16` untuk hit, (b) border `strokeWidth: 2` kontras `_contrastBorder(theme)`, (c) main `strokeWidth: 5` dengan `AppColors.resolveHaulColor(colorValue, orderIndex).withValues(alpha: 1.0)`
    - Wrap `GestureDetector` yang membaca `hitNotifier.value` pada `onTap` dan meneruskan `onTrackTap(hit, tapPosition)` callback
    - _Requirements: 3.1, 3.2, 3.6, 3.8_

  - [ ]* 8.2 Property test untuk hit tolerance polyline
    - **Property 12: Hit test tolerance polyline ≥ 16 logical pixels**
    - **Validates: Requirements 3.8, Invariant tap-target-reachability**
    - File baru: `app/test/features/map/presentation/widgets/history_polyline_layer_hit_test.dart`
    - Widget test dengan `flutter_map` di berbagai zoom; generator titik tap pada jarak Euclidean 0..30 px dari sumbu; assert hit jika ≤ 16, non-hit jika > 16 + visualStroke/2

  - [-] 8.3 Implement widget `TrackPopup`
    - File baru: `app/lib/features/map/presentation/widgets/track_popup.dart`
    - Define `enum TrackKind { haul, trip }`
    - `TrackPopup({required HaulTrackRender track, required String? storedName, required DateTime startedAt, required TrackKind kind, required VoidCallback onClose, required VoidCallback onNavigate})`
    - Header memakai `trackDisplayLabel(...)`; body menampilkan kind, `startedAt` formatted, dan tombol "Navigasi ke sini"
    - _Requirements: 3.3, 3.3a, 3.4, 3.5, 3.7_

  - [~] 8.4 Integrasi `HistoryPolylineLayer` dan `TrackPopup` ke `MapScreen`
    - File: `app/lib/features/map/presentation/map_screen.dart`
    - Gantikan polyline rendering lama dengan `HistoryPolylineLayer` saat `allHistoryOn`
    - State lokal `TrackPopup? _activePopup`; `onTrackTap` set popup pada `Positioned` di atas peta (konversi `LatLng → screen offset` via `MapController.camera.latLngToScreenOffset`)
    - `GestureDetector` overlay transparan di luar popup rectangle memanggil `onClose` → `setState(() => _activePopup = null)`
    - _Requirements: 3.3, 3.3a, 3.5, 3.7_

  - [~] 8.5 Wire tombol "Navigasi ke sini" ke `NavigationController.startFollowTrack`
    - File: `app/lib/features/map/presentation/map_screen.dart`
    - `onNavigate` di popup → panggil `ref.read(navigationControllerProvider.notifier).startFollowTrack(FollowTrackTarget(pathPoints: track.points, trackId: track.haulId))` lalu set `_activePopup = null`
    - `mapModeProvider` otomatis berpindah ke `MapMode.navigating` via derivation
    - _Requirements: 3.4_

  - [ ]* 8.6 Property test untuk round-trip tap → navigate → cancel
    - **Property 11: Tap "Navigasi ke sini" memulai FollowTrack dan kembali ke mode awal saat dibatalkan**
    - **Validates: Requirements 3.4, 3.5, Round-trip tap-navigate-back**
    - File baru: `app/test/features/map/presentation/track_navigate_roundtrip_test.dart`
    - Widget test; generator `HaulTrackRender` dengan ≥ 2 points dan initial `historyOverlayActive ∈ {true, false}`; assert setelah navigate mode = `navigating` dengan `FollowTrackTarget` yang benar, dan setelah cancel mode kembali ke `deriveMapMode(false, false, h)`

- [ ] 9. Widget adaptive UI dan mode switch di `MapScreen`
  - [-] 9.1 Extract widget `IdleControls`
    - File baru: `app/lib/features/map/presentation/widgets/idle_controls.dart`
    - FAB "Mulai tracking" (panggil `trackingControllerProvider.notifier.startHaul`), tombol toggle History_Overlay, tombol my-location, tombol layer toggle
    - _Requirements: 4.6_

  - [-] 9.2 Buat widget `TrackingBottomSheet`
    - File baru: `app/lib/features/map/presentation/widgets/tracking_bottom_sheet.dart`
    - Bottom sheet collapsible menampilkan duration, cumulative distance, last speed dari `trackingControllerProvider.state`; tombol "Berhenti tracking" memanggil `stopHaul`
    - _Requirements: 4.7_

  - [-] 9.3 Buat widget `HistoryOverlayControls`
    - File baru: `app/lib/features/map/presentation/widgets/history_overlay_controls.dart`
    - Tombol toggle off History_Overlay, filter kategori, tombol "Paskan semua" yang memanggil `mapCameraController.fitCameraExplicit(bounds)`
    - _Requirements: 2.5, 4.9_

  - [-] 9.4 Buat widget `_CollapsedTrackingMini`
    - File baru: `app/lib/features/map/presentation/widgets/collapsed_tracking_mini.dart`
    - Mini banner collapsed untuk kasus Tracking + Navigating bersamaan (prioritas layout Navigating di atas)
    - _Requirements: 4.12_

  - [-] 9.5 Buat widget `_MapOverflowMenu`
    - File baru: `app/lib/features/map/presentation/widgets/map_overflow_menu.dart`
    - Three-dot menu berisi kontrol yang disembunyikan oleh mode aktif (misal "Tambahkan penanda di sini", "Paskan semua" saat tidak di `ViewingHistory`, dst) tanpa mengubah `MapMode`
    - _Requirements: 4.10_

  - [~] 9.6 Switch `MapScreen.body` berdasarkan `mapModeProvider` dengan `AnimatedSwitcher` 250 ms
    - File: `app/lib/features/map/presentation/map_screen.dart`
    - `final mode = ref.watch(mapModeProvider);`
    - `Stack` children dipilih via `switch (mode)`: `idle → [IdleControls]`, `tracking → [TrackingBottomSheet, _StandardMapControls]`, `navigating → [NavigationPanel, if (trackingAlso) _CollapsedTrackingMini]`, `viewingHistory → [HistoryOverlayControls, _StandardMapControls]`; selalu render `_MapOverflowMenu`
    - Bungkus setiap slot dengan `AnimatedSwitcher(duration: Duration(milliseconds: 250))`
    - _Requirements: 4.6, 4.7, 4.8, 4.9, 4.11, 4.12_

  - [ ]* 9.7 Widget test: visible controls per mode merupakan subset allowed
    - **Property 14: Visible controls per mode merupakan subset allowed set**
    - **Validates: Requirements 4.6, 4.7, 4.8, 4.9, Invariant no-forbidden-control**
    - File baru: `app/test/features/map/presentation/map_screen_mode_controls_test.dart`
    - Widget test untuk setiap `MapMode`; assert `find.byKey(forbiddenKey).evaluate().isEmpty` dan `find.byKey(allowedKey)` sesuai `allowedControls(mode)`

  - [ ]* 9.8 Property test: mode-change reversibility
    - **Property 15: Mode-change reversibility**
    - **Validates: Requirements 4.5, 4.11, Round-trip mode-change-reversibility**
    - File baru: `app/test/features/map/presentation/map_screen_mode_reversibility_test.dart`
    - Generator `historyOverlayActive ∈ {true, false}`; sequence `startTracking → stopTracking`; assert mode final dan set kontrol terlihat identik dengan initial

- [~] 10. Checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 11. Trip color field dan repository
  - [x] 11.1 Tambah field `colorValue` pada entitas `Trip` dan schema Drift
    - File: `app/lib/features/tracking/domain/trip.dart` (tambah `int? colorValue`)
    - File: `app/lib/core/database/tables.dart` (tambah kolom `IntColumn get colorValue => integer().nullable()();` pada tabel `Trips`)
    - File: `app/lib/core/database/app_database.dart` — naikkan `schemaVersion` dan tambah branch di `onUpgrade`: `await m.addColumn(trips, trips.colorValue);`
    - Update mapper `Trip.fromRow` / `Trip.toCompanion`
    - _Requirements: 5.1, 5.2, 5.3, 5.9_

  - [-] 11.2 Implement `TripRepository.setColor`
    - File: `app/lib/features/tracking/data/trip_repository.dart`
    - Analog dengan `HaulRepository.setColor`: `Future<void> setColor(String tripId, int? colorValue)` yang no-op bila trip tidak ada, lalu `_dao.updateTrip(tripId, TripsCompanion(colorValue: Value(colorValue)))`
    - _Requirements: 5.2, 5.9_

  - [ ]* 11.3 Property test untuk color persist round-trip Trip dan Haul
    - **Property 16: Color persist round-trip untuk Trip dan Haul**
    - **Validates: Requirements 5.2, Round-trip color-persist**
    - File baru: `app/test/features/tracking/data/trip_haul_color_persist_test.dart`
    - Generator `arbColor` (ARGB32 int); untuk setiap `e ∈ {Trip, Haul}` assert `setColor → read → colorValue == c` dan entity lain tidak berubah (hash checksum)

  - [ ]* 11.4 Property test: `setColor` tidak memodifikasi Track_Point
    - **Property 19: Perubahan color pada Trip/Haul tidak memodifikasi Track_Point**
    - **Validates: Requirements 5.9, Invariant track_point-immutability**
    - File baru: `app/test/features/tracking/data/color_change_track_point_immutability_test.dart`
    - Seed sejumlah Track_Point; hitung `count(*)` dan SHA-256 checksum atas field GPS; assert sama sebelum/sesudah `setColor`

  - [ ]* 11.5 Unit test untuk default polyline color fallback
    - **Property 17: Default polyline color bergantung pada orderIndex saat `colorValue == null`**
    - **Validates: Requirements 5.3**
    - File baru: `app/test/core/theme/resolve_haul_color_test.dart`
    - Generator `orderIndex >= 1`; assert `AppColors.resolveHaulColor(colorValue: null, orderIndex: o) == AppColors.colorForHaul(o)`

- [ ] 12. Color picker sheet dan integrasinya
  - [x] 12.1 Tambah `flutter_colorpicker` ke `pubspec.yaml`
    - File: `app/pubspec.yaml`
    - Tambah dependency `flutter_colorpicker: ^1.1.0` (atau versi stabil terbaru yang kompatibel); jalankan `flutter pub get`
    - _Requirements: 5.1_

  - [-] 12.2 Implement widget `ColorPickerSheet`
    - File baru: `app/lib/features/tracking/presentation/widgets/color_picker_sheet.dart`
    - Tampilkan grid `AppColors.pickablePalette` (pre-set ≥ 8 warna) + tombol "Custom" yang membuka `showColorPicker` dari `flutter_colorpicker`
    - Return ARGB32 `int?` via `Navigator.pop(context, selectedColor?.value)`
    - _Requirements: 5.1_

  - [~] 12.3 Wire `ColorPickerSheet` ke layar detail Trip dan Haul
    - File: layar detail Trip (`app/lib/features/tracking/presentation/trip_detail_screen.dart`) dan Haul (`app/lib/features/tracking/presentation/haul_detail_screen.dart`) — sesuaikan path aktual
    - Tambah section "Warna Track" dengan preview swatch; tap membuka `ColorPickerSheet`; hasil dipersist via `TripRepository.setColor` / `HaulRepository.setColor`
    - _Requirements: 5.1, 5.2_

- [ ] 13. Edit Marker_Category di Markers_List_Screen
  - [x] 13.1 Tambah method `MarkerRepository.updateCategory` dengan audit log
    - File: `app/lib/features/marker/data/marker_repository.dart`
    - `Future<void> updateCategory(String markerId, MarkerCategory category)`; throw `StateError` jika marker tidak ada
    - Log via `Logger` (`log.info('marker.category.change', {markerId, from, to})`) sebelum update (Requirement 5.10 audit)
    - Panggil `_dao.updateMarker(markerId, MarkersCompanion(category: Value(category.storageKey)))`
    - _Requirements: 5.4, 5.5, 5.6, 5.10_

  - [ ]* 13.2 Property test untuk category update round-trip
    - **Property 18: Category update round-trip pada Marker**
    - **Validates: Requirements 5.5, 5.6**
    - File baru: `app/test/features/marker/data/marker_update_category_test.dart`
    - Generator `AppMarker`, `cat1 ∈ MarkerCategory.values`; assert `updateCategory → getById → .category == cat1`, dan filter by category konsisten

  - [ ]* 13.3 Unit test untuk category validity invariant
    - **Property 21: Category validity invariant di repository**
    - **Validates: Requirements 5.6, Invariant category-validity**
    - File baru: `app/test/features/marker/data/marker_category_validity_test.dart`
    - Seed marker dengan berbagai storageKey (valid + invalid); assert marker yang di-load selalu memiliki `category ∈ MarkerCategory.values` (fallback `.other`)

  - [ ] 13.4 Implement widget `EditMarkerCategorySheet`
    - File baru: `app/lib/features/marker/presentation/widgets/edit_marker_category_sheet.dart`
    - `showModalBottomSheet` menampilkan `MarkerCategory.values` sebagai `RadioListTile` dengan icon + label
    - On confirm panggil `markerRepositoryProvider.notifier.updateCategory(marker.id, selected)`
    - _Requirements: 5.4, 5.5_

  - [~] 13.5 Tambah menu "Ubah kategori" di item `_MarkerTile`
    - File: `app/lib/features/marker/presentation/markers_list_screen.dart`
    - Trailing `PopupMenuButton` pada `_MarkerTile` dengan entry "Ubah kategori" → panggil `EditMarkerCategorySheet`
    - _Requirements: 5.4, 5.5_

- [ ] 14. Jump-to-location dari `MarkersListScreen`
  - [~] 14.1 Dukung query parameter `focusMarkerId` di router
    - File: `app/lib/core/router/app_router.dart`
    - Pada route `/` (Map), baca `state.uri.queryParameters['focusMarkerId']` dan teruskan ke `MapScreen(focusMarkerId: ...)`
    - _Requirements: 5.7, 5.8_

  - [~] 14.2 Ubah `_MarkerTile` menjadi tap-to-locate
    - File: `app/lib/features/marker/presentation/markers_list_screen.dart`
    - Bungkus tile dengan `InkWell(onTap: () => context.go('/?focusMarkerId=${marker.id}'))`
    - _Requirements: 5.7_

  - [~] 14.3 Implement focus behavior di `MapScreen`
    - File: `app/lib/features/map/presentation/map_screen.dart`
    - Tambah parameter `final String? focusMarkerId`; pada `initState` atau `postFrameCallback` pertama: fetch marker via `ref.read(markerByIdProvider(focusMarkerId!))`
    - Jika ditemukan: `_mapController.move(marker.latLng, max(15, currentZoom))`, set `markersOverlayEnabledProvider = true`, trigger popup info marker
    - Jika null: log dan tampilkan toast non-blocking
    - _Requirements: 5.7, 5.8_

  - [ ]* 14.4 Property test untuk determinisme viewport jump-to-location
    - **Property 20: Jump-to-location deterministik terhadap initial mode**
    - **Validates: Requirements 5.7, 5.8, Metamorphic jump-to-location-deterministik**
    - File baru: `app/test/features/map/presentation/jump_to_location_test.dart`
    - Generator `AppMarker` posisi acak dan `initialMode ∈ MapMode.values`; assert `|center − marker.latLng| <= 1e-6`, `zoom >= 15`, `markersOverlayEnabledProvider == true`, dan mode akhir sesuai `deriveMapMode` (idle bila tracking & navigating false)

- [~] 15. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Sub-tasks bertanda `*` adalah test (unit, property, widget) yang opsional untuk MVP tapi sangat disarankan; tiap test men-cover tepat satu Correctness Property dari design untuk traceability.
- Setiap task non-test mereferensikan sub-requirement granular (misal `5.2, 5.9`), bukan sekadar nomor user story.
- Checkpoint di task 3, 7, 10, 15 memberikan gate validasi antar layer (foundation → background → rendering → adaptive UI → kustomisasi).
- Implementasi background tracking (task 4-6) menjadi simpul kritis; blunder di urutan ini menyebabkan kehilangan Track_Point. Retry + audit log didesain defensif.
- Tasks PBT memakai `package:glados` dengan seed tetap (`@Glados(seed: 42)`) + minimum 100 iterasi per instruksi design.
- Edit file bersama (`map_screen.dart`, `tracking_controller.dart`, `markers_list_screen.dart`) di-serialize antar wave di dependency graph agar tidak ada konflik paralel.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.4", "1.6", "1.8", "2.1", "4.1", "4.2", "5.1", "11.1", "12.1", "13.1"] },
    { "id": 1, "tasks": ["1.2", "1.3", "1.5", "1.7", "2.2", "2.3", "2.4", "4.3", "5.2", "6.1", "8.1", "8.3", "9.1", "9.2", "9.3", "9.4", "9.5", "11.2", "11.5", "12.2", "13.2", "13.3", "13.4"] },
    { "id": 2, "tasks": ["4.4", "4.5", "4.6", "4.7", "6.2", "8.2", "8.4", "11.3", "11.4", "12.3", "13.5"] },
    { "id": 3, "tasks": ["6.3", "9.6", "14.2"] },
    { "id": 4, "tasks": ["6.5", "8.5"] },
    { "id": 5, "tasks": ["6.4", "8.6", "9.7", "9.8", "14.3"] },
    { "id": 6, "tasks": ["14.1"] },
    { "id": 7, "tasks": ["14.4"] }
  ]
}
```
