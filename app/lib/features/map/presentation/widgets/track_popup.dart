import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../application/history_overlay_providers.dart';
import 'track_display_label.dart';

/// Differentiates between a Haul track (a single net pull) and a Trip
/// track (a full fishing trip) for the popup header chip and label copy.
enum TrackKind { haul, trip }

/// Contextual info-card shown above the map when the user taps a
/// history Polyline (or its start point).
///
/// Layout follows the Clean Liquid Glass info-sheet pattern used for
/// markers, but compacted to float over the map:
///
///   • Max width ~320 logical px so it still fits on small phones in
///     landscape without colliding with the opposite edge.
///   • Header uses [trackDisplayLabel] (user-given name OR fallback
///     timestamp), bold, single line with ellipsis.
///   • A coloured swatch mirrors the polyline stroke colour resolved
///     via [AppColors.resolveHaulColor] so the user can visually link
///     this popup with the line they tapped (Requirement 3.6).
///   • Body rows show the kind ("Tarikan"/"Trip") with a Phosphor icon
///     and the formatted start timestamp in Indonesian.
///   • Close (X) top-right → [onClose]; primary "Navigasi ke sini" →
///     [onNavigate]. Neither callback is wired to business logic here;
///     the caller (MapScreen) owns navigation + overlay dismissal. See
///     tasks 8.4 (mount into MapScreen) and 8.5 (wire onNavigate to
///     NavigationController.startFollowTrack).
///
/// Indonesian UI copy per app-wide convention.
///
/// Validates Requirements 3.3, 3.3a, 3.4, 3.5, 3.7.
class TrackPopup extends StatelessWidget {
  const TrackPopup({
    super.key,
    required this.track,
    required this.storedName,
    required this.startedAt,
    required this.kind,
    required this.onClose,
    required this.onNavigate,
  });

  /// The rendered track this popup refers to — used for the colour
  /// swatch (resolveHaulColor) and kept around so callers can forward
  /// `track.points` into FollowTrack navigation without re-lookups.
  final HaulTrackRender track;

  /// User-assigned name for the Haul/Trip, if any. `null` or empty
  /// triggers the date-based fallback in [trackDisplayLabel] per
  /// Requirement 3.7.
  final String? storedName;

  /// Start timestamp of the track. Shown in the body and used by the
  /// fallback label when [storedName] is absent.
  final DateTime startedAt;

  /// Whether the track represents a Haul (tarikan jaring) or a full
  /// Trip. Drives the body icon + label copy.
  final TrackKind kind;

  /// Called when the user dismisses the popup via the (X) button.
  /// MapScreen clears its `_activePopup` slot in response.
  final VoidCallback onClose;

  /// Called when the user taps the "Navigasi ke sini" CTA. Wiring to
  /// NavigationController.startFollowTrack lives in task 8.5 — this
  /// widget just surfaces the intent.
  final VoidCallback onNavigate;

  /// Tight enough to read on small phones without stealing the whole
  /// map, wide enough to fit a two-line title + CTA comfortably.
  static const double _maxWidth = 320;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;

    final swatchColor = AppColors.resolveHaulColor(
      colorValue: track.colorValue,
      orderIndex: track.orderIndex,
    );

    final kindLabel = kind == TrackKind.haul ? 'Tarikan' : 'Trip';
    final kindIcon = kind == TrackKind.haul
        ? PhosphorIconsBold.path
        : PhosphorIconsBold.compass;

    // Format: "8 Mei 2026, 05:30" — Indonesian-friendly, matches the
    // section-header/wall-clock formatters already used elsewhere so
    // we avoid pulling in a locale-initialised intl setup just for one
    // popup (see Formatters doc).
    final startedAtLabel =
        '${Formatters.shortDate(startedAt)}, ${Formatters.wallClock(startedAt)}';

    final title = trackDisplayLabel(
      storedName: storedName,
      startedAt: startedAt,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxWidth),
      child: Material(
        elevation: 4,
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.sp4,
            AppSizes.sp3,
            AppSizes.sp2,
            AppSizes.sp4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row: colour swatch + title + close button.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Swatch mirrors the polyline stroke so the user can
                  // visually link popup → line.
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: swatchColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: tokens.border,
                        width: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.sp2),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  // Compact close target — still ≥ 40px tappable via
                  // IconButton's default constraints.
                  IconButton(
                    icon: const Icon(PhosphorIconsRegular.x, size: 18),
                    tooltip: 'Tutup',
                    onPressed: onClose,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.sp3),

              // Kind row — "Tarikan" / "Trip" with a themed icon.
              _InfoRow(
                icon: kindIcon,
                iconColor: swatchColor,
                label: kindLabel,
              ),
              const SizedBox(height: AppSizes.sp2),

              // Started at — shown even when `storedName` is present,
              // because the header may be a user-given name that
              // doesn't encode a date (Requirement 3.3).
              _InfoRow(
                icon: PhosphorIconsRegular.clock,
                iconColor: tokens.textTertiary,
                label: 'Dimulai $startedAtLabel',
              ),
              const SizedBox(height: AppSizes.sp4),

              // Primary CTA. ElevatedButton (Material 3) gives us a
              // clear affordance without the full-width critical styling
              // of PrimaryActionButton, which would dominate the popup.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onNavigate,
                  icon: const Icon(
                    PhosphorIconsBold.navigationArrow,
                    size: 18,
                  ),
                  label: const Text('Navigasi ke sini'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSizes.sp3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    textStyle: text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple icon + label line used inside [TrackPopup]. Kept private and
/// inline because it carries no behaviour; promoting it to a shared
/// widget would obscure the popup's visual layout for little gain.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;

    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: AppSizes.sp2),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(
              color: tokens.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
