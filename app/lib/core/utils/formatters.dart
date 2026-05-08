/// Lightweight formatters for metrics shown in the UI.
/// Keep these pure (no BuildContext / l10n) so they are trivially testable.
class Formatters {
  Formatters._();

  /// "1.24 km" or "480 m".
  static String distance(double meters) {
    if (meters.isNaN || meters.isInfinite) return '— km';
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(km < 10 ? 2 : 1)} km';
  }

  /// "3.2 kn" — speed in knots with 1 decimal.
  static String knots(double? knots) {
    if (knots == null || knots.isNaN) return '— kn';
    return '${knots.toStringAsFixed(1)} kn';
  }

  /// "045°" — heading with 3-digit padding.
  static String heading(double? degrees) {
    if (degrees == null || degrees.isNaN) return '—°';
    final d = degrees.round() % 360;
    return '${d.toString().padLeft(3, '0')}°';
  }

  /// "00:42:18" for Duration.
  static String duration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// "±4m" — compact GPS accuracy.
  static String accuracy(double? meters) {
    if (meters == null) return '±—m';
    return '±${meters.round()}m';
  }

  /// "8 Mei 2026" — very short Indonesian date for headers.
  static const _months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static String shortDate(DateTime d) =>
      '${d.day} ${_months[d.month]} ${d.year}';
}
