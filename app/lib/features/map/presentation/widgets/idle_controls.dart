import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../../onboarding/data/user_profile_repository.dart';
import '../../../onboarding/domain/entities/user_profile.dart';
import '../../../tracking/application/tracking_controller.dart';
import '../../application/all_history_visible_provider.dart';

/// Idle-mode control cluster for `MapScreen`.
///
/// Rendered when `MapMode == idle` (Requirement 4.6): a primary CTA to
/// start a new haul, the History_Overlay (footprints) toggle, a layer
/// toggle, and a my-location shortcut.
///
/// This widget does NOT assume a particular parent Stack — it fills
/// its parent via `Stack(fit: StackFit.expand)` and positions each
/// control absolutely so it can be swapped in/out by `AnimatedSwitcher`
/// in task 9.6 without re-laying out siblings.
///
/// Keyboard / MapController-dependent behaviours (my-location,
/// layer cycling) are delegated to the host via callbacks because the
/// `MapController` instance lives in `MapScreen._MapScreenState`.
/// History_Overlay toggle and `startHaul` live entirely in Riverpod
/// and are handled inline.
class IdleControls extends ConsumerWidget {
  const IdleControls({
    super.key,
    required this.onLocateMe,
    required this.onToggleLayers,
    this.hasPermission = true,
  });

  /// Re-centre camera on the current GPS fix. The host owns
  /// `MapController`, so the actual move is done there.
  final VoidCallback onLocateMe;

  /// Cycle through the configured tile layer presets. Host-owned
  /// for the same reason as [onLocateMe]; a no-op is acceptable until
  /// the layer-cycling feature is wired.
  final VoidCallback onToggleLayers;

  /// When `false`, the start-tracking CTA and my-location button are
  /// disabled and the host is expected to surface its own permission
  /// flow (e.g. `LocationPermissionSheet`) on tap.
  final bool hasPermission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allHistoryOn = ref.watch(allHistoryVisibleProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Top-right control column: history overlay toggle, tile
        // layer cycle, and my-location shortcut. Mirrors the column
        // currently hosted inline in `MapScreen` so the visual
        // balance doesn't shift when this widget swaps in.
        Positioned(
          top: AppSizes.sp4,
          right: AppSizes.sp5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _CircleControlButton(
                icon: allHistoryOn
                    ? PhosphorIconsFill.footprints
                    : PhosphorIconsRegular.footprints,
                active: allHistoryOn,
                semanticsLabel: allHistoryOn
                    ? 'Sembunyikan jejak riwayat'
                    : 'Tampilkan semua riwayat',
                onTap: () {
                  final notifier =
                      ref.read(allHistoryVisibleProvider.notifier);
                  notifier.state = !notifier.state;
                },
              ),
              const SizedBox(height: AppSizes.sp2),
              _CircleControlButton(
                icon: PhosphorIconsRegular.stack,
                active: false,
                semanticsLabel: 'Ganti lapisan peta',
                onTap: onToggleLayers,
              ),
              const SizedBox(height: AppSizes.sp2),
              _CircleControlButton(
                icon: PhosphorIconsBold.navigationArrow,
                active: true,
                semanticsLabel: 'Ke posisi saya',
                onTap: hasPermission ? onLocateMe : null,
              ),
            ],
          ),
        ),

        // Bottom-anchored primary CTA: "Mulai tracking". Uses the
        // existing `PrimaryActionButton` idiom (gradient, glow,
        // critical touch target) rather than Material's stock
        // `FloatingActionButton` to match the rest of the app.
        Positioned(
          left: AppSizes.sp4,
          right: AppSizes.sp4,
          bottom: AppSizes.sp4,
          child: Semantics(
            label: 'Mulai merekam tarikan baru',
            button: true,
            enabled: hasPermission,
            child: PrimaryActionButton(
              label: 'Mulai tracking',
              icon: PhosphorIconsFill.playCircle,
              variant: ActionButtonVariant.success,
              critical: true,
              onPressed: hasPermission ? () => _startTracking(ref) : null,
            ),
          ),
        ),
      ],
    );
  }

  /// Kicks off a new haul via [TrackingController.startHaul], reading
  /// `trawlWidthMeters` from the stored user profile (falling back to
  /// the PRD default when the profile is not yet loaded). The host is
  /// expected to gate availability via [hasPermission] so we don't
  /// enter a haul while the GPS stack is not ready.
  Future<void> _startTracking(WidgetRef ref) async {
    final profile = ref.read(userProfileProvider).asData?.value;
    final width =
        profile?.trawlWidthMeters ?? UserProfile.defaultTrawlWidthMeters;
    await ref
        .read(trackingControllerProvider.notifier)
        .startHaul(trawlWidthMeters: width);
  }
}

/// Small circular icon button used in the top-right control column.
///
/// Mirrors the look of `_AllHistoryToggle` / `_MarkersToggle` in the
/// current `MapScreen` so the widget swap does not cause a visual
/// jump. `onTap == null` renders a disabled (greyed) variant.
class _CircleControlButton extends StatelessWidget {
  const _CircleControlButton({
    required this.icon,
    required this.active,
    required this.semanticsLabel,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final String semanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final enabled = onTap != null;
    final color = enabled
        ? (active ? context.colors.primary : tokens.textSecondary)
        : tokens.textTertiary;

    return Semantics(
      label: semanticsLabel,
      button: true,
      enabled: enabled,
      toggled: active,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
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
              child: Icon(icon, color: color, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
