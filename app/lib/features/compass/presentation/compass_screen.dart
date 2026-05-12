import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';

/// Full-screen compass page that reads the device magnetometer via
/// [FlutterCompass] and displays a large, easy-to-read compass rose.
///
/// Accessed from Settings → "Kompas".
class CompassScreen extends StatefulWidget {
  const CompassScreen({super.key});

  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends State<CompassScreen> {
  double? _heading;
  StreamSubscription<CompassEvent>? _compassSub;
  bool _sensorAvailable = true;

  @override
  void initState() {
    super.initState();
    _compassSub = FlutterCompass.events?.listen((event) {
      if (mounted) {
        setState(() => _heading = event.heading);
      }
    }, onError: (_) {
      if (mounted) setState(() => _sensorAvailable = false);
    });

    // If the stream itself is null, the platform has no magnetometer.
    if (_compassSub == null) {
      _sensorAvailable = false;
    }
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    super.dispose();
  }

  String _headingLabel(double heading) {
    const labels = ['U', 'TL', 'T', 'TG', 'S', 'BD', 'B', 'BL'];
    final index = ((heading + 22.5) % 360 / 45).floor();
    return labels[index];
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;

    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Kompas', style: text.titleLarge),
          centerTitle: true,
        ),
        body: Center(
          child: !_sensorAvailable
              ? _NoSensorMessage(tokens: tokens, text: text)
              : _heading == null
                  ? CircularProgressIndicator(color: tokens.primary)
                  : _CompassDisplay(
                      heading: _heading!,
                      headingLabel: _headingLabel(_heading!),
                      tokens: tokens,
                      text: text,
                    ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// No sensor fallback
// ---------------------------------------------------------------------------

class _NoSensorMessage extends StatelessWidget {
  const _NoSensorMessage({required this.tokens, required this.text});

  final AppTokens tokens;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.sp5),
      child: GlassCard(
        level: GlassLevel.level2,
        padding: const EdgeInsets.all(AppSizes.sp5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sensors_off, size: 56, color: tokens.danger),
            const SizedBox(height: AppSizes.sp3),
            Text(
              'Sensor kompas tidak tersedia',
              style: text.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.sp2),
            Text(
              'Perangkat Anda tidak memiliki sensor magnetometer atau sensor sedang tidak aktif.',
              style: text.bodySmall?.copyWith(color: tokens.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main compass display
// ---------------------------------------------------------------------------

class _CompassDisplay extends StatelessWidget {
  const _CompassDisplay({
    required this.heading,
    required this.headingLabel,
    required this.tokens,
    required this.text,
  });

  final double heading;
  final String headingLabel;
  final AppTokens tokens;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Heading readout
        Text(
          '${heading.toStringAsFixed(0)}°',
          style: text.displayLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            gradient: tokens.primaryGradient,
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          ),
          child: Text(
            headingLabel,
            style: text.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: AppSizes.sp6),

        // Compass rose
        SizedBox(
          width: 280,
          height: 280,
          child: CustomPaint(
            painter: _CompassRosePainter(
              heading: heading,
              northColor: const Color(0xFFEF4444),
              tickColor: tokens.textSecondary,
              labelColor: tokens.textPrimary,
              ringColor: tokens.border,
            ),
          ),
        ),

        const SizedBox(height: AppSizes.sp5),
        Text(
          'Kalibrasi: putar HP membentuk angka 8',
          style: text.bodySmall?.copyWith(color: tokens.textTertiary),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Compass rose painter
// ---------------------------------------------------------------------------

class _CompassRosePainter extends CustomPainter {
  _CompassRosePainter({
    required this.heading,
    required this.northColor,
    required this.tickColor,
    required this.labelColor,
    required this.ringColor,
  });

  final double heading;
  final Color northColor;
  final Color tickColor;
  final Color labelColor;
  final Color ringColor;

  static const _cardinals = ['U', 'T', 'S', 'B'];
  static const _intercardinals = ['TL', 'TG', 'BD', 'BL'];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final rotationRad = -heading * math.pi / 180;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationRad);

    // Outer ring
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = ringColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Inner ring
    canvas.drawCircle(
      Offset.zero,
      radius * 0.75,
      Paint()
        ..color = ringColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Tick marks (every 10°)
    for (int deg = 0; deg < 360; deg += 10) {
      final rad = deg * math.pi / 180;
      final isMajor = deg % 30 == 0;
      final innerR = isMajor ? radius * 0.82 : radius * 0.88;
      final outerR = radius * 0.95;

      final p1 = Offset(math.sin(rad) * innerR, -math.cos(rad) * innerR);
      final p2 = Offset(math.sin(rad) * outerR, -math.cos(rad) * outerR);

      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = (deg == 0)
              ? northColor
              : tickColor.withValues(alpha: isMajor ? 0.7 : 0.35)
          ..strokeWidth = isMajor ? 2.5 : 1.0
          ..strokeCap = StrokeCap.round,
      );
    }

    // Cardinal labels (U, T, S, B)
    for (int i = 0; i < 4; i++) {
      final deg = i * 90.0;
      final rad = deg * math.pi / 180;
      final labelR = radius * 0.68;
      final dx = math.sin(rad) * labelR;
      final dy = -math.cos(rad) * labelR;

      final isNorth = i == 0;
      final tp = TextPainter(
        text: TextSpan(
          text: _cardinals[i],
          style: TextStyle(
            color: isNorth ? northColor : labelColor,
            fontSize: isNorth ? 22 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(dx - tp.width / 2, dy - tp.height / 2));
    }

    // Intercardinal labels (TL, TG, BD, BL)
    for (int i = 0; i < 4; i++) {
      final deg = 45.0 + i * 90.0;
      final rad = deg * math.pi / 180;
      final labelR = radius * 0.68;
      final dx = math.sin(rad) * labelR;
      final dy = -math.cos(rad) * labelR;

      final tp = TextPainter(
        text: TextSpan(
          text: _intercardinals[i],
          style: TextStyle(
            color: labelColor.withValues(alpha: 0.5),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(dx - tp.width / 2, dy - tp.height / 2));
    }

    // North needle (red triangle)
    final needleR = radius * 0.48;
    final northPath = Path()
      ..moveTo(0, -needleR) // tip (north)
      ..lineTo(-7, 0)
      ..lineTo(7, 0)
      ..close();
    canvas.drawPath(northPath, Paint()..color = northColor);

    // South needle (white)
    final southPath = Path()
      ..moveTo(0, needleR) // tip (south)
      ..lineTo(-7, 0)
      ..lineTo(7, 0)
      ..close();
    canvas.drawPath(
      southPath,
      Paint()..color = labelColor.withValues(alpha: 0.5),
    );

    // Center pivot
    canvas.drawCircle(Offset.zero, 5, Paint()..color = northColor);
    canvas.drawCircle(Offset.zero, 3, Paint()..color = labelColor);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_CompassRosePainter oldDelegate) =>
      oldDelegate.heading != heading;
}
