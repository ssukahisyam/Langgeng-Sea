/// Rentang waktu inklusif-eksklusif untuk filter ekspor.
///
/// Konvensi: `start` inclusive, `end` exclusive. Pemilihan ini
/// mempermudah komposisi (rentang berurutan tidak overlap di edge:
/// `[a, b)` + `[b, c)` = `[a, c)` tanpa duplikasi titik `b`).
///
/// Lihat PR #27 R5 untuk pemakaian: filter rentang tanggal di
/// ExportScreen.
class DateRange {
  const DateRange({required this.start, required this.end})
      : assert(true);

  /// Batas bawah inclusive.
  final DateTime start;

  /// Batas atas exclusive.
  final DateTime end;

  /// Apakah `t` berada di dalam rentang `[start, end)`.
  ///
  /// Properti yang dipertahankan:
  /// - `t == start` → masuk
  /// - `t == end` → tidak masuk (exclusive)
  /// - `start.isAfter(end)` → semua false (rentang kosong)
  bool contains(DateTime t) {
    if (!start.isBefore(end)) return false;
    return !t.isBefore(start) && t.isBefore(end);
  }

  /// Rentang 7 hari terakhir relatif terhadap [now] (default `DateTime.now()`).
  ///
  /// `end` di-set ke besok-pagi (start of next day) supaya hari ini ikut
  /// masuk rentang. `start` = end - 7 hari.
  factory DateRange.last7Days({DateTime? now}) {
    final ref = now ?? DateTime.now();
    final endOfToday = DateTime(ref.year, ref.month, ref.day)
        .add(const Duration(days: 1));
    return DateRange(
      start: endOfToday.subtract(const Duration(days: 7)),
      end: endOfToday,
    );
  }

  /// Rentang 30 hari terakhir relatif terhadap [now].
  factory DateRange.last30Days({DateTime? now}) {
    final ref = now ?? DateTime.now();
    final endOfToday = DateTime(ref.year, ref.month, ref.day)
        .add(const Duration(days: 1));
    return DateRange(
      start: endOfToday.subtract(const Duration(days: 30)),
      end: endOfToday,
    );
  }

  /// Rentang hanya hari ini (00:00 — 24:00 lokal).
  factory DateRange.today({DateTime? now}) {
    final ref = now ?? DateTime.now();
    final startOfToday = DateTime(ref.year, ref.month, ref.day);
    return DateRange(
      start: startOfToday,
      end: startOfToday.add(const Duration(days: 1)),
    );
  }

  /// Rentang dari [from] sampai [to] (kedua-duanya inclusive di hari).
  ///
  /// Implementasi me-normalisasi `start` ke awal-hari [from] dan `end`
  /// ke awal-hari setelah [to], sehingga `contains(to akhir hari)`
  /// tetap true.
  factory DateRange.fromDates({required DateTime from, required DateTime to}) {
    final start = DateTime(from.year, from.month, from.day);
    final endOfTo =
        DateTime(to.year, to.month, to.day).add(const Duration(days: 1));
    return DateRange(start: start, end: endOfTo);
  }

  /// Apakah rentang ini kosong (start ≥ end).
  bool get isEmpty => !start.isBefore(end);

  /// Format human-readable untuk Bahasa Indonesia.
  ///
  /// Contoh:
  /// - "1 Mei 2026 – 7 Mei 2026"
  /// - kalau start.year sama dengan end.year sama tahun-saat-format,
  ///   tahun di-omit di start.
  String describeIndonesian() {
    if (isEmpty) return 'Rentang kosong';

    // `end` exclusive → display end-1ms agar user lihat tanggal
    // terakhir yang BENAR-BENAR ikut.
    final inclusiveEnd = end.subtract(const Duration(milliseconds: 1));

    final startLabel = _formatDate(start, includeYear: start.year != inclusiveEnd.year);
    final endLabel = _formatDate(inclusiveEnd, includeYear: true);

    if (_sameDay(start, inclusiveEnd)) return endLabel;
    return '$startLabel – $endLabel';
  }

  static const _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  static String _formatDate(DateTime t, {required bool includeYear}) {
    final m = _months[t.month - 1];
    return includeYear ? '${t.day} $m ${t.year}' : '${t.day} $m';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'DateRange($start … $end)';
}
