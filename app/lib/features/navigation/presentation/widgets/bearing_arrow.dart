import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_theme.dart';

/// Small arrow overlay composed on top of the BoatMarker when a
/// navigation target is active.
///
/// The arrow rotates to the compass bearing of the target (pointing
/// from the boat to where the user needs to go). Rendered in a colour
/// distinct from the boat marker itself so "what the boat is doing"
/// (heading -- inside BoatMarker) and "what the user should do"
/// (bearing to target -- here) never blur together.
///
/// Sized small enough to sit *around* the boat marker without
/// occluding the live GPS position. Parents typically stack it in an
/// [Align] or [Stack] child slot with `alignment: Alignment.center`
/// alongside the BoatMarker body.
class BearingArrow extends StatelessWidget {
  const BearingArrow({
    super.key,
    required this.bearingDegrees,
    this.size = 16,
    this.orbitRadius = 26,
    this.arrived = false,
  });

  /// Compass bearing 0..360 -- 0 = north, 90 = east.
  final double bearingDegrees;

  /// Pixel size of the arrow glyph.
  final double size;

  /// Distance in pixels from the boat centre at which the arrow sits.
  /// The arrow appears to orbit the boat pointing outward along the
  /// bearing direction.
  final double orbitRadius;

  /// When true, render in success colour + static (not rotating) as a
  /// "you are here" indicator. Exposed for the NavigationController
  /// arrived state even though map_screen currently swaps the panel.
  final bool arrived;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    // Convert compass bearing to radians. In screen space, 0 rad
    // points up (north) after the -pi/2 offset we fold into the
    // cos/sin below.
    final rad = (bearingDegrees % 360) * math.pi / 180.0;
    // Offset from boat centre: x = sin(rad)*radius, y = -cos(rad)*radius
    // (y flipped because screen y grows downward).
    final dx = math.sin(rad) * orbitRadius;
    final dy = -math.cos(rad) * orbitRadius;

    final colour = arrived ? tokens.success : context.colors.primary;

    return IgnorePointer(
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Transform.rotate(
          angle: rad,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colour,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: colour.withValues(alpha: 0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              PhosphorIconsFill.caretUp,
              color: Colors.white,
              size: size * 0.7,
            ),
          ),
        ),
      ),
    );
  }
}
