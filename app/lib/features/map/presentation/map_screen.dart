import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show ServiceStatus;
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/gps_reading.dart';
import '../../../core/services/gps_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../../../core/widgets/status_chip.dart';
import '../../tracking/application/tracking_controller.dart';
import '../../tracking/application/tracking_state.dart';
import '../../tracking/data/background_tracking_service.dart';
import '../../tracking/data/haul_repository.dart';
import '../../tracking/data/trip_repository.dart';
import '../../tracking/domain/entities/haul.dart';
import '../../tracking/domain/entities/trip.dart';
import '../../tracking/presentation/widgets/active_haul_polyline.dart';
import '../../tracking/presentation/widgets/haul_summary_sheet.dart';
import '../../tracking/presentation/widgets/live_stats_panel.dart';
import '../../tracking/presentation/widgets/recording_banner.dart';
import '../../marker/data/marker_repository.dart';
import '../../marker/domain/entities/marker.dart';
import '../../marker/presentation/widgets/add_marker_dialog.dart';
import '../../marker/presentation/widgets/marker_info_sheet.dart';
import '../../marker/presentation/widgets/marker_pin.dart';
import '../../navigation/application/navigation_controller.dart';
import '../../navigation/application/navigation_state.dart';
import '../../navigation/domain/entities/navigation_target.dart';
import '../../navigation/presentation/widgets/long_press_menu.dart';
import '../../navigation/presentation/widgets/navigation_panel.dart';
import '../../navigation/presentation/widgets/navigation_polyline.dart';
import '../../offline_map/data/tile_cache_service.dart';
import '../../onboarding/data/user_profile_repository.dart';
import '../application/all_history_visible_provider.dart';
import '../application/current_reading_provider.dart';
import '../application/history_overlay_providers.dart';
import '../application/map_camera_controller.dart';
import '../application/map_mode.dart';
import '../application/map_mode_provider.dart';
import '../application/map_overlay_state.dart';
import '../application/markers_overlay_provider.dart';
import 'providers/location_permission_provider.dart';
import 'widgets/boat_marker.dart';
import 'widgets/collapsed_tracking_mini.dart';
import 'widgets/gps_accuracy_chip.dart';
import 'widgets/gps_error_banner.dart';
import 'widgets/history_overlay_controls.dart';
import 'widgets/history_polyline_layer.dart';
import 'widgets/location_permission_sheet.dart';
import 'widgets/map_attribution.dart';
import 'widgets/map_controls.dart';
import 'widgets/map_overflow_menu.dart';
import 'widgets/track_popup.dart';
import 'widgets/tracking_bottom_sheet.dart';

