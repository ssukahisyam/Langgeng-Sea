import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/gps_reading.dart';
import '../../../core/services/gps_service.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../../../core/widgets/status_chip.dart';
import '../../tracking/application/tracking_controller.dart';
import '../../tracking/application/tracking_state.dart';
import '../../tracking/domain/entities/haul.dart';
import '../../tracking/presentation/widgets/active_haul_polyline.dart';
import '../../tracking/presentation/widgets/haul_summary_sheet.dart';
import '../../tracking/presentation/widgets/live_stats_panel.dart';
import '../../tracking/presentation/widgets/recording_banner.dart';
import '../../offline_map/data/tile_cache_service.dart';
import '../../onboarding/data/user_profile_repository.dart';
import 'providers/location_permission_provider.dart';
import 'widgets/boat_marker.dart';
import 'widgets/gps_accuracy_chip.dart';
import 'widgets/gps_error_banner.dart';
import 'widgets/location_permission_sheet.dart';
import 'widgets/map_attribution.dart';
import 'widgets/map_controls.dart';

/// Home tab — map + live GPS position + haul recording controls.
///
/// PERFORMANCE NOTE: this widget is intentionally NOT a `Consumer` at
/// the top level. Watching `trackingControllerProvider` or
/// `currentReadingProvider` at the top would rebuild the entire Stack
/// (map tile layer + overlays + bottom panel) on every GPS fix — about
/// once per 1-2 seconds. That was the source of the app-wide lag.
///
/// Instead we do two things:
///   1. `ref.listen` on `currentReadingProvider` to drive camera follow
///      as a side-effect (no rebuild).
///   2. Push the provider `watch` calls down into tiny `Consumer`
///      widgets that wrap only the piece that depends on that state
///      (boat marker, polyline, GPS chip, action panel). Rebuilds stay
///      isolated to a few hundred Bytes of the widget tree.
///
/// The AmbientBackground wrapper is also intentionally removed — the
/// map tile layer IS the background; stacking a blur layer on top of
/// streaming tiles was killing the raster cache.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _initialCenter = LatLng(-7.25, 113.42); // Selat Madura
  static const _initialZoom = 9.0;

  final MapController _mapController = MapController();
  bool _followingUser = true;
  bool _checkedRecovery = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(locationPermissionProvider.notifier).check();
      if (!mounted) return;
      final permState = ref.read(locationPermissionProvider);
      if (permState != LocationPermissionState.ready &&
          permState != LocationPermissionState.unknown) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        await LocationPermissionSheet.show(context);
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
    _mapController.dispose();
    super.dispose();
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
        LocationPermissionSheet.show(context);
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
      await LocationPermissionSheet.show(context);
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
      case HaulSummaryAction.nextHaul:
        await _onStartHaulPressed();
      case HaulSummaryAction.endTrip:
        await ref.read(trackingControllerProvider.notifier).endTrip();
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
        title: Text('Haul Belum Selesai', style: text.titleLarge),
        content: Text(
          '${orphan.displayName()} masih tercatat sedang merekam. '
          'Anda bisa melanjutkan tracking atau menutup haul dengan data '
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
      // no-op
    }
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Side-effect only: follow the user's camera position. Does NOT
    // trigger rebuild of this widget.
    ref.listen<AsyncValue<GpsReading>>(currentReadingProvider, (_, next) {
      next.whenData(_maybeFollow);
    });

    // Bottom padding = safe area (gesture bar) + nav bar + breathing
    // room. This is what prevents the action panel from being hidden
    // behind the floating bottom-nav on tall phones like Redmi Note
    // 10 Pro with gesture navigation.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const kNavBarHeight = 72.0; // matches _NavButton size in AppShell
    const kGapFromNav = 16.0;
    final bottomSafe = bottomInset + kNavBarHeight + kGapFromNav;

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          // --- Map (fills background, tiles provide visual depth) ---
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialCenter,
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
                // Isolated consumer: rebuild only when livePoints grows.
                const _ActivePolylineIsolated(),
                // Isolated consumer: rebuild only when reading changes,
                // and wrapped in RepaintBoundary so the rest of the
                // FlutterMap child stack doesn't repaint.
                const _BoatMarkerIsolated(),
              ],
            ),
          ),

          // --- Top panel (swaps between vessel info and recording banner) ---
          Positioned(
            top: AppSizes.sp3,
            left: AppSizes.sp4,
            right: AppSizes.sp4,
            child: const _TopPanel(),
          ),

          // --- Live stats (only while recording, isolated consumer) ---
          const Positioned(
            top: 80,
            left: AppSizes.sp4,
            right: AppSizes.sp4,
            child: _LiveStatsIsolated(),
          ),

          // --- GPS accuracy chip ---
          const Positioned(
            top: 100,
            right: AppSizes.sp5,
            child: GpsAccuracyChip(),
          ),

          // --- Map controls (fab column) ---
          // Positioned above the action panel so they don't overlap.
          // 100 for action panel height + gap. RepaintBoundary isolates
          // the FAB repaint from the map tile rebuild.
          Positioned(
            right: AppSizes.sp4,
            bottom: bottomSafe + 140,
            child: RepaintBoundary(
              child: _MapControlsIsolated(onCenterOnMe: _centerOnMe),
            ),
          ),

          // --- Attribution (OSM + OpenSeaMap ToS requirement) ---
          Positioned(
            left: AppSizes.sp4,
            bottom: bottomSafe + 140,
            child: const MapAttribution(),
          ),

          // --- Bottom action panel ---
          // Sits above the nav bar with gesture-bar safe padding.
          Positioned(
            left: AppSizes.sp4,
            right: AppSizes.sp4,
            bottom: bottomSafe,
            child: const _BottomPanelIsolated(),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// Isolated consumer widgets. Each reads exactly the slice of state it
// needs, and its `build` fires only when THAT slice changes. This keeps
// rebuild costs flat as GPS fixes arrive at 1-2 Hz.
// =========================================================================

/// Rebuilds only when TrackingState.livePoints list identity changes.
class _ActivePolylineIsolated extends ConsumerWidget {
  const _ActivePolylineIsolated();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Single call still watches the whole state, but the widget is
    // tiny: Flutter's build only diffs the Polyline list, which
    // RenderFlutterMap already handles efficiently.
    return const ActiveHaulPolyline();
  }
}

