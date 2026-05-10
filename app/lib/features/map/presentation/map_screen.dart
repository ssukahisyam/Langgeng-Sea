import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show ServiceStatus;
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_strings.dart';
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
import '../../tracking/data/haul_repository.dart';
import '../../tracking/data/trip_repository.dart';
import '../../tracking/domain/entities/haul.dart';
import '../../tracking/domain/entities/trip.dart';
import '../../tracking/presentation/widgets/active_haul_polyline.dart';
import '../../tracking/presentation/widgets/haul_summary_sheet.dart';
import '../../tracking/presentation/widgets/live_stats_panel.dart';
import '../../tracking/presentation/widgets/recording_banner.dart';
import '../../offline_map/data/tile_cache_service.dart';
import '../../onboarding/data/user_profile_repository.dart';
import '../application/history_overlay_providers.dart';
import '../application/map_overlay_state.dart';
import 'providers/location_permission_provider.dart';
import 'widgets/boat_marker.dart';
import 'widgets/gps_accuracy_chip.dart';
import 'widgets/gps_error_banner.dart';
import 'widgets/location_permission_sheet.dart';
import 'widgets/map_attribution.dart';
import 'widgets/map_controls.dart';

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
  bool _followingUser = true;
  bool _checkedRecovery = false;

  // Tracks the overlay whose bounds we already fitted the camera to, so
  // pulling to refresh doesn't keep snapping the user's view.
  Object? _fittedOverlayKey;

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
        await ref.read(trackingControllerProvider.notifier).endTrip();
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

  /// Resolve the current overlay's render provider (if any). Returns null
  /// for [MapOverlayNone], keeping the rest of the build call simple.
  AsyncValue<HistoryOverlayRender>? _watchOverlayRender(
    MapOverlayMode mode,
  ) {
    return switch (mode) {
      MapOverlayNone() => null,
      MapOverlayAllHistory() => ref.watch(allHistoryRenderProvider),
      MapOverlaySingleTrip(tripId: final id) =>
        ref.watch(tripRenderProvider(id)),
      MapOverlaySingleHaul(haulId: final id) =>
        ref.watch(haulRenderProvider(id)),
    };
  }

  void _fitOverlayBounds(MapOverlayMode mode, HistoryOverlayRender render) {
    if (render.bounds == null) return;
    final key = _overlayKey(mode);
    if (_fittedOverlayKey == key) return;
    _fittedOverlayKey = key;
    _followingUser = false;
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: render.bounds!,
        padding: const EdgeInsets.all(64),
      ),
    );
  }

  Object _overlayKey(MapOverlayMode mode) => switch (mode) {
        MapOverlayNone() => 'none',
        MapOverlayAllHistory() => 'all',
        MapOverlaySingleTrip(tripId: final id) => 'trip:$id',
        MapOverlaySingleHaul(haulId: final id) => 'haul:$id',
      };

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

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

    final overlayMode = ref.watch(mapOverlayControllerProvider);
    final overlayAsync = _watchOverlayRender(overlayMode);
    final overlayActive = overlayMode is! MapOverlayNone;

    // Reset remembered fit when overlay is cleared so the next enable
    // will re-fit.
    if (!overlayActive) {
      _fittedOverlayKey = null;
    }

    // Auto-zoom on new overlay data.
    overlayAsync?.whenData((render) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fitOverlayBounds(overlayMode, render);
      });
    });

    final overlayPolylines = <Polyline>[];
    if (overlayAsync != null) {
      final tracks = overlayAsync.asData?.value.tracks ?? const [];
      for (final t in tracks) {
        final color = AppColors.resolveHaulColor(
          colorValue: t.colorValue,
          orderIndex: t.orderIndex,
        );
        overlayPolylines.add(
          Polyline(
            points: t.points,
            strokeWidth: 4,
            color: color.withValues(alpha: 0.4),
            borderStrokeWidth: 0.6,
            borderColor: Colors.white.withValues(alpha: 0.35),
          ),
        );
      }
    }

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
                  maxZoom: 18,
                  onPositionChanged: (pos, hasGesture) {
                    if (hasGesture && _followingUser) {
                      setState(() => _followingUser = false);
                    }
                  },
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
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
                  if (overlayPolylines.isNotEmpty)
                    PolylineLayer<Object>(polylines: overlayPolylines),
                  // Active haul polyline (empty layer when not recording).
                  const ActiveHaulPolyline(),
                  if (reading != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: reading.latLng,
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          child: BoatMarker(
                            reading: reading,
                            isTracking: isRecording,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // --- Top panel (swaps between vessel info and recording banner) ---
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
                ],
              ),
            ),

            // --- Live stats (only while recording) ---
            if (isRecording)
              const Positioned(
                top: 80,
                left: AppSizes.sp4,
                right: AppSizes.sp4,
                child: LiveStatsPanel(),
              ),

            // --- GPS accuracy chip + Footprints toggle (top-right column) ---
            Positioned(
              top: isRecording ? 170 : 100,
              right: AppSizes.sp5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const GpsAccuracyChip(),
                  const SizedBox(height: AppSizes.sp2),
                  _AllHistoryToggle(
                    on: overlayMode is MapOverlayAllHistory,
                    onTap: () => ref
                        .read(mapOverlayControllerProvider.notifier)
                        .toggleAllHistory(),
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

            // --- Attribution ---
            const Positioned(
              left: AppSizes.sp4,
              bottom: 200,
              child: MapAttribution(),
            ),

            // --- Bottom action panel ---
            Positioned(
              left: AppSizes.sp4,
              right: AppSizes.sp4,
              bottom: AppSizes.sp4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GpsErrorBanner(),
                  const SizedBox(height: AppSizes.sp2),
                  _ActionPanel(
                    isRecording: isRecording,
                    state: trackingState,
                    onStart: _onStartHaulPressed,
                    onStop: _onStopHaulPressed,
                    onEndTrip: () =>
                        ref.read(trackingControllerProvider.notifier).endTrip(),
                    hasPermission: hasPermission,
                    hasFix: reading != null,
                  ),
                ],
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
      case MapOverlayAllHistory():
        if (render == null) return ('Semua Riwayat', 'Memuat…');
        return (
          'Semua Riwayat',
          '$tripHeadCount tarikan selesai',
        );
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