/// Home tab — map + live GPS position + haul recording controls.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with WidgetsBindingObserver {
  static const _initialCenter = LatLng(-7.25, 113.42); // Selat Madura
  static const _initialZoom = 9.0;

  final MapController _mapController = MapController();
  late final MapCameraController _cameraController;
  bool _followingUser = true;
  bool _checkedRecovery = false;

  /// Active popup for tapped polyline track. Null when no popup is shown.
  HaulTrackRender? _activePopupTrack;

  /// Tracks the current map zoom so the marker layer can decide
  /// whether to show name labels (see MarkerPin.labelZoomThreshold).
  double _currentZoom = _initialZoom;


  // Subscribes to the OS-level location service toggle. When the user
  // flips GPS on from the system shade / Settings and returns to the
  // app, Geolocator emits a `ServiceStatus.enabled` event — we use that
  // as a hint to silently re-check permission state and dismiss any
  // stale "activate GPS" sheet. Without this the user would see the
  // sheet hang around until they touched the app manually.
  StreamSubscription<ServiceStatus>? _serviceStatusSub;

  /// Tracks whether our location permission sheet is currently on
  /// screen so the auto-dismiss on service-on / app-resume only ever
  /// closes THAT route (not, say, a haul summary sheet or a crash
  /// recovery dialog that might also be open).
  bool _permissionSheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraController = MapCameraController(_mapController);
    // Service-status stream runs for the lifetime of the map tab —
    // it's cheap (one platform-channel callback) and lets us react
    // immediately to GPS-toggle changes even while the app is
    // foregrounded.
    try {
      _serviceStatusSub = ref
          .read(gpsServiceProvider)
          .watchServiceStatus()
          .listen((status) {
        if (!mounted) return;
        // Re-check permission on every transition so the sheet text
        // updates in place ("Aktifkan Lokasi" → "Lokasi Aktif") without
        // the user having to dismiss and reopen.
        unawaited(ref.read(locationPermissionProvider.notifier).check());
        if (status == ServiceStatus.enabled) {
          _maybeAutoDismissPermissionSheet();
        }
      });
    } catch (_) {
      // Widget tests and other environments without a platform channel
      // just won't get auto-dismiss on GPS toggle — the resume-based
      // path in didChangeAppLifecycleState still covers them.
      _serviceStatusSub = null;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(locationPermissionProvider.notifier).check();
      if (!mounted) return;
      final permState = ref.read(locationPermissionProvider);
      if (permState != LocationPermissionState.ready &&
          permState != LocationPermissionState.unknown) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        await _showPermissionSheet();
      }

      // Crash recovery: do this once per app session.
      if (!_checkedRecovery) {
        _checkedRecovery = true;
        final orphan = await ref
            .read(trackingControllerProvider.notifier)
            .detectRecoverableHaul();
        if (!mounted || orphan == null) return;
        await _showRecoveryDialog(orphan);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _serviceStatusSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // User often toggles GPS from system Settings and returns via the
    // task switcher. Refresh permission state on every resume so the
    // permission sheet is in sync with reality.
    if (state == AppLifecycleState.resumed) {
      ref.read(locationPermissionProvider.notifier).check().then((_) {
        if (!mounted) return;
        _maybeAutoDismissPermissionSheet();
      });
    }
  }

  /// Wraps [LocationPermissionSheet.show] with the bookkeeping that
  /// lets the auto-dismiss paths know whether the sheet is currently
  /// on screen. Everything goes through this helper; never call
  /// LocationPermissionSheet.show directly from this screen.
  Future<void> _showPermissionSheet() async {
    if (_permissionSheetOpen) return;
    _permissionSheetOpen = true;
    try {
      await LocationPermissionSheet.show(context);
    } finally {
      if (mounted) _permissionSheetOpen = false;
    }
  }

  /// If the permission sheet is still on top but the state is now
  /// `ready`, pop it automatically so the user doesn't have to tap
  /// "Tutup" after enabling GPS from system Settings.
  ///
  /// Guarded by [_permissionSheetOpen] so we don't accidentally pop a
  /// haul summary sheet or a recovery dialog that happens to be
  /// sitting above the map.
  ///
  /// The sheet is hosted in the local (shell) navigator — see
  /// [LocationPermissionSheet.show]'s `useRootNavigator: false` —
  /// so we must pop the local one, not the root. Popping the root
  /// here would accidentally unwind a Haul summary sheet or crash
  /// recovery dialog that happens to be on top.
  void _maybeAutoDismissPermissionSheet() {
    if (!_permissionSheetOpen) return;
    final permState = ref.read(locationPermissionProvider);
    if (permState != LocationPermissionState.ready) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    }
  }

  void _maybeFollow(GpsReading reading) {
    if (!_followingUser) return;
    _mapController.move(reading.latLng, _mapController.camera.zoom);
  }

  void _centerOnMe() {
    final reading = ref.read(currentReadingProvider).asData?.value;
    if (reading == null) {
      final state = ref.read(locationPermissionProvider);
      if (state != LocationPermissionState.ready) {
        unawaited(_showPermissionSheet());
      }
      return;
    }
    setState(() => _followingUser = true);
    _mapController.move(reading.latLng, 15);
  }

  /// Handle polyline tap from HistoryPolylineLayer.
  void _onTrackTap(HaulTrackRender track, Offset _) {
    setState(() => _activePopupTrack = track);
  }

  /// Dismiss the active track popup.
  void _dismissPopup() {
    setState(() => _activePopupTrack = null);
  }


  // Marker handlers
  // ---------------------------------------------------------------------

  /// Prompt to add a marker at the user's current GPS position.
  /// Requires a live fix — otherwise we'd drop a pin at (0,0).
  Future<void> _onAddMarkerPressed(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final reading = ref.read(currentReadingProvider).asData?.value;
    if (reading == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tunggu sinyal GPS dulu sebelum menandai lokasi.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final draft = await showDialog<AppMarker>(
      context: context,
      builder: (_) => AddMarkerDialog(
        latitude: reading.latLng.latitude,
        longitude: reading.latLng.longitude,
      ),
    );
    if (draft == null || !context.mounted) return;
    // AddMarkerDialog only builds a draft AppMarker — the caller is
    // responsible for persisting it through the repository.
    await ref.read(markerRepositoryProvider).create(
          name: draft.name,
          category: draft.category,
          latitude: draft.latitude,
          longitude: draft.longitude,
          notes: draft.notes,
        );
    if (!context.mounted) return;
    // Auto-enable the overlay so the user immediately sees their pin.
    ref.read(markersOverlayEnabledProvider.notifier).state = true;
  }

  // ---------------------------------------------------------------------
  // Navigation handlers
  // ---------------------------------------------------------------------

  /// Long-press on the map -> open [LongPressMenu] at the tapped
  /// coordinate. The menu offers a shortcut to start go-to navigation
  /// to the coord or drop a marker there.
  Future<void> _onMapLongPress(LatLng point) async {
    await _haptic();
    if (!mounted) return;
    await LongPressMenu.show(
      context,
      coord: point,
      onNavigate: () {
        Navigator.of(context).pop();
        ref.read(navigationControllerProvider.notifier).startGoto(
              GotoTarget(position: point, label: 'Titik Peta'),
            );
      },
      onAddMarker: () async {
        Navigator.of(context).pop();
        // Pre-populate the AddMarker dialog at the long-pressed coord.
        final draft = await showDialog<AppMarker>(
          context: context,
          builder: (_) => AddMarkerDialog(
            latitude: point.latitude,
            longitude: point.longitude,
          ),
        );
        if (draft == null || !context.mounted) return;
        await ref.read(markerRepositoryProvider).create(
              name: draft.name,
              category: draft.category,
              latitude: draft.latitude,
              longitude: draft.longitude,
              notes: draft.notes,
            );
        if (!context.mounted) return;
        ref.read(markersOverlayEnabledProvider.notifier).state = true;
      },
    );
  }

  // ---------------------------------------------------------------------
  // Haul lifecycle handlers
  // ---------------------------------------------------------------------

  Future<void> _onStartHaulPressed() async {
    final permState = ref.read(locationPermissionProvider);
    if (permState != LocationPermissionState.ready) {
      await _showPermissionSheet();
      return;
    }

    await _haptic();

    final profile = ref.read(userProfileProvider).asData?.value;
    final width = profile?.trawlWidthMeters ?? 20.0;

    await ref
        .read(trackingControllerProvider.notifier)
        .startHaul(trawlWidthMeters: width);
    if (!mounted) return;
    setState(() => _followingUser = true);
  }

  Future<void> _onStopHaulPressed() async {
    await _haptic();
    final completion =
        await ref.read(trackingControllerProvider.notifier).stopHaul();
    if (!mounted || completion == null) return;

    final action = await HaulSummarySheet.show(context, completion);
    if (!mounted) return;

    switch (action) {
      case HaulSummaryAction.endTrip:
        // Dialog already renamed the trip; now actually finalise it.
        // Pass `forceTripId` directly off the just-completed haul so
        // the end survives even if activeTrip already cleared during
        // stopHaul() above.
        await ref
            .read(trackingControllerProvider.notifier)
            .endTrip(forceTripId: completion.haul.tripId);
      case HaulSummaryAction.savedAndOpenLogBook:
        // Edits were persisted inside the sheet before pop. Now push
        // the log-book form for this haul so the user can fill it in
        // one flow.
        if (context.mounted) {
          context.push(AppRoutes.logBookForHaul(completion.haul.id));
        }
      case HaulSummaryAction.saved:
        // Stay idle. User taps MULAI TEBAR again from the bottom panel
        // if they want another haul in the same trip.
        break;
      case HaulSummaryAction.dismissed:
        break;
    }
  }

  Future<void> _showRecoveryDialog(Haul orphan) async {
    final text = context.text;
    final tokens = context.tokens;

    final resume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: tokens.surface3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
        icon: Icon(PhosphorIconsFill.warningCircle,
            color: tokens.warning, size: 36),
        title: Text('Tarikan Belum Selesai', style: text.titleLarge),
        content: Text(
          '${orphan.displayName()} masih tercatat sedang merekam. '
          'Anda bisa melanjutkan tracking atau menutup tarikan dengan data '
          'yang sudah terkumpul.',
          style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'Akhiri sekarang',
              style: text.labelMedium?.copyWith(color: tokens.danger),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text('Lanjutkan',
                style: text.labelMedium?.copyWith(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ],
      ),
    );

    if (!mounted) return;
    final controller = ref.read(trackingControllerProvider.notifier);
    if (resume == true) {
      await controller.resumeHaul(orphan);
    } else {
      final completion = await controller.finalizeRecoveredHaul(orphan);
      if (!mounted || completion == null) return;
      await HaulSummarySheet.show(context, completion);
    }
  }

  Future<void> _haptic() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // no-op — test env has no platform channel.
    }
  }

  // ---------------------------------------------------------------------
  // Overlay helpers
  // ---------------------------------------------------------------------

  /// Resolve the pinned overlay's render provider (if any). Returns null
  /// for [MapOverlayNone], keeping the rest of the build call simple.
  ///
  /// This only covers the SINGLE-slot pinned overlay. The independent
  /// all-history footprints layer is resolved separately in [build] via
  /// [allHistoryVisibleProvider] + [allHistoryRenderProvider].
  AsyncValue<HistoryOverlayRender>? _watchOverlayRender(
    MapOverlayMode mode,
  ) {
    return switch (mode) {
      MapOverlayNone() => null,
      MapOverlaySingleTrip(tripId: final id) =>
        ref.watch(tripRenderProvider(id)),
      MapOverlaySingleHaul(haulId: final id) =>
        ref.watch(haulRenderProvider(id)),
    };
  }

  Object _overlayKey(MapOverlayMode mode) => switch (mode) {
        MapOverlayNone() => 'none',
        MapOverlaySingleTrip(tripId: final id) => 'trip:$id',
        MapOverlaySingleHaul(haulId: final id) => 'haul:$id',
      };

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  /// Build the mode-appropriate bottom controls widget.
  ///
  /// Key on the [MapMode] value so [AnimatedSwitcher] detects swaps.
  Widget _buildModeControls({
    required MapMode mode,
    required bool isRecording,
    required TrackingState trackingState,
    required bool hasPermission,
    required bool hasFix,
    required NavigationActive? navActive,
    required bool allHistoryOn,
    required AsyncValue<HistoryOverlayRender>? allHistoryAsync,
  }) {
    // When navigating, the full NavigationPanel is at the top.
    // If also tracking, CollapsedTrackingMini is under NavPanel.
    // So the bottom should show either the old _ActionPanel or nothing.
    if (navActive != null) {
      // Navigating mode — bottom controls hidden (NavPanel is up top).
      // But if NOT recording, show the idle "start haul" CTA so the
      // user can begin tracking while navigating.
      if (!isRecording) {
        return _ActionPanel(
          key: const ValueKey(MapMode.navigating),
          isRecording: false,
          state: trackingState,
          onStart: _onStartHaulPressed,
          onStop: _onStopHaulPressed,
          onEndTrip: () =>
              ref.read(trackingControllerProvider.notifier).endTrip(),
          hasPermission: hasPermission,
          hasFix: hasFix,
        );
      }
      // Navigating + tracking: bottom is empty since
      // CollapsedTrackingMini is shown under NavPanel at top.
      return SizedBox.shrink(key: const ValueKey('nav-tracking'));
    }

    return switch (mode) {
      MapMode.idle => _ActionPanel(
        key: const ValueKey(MapMode.idle),
        isRecording: false,
        state: trackingState,
        onStart: _onStartHaulPressed,
        onStop: _onStopHaulPressed,
        onEndTrip: () =>
            ref.read(trackingControllerProvider.notifier).endTrip(),
        hasPermission: hasPermission,
        hasFix: hasFix,
      ),
      MapMode.tracking => TrackingBottomSheet(
        key: const ValueKey(MapMode.tracking),
        onStopPressed: _onStopHaulPressed,
      ),
      MapMode.viewingHistory => HistoryOverlayControls(
        key: const ValueKey(MapMode.viewingHistory),
        cameraController: _cameraController,
      ),
      MapMode.navigating => const SizedBox.shrink(
        key: ValueKey('nav-fallback'),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<GpsReading>>(currentReadingProvider, (_, next) {
      next.whenData(_maybeFollow);
    });

    final reading = ref.watch(currentReadingProvider).asData?.value;
    final permState = ref.watch(locationPermissionProvider);
    final hasPermission = permState == LocationPermissionState.ready;
    final trackingState = ref.watch(trackingControllerProvider);
    final isRecording = trackingState.isRecording;
    final mode = ref.watch(mapModeProvider);

    // Navigation overlay state -- drives the top-of-map panel, the
    // dashed go-to polyline, and the bearing arrow on the boat marker.
    // Idle when the user has not picked a target.
    final navState = ref.watch(navigationControllerProvider);
    final navActive = navState is NavigationActive ? navState : null;
    final navArrived =
        navActive?.alarmState == NavigationAlarmState.arrived;

    final overlayMode = ref.watch(mapOverlayControllerProvider);
    final overlayAsync = _watchOverlayRender(overlayMode);
    final overlayActive = overlayMode is! MapOverlayNone;

    // All-history footprints toggle — independent from the pinned
    // overlay above. When ON we also watch the all-history render
    // provider so its polylines can be merged into the layer below.
    // When OFF we deliberately do NOT watch the provider so it
    // auto-disposes and frees memory on devices with hundreds of
    // completed hauls.
    final allHistoryOn = ref.watch(allHistoryVisibleProvider);
    final allHistoryAsync =
        allHistoryOn ? ref.watch(allHistoryRenderProvider) : null;

    // User-placed markers overlay (persistent toggle, see
    // markersOverlayEnabledProvider).
    final markersOn = ref.watch(markersOverlayEnabledProvider);
    final markersAsync =
        markersOn ? ref.watch(allMarkersProvider) : null;

    // Camera controller lifecycle — use ref.listen so activate/deactivate
    // fire ONLY on state transitions, not every rebuild. This prevents
    // the snap-back bug where activate() reset _userLatched on every
    // frame, making zoom/pan impossible while history was active.
    ref.listen<MapOverlayMode>(mapOverlayControllerProvider, (prev, next) {
      if (next is! MapOverlayNone) {
        _cameraController.activate(_overlayKey(next));
      } else if (prev is! MapOverlayNone) {
        _cameraController.deactivate();
      }
    });
    ref.listen<bool>(allHistoryVisibleProvider, (prev, next) {
      // Only manage camera when no pinned overlay is active (pinned wins).
      if (overlayActive) return;
      if (prev == false && next == true) {
        _cameraController.activate('all-history:on');
      } else if (prev == true && next == false) {
        _cameraController.deactivate();
      }
    });

    // Auto-zoom via MapCameraController — maybeInitialFit is gated by the
    // internal latch so it only fires once per activation cycle. Calling it
    // here on every data-ready build is safe: the latch no-ops after the
    // first successful fit, and user gestures suppress it permanently.
    if (overlayActive && overlayAsync != null) {
      overlayAsync.whenData((render) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || render.bounds == null) return;
          _cameraController.maybeInitialFit(render.bounds!);
        });
      });
    } else if (allHistoryOn && allHistoryAsync != null) {
      allHistoryAsync.whenData((render) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || render.bounds == null) return;
          _cameraController.maybeInitialFit(render.bounds!);
        });
      });
    }

    // Compose polyline layers using HistoryPolylineLayer for tap detection.
    // All-history is the background layer, pinned overlay is the focused layer.
    final allHistoryTracks = allHistoryOn
        ? (allHistoryAsync?.asData?.value.tracks ?? const <HaulTrackRender>[])
        : const <HaulTrackRender>[];
    final pinnedTracks = overlayAsync != null
        ? (overlayAsync.asData?.value.tracks ?? const <HaulTrackRender>[])
        : const <HaulTrackRender>[];

    return AmbientBackground(
      showBlobs: false,
      child: SafeArea(
        // `bottom: true` uses the padding injected by AppShell
        // (MediaQuery.padding.bottom = navClearance). Every positioned
        // child below therefore measures `bottom: 0` as "flush with
        // the top of the floating nav", not "under it". That's why
        // the action panel can say `bottom: AppSizes.sp4` below
        // instead of the old brittle `bottom: 100`.
        bottom: true,
        child: Stack(
          children: [
            // --- Map ---
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: reading?.latLng ?? _initialCenter,
                  initialZoom: _initialZoom,
                  minZoom: 3,
                  // z=20 is beyond OSM native tiles (z=19 max — see
                  // maxNativeZoom on the TileLayer below), so the last
                  // level overzooms / stretches the z=19 tile. Users
                  // in port asked for this: at z=19 a whole pier fits
                  // in one tile, they want to resolve individual boat
                  // slips. Visual fuzziness at z=20 is acceptable
                  // compared to the alternative of clamping the view.
                  maxZoom: 20,
                  onPositionChanged: (pos, hasGesture) {
                    final z = pos.zoom;
                    final wasShowing =
                        _currentZoom >= MarkerPin.labelZoomThreshold;
                    final nowShowing =
                        z >= MarkerPin.labelZoomThreshold;
                    if (wasShowing != nowShowing) {
                      setState(() => _currentZoom = z);
                    } else {
                      _currentZoom = z;
                    }
                    if (hasGesture) {
                      _cameraController.onUserGesture();
                      if (_followingUser) {
                        setState(() => _followingUser = false);
                      }
                    }
                  },
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  // Long-press anywhere on the map opens the LongPressMenu
                  // with two primary actions: start navigation to the
                  // tapped coord, or drop a marker there.
                  onLongPress: (_, latLng) => _onMapLongPress(latLng),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'id.co.langgengsea',
                    maxNativeZoom: 19,
                    retinaMode: RetinaMode.isHighDensity(context),
                    tileProvider: ref
                        .read(tileCacheServiceProvider)
                        .cachedTileProvider(
                          userAgentPackageName: 'id.co.langgengsea',
                        ),
                  ),
                  TileLayer(
                    urlTemplate:
                        'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png',
                    userAgentPackageName: 'id.co.langgengsea',
                  ),
                  if (allHistoryTracks.isNotEmpty)
                    HistoryPolylineLayer(
                      tracks: allHistoryTracks,
                      onTrackTap: _onTrackTap,
                      isBackground: true,
                    ),
                  if (pinnedTracks.isNotEmpty)
                    HistoryPolylineLayer(
                      tracks: pinnedTracks,
                      onTrackTap: _onTrackTap,
                      isBackground: false,
                    ),
                  // Active haul polyline (empty layer when not recording).
                  const ActiveHaulPolyline(),
                  // Navigation layers -- dashed go-to line to the
                  // active target, or solid reference polyline +
                  // start/end dots for follow-track. Returns empty
                  // when nav is idle so this spread is always safe.
                  if (navActive != null)
                    ...NavigationPolyline.buildLayers(
                      context,
                      ref,
                      navActive,
                    ),
                  // User-placed markers — toggled by the pin icon in
                  // the top-right column. Rendered ABOVE the history
                  // polyline overlay but BELOW the boat marker so the
                  // live position never disappears under a pin.
                  if (markersOn)
                    MarkerLayer(
                      // Name labels auto-show once the user zooms in
                      // past MarkerPin.labelZoomThreshold (currently
                      // z=14) and auto-hide again when they zoom out.
                      // MarkerPin.markerSize / markerAlignment MUST be
                      // called with the SAME showLabel flag — both
                      // helpers are stamped here once so the values
                      // can't drift.
                      markers: () {
                        final showLabel =
                            _currentZoom >= MarkerPin.labelZoomThreshold;
                        final size =
                            MarkerPin.markerSize(showLabel: showLabel);
                        final alignment = MarkerPin.markerAlignment(
                          showLabel: showLabel,
                        );
                        return (markersAsync?.asData?.value ?? const [])
                            .map(
                              (m) => Marker(
                                point: m.latLng,
                                width: size.width,
                                height: size.height,
                                alignment: alignment,
                                child: MarkerPin(
                                  marker: m,
                                  showLabel: showLabel,
                                  onTap: () =>
                                      MarkerInfoSheet.show(context, m),
                                ),
                              ),
                            )
                            .toList();
                      }(),
                    ),
                  if (reading != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: reading.latLng,
                          // Enlarged from 64 to 96 so the navigation
                          // bearing arrow (orbits at r=26 around the
                          // boat centre) doesn't clip on the edges.
                          width: 96,
                          height: 96,
                          alignment: Alignment.center,
                          child: BoatMarker(
                            reading: reading,
                            isTracking: isRecording,
                            bearingToTarget:
                                navActive?.progress.bearingDegrees,
                            navArrived: navArrived,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // --- Top panel (mode-aware) ---
            Positioned(
              top: AppSizes.sp3,
              left: AppSizes.sp4,
              right: AppSizes.sp4,
              child: Column(
                children: [
                  isRecording ? const RecordingBanner() : _IdleAppBar(),
                  if (overlayActive && overlayAsync != null) ...[
                    const SizedBox(height: AppSizes.sp2),
                    _OverlayContextChip(
                      mode: overlayMode,
                      async: overlayAsync,
                      onClear: () => ref
                          .read(mapOverlayControllerProvider.notifier)
                          .clear(),
                    ),
                  ],
                  // Navigation panel sits under the top banner whenever
                  // a target is active -- it does NOT replace the
                  // recording banner / app bar because the user may be
                  // navigating AND recording simultaneously (spec M.5).
                  if (navActive != null) ...[
                    const SizedBox(height: AppSizes.sp2),
                    NavigationPanel(
                      state: navActive,
                      onStop: () => ref
                          .read(navigationControllerProvider.notifier)
                          .stop(),
                    ),
                    // Collapsed tracking mini-banner for concurrent
                    // navigating + tracking (Requirement 4.12).
                    if (isRecording) ...[
                      const SizedBox(height: AppSizes.sp2),
                      CollapsedTrackingMini(
                        onStop: _onStopHaulPressed,
                      ),
                    ],
                  ],
                ],
              ),
            ),

            // --- Live stats (only while recording and nav NOT active) ---
            if (isRecording && navActive == null)
              const Positioned(
                top: 80,
                left: AppSizes.sp4,
                right: AppSizes.sp4,
                child: LiveStatsPanel(),
              ),

            // --- GPS accuracy chip + toggles + overflow menu (top-right) ---
            Positioned(
              top: isRecording ? 170 : 100,
              right: AppSizes.sp5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const GpsAccuracyChip(),
                  const SizedBox(height: AppSizes.sp2),
                  _AllHistoryToggle(
                    on: allHistoryOn,
                    onTap: () {
                      final notifier =
                          ref.read(allHistoryVisibleProvider.notifier);
                      notifier.state = !notifier.state;
                    },
                  ),
                  const SizedBox(height: AppSizes.sp2),
                  _MarkersToggle(
                    on: markersOn,
                    onTap: () {
                      final notifier =
                          ref.read(markersOverlayEnabledProvider.notifier);
                      notifier.state = !notifier.state;
                    },
                  ),
                  const SizedBox(height: AppSizes.sp2),
                  // Three-dot overflow menu (Requirement 4.10) — always
                  // visible regardless of mode, adapts entries internally.
                  MapOverflowMenu(
                    onAddMarkerHere: hasPermission
                        ? () => _onAddMarkerPressed(context, ref)
                        : null,
                    onFitAll: allHistoryOn
                        ? () {
                            final bounds = allHistoryAsync
                                ?.asData?.value.bounds;
                            if (bounds != null) {
                              _cameraController.fitCameraExplicit(bounds);
                            }
                          }
                        : null,
                  ),
                ],
              ),
            ),

            // --- Map controls ---
            Positioned(
              right: AppSizes.sp4,
              bottom: 220,
              child: MapControls(
                onCenterOnMe: _centerOnMe,
                centerEnabled: hasPermission,
              ),
            ),

            // --- Add-marker FAB (left side, sejajar MapControls) ---
            Positioned(
              left: AppSizes.sp4,
              bottom: 220,
              child: _AddMarkerButton(
                onTap: () => _onAddMarkerPressed(context, ref),
                enabled: hasPermission,
              ),
            ),

            // --- Attribution ---
            const Positioned(
              left: AppSizes.sp4,
              bottom: 280,
              child: MapAttribution(),
            ),

            // --- Bottom action panel (mode-driven via AnimatedSwitcher) ---
            Positioned(
              left: AppSizes.sp4,
              right: AppSizes.sp4,
              bottom: AppSizes.sp4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Background tracking degradation warning
                  if (isRecording && trackingState.backgroundDegraded)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.sp2),
                      child: GlassCard(
                        level: GlassLevel.level1,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.sp3,
                          vertical: AppSizes.sp2,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              PhosphorIconsFill.warning,
                              size: 16,
                              color: context.tokens.warning,
                            ),
                            const SizedBox(width: AppSizes.sp2),
                            Expanded(
                              child: Text(
                                trackingState.backgroundStatus ==
                                        BackgroundTrackingStatus.restarting
                                    ? 'Background GPS restarting…'
                                    : 'Background GPS gagal. Tetap merekam di foreground.',
                                style: context.text.bodySmall?.copyWith(
                                  color: context.tokens.warning,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const GpsErrorBanner(),
                  const SizedBox(height: AppSizes.sp2),
                  // Mode-driven bottom controls (Task 9.6)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _buildModeControls(
                      mode: mode,
                      isRecording: isRecording,
                      trackingState: trackingState,
                      hasPermission: hasPermission,
                      hasFix: reading != null,
                      navActive: navActive,
                      allHistoryOn: allHistoryOn,
                      allHistoryAsync: allHistoryAsync,
                    ),
                  ),
                ],
              ),
            ),

            // --- Track popup (shown when a polyline track is tapped) ---
            if (_activePopupTrack != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 120,
                left: AppSizes.sp4,
                right: AppSizes.sp4,
                child: Center(
                  child: TrackPopup(
                    track: _activePopupTrack!,
                    storedName: _activePopupTrack!.storedName,
                    startedAt: _activePopupTrack!.startedAt,
                    kind: TrackKind.haul,
                    onClose: _dismissPopup,
                    onNavigate: () {
                      final track = _activePopupTrack!;
                      _dismissPopup();
                      ref
                          .read(navigationControllerProvider.notifier)
                          .startFollowTrack(
                            FollowTrackTarget(
                              pathPoints: track.points,
                              label: track.storedName ??
                                  Formatters.shortDate(track.startedAt),
                              sourceType: FollowTrackSource.haul,
                              sourceId: track.haulId,
                            ),
                          );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// All-history footprints toggle (sits right under the GPS accuracy chip)
// ===========================================================================

class _AllHistoryToggle extends StatelessWidget {
  const _AllHistoryToggle({required this.on, required this.onTap});

  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = on ? context.colors.primary : tokens.textTertiary;
    return Semantics(
      label: on ? 'Sembunyikan jejak riwayat' : 'Tampilkan semua riwayat',
      button: true,
      toggled: on,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.surface3,
              shape: BoxShape.circle,
              border: Border.all(color: tokens.borderStrong),
              boxShadow: [
                BoxShadow(
                  color: tokens.shadowMd,
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              on
                  ? PhosphorIconsFill.footprints
                  : PhosphorIconsRegular.footprints,
              color: color,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Markers toggle (sits below the All-History toggle)
// ===========================================================================

class _MarkersToggle extends StatelessWidget {
  const _MarkersToggle({required this.on, required this.onTap});

  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = on ? context.colors.primary : tokens.textTertiary;
    return Semantics(
      label: on ? 'Sembunyikan penanda' : 'Tampilkan penanda',
      button: true,
      toggled: on,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.surface3,
              shape: BoxShape.circle,
              border: Border.all(color: tokens.borderStrong),
              boxShadow: [
                BoxShadow(
                  color: tokens.shadowMd,
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              on ? PhosphorIconsFill.mapPin : PhosphorIconsRegular.mapPin,
              color: color,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Add-marker FAB (mirrors MapControls' center-on-me button on the left)
// ===========================================================================

class _AddMarkerButton extends StatelessWidget {
  const _AddMarkerButton({required this.onTap, required this.enabled});

  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      label: 'Tambah penanda di posisi saat ini',
      button: true,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          child: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.surface3,
              shape: BoxShape.circle,
              border: Border.all(color: tokens.borderStrong),
              boxShadow: [
                BoxShadow(
                  color: tokens.shadowMd,
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              PhosphorIconsBold.mapPinPlus,
              color: enabled
                  ? context.colors.primary
                  : tokens.textTertiary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Overlay context chip (top of the map while an overlay is active)
// ===========================================================================

class _OverlayContextChip extends ConsumerWidget {
  const _OverlayContextChip({
    required this.mode,
    required this.async,
    required this.onClear,
  });

  final MapOverlayMode mode;
  final AsyncValue<HistoryOverlayRender> async;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final text = context.text;

    final (label, subtitle) = _buildLabel(ref);

    return GlassCard(
      level: GlassLevel.level2,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sp3,
        vertical: AppSizes.sp2 + 2,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: tokens.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              PhosphorIconsFill.footprints,
              size: 16,
              color: context.colors.primary,
            ),
          ),
          const SizedBox(width: AppSizes.sp2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: text.titleSmall?.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: text.bodySmall?.copyWith(
                      color: tokens.textTertiary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            tooltip: 'Tutup overlay',
            icon: const Icon(PhosphorIconsRegular.x, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
        ],
      ),
    );
  }

  (String, String) _buildLabel(WidgetRef ref) {
    final render = async.asData?.value;
    final tripHeadCount = render?.sourceHaulCount ?? 0;

    switch (mode) {
      case MapOverlayNone():
        return ('', '');
      case MapOverlaySingleTrip(tripId: final id):
        final tripAsync = ref.watch(tripByIdProvider(id));
        final trip = tripAsync.asData?.value;
        final titleBase = _tripTitle(trip);
        final countLabel = render == null
            ? 'Memuat…'
            : '$tripHeadCount tarikan';
        return ('Trip: $titleBase', countLabel);
      case MapOverlaySingleHaul(haulId: final id):
        final haulAsync = ref.watch(haulByIdProvider(id));
        final haul = haulAsync.asData?.value;
        final title = haul == null
            ? 'Tarikan'
            : 'Tarikan #${haul.orderIndex}: ${haul.displayName()}';
        final subtitle = haul == null
            ? 'Memuat…'
            : Formatters.sectionDate(haul.startedAt);
        return (title, subtitle);
    }
  }

  String _tripTitle(Trip? trip) {
    if (trip == null) return '…';
    if (trip.name != null && trip.name!.isNotEmpty) return trip.name!;
    return Formatters.sectionDate(trip.startedAt);
  }
}

// ===========================================================================
// Private UI pieces (idle app bar + action panel) — unchanged behaviour
// ===========================================================================

class _IdleAppBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final text = context.text;
    final trackingState = ref.watch(trackingControllerProvider);
    final profile = ref.watch(userProfileProvider).asData?.value;

    return GlassCard(
      level: GlassLevel.level2,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sp3,
        vertical: AppSizes.sp3,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: tokens.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: tokens.glowPrimary,
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              PhosphorIconsFill.sailboat,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSizes.sp3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profile?.vesselName ?? 'KM Belum Diisi',
                  style: text.titleSmall,
                ),
                Text(
                  profile == null
                      ? 'Isi profil di Pengaturan'
                      : profile.friendlyGreeting,
                  style: text.bodySmall?.copyWith(
                    color: tokens.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          StatusChip(
            label: trackingState.hasTrip
                ? AppStrings.tripActive
                : AppStrings.noTrip,
            variant: trackingState.hasTrip
                ? StatusVariant.success
                : StatusVariant.neutral,
            showDot: true,
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    super.key,
    required this.isRecording,
    required this.state,
    required this.onStart,
    required this.onStop,
    required this.onEndTrip,
    required this.hasPermission,
    required this.hasFix,
  });

  final bool isRecording;
  final TrackingState state;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final Future<void> Function() onEndTrip;
  final bool hasPermission;
  final bool hasFix;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;

    if (isRecording) {
      final haul = state.haul!;
      return GlassCard(
        level: GlassLevel.level2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${haul.displayName()} aktif',
                          style: text.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        'GPS sedang merekam jejak trawl',
                        style: text.bodySmall?.copyWith(
                          color: tokens.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sp3),
            Semantics(
              label: 'Berhenti merekam tarikan',
              button: true,
              child: PrimaryActionButton(
                label: AppStrings.stopTrawl,
                icon: PhosphorIconsFill.stopCircle,
                variant: ActionButtonVariant.danger,
                critical: true,
                onPressed: onStop,
              ),
            ),
          ],
        ),
      );
    }

    // Idle (possibly mid-trip).
    return GlassCard(
      level: GlassLevel.level2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.hasTrip ? 'Trip Berjalan' : AppStrings.readyToSail,
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(
                          state: state,
                          hasPermission: hasPermission,
                          hasFix: hasFix),
                      style: text.bodySmall?.copyWith(
                        color: tokens.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (state.hasTrip)
                TextButton(
                  onPressed: onEndTrip,
                  child: Text('Akhiri Trip',
                      style: text.labelMedium?.copyWith(
                        color: tokens.danger,
                        fontWeight: FontWeight.w700,
                      )),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.sp3),
          Semantics(
            label: 'Mulai merekam tarikan baru',
            button: true,
            child: PrimaryActionButton(
              label: AppStrings.startTrawl,
              icon: PhosphorIconsFill.playCircle,
              variant: ActionButtonVariant.success,
              critical: true,
              onPressed: onStart,
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle({
    required TrackingState state,
    required bool hasPermission,
    required bool hasFix,
  }) {
    if (!hasPermission) return 'Aktifkan lokasi untuk merekam';
    if (!hasFix) return 'Menunggu sinyal GPS…';
    if (state.hasTrip) return 'Tekan untuk tarikan berikutnya';
    return 'Siap rekam tarikan pertama';
  }
}
