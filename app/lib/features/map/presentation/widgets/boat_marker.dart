import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/services/gps_reading.dart';
import '../../../../core/theme/app_theme.dart';

/// Visual representation of the user's boat on the map.
///
/// Rotates with [reading.headingDegrees] when available, shows a pulsing
/// halo for visibility, and darkens when [isTracking] (during active haul).
class BoatMarker extends StatefulWidget {
  const BoatMarker({
    super.key,
    required this.reading,
    this.isTracking = false,
    this.size = 36,
  });

  final GpsReading? reading;
  final bool isTracking;
  final double size;

  @override
  State<BoatMarker> createState() => _BoatMarkerState();
}

class _BoatMarkerState extends State<BoatMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final gradient =
        widget.isTracking ? tokens.dangerGradient : tokens.primaryGradient;
    final glow = widget.isTracking
        ? tokens.danger.withValues(alpha: 0.4)
        : tokens.glowPrimary;

    final heading = widget.reading?.headingDegrees;
    final rotate = widget.reading?.hasReliableHeading ?? false;
    final rotationRadians = rotate ? (heading! * math.pi / 180.0) : 0.0;

    final haloColor = widget.isTracking ? tokens.danger : context.colors.primary;

    return SizedBox(
      width: widget.size * 1.6,
      height: widget.size * 1.6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing halo
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              final t = _pulse.value;
              final scale = 0.6 + t * 0.8;
              final opacity = (1.0 - t) * 0.4;
              return IgnorePointer(
                child: Container(
                  width: widget.size * 1.6 * scale,
                  height: widget.size * 1.6 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: haloColor.withValues(alpha: opacity),
                  ),
                ),
              );
            },
          ),

          // Rotating icon
          Transform.rotate(
            angle: rotationRadians,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                gradient: gradient,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: glow,
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                PhosphorIconsFill.navigationArrow,
                color: Colors.white,
                size: widget.size * 0.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
