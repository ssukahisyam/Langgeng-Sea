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
        final radians = -rotation * (math.pi / 180.0);

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
    final radius = size.width / 2 - 6;

    // --- Compass tick marks ---
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * math.pi / 180;
      final isCardinal = i % 3 == 0;
      final inner = isCardinal ? radius - 8 : radius - 5;
      final outer = radius - 2;
      canvas.drawLine(
        Offset(
          center.dx + inner * math.sin(angle),
          center.dy - inner * math.cos(angle),
        ),
        Offset(
          center.dx + outer * math.sin(angle),
          center.dy - outer * math.cos(angle),
        ),
        tickPaint..strokeWidth = (isCardinal ? 1.5 : 1.0),
      );
    }

    // --- North arrow (red) ---
    final northPath = Path()
      ..moveTo(center.dx, center.dy - radius + 10)
      ..lineTo(center.dx - 5, center.dy - 2)
      ..lineTo(center.dx + 5, center.dy - 2)
      ..close();
    canvas.drawPath(
      northPath,
      Paint()..color = const Color(0xFFEF4444),
    );

    // --- South arrow (white, subdued) ---
    final southPath = Path()
      ..moveTo(center.dx, center.dy + radius - 10)
      ..lineTo(center.dx - 5, center.dy + 2)
      ..lineTo(center.dx + 5, center.dy + 2)
      ..close();
    canvas.drawPath(
      southPath,
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );

    // --- Cardinal labels ---
    _drawLabel(canvas, center, radius, 0, 'N', const Color(0xFFEF4444));
    _drawLabel(
        canvas, center, radius, 90, 'E', Colors.white.withValues(alpha: 0.7));
    _drawLabel(canvas, center, radius, 180, 'S',
        Colors.white.withValues(alpha: 0.7));
    _drawLabel(
        canvas, center, radius, 270, 'W', Colors.white.withValues(alpha: 0.7));
  }

  void _drawLabel(Canvas canvas, Offset center, double radius,
      double angleDegrees, String label, Color color) {
    final angle = angleDegrees * math.pi / 180;
    final labelRadius = radius - 15;
    final offset = Offset(
      center.dx + labelRadius * math.sin(angle),
      center.dy - labelRadius * math.cos(angle),
    );

    final textSpan = TextSpan(
      text: label,
      style: TextStyle(
        color: color,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    );
    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      Offset(offset.dx - tp.width / 2, offset.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
