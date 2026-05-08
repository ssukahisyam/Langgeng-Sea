/// Centralized string constants in Bahasa Indonesia.
/// Ready to be migrated to ARB localization files in v2.
class AppStrings {
  AppStrings._();

  static const String appName = 'Langgeng Sea';
  static const String tagline = 'Jejak Setia di Lautan';

  // Navigation tabs
  static const String tabMap = 'Peta';
  static const String tabHistory = 'Riwayat';
  static const String tabDashboard = 'Dashboard';
  static const String tabSettings = 'Pengaturan';

  // Tracking
  static const String startTrawl = 'MULAI TEBAR TRAWL';
  static const String stopTrawl = 'ANGKAT TRAWL';
  static const String startTrip = 'MULAI TRIP';
  static const String endTrip = 'Akhiri Trip';
  static const String nextHaul = 'Haul Berikutnya';
  static const String fillLogBook = 'Isi Log Book';

  // Status
  static const String noTrip = 'Belum Trip';
  static const String tripActive = 'Trip Aktif';
  static const String recording = 'MEREKAM HAUL';
  static const String completed = 'Selesai';
  static const String readyToSail = 'Siap Melaut';

  // Metric labels
  static const String distance = 'Jarak';
  static const String distanceTrawl = 'Jarak Tarik';
  static const String duration = 'Durasi';
  static const String speed = 'Kecepatan';
  static const String avgSpeed = 'Kecepatan Rata-rata';
  static const String heading = 'Arah';
  static const String dominantHeading = 'Arah Dominan';
  static const String sweptArea = 'Luas Area Sapuan';
  static const String catchWeight = 'Tangkap';
  static const String fuel = 'BBM';
  static const String accuracy = 'Akurasi';

  // Common
  static const String save = 'Simpan';
  static const String cancel = 'Batal';
  static const String delete = 'Hapus';
  static const String edit = 'Edit';
  static const String share = 'Bagikan';
  static const String close = 'Tutup';
  static const String continueText = 'Lanjut';
  static const String skip = 'Lewati';
  static const String confirm = 'Konfirmasi';
  static const String back = 'Kembali';

  // Empty states
  static const String emptyHistoryTitle = 'Belum Ada Trip';
  static const String emptyHistorySub = 'Mulai trip pertama Anda dari tab Peta.';
  static const String emptyMarkersTitle = 'Belum Ada Marker';
  static const String emptyMarkersSub =
      'Tekan lama di peta untuk menandai lokasi penting.';
}