/// Rebuilds only when GPS reading changes. Wrapped in RepaintBoundary
/// so its paint is cached when only the boat position micro-moves.
class _BoatMarkerIsolated extends ConsumerWidget {
  const _BoatMarkerIsolated();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reading = ref.watch(currentReadingProvider).asData?.value;
    final isRecording = ref
        .watch(trackingControllerProvider.select((s) => s.isRecording));
    if (reading == null) {
      return const MarkerLayer(markers: []);
    }
    return MarkerLayer(
      markers: [
        Marker(
          point: reading.latLng,
          width: 64,
          height: 64,
          alignment: Alignment.center,
          child: RepaintBoundary(
            child: BoatMarker(
              reading: reading,
              isTracking: isRecording,
            ),
          ),
        ),
      ],
    );
  }
}

/// Top panel — selects `isRecording` only, not the full state blob.
class _TopPanel extends ConsumerWidget {
  const _TopPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRecording = ref
        .watch(trackingControllerProvider.select((s) => s.isRecording));
    return isRecording ? const RecordingBanner() : const _IdleAppBar();
  }
}

/// Live stats only rendered when recording. Uses internal Consumer so
/// it's a single 1 Hz ticker when visible, zero work when not.
class _LiveStatsIsolated extends ConsumerWidget {
  const _LiveStatsIsolated();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRecording = ref
        .watch(trackingControllerProvider.select((s) => s.isRecording));
    if (!isRecording) return const SizedBox.shrink();
    return const LiveStatsPanel();
  }
}

/// Center-on-me FAB. Only rebuilds when permission state flips.
class _MapControlsIsolated extends ConsumerWidget {
  const _MapControlsIsolated({required this.onCenterOnMe});

  final VoidCallback onCenterOnMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermission = ref.watch(locationPermissionProvider) ==
        LocationPermissionState.ready;
    return MapControls(
      onCenterOnMe: onCenterOnMe,
      centerEnabled: hasPermission,
    );
  }
}

/// Bottom panel: error banner + action panel. Stateful wrapping because
/// the action handlers need access to `MapScreen`'s _onStart/_onStop.
class _BottomPanelIsolated extends ConsumerWidget {
  const _BottomPanelIsolated();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingState = ref.watch(trackingControllerProvider);
    final hasPermission = ref.watch(locationPermissionProvider) ==
        LocationPermissionState.ready;
    final hasFix = ref.watch(currentReadingProvider).asData?.value != null;

    // Walk up the widget tree to find _MapScreenState so we can call
    // the same handlers the old design used. This keeps the haul
    // lifecycle logic in one place (the stateful parent) while the
    // visual rebuild cost stays isolated here.
    final mapState = context.findAncestorStateOfType<_MapScreenState>();
    if (mapState == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const GpsErrorBanner(),
        const SizedBox(height: AppSizes.sp2),
        _ActionPanel(
          isRecording: trackingState.isRecording,
          state: trackingState,
          onStart: mapState._onStartHaulPressed,
          onStop: mapState._onStopHaulPressed,
          onEndTrip: () =>
              ref.read(trackingControllerProvider.notifier).endTrip(),
          hasPermission: hasPermission,
          hasFix: hasFix,
        ),
      ],
    );
  }
}

// =========================================================================
// Existing private widgets (unchanged behavior, preserved below)
// =========================================================================

class _IdleAppBar extends ConsumerWidget {
  const _IdleAppBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final text = context.text;
    final hasTrip = ref
        .watch(trackingControllerProvider.select((s) => s.hasTrip));
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
            label: hasTrip ? AppStrings.tripActive : AppStrings.noTrip,
            variant:
                hasTrip ? StatusVariant.success : StatusVariant.neutral,
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
              label: 'Angkat trawl, selesaikan rekam haul',
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
                        hasFix: hasFix,
                      ),
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
            label: 'Mulai tebar trawl, rekam haul baru',
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
    if (state.hasTrip) return 'Tekan untuk haul berikutnya';
    return 'Siap rekam haul pertama';
  }
}
