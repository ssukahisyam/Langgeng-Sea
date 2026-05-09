import '../../../features/tracking/domain/entities/haul.dart';
import '../../../features/tracking/domain/entities/track_point.dart';
import '../../../features/tracking/domain/entities/trip.dart';

/// Generates GPX 1.1 XML from haul/trip track data.
///
/// Uses [StringBuffer] for simplicity — GPX structure is flat enough
/// that a full XML builder (like the `xml` package) isn't warranted.
class GpxExporter {
  /// Export a single haul as a GPX `<trk>`.
  String exportHaul(Haul haul, List<TrackPoint> points) {
    final buf = StringBuffer();
    _writeHeader(buf);
    _writeTrack(buf, haul.displayName(), points);
    _writeFooter(buf);
    return buf.toString();
  }

  /// Export an entire trip (all hauls) as a multi-track GPX.
  String exportTrip(
    Trip trip,
    List<Haul> hauls,
    Map<String, List<TrackPoint>> pointsByHaul,
  ) {
    final buf = StringBuffer();
    _writeHeader(buf);

    for (final haul in hauls) {
      final points = pointsByHaul[haul.id] ?? [];
      _writeTrack(buf, haul.displayName(), points);
    }

    _writeFooter(buf);
    return buf.toString();
  }

  void _writeHeader(StringBuffer buf) {
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln(
      '<gpx version="1.1" creator="Langgeng Sea" '
      'xmlns="http://www.topografix.com/GPX/1/1" '
      'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
      'xsi:schemaLocation="http://www.topografix.com/GPX/1/1 '
      'http://www.topografix.com/GPX/1/1/gpx.xsd">',
    );
  }

  void _writeTrack(StringBuffer buf, String name, List<TrackPoint> points) {
    buf.writeln('  <trk>');
    buf.writeln('    <name>${_escapeXml(name)}</name>');
    buf.writeln('    <trkseg>');

    for (final pt in points) {
      buf.write(
        '      <trkpt lat="${pt.latitude}" lon="${pt.longitude}">',
      );
      buf.write('<time>${pt.timestamp.toUtc().toIso8601String()}</time>');
      if (pt.speedMps != null) {
        buf.write('<speed>${pt.speedMps!.toStringAsFixed(2)}</speed>');
      }
      buf.writeln('</trkpt>');
    }

    buf.writeln('    </trkseg>');
    buf.writeln('  </trk>');
  }

  void _writeFooter(StringBuffer buf) {
    buf.writeln('</gpx>');
  }

  String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
