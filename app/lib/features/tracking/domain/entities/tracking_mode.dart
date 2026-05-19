/// Mode tracking yang dipilih user di Settings.
///
/// Diintroduksi di PR #29 supaya user nelayan tidak dipaksa memberi
/// izin (notifikasi, battery optimization) yang tidak relevan untuk
/// skenario pemakaian singkat. Setiap mode menentukan permission
/// flow + apakah foreground service Android di-start atau tidak.
///
/// - [TrackingMode.normal]: tracking pakai stream GPS foreground
///   saja (lewat `Geolocator.getPositionStream` yang terikat ke
///   lifecycle Flutter). Tidak start foreground service Android,
///   tidak request `POST_NOTIFICATIONS`, tidak request
///   `ignoreBatteryOptimizations`. Saat app dipindah ke background,
///   stream akan di-pause oleh OS — tracking lanjut normal saat app
///   kembali ke foreground. Cocok untuk trip pendek atau test fitur
///   di darat. Hemat baterai dan paling sedikit gangguan UX.
///
/// - [TrackingMode.accurate]: tracking pakai foreground service
///   `flutter_background_service` + notifikasi persisten + idealnya
///   battery optimization exemption. Tracking tetap merekam saat
///   layar mati / app di-background. Cocok untuk trip panjang.
///   Ini adalah mode yang dibangun di PR #27 dan PR #28.
///
/// **Default first install:** [TrackingMode.normal] — supaya tidak
/// ada dialog izin yang muncul tanpa konteks. User pindah ke
/// [TrackingMode.accurate] secara sadar saat butuh trip panjang.
///
/// **Persistence:** disimpan di tabel `app_settings` kolom
/// `tracking_mode TEXT` (schema v9 keatas). Mapping DB <-> enum lewat
/// [fromDbValue] / [dbValue].
enum TrackingMode {
  normal,
  accurate;

  /// Parse nilai dari kolom DB. Nilai tidak dikenal (mis. data lama
  /// yang corrupt, atau kolom kosong sebelum migrasi terkonfirmasi)
  /// di-fallback ke [normal] supaya app tidak crash karena
  /// preferensi yang tidak valid.
  static TrackingMode fromDbValue(String? value) =>
      switch (value) {
        'accurate' => TrackingMode.accurate,
        _ => TrackingMode.normal,
      };

  /// Nilai yang ditulis ke kolom `tracking_mode` di DB.
  ///
  /// Sengaja pakai nama enum (lowercase) supaya stable across
  /// refactor dan mudah di-grep di file SQL/migration.
  String get dbValue => name;

  /// Label pendek untuk segmented button di Settings.
  String get displayLabel => switch (this) {
        TrackingMode.normal => 'Normal',
        TrackingMode.accurate => 'Akurasi',
      };

  /// Subtitle dinamis di TrackingModeCard, menjelaskan behavior mode
  /// yang sedang aktif. Bahasa Indonesia, ringkas (≤ 1 baris di
  /// layar Redmi Note 10 Pro).
  ///
  /// Wording diperjelas (post-PR follow-up Bug 1) supaya user paham
  /// bahwa Mode Normal sekarang tetap pakai foreground service
  /// (best-effort screen-off) tapi tanpa minta izin baterai. Mode
  /// Akurasi tetap full path dengan battery optimization.
  String get subtitle => switch (this) {
        TrackingMode.normal =>
          'Best-effort layar mati, tanpa izin baterai. Hemat tapi kurang akurat.',
        TrackingMode.accurate =>
          'Tracking akurat saat layar mati. Memerlukan izin notifikasi & baterai.',
      };
}
