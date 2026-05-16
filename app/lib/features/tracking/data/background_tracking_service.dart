// Abstract interface — see `flutter_background_tracking_service.dart`
// for the concrete implementation.

/// Lifecycle state dari [BackgroundTrackingService], diemisikan ke UI
/// foreground melalui [BackgroundTrackingService.watchStatus].
///
/// Transisi yang mungkin:
/// - `stopped → starting → running` ketika pengguna memulai sesi tracking
///   dan Android foreground service berhasil aktif (Requirement 1.1).
/// - `running → restarting → running` ketika `TrackingController`
///   melakukan auto-restart setelah service dihentikan OS
///   (Requirement 1.7, jeda eksponensial 1s/2s/4s).
/// - `restarting → failed` setelah 3 upaya restart berturut-turut gagal
///   (Requirement 1.7, banner error non-blocking). State `failed` TIDAK
///   menghilangkan `Track_Point` yang sudah tersimpan.
/// - `running → stopped` ketika pengguna menghentikan sesi tracking
///   secara eksplisit (Requirement 1.8).
enum BackgroundTrackingStatus {
  /// Service tidak aktif. Tidak ada foreground service berjalan dan
  /// tidak ada persistent notification yang tampil.
  stopped,

  /// Transisi sementara setelah [BackgroundTrackingService.start]
  /// dipanggil tetapi service Android belum menyala sepenuhnya.
  starting,

  /// Service aktif: Android foreground service berjalan, persistent
  /// notification tampil, dan isolate background sedang men-listen
  /// pembacaan GPS untuk persist `Track_Point`.
  running,

  /// Service sedang di-restart oleh `TrackingController` setelah OS
  /// mematikannya sementara sesi tracking masih seharusnya berjalan.
  /// Tidak ada data loss selama transisi ini karena insert `Track_Point`
  /// bersifat append-only.
  restarting,

  /// Ketiga upaya restart gagal (Requirement 1.7). UI menampilkan banner
  /// error non-blocking. Pengguna harus memulai ulang sesi secara manual.
  failed,
}

/// Abstraksi foreground service Android yang memperoleh pembacaan GPS
/// dan mempersist `Track_Point` meskipun aplikasi berada di background
/// atau layar perangkat mati.
///
/// Implementasi konkret ([FlutterBackgroundTrackingService]) memakai
/// paket `flutter_background_service` untuk menjalankan service Android
/// dengan `foregroundServiceType="location"` sehingga Android 14 (API
/// 34) mengizinkan perolehan GPS di background.
///
/// Kontrak ini dipanggil dari foreground isolate (mis. oleh
/// `TrackingController.startHaul`), sedangkan logika GPS acquisition
/// dijalankan di isolate background via [onBackgroundStart].
///
/// _Requirements: 1.1, 1.7, 1.8_
abstract class BackgroundTrackingService {
  /// Konfigurasi awal service plugin (mendaftarkan notification channel,
  /// menyetel `AndroidConfiguration.onStart`, men-subscribe channel
  /// status). HARUS dipanggil tepat satu kali sebelum [start] / [stop].
  ///
  /// Idempotent — pemanggilan ulang aman tapi tidak punya efek tambahan.
  /// Dijalankan dari foreground isolate selama bootstrap aplikasi
  /// (`main.dart`).
  ///
  /// _Requirements: 1.1, 1.10_
  Future<void> initialise();

  /// Memulai Android foreground service dan menampilkan persistent
  /// notification dengan [notificationTitle] dan [notificationBody].
  /// [haulId] dipakai sebagai konteks persistence di isolate background.
  ///
  /// Setelah panggilan ini, [watchStatus] akan mengemisikan
  /// [BackgroundTrackingStatus.starting] lalu
  /// [BackgroundTrackingStatus.running] bila Android service berhasil
  /// aktif.
  ///
  /// Bila [skipBatteryPermission] `true`, implementasi konkret HARUS
  /// melewati permintaan `Permission.ignoreBatteryOptimizations`. Ini
  /// dipakai pada path crash-recovery (`TrackingController.resumeHaul`)
  /// supaya dialog OS tidak muncul ulang setelah user pernah merespons
  /// di sesi sebelumnya. Lihat PR #27 — Requirement R1, R2.
  ///
  /// _Requirements: 1.1, R1, R2_
  Future<void> start({
    required String haulId,
    required String notificationTitle,
    required String notificationBody,
    bool skipBatteryPermission,
  });

  /// Menghentikan Android foreground service dan menghapus persistent
  /// notification. Aman dipanggil bila service sudah dalam keadaan
  /// [BackgroundTrackingStatus.stopped] (no-op).
  ///
  /// Setelah panggilan ini, [watchStatus] akan mengemisikan
  /// [BackgroundTrackingStatus.stopped].
  ///
  /// _Requirements: 1.8_
  Future<void> stop();

  /// Stream status service untuk dikonsumsi UI foreground (mis.
  /// `TrackingController` men-subscribe untuk mendeteksi transisi
  /// `running → stopped` yang memicu retry).
  ///
  /// Stream bersifat broadcast — multiple listeners diperbolehkan —
  /// dan selalu memulai dengan status terakhir yang diketahui (atau
  /// [BackgroundTrackingStatus.stopped] bila service belum pernah
  /// dijalankan).
  ///
  /// _Requirements: 1.7_
  Stream<BackgroundTrackingStatus> watchStatus();
}

// The concrete `onBackgroundStart` entrypoint is defined in
// `flutter_background_tracking_service.dart` (task 4.3). Import that
// file wherever the entrypoint is needed (e.g. AndroidConfiguration).
