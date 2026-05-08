import 'package:flutter/material.dart';
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
import 'providers/location_permission_provider.dart';
import 'widgets/boat_marker.dart';
import 'widgets/gps_accuracy_chip.dart';
import 'widgets/gps_error_banner.dart';
import 'widgets/location_permission_sheet.dart';
import 'widgets/map_attribution.dart';
import 'widgets/map_controls.dart';

/// Home tab — map + live GPS position.
///
/// In M1 we wire flutter_map (OSM + OpenSeaMap) and the geolocator stream.
/// Tile caching & offline support arrives in M4; haul recording in M2.
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(locationPermissionProvider.notifier).check();
      if (!mounted) return;
      final state = ref.read(locationPermissionProvider);
      if (state != LocationPermissionState.ready &&
          state != LocationPermissionState.unknown) {
        // Surface the permission sheet on first load so user is guided.
        // We wait a frame so the bottom nav etc. are laid out.
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        await LocationPermissionSheet.show(context);
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Keep the camera over the user's position while [_followingUser] is on.
  void _maybeFollow(GpsReading reading) {
    if (!_followingUser) return;
    _mapController.move(reading.latLng, _mapController.camera.zoom);
  }

  void _centerOnMe() {
    final reading = ref.read(currentReadingProvider).asData?.value;
    if (reading == null) {
      // No fix yet — prompt permission flow if needed.
      final state = ref.read(locationPermissionProvider);
      if (state != LocationPermissionState.ready) {
        LocationPermissionSheet.show(context);
      }
      return;
    }
    setState(() => _followingUser = true);
    _mapController.move(reading.latLng, 15);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;

    // Watch the stream so UI rebuilds with each fix, and follow camera.
    ref.listen<AsyncValue<GpsReading>>(currentReadingProvider, (_, next) {
      next.whenData(_maybeFollow);
    });

    final reading = ref.watch(currentReadingProvider).asData?.value;
    final permState = ref.watch(locationPermissionProvider);
    final hasPermission = permState == LocationPermissionState.ready;

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
                    // User dragged — stop auto-following.
                    if (hasGesture && _followingUser) {
                      setState(() => _followingUser = false);
                    }
                  },
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all &
                        ~InteractiveFlag.rotate, // disable rotate for MVP
                  ),
                ),
                children: [
                  // OpenStreetMap base layer. Per OSMF tile usage policy we
                  // declare a User-Agent identifying this app.
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'id.co.langgengsea',
                    maxNativeZoom: 19,
                    retinaMode: RetinaMode.isHighDensity(context),
                  ),
                  // OpenSeaMap nautical overlay.
                  TileLayer(
                    urlTemplate:
                        'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png',
                    userAgentPackageName: 'id.co.langgengsea',
                    backgroundColor: Colors.transparent,
                  ),
                  if (reading != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: reading.latLng,
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          child: BoatMarker(reading: reading),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // --- Top app bar ---
            Positioned(
              top: AppSizes.sp3,
              left: AppSizes.sp4,
              right: AppSizes.sp4,
              child: GlassCard(
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
                            'KM Belum Diisi',
                            style: text.titleSmall,
                          ),
                          Text(
                            'Isi profil di Pengaturan',
                            style: text.bodySmall?.copyWith(
                              color: tokens.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const StatusChip(
                      label: AppStrings.noTrip,
                      variant: StatusVariant.neutral,
                      showDot: true,
                    ),
                  ],
                ),
              ),
            ),

            // --- GPS accuracy chip ---
            const Positioned(
              top: 100,
              right: AppSizes.sp5,
              child: GpsAccuracyChip(),
            ),

            // --- Map controls (center on me) ---
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
                  GlassCard(
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
                                    AppStrings.readyToSail,
                                    style: text.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    hasPermission && reading != null
                                        ? 'GPS aktif • Siap melaut'
                                        : 'Perekaman haul akan tersedia di M2',
                                    style: text.bodySmall?.copyWith(
                                      color: tokens.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _showMvpInfo(context),
                              icon: const Icon(PhosphorIconsRegular.info),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.sp3),
                        PrimaryActionButton(
                          label: AppStrings.startTrawl,
                          icon: PhosphorIconsFill.playCircle,
                          variant: ActionButtonVariant.success,
                          critical: true,
                          onPressed: () => _showMvpInfo(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMvpInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MvpInfoSheet(),
    );
  }
}

class _MvpInfoSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.all(AppSizes.sp4),
      child: GlassCard(
        level: GlassLevel.level3,
        borderRadius: BorderRadius.circular(AppSizes.radius2xl),
        padding: const EdgeInsets.all(AppSizes.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSizes.sp5),
            Icon(
              PhosphorIconsFill.wrench,
              size: 48,
              color: context.colors.primary,
            ),
            const SizedBox(height: AppSizes.sp3),
            Text('Sedang Dibangun', style: text.headlineSmall),
            const SizedBox(height: AppSizes.sp2),
            Text(
              'Perekaman haul (tombol Mulai/Angkat Trawl) akan tersedia di '
              'milestone M2. M1 ini mengaktifkan peta & posisi GPS real-time.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: AppSizes.sp5),
            PrimaryActionButton(
              label: 'Mengerti',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
