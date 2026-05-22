/// Mode tracking aplikasi.
///
/// **Sejak schema v11:** mode "Normal" dihapus. Audit pasca rilis
/// menunjukkan kedua mode sebenarnya identik secara operasional
/// (foreground service + wakelock + GPS accuracy = high di
/// keduanya); satu-satunya beda adalah Mode Normal tidak meminta
/// exemption optimasi baterai. Itu justru bikin Android throttling
/// agresif saat layar mati, jadi konsumsi baterai lebih boros
/// daripada mode Akurasi (yang dapat exemption + power-state stabil).
///
/// Hasil: tracking sekarang selalu pakai jalur Akurasi tanpa pilihan
/// mode. Enum dipertahankan sebagai single-value untuk backward
/// compat dengan kolom DB `app_settings.tracking_mode` (TEXT, default
/// `'accurate'` setelah migrasi v11).
enum TrackingMode {
  accurate;

  /// Parse nilai dari kolom DB. Apapun isinya — termasuk legacy
  /// `'normal'` dari pre-migration row yang belum di-touch — semua
  /// mapped ke [accurate]. Ini menjaga app tetap konsisten meskipun
  /// ada row yang tidak terkena migrasi v11 (mis. test DB lama,
  /// device yang DB-nya restored dari backup pre-v11).
  static TrackingMode fromDbValue(String? value) => TrackingMode.accurate;

  /// Nilai canonical yang ditulis ke kolom `tracking_mode`.
  String get dbValue => 'accurate';
}
