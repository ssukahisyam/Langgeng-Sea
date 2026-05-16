import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// A small compass rose overlay for the map that rotates inversely
/// to the map's rotation, always pointing towards true north.
///
/// Shows N/S/E/W labels and a red-tipped north arrow. Tapping the
/// compass resets the map rotation to 0° (north-up).
class CompassIndicator extends StatelessWidget {
  const CompassIndicator({
    super.key,
    required this.mapController,
    this.size = 56.0,
  });

  final MapController mapController;
  final double size;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MapEvent>(
      stream: mapController.mapEventStream,
      builder: (context, _) {
        final rotation = mapController.camera.rotation;
        final radians = rotation * (math.pi / 180.0);

        return GestureDetector(
          onTap: () => mapController.rotate(0.0),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Transform.rotate(
              angle: radians,
              child: CustomPaint(
                size: Size(size, size),
                painter: _CompassPainter(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // A simple, high-visibility compass needle (two large triangles)
    // Red triangle pointing North
    final northPath = Path()
      ..moveTo(center.dx, center.dy - radius) // Top tip
      ..lineTo(center.dx - 6, center.dy)      // Left base
      ..lineTo(center.dx + 6, center.dy)      // Right base
      ..close();
    canvas.drawPath(northPath, Paint()..color = const Color(0xFFEF4444));

    // White/grey triangle pointing South
    final southPath = Path()
      ..moveTo(center.dx, center.dy + radius) // Bottom tip
      ..lineTo(center.dx - 6, center.dy)      // Left base
      ..lineTo(center.dx + 6, center.dy)      // Right base
      ..close();
    canvas.drawPath(
      southPath,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );

    // Small dot in the center for the pin
    canvas.drawCircle(
      center,
      2.5,
      Paint()..color = Colors.black.withValues(alpha: 0.7),
    );
    canvas.drawCircle(
      center,
      1.5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
