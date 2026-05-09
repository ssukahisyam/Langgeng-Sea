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
import '../../../core/widgets/ambient_background.dart';
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
/// M1: flutter_map, OSM + OpenSeaMap, live boat marker.
/// M2: tombol Mulai Tebar / Angkat Trawl wired, live stats, polyline,
/// summary sheet, crash recovery dialog.
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

    // Haptic feedback (per design §7).
    await _haptic();

    // M8: read trawl width from the user profile (set during onboarding).
    // Fallback to 20m — matches the onboarding default and keeps tests
    // that bypass the profile working unchanged.
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
        // Stay idle with trip still active — user can tap again later.
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
    // Medium-impact haptic on start/stop haul — matches design §7.
    // Wrapped in try/catch because some test environments don't have a
    // platform channel attached.
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
    ref.listen<AsyncValue<GpsReading>>(currentReadingProvider, (_, next) {
      next.whenData(_maybeFollow);
    });

    final reading = ref.watch(currentReadingProvider).asData?.value;
    final permState = ref.watch(locationPermissionProvider);
    final hasPermission = permState == LocationPermissionState.ready;
    final trackingState = ref.watch(trackingControllerProvider);
    final isRecording = trackingState.isRecording;

    return AmbientBackground(
      showBlobs: false,
      child: SafeArea(
        bottom: false,
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
                    // Cache-first tile provider. Tiles the user has
                    // downloaded for offline use are served from disk;
                    // new tiles fall back to the network and also get
                    // cached for next time the user browses this area.
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
              child: isRecording
                  ? const RecordingBanner()
                  : _IdleAppBar(),
            ),

            // --- Live stats (only while recording) ---
            if (isRecording)
              const Positioned(
                top: 80,
                left: AppSizes.sp4,
                right: AppSizes.sp4,
                child: LiveStatsPanel(),
              ),

            // --- GPS accuracy chip ---
            Positioned(
              top: isRecording ? 170 : 100,
              right: AppSizes.sp5,
              child: const GpsAccuracyChip(),
            ),

            // --- Map controls ---
            Positioned(
              right: AppSizes.sp4,
              bottom: 260,
              child: MapControls(
                onCenterOnMe: _centerOnMe,
                centerEnabled: hasPermission,
              ),
            ),

            // --- Attribution ---
            const Positioned(
              left: AppSizes.sp4,
              bottom: 260,
              child: MapAttribution(),
            ),

            // --- Bottom action panel ---
            Positioned(
              left: AppSizes.sp4,
              right: AppSizes.sp4,
              bottom: 100,
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
// Private UI pieces
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
                      _subtitle(state: state, hasPermission: hasPermission, hasFix: hasFix),
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
