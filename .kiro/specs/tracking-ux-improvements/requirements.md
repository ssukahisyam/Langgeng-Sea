# Requirements Document

## Introduction

Dokumen ini memuat requirements untuk batch perbaikan UX dan bugfix pada aplikasi **Langgeng Sea** — aplikasi Flutter tracking GPS offline untuk nelayan trawl Indonesia — yang akan dikerjakan di branch `feat/ux-tracking-improvements-pr21` dan dirilis sebagai PR #21.

Perbaikan berangkat dari uji tracking di lapangan oleh pengguna, yang mengidentifikasi lima area bermasalah:

1. **Background tracking** — Ketika layar perangkat mati atau aplikasi di-background, Track_Point yang direkam terputus sehingga Track yang tersimpan hanya berupa garis lurus antara titik awal dan titik akhir, tidak mengikuti belokan nyata kapal.
2. **Mode "tampilkan semua riwayat"** — Tombol jejak kaki (History_Overlay) memaksa peta selalu kembali (snap-back) ke Fit_All_Bounds setiap kali pengguna mencoba zoom atau pan, sehingga peta tidak bisa dieksplorasi.
3. **Tampilan dan interaksi tanda tracking** — Polyline dan marker tracking kurang kontras, tidak bisa ditekan untuk menampilkan label nama tracking, dan tidak ada jalan pintas untuk memulai navigasi ke tracking tersebut dari peta.
4. **Peta terlalu penuh** — Map_Screen selalu menampilkan tombol mulai/berhenti, kartu haul, dan kartu navigasi secara bersamaan, menutupi sebagian besar peta. UI perlu adaptif berdasarkan Map_Mode (Idle, Tracking, Navigating, ViewingHistory).
5. **Kustomisasi dan manajemen penanda** — Pengguna belum bisa memilih warna per-Track, belum bisa mengubah Marker_Category setelah dibuat, dan daftar penanda di Markers_List_Screen belum mendukung tap-to-locate langsung ke posisi Marker di peta.

Perbaikan meneruskan milestone M1–M11 yang sudah selesai dan mengintegrasikan Navigation_Service dari M11 (`startGoto` / `FollowTrack`) sebagai entry point navigasi dari popup tracking dan dari Markers_List_Screen.

Narasi user story ditulis dalam Bahasa Indonesia, sementara kata kunci EARS (WHEN, WHILE, IF, THEN, WHERE, THE, SHALL) tetap dalam Bahasa Inggris sesuai konvensi EARS.

## Glossary

- **Langgeng_Sea_App** — Aplikasi Flutter Android (paket `id.co.langgengsea`) yang menjalankan seluruh fitur tracking, peta, marker, dan navigasi.
- **Trip** — Satu perjalanan melaut yang memiliki `startedAt`, `endedAt`, dan kumpulan Haul. Disimpan di `trip_repository`.
- **Haul** — Satu sesi tarikan jaring di dalam sebuah Trip, memiliki `startedAt`, `endedAt`, `displayName`, opsional `colorValue`, dan kumpulan Track_Point sendiri. Disimpan di `haul_repository`.
- **Track** — Urutan Track_Point yang membentuk lintasan, melekat pada Trip atau Haul. Track tidak memiliki tabel terpisah; istilah "Track" dipakai untuk menyebut kumpulan Track_Point milik sebuah Trip atau Haul.
- **Track_Point** — Satu pembacaan GPS dengan field `latitude`, `longitude`, `timestamp`, opsional `accuracyMeters`, `altitudeMeters`, `speedMps`. Disimpan di `track_point_repository`.
- **Polyline** — Representasi visual Track di peta sebagai rangkaian segmen garis yang menghubungkan Track_Point berurutan, digambar menggunakan `flutter_map` `PolylineLayer`.
- **Marker** — Penanda lokasi tetap yang dibuat pengguna (misalnya rumpon, dermaga, area larangan) dengan `name`, `Marker_Category`, posisi, dan metadata opsional. Disimpan di `marker_repository`.
- **Marker_Category** — Klasifikasi Marker yang menentukan ikon dan makna. Daftar kategori yang valid dikelola sebagai enum domain.
- **Tracking_Controller** — `TrackingController` di `app/lib/features/tracking/application/tracking_controller.dart` yang mengelola siklus hidup Trip dan Haul aktif.
- **GPS_Service** — Abstraksi di `app/lib/core/services/gps_service.dart` yang memperoleh pembacaan lokasi dari platform menggunakan `geolocator`.
- **Background_Service** — Android foreground service (berbasis `flutter_background_service` dan `flutter_background_service_android`) yang mempertahankan perolehan GPS ketika Langgeng_Sea_App berada di background atau layar perangkat mati.
- **Navigation_Service** — `NavigationController` dari milestone M11 (`app/lib/features/navigation/`) yang menjalankan mode `GotoTarget` atau `FollowTrackTarget`.
- **Map_Screen** — Layar peta utama (`app/lib/features/map/presentation/map_screen.dart`).
- **Markers_List_Screen** — Halaman "Kelola Penanda" (`app/lib/features/marker/presentation/markers_list_screen.dart`).
- **History_Overlay** — Mode tampilan peta yang memunculkan seluruh Marker dan Track dari histori, dipicu oleh tombol jejak kaki. Menggunakan `all_history_visible_provider` dan `history_overlay_providers`.
- **Map_Mode** — Status kontekstual Map_Screen. Empat nilai: `Idle`, `Tracking`, `Navigating`, `ViewingHistory`. Menentukan kontrol UI yang ditampilkan.
- **Fit_All_Bounds** — Operasi kamera yang mengatur viewport peta agar seluruh Marker dan Track yang aktif terlihat.
- **User_Map_Gesture** — Interaksi pengguna langsung pada peta: pinch zoom, double-tap zoom, drag/pan, atau rotate.
- **Persistent_Notification** — Notifikasi foreground service Android yang tidak bisa di-swipe hilang, menampilkan status tracking aktif. Diimplementasikan menggunakan `flutter_local_notifications`.
- **Doze_Mode** — Keadaan Android di mana sistem operasi membatasi aktivitas aplikasi untuk menghemat baterai ketika perangkat diam dan layar mati.
- **Track_Popup** — Popup info kontekstual yang muncul di Map_Screen ketika pengguna menekan (tap) Polyline atau titik awal sebuah Track di History_Overlay. Berisi identitas Track dan tombol aksi "Navigasi ke sini".
- **Marker_Popup** — Popup info kontekstual yang muncul di Map_Screen ketika pengguna menekan (tap) sebuah Marker, atau ketika Marker disorot melalui aksi jump-to-location dari Markers_List_Screen. Berisi identitas Marker dan tombol aksi yang relevan.
- **Tracking_Permission_Result** — Hasil alur permintaan izin sebelum memulai sesi tracking, dengan tiga nilai: `Granted` (fine + background), `GrantedForegroundOnly` (fine saja), dan `Denied` (fine ditolak).

## Requirements

### Requirement 1: Tracking GPS yang Andal di Background dan Layar Mati

**User Story:** Sebagai nelayan trawl yang melaut berjam-jam dengan layar HP dimatikan untuk menghemat baterai, saya ingin rekaman Track tetap mengikuti belokan kapal secara akurat meskipun Langgeng_Sea_App berada di background atau perangkat dalam Doze_Mode, sehingga Track yang tersimpan tidak hanya berupa garis lurus dari titik awal ke titik akhir.

#### Acceptance Criteria

1. WHEN pengguna memulai sesi tracking Trip atau Haul melalui Langgeng_Sea_App dan Tracking_Permission_Result bernilai `Granted`, THE Tracking_Controller SHALL mengaktifkan Background_Service sebagai Android foreground service dengan Persistent_Notification yang menampilkan status "Tracking aktif" dan nama Haul/Trip yang sedang direkam.
1a. WHEN pengguna memulai sesi tracking dan Tracking_Permission_Result bernilai `GrantedForegroundOnly`, THE Tracking_Controller SHALL memulai sesi tracking hanya dengan perolehan GPS foreground (tanpa mengaktifkan Background_Service) dan SHALL tetap menampilkan Persistent_Notification status "Tracking aktif (foreground only)" selama Langgeng_Sea_App berada di foreground.
2. WHILE sesi tracking aktif, layar perangkat dalam keadaan mati, perangkat tidak berada di Doze_Mode, dan akurasi GPS terlapor ≤ 50 meter, THE Background_Service SHALL memperoleh pembacaan GPS dari GPS_Service dan mempersist Track_Point ke `track_point_repository` dengan jarak waktu antar Track_Point tersimpan tidak melebihi 5 detik. Batas timing pada acceptance criterion ini hanya berlaku di luar Doze_Mode; perilaku saat Doze_Mode aktif diatur di acceptance criterion 4; perilaku saat akurasi > 50 meter diatur di acceptance criterion 2a.
2a. IF sebuah pembacaan GPS memiliki `accuracyMeters` > 50 meter sementara sesi tracking aktif dan perangkat tidak berada di Doze_Mode, THEN THE Background_Service SHALL NOT mempersist pembacaan tersebut sebagai Track_Point dan SHALL mencatat kejadian "reading dropped: accuracy too low" melalui Logger pada level debug; batas timing 5 detik di AC 2 diukur hanya atas pembacaan yang memenuhi syarat akurasi.
3. WHILE sesi tracking aktif, Langgeng_Sea_App di background, akurasi GPS ≤ 20 meter, dan kapal bergerak dengan kecepatan hingga 15 knot (sekitar 7,7 m/s), THE Background_Service SHALL memastikan jarak spasial antar dua Track_Point berurutan yang tersimpan tidak melebihi 50 meter.
4. WHEN perangkat Android memasuki Doze_Mode sementara sesi tracking aktif, THE Background_Service SHALL mempertahankan perolehan GPS dengan jarak waktu antar Track_Point tersimpan tidak melebihi 30 detik.
4a. IF GPS_Service tidak mengemisi pembacaan apapun selama 2 menit berturut-turut sementara sesi tracking aktif, THEN THE Background_Service SHALL memperbarui teks Persistent_Notification menjadi "Tracking aktif (sinyal GPS hilang)", SHALL mencatat kejadian ini melalui Logger pada level warning, dan SHALL NOT menghentikan sesi tracking secara otomatis. Ketika pembacaan GPS kembali diperoleh, teks Persistent_Notification SHALL dikembalikan ke "Tracking aktif" pada pembaruan berikutnya.
5. IF izin lokasi latar belakang (`ACCESS_BACKGROUND_LOCATION`) belum diberikan saat pengguna memulai sesi tracking, THEN THE Tracking_Controller SHALL meminta izin tersebut melalui `permission_handler` dan menampilkan penjelasan mengapa izin tersebut dibutuhkan sebelum memulai sesi.
6. IF pengguna menolak memberikan `ACCESS_BACKGROUND_LOCATION` (Tracking_Permission_Result = `GrantedForegroundOnly`), THEN THE Tracking_Controller SHALL menampilkan peringatan non-blocking bahwa tracking tidak akan berjalan saat aplikasi di background, SHALL NOT memulai sesi tracking secara otomatis, dan SHALL menunggu pengguna menekan ulang tombol "Mulai tracking" untuk memulai sesi dengan perolehan GPS foreground saja sebagaimana diatur di AC 1a.
7. IF Background_Service dihentikan oleh sistem operasi saat sesi tracking aktif, THEN THE Tracking_Controller SHALL mencatat kejadian ini melalui Logger, mencoba me-restart Background_Service sebanyak tiga kali dengan jeda eksponensial (1s, 2s, 4s), dan tidak menghilangkan Track_Point yang sudah tersimpan. Jika ketiga upaya restart gagal, THE Tracking_Controller SHALL menandai status sesi sebagai `failed`, menampilkan banner error non-blocking di Map_Screen, dan tetap mempertahankan Track_Point yang sudah tersimpan agar dapat dilanjutkan manual oleh pengguna.
8. WHEN sesi tracking dihentikan oleh pengguna, THE Tracking_Controller SHALL menghentikan Background_Service dan menghapus Persistent_Notification.
8a. WHEN pengguna menghentikan Haul aktif lalu memulai Haul baru pada Trip yang sama tanpa menghentikan Trip, THE Tracking_Controller SHALL memperbarui teks Persistent_Notification agar mencantumkan nama Haul baru tanpa men-dismiss dan menampilkan ulang notifikasi.
9. THE Background_Service SHALL mempersist setiap Track_Point secara atomik ke `track_point_repository` sesegera mungkin setelah diperoleh, tanpa menunggu aplikasi kembali ke foreground.
9a. IF operasi tulis Track_Point ke `track_point_repository` melempar exception, THEN THE Background_Service SHALL mencoba ulang operasi tulis yang sama dua kali dengan jeda 200 ms, SHALL mencatat kegagalan terakhir melalui Logger pada level error jika ketiga upaya gagal, dan SHALL melanjutkan memproses pembacaan berikutnya tanpa men-crash isolate background.
10. THE Langgeng_Sea_App SHALL mendukung perilaku background tracking pada perangkat Android versi 8.0 (API 26) hingga 14 (API 34) sebagaimana dideklarasikan di `AndroidManifest.xml`.

#### Correctness Properties

- **Invariant (monotonic timestamps):** Untuk setiap Trip atau Haul aktif, urutan Track_Point tersimpan SHALL memiliki `timestamp` yang non-descending.
- **Invariant (accuracy filter):** Untuk setiap pembacaan GPS yang masuk ke Background_Service, pembacaan dengan `accuracyMeters` > 50 meter di luar Doze_Mode SHALL tidak pernah tersimpan sebagai Track_Point — diverifikasi dengan stream sintetis yang bercampur antara reading akurat dan tidak akurat.
- **Invariant (sampling density — foreground ≡ background):** Dengan skenario simulasi pembacaan GPS di `fake_async`, rata-rata jarak waktu antar Track_Point tersimpan dalam mode background SHALL tidak lebih dari 1,5× rata-rata dalam mode foreground untuk input pembacaan yang identik.
- **Round-trip (restart recovery):** Jika Background_Service dihentikan lalu di-restart saat Trip aktif, kumpulan Track_Point yang sudah tersimpan sebelum restart SHALL tetap utuh, dan Track_Point baru SHALL berlanjut append-only tanpa duplikat `(haulId, timestamp)`.
- **Metamorphic (foreground vs background path length):** Panjang Track (jumlah segmen haversine) yang direkam saat layar mati pada simulator yang sama SHALL berada di rentang ±10% dari panjang Track saat layar menyala pada input sintetis yang identik. Properti ini divalidasi melalui unit test dengan stream pembacaan GPS yang dimock.
- **Invariant (DB write resiliency):** Untuk stream pembacaan GPS sintetis yang sebagian gagal di-write (repository simulasi throw pada pembacaan tertentu), Background_Service SHALL tetap memproses seluruh pembacaan berikutnya tanpa men-crash isolate, dan jumlah Track_Point tersimpan SHALL sama dengan jumlah pembacaan valid dikurangi pembacaan yang konsisten gagal tiga kali.

---

### Requirement 2: Zoom dan Pan Bebas pada Mode Tampilkan Semua Riwayat

**User Story:** Sebagai pengguna yang menekan tombol jejak kaki untuk menampilkan seluruh histori tracking dan Marker di peta, saya ingin tetap bisa melakukan zoom-in, zoom-out, dan menggeser peta tanpa peta memaksa kembali ke Fit_All_Bounds, sehingga saya bebas memeriksa area tertentu dari histori.

#### Acceptance Criteria

1. WHEN pengguna mengaktifkan History_Overlay (tombol jejak kaki ditekan dari keadaan non-aktif menjadi aktif) dan data History_Overlay yang pertama diemisikan setelah aktivasi memiliki bounds yang valid (lihat AC 7 dan AC 8 untuk definisi "valid"), THE Map_Screen SHALL melakukan Fit_All_Bounds tepat satu kali untuk menampilkan seluruh Marker dan Track yang dimuat oleh History_Overlay.
2. WHILE History_Overlay aktif, THE Map_Screen SHALL meneruskan seluruh User_Map_Gesture (pinch zoom, double-tap zoom, pan, rotate) ke `flutter_map` `MapController` dan SHALL memperbarui viewport sesuai input pengguna.
3. WHILE History_Overlay aktif dan pengguna telah melakukan minimal satu User_Map_Gesture setelah Fit_All_Bounds awal, THE Map_Screen SHALL NOT memicu Fit_All_Bounds otomatis pada perubahan data overlay berikutnya (penambahan Marker baru, refresh layer, atau pembaruan polyline).
4. WHEN data History_Overlay diperbarui sementara pengguna sudah melakukan User_Map_Gesture, THE Map_Screen SHALL menggambar ulang layer Marker dan Polyline tanpa mengubah `center` dan `zoom` peta.
5. WHERE pengguna menekan kontrol eksplisit "Paskan semua" pada UI History_Overlay, THE Map_Screen SHALL melakukan Fit_All_Bounds satu kali pada saat kontrol tersebut ditekan, tanpa mengubah state "user sudah melakukan gesture" (tekan lanjutan masih efektif dan data refresh berikutnya tetap tidak memicu auto-fit). Kontrol ini hanya diekspos saat Map_Mode = `ViewingHistory` (lihat Requirement 4).
6. WHEN pengguna menonaktifkan History_Overlay lalu mengaktifkannya kembali, THE Map_Screen SHALL memperlakukan aktivasi tersebut sebagai aktivasi pertama (acceptance criterion 1 berlaku kembali, state "user sudah melakukan gesture" di-reset). Jika pengguna mematikan lalu menyalakan History_Overlay dalam satu frame (rapid toggle) sebelum emission data pertama datang, aktivasi terakhir SHALL yang menjadi acuan dan Fit_All_Bounds awal SHALL dijalankan pada emission pertama setelah aktivasi terakhir.
7. IF data History_Overlay kosong (tidak ada Marker dan tidak ada Track), THEN THE Map_Screen SHALL NOT melakukan Fit_All_Bounds dan SHALL mempertahankan viewport yang sedang aktif.
8. IF bounds data History_Overlay hanya terdiri dari satu titik atau seluruh titik identik (bounds degenerate), THEN THE Map_Screen SHALL memposisikan `center` peta pada titik tersebut pada zoom level minimum 15 dan SHALL menandai Fit_All_Bounds awal sebagai sudah dilakukan (latch "initialFitDone" diset) sehingga pembaruan data berikutnya tidak memicu auto-fit.

#### Correctness Properties

- **Invariant (idempotent gesture handling):** Setelah Fit_All_Bounds awal, untuk setiap urutan User_Map_Gesture yang tidak bersinggungan dengan kontrol "Paskan semua", `center` dan `zoom` terakhir yang dihasilkan SHALL hanya bergantung pada urutan gesture — tidak pernah di-override oleh pembaruan data overlay.
- **Invariant (single initial fit):** Dalam satu siklus aktivasi History_Overlay, Fit_All_Bounds otomatis SHALL terjadi tepat satu kali; setiap Fit_All_Bounds tambahan dalam siklus yang sama SHALL merupakan hasil dari penekanan eksplisit "Paskan semua".
- **Round-trip (toggle reset):** Menonaktifkan lalu mengaktifkan kembali History_Overlay SHALL mengembalikan perilaku ke keadaan "Fit_All_Bounds awal belum dilakukan", yang dapat diverifikasi melalui sequence test (activate → gesture → deactivate → activate → expect Fit_All_Bounds dipanggil sekali).
- **Invariant (degenerate bounds safety):** Untuk bounds yang hanya memiliki satu titik atau semua titik identik, Map_Screen SHALL NOT memanggil `fitCamera` dengan bounds tak valid (yang dapat memicu zoom ∞ atau exception di `flutter_map`) — diverifikasi dengan unit test atas `MapCameraController.maybeInitialFit` untuk bounds degenerate.

---

### Requirement 3: Tampilan Kontras dan Interaksi Tap pada Polyline/Marker Tracking

**User Story:** Sebagai pengguna yang melihat Track histori di peta, saya ingin Polyline dan titik awal Track tampak kontras di atas tile peta, dapat saya tekan untuk memunculkan label nama Track, dan memberi saya tombol cepat untuk memulai Navigation_Service menuju Track tersebut.

#### Acceptance Criteria

1. WHILE History_Overlay aktif, THE Map_Screen SHALL merender setiap Polyline milik Track menggunakan warna solid (alpha = 1.0) dengan rasio kontras minimum 4.5:1 terhadap tile peta baik pada preset peta terang maupun gelap.
2. WHILE History_Overlay aktif, THE Map_Screen SHALL merender setiap Polyline dengan `strokeWidth` minimal 4 logical pixels dan `borderColor` kontras (misalnya putih di atas polyline warna utama) agar tetap terlihat di atas tile peta bertekstur tinggi.
3. WHEN pengguna menekan (tap) sebuah Polyline Track atau titik awal Track pada History_Overlay dan Track memiliki nama yang tersimpan, THE Map_Screen SHALL menampilkan Track_Popup yang memuat nama Track tersebut (displayName Trip/Haul), jenis Track (`Trip` atau `Haul`), waktu mulai dalam format `yyyy-MM-dd HH:mm`, dan satu tombol aksi "Navigasi ke sini".
3a. WHEN pengguna menekan (tap) sebuah Polyline Track atau titik awal Track pada History_Overlay dan Track tidak memiliki nama yang tersimpan, THE Map_Screen SHALL menampilkan Track_Popup dengan konten yang sama, menggunakan label default sesuai acceptance criterion 7 sebagai pengganti nama Track.
3b. WHEN pengguna menekan sebuah Polyline Track atau titik awal Track sementara Track_Popup untuk Track lain sedang ditampilkan, THE Map_Screen SHALL menutup Track_Popup yang sedang tampil dan membuka Track_Popup baru untuk Track yang baru di-tap dalam satu frame.
3c. WHEN pengguna menekan (tap) sebuah Marker di Map_Screen, THE Map_Screen SHALL menampilkan Marker_Popup yang memuat `name` Marker, Marker_Category dalam bentuk label yang dapat dibaca pengguna, posisi (lat, lon) dalam format derajat desimal enam digit, dan tombol aksi "Navigasi ke sini" yang memulai Navigation_Service pada mode `GotoTarget` dengan target posisi Marker.
4. WHEN pengguna menekan tombol "Navigasi ke sini" pada Track_Popup dan Map_Mode saat itu bukan `Navigating`, THE Navigation_Service SHALL memulai sesi `FollowTrackTarget` dengan `pathPoints` dari Track tersebut, THE Map_Screen SHALL menutup Track_Popup, dan THE Map_Screen SHALL beralih ke Map_Mode `Navigating` (lihat Requirement 4).
4a. WHEN pengguna menekan tombol "Navigasi ke sini" pada Track_Popup atau Marker_Popup sementara Map_Mode saat itu bernilai `Navigating`, THE Map_Screen SHALL menampilkan dialog konfirmasi "Ganti tujuan navigasi saat ini?" sebelum mengganti target navigasi; jika pengguna menolak, Navigation_Service SHALL tidak diubah dan popup SHALL ditutup.
5. WHEN pengguna menekan area kosong pada peta saat sebuah Track_Popup atau Marker_Popup sedang ditampilkan, THE Map_Screen SHALL menutup popup tanpa memulai Navigation_Service.
6. WHERE sebuah Marker atau Track memiliki warna kustom (lihat Requirement 5), THE Map_Screen SHALL menggunakan warna kustom sebagai warna utama dan SHALL menambahkan `borderColor` pendukung agar rasio kontras pada acceptance criterion 1 tetap terpenuhi.
7. IF sebuah Track tidak memiliki nama yang tersimpan, THEN THE Map_Screen SHALL menampilkan label default dalam format `yyyy-MM-dd HH:mm` berdasarkan `startedAt` Track.
8. THE Map_Screen SHALL menyediakan area hit-test Polyline dengan toleransi minimum 16 logical pixels dari sumbu polyline, agar Polyline yang tipis tetap bisa ditekan dengan mudah di perangkat mobile. THE Map_Screen SHALL menyediakan area hit-test titik awal Track dengan radius minimum 20 logical pixels dari pusat marker titik awal.
9. WHEN posisi tap yang dipakai sebagai anchor Track_Popup atau Marker_Popup membuat popup ter-clip di salah satu tepi viewport peta (popup akan keluar dari area visible), THE Map_Screen SHALL memindahkan anchor popup ke sisi berlawanan sehingga seluruh popup tetap berada di dalam viewport tanpa menutup Marker/Track yang sedang direferensikan.

#### Correctness Properties

- **Invariant (tap target reachability):** Untuk setiap Track yang ter-render di History_Overlay, ada posisi tap yang valid (dalam toleransi hit-test 16 logical pixels untuk polyline, 20 logical pixels untuk titik awal) yang SHALL memunculkan Track_Popup yang benar — diverifikasi dengan widget test pada beberapa tingkat zoom.
- **Round-trip (tap → navigate → back):** Setelah tap Polyline → tekan "Navigasi ke sini" → batalkan navigasi, Langgeng_Sea_App SHALL kembali ke Map_Mode sebelum navigasi dimulai (`Idle` atau `ViewingHistory`) dengan History_Overlay dalam keadaan yang sama seperti sebelum navigasi dimulai.
- **Invariant (contrast under theme toggle):** Saat pengguna mengubah tema aplikasi (terang ↔ gelap), rasio kontras Polyline SHALL tetap ≥ 4.5:1 tanpa perlu menggambar ulang manual (dibuktikan dengan golden test terhadap palet warna tile peta yang dipakai).
- **Invariant (popup singleton):** Untuk setiap keadaan Map_Screen, paling banyak satu Track_Popup atau satu Marker_Popup yang terlihat pada saat bersamaan — tap pada popup lain secara atomik menggantikan popup sebelumnya.

---

### Requirement 4: Tampilan Peta Adaptif Sesuai Map_Mode

**User Story:** Sebagai pengguna yang memakai peta pada berbagai konteks (melihat peta biasa, sedang tracking, sedang navigasi, atau sedang melihat histori), saya ingin Map_Screen hanya menampilkan kontrol yang relevan dengan Map_Mode saya saat itu, sehingga peta tidak tertutup oleh tombol dan kartu yang tidak dibutuhkan.

#### Acceptance Criteria

1. THE Map_Screen SHALL memelihara Map_Mode sebagai state terobservasi dengan tepat satu dari empat nilai: `Idle`, `Tracking`, `Navigating`, `ViewingHistory`.
2. WHEN Tracking_Controller berpindah dari "tidak aktif" menjadi "aktif" dan Navigation_Service dalam keadaan tidak aktif, THE Map_Screen SHALL mengubah Map_Mode menjadi `Tracking`.
3. WHEN Navigation_Service berpindah dari "tidak aktif" menjadi "aktif", THE Map_Screen SHALL mengubah Map_Mode menjadi `Navigating`.
4. WHEN History_Overlay diaktifkan oleh pengguna dan Tracking_Controller serta Navigation_Service dalam keadaan tidak aktif, THE Map_Screen SHALL mengubah Map_Mode menjadi `ViewingHistory`.
5. WHEN Tracking_Controller, Navigation_Service, dan History_Overlay semuanya dalam keadaan tidak aktif, THE Map_Screen SHALL mengubah Map_Mode menjadi `Idle`.
6. WHILE Map_Mode bernilai `Idle`, THE Map_Screen SHALL menampilkan sebuah Floating Action Button utama berlabel "Mulai tracking", tombol aktivasi History_Overlay, dan kontrol peta standar (my-location, layer, kompas); THE Map_Screen SHALL NOT menampilkan tombol "Berhenti tracking", kartu statistik tracking, maupun kartu progres navigasi.
7. WHILE Map_Mode bernilai `Tracking`, THE Map_Screen SHALL menampilkan bottom sheet yang dapat di-collapse dengan ringkasan statistik tracking aktif (durasi, jarak kumulatif, kecepatan terakhir) dan tombol "Berhenti tracking" di dalamnya, serta kontrol peta standar; THE Map_Screen SHALL NOT menampilkan tombol "Mulai tracking", kontrol aktivasi History_Overlay di toolbar utama, maupun kartu progres navigasi.
7a. WHEN Tracking_Controller berpindah dari "tidak aktif" menjadi "aktif" sementara History_Overlay sedang aktif, THE Map_Screen SHALL mempertahankan History_Overlay dalam keadaan aktif (Polyline dan Marker histori tetap di-render sebagai layer peta) tetapi SHALL menyembunyikan kontrol aktivasi History_Overlay dari toolbar utama sesuai AC 7. Pengguna tetap dapat menonaktifkan History_Overlay melalui overflow menu (lihat AC 10).
8. WHILE Map_Mode bernilai `Navigating`, THE Map_Screen SHALL menampilkan `NavigationPanel` M11 (jarak ke target, ETA, bearing, progress bar untuk follow-track) dan tombol "Batalkan navigasi", serta kontrol peta standar; THE Map_Screen SHALL NOT menampilkan tombol "Mulai tracking", kontrol aktivasi History_Overlay di toolbar utama, maupun bottom sheet statistik tracking selain layout concurrent yang diatur di AC 12a.
9. WHILE Map_Mode bernilai `ViewingHistory`, THE Map_Screen SHALL menampilkan kontrol History_Overlay (toggle jejak kaki, filter, "Paskan semua") dan kontrol peta standar; THE Map_Screen SHALL NOT menampilkan tombol "Mulai tracking", tombol "Berhenti tracking", maupun kartu statistik tracking.
10. WHERE sebuah kontrol tersembunyi oleh Map_Mode tetap dibutuhkan pengguna, THE Map_Screen SHALL menyediakannya di overflow menu yang dapat dibuka tanpa mengubah Map_Mode aktif. Overflow menu SHALL paling sedikit berisi: (a) toggle aktivasi/deaktivasi History_Overlay jika History_Overlay sedang aktif tetapi kontrol toolbar-nya disembunyikan, (b) "Tambah penanda di sini", dan (c) akses cepat ke Markers_List_Screen.
11. WHEN Map_Mode berubah, THE Map_Screen SHALL menjalankan transisi visual dengan durasi maksimum 250 ms untuk kontrol yang disembunyikan maupun ditampilkan (fade atau slide).
12. IF Tracking_Controller dan Navigation_Service sama-sama aktif, THEN Map_Mode SHALL bernilai `Navigating` sesuai prioritas di AC 3; pengaturan mode ini ditentukan oleh prioritas deterministik `Navigating > Tracking > ViewingHistory > Idle` terlepas dari layout visual yang diterapkan.
12a. WHILE Tracking_Controller dan Navigation_Service sama-sama aktif, THE Map_Screen SHALL menerapkan layout concurrent di mana `NavigationPanel` ditampilkan di posisi atas dan bottom sheet statistik tracking ditampilkan dalam keadaan collapsed (hanya ringkasan durasi dan tombol "Berhenti tracking"); layout concurrent ini SHALL didokumentasikan di komentar kode kontrol.
13. WHEN Map_Screen dibangun ulang akibat rotasi layar, pengembalian dari background, atau pemulihan state, THE Map_Screen SHALL mempertahankan Map_Mode yang sama seperti sebelum rebuild dan SHALL merender ulang kontrol UI yang identik dengan state sebelum rebuild.

#### Correctness Properties

- **Invariant (mutual exclusion + priority):** Untuk setiap kombinasi status (`tracking`, `navigating`, `historyOverlayActive`), Map_Mode yang dihasilkan SHALL deterministik dan mematuhi prioritas `Navigating > Tracking > ViewingHistory > Idle` — diverifikasi dengan property-based test atas seluruh 2³ = 8 kombinasi boolean.
- **Invariant (no-forbidden-control):** Untuk setiap Map_Mode, himpunan kontrol UI yang terlihat pada toolbar utama SHALL menjadi subset dari daftar yang diizinkan mode tersebut (acceptance criteria 6–9); kontrol yang dilarang tidak pernah muncul di toolbar utama. Overflow menu (AC 10) di-exclude dari properti ini.
- **Invariant (overlay persistence):** Saat Map_Mode berubah dari `ViewingHistory` ke `Tracking` atau `Navigating`, kumpulan Marker dan Polyline histori yang sedang di-render di layer peta SHALL tidak berubah — hanya visibilitas kontrol UI yang berubah.
- **Round-trip (mode change reversibility):** Memulai lalu menghentikan tracking dari Map_Mode `Idle` SHALL mengembalikan Map_Mode ke `Idle` dengan kontrol UI identik sebelum tracking dimulai (verifikasi widget test).

---

### Requirement 5: Kustomisasi Warna Track, Edit Marker_Category, dan Jump-To-Location

**User Story:** Sebagai pengguna, saya ingin memberi warna berbeda untuk setiap Trip dan Haul agar mudah dibedakan di peta, mengubah Marker_Category sebuah Marker yang sudah tersimpan, dan menekan Marker di Markers_List_Screen untuk langsung dibawa ke Map_Screen pada posisi Marker tersebut.

#### Acceptance Criteria

1. THE Langgeng_Sea_App SHALL menyediakan kontrol color picker pada layar detail Trip maupun Haul, dengan palet minimum 8 warna pre-set dan opsi kustom hex. Nilai kustom hex SHALL menerima format `#RRGGBB` (6 digit, alpha diasumsikan `FF`) dan SHALL menolak input yang tidak sesuai pola regex `^#[0-9A-Fa-f]{6}$` dengan pesan error "Gunakan format #RRGGBB". Format `#RGB` singkat dan `#RRGGBBAA` dengan alpha tidak didukung pada PR #21.
1a. THE entitas Trip SHALL memiliki field opsional `colorValue: int?` yang mempersist warna terpilih sebagai ARGB32; jika field ini belum ada pada skema basis data saat ini, THE Langgeng_Sea_App SHALL menambahkannya melalui migrasi Drift pada rilis PR #21 tanpa menghilangkan Trip atau Haul yang sudah tersimpan.
2. WHEN pengguna memilih warna baru untuk sebuah Trip individual maupun Haul individual (bukan kedua entitas sekaligus), THE Langgeng_Sea_App SHALL mempersist pilihan warna pada field `colorValue` entitas yang bersangkutan saja tanpa memengaruhi `colorValue` entitas lain.
2a. WHEN Polyline sebuah Haul dirender di Map_Screen dan Haul tersebut memiliki `colorValue` non-null, THE Map_Screen SHALL memakai `Haul.colorValue` sebagai warna utama Polyline, mengabaikan `Trip.colorValue` dari Trip induknya.
2b. WHEN Polyline sebuah Haul dirender di Map_Screen dan `Haul.colorValue` bernilai null tetapi `Trip.colorValue` dari Trip induk non-null, THE Map_Screen SHALL memakai `Trip.colorValue` sebagai warna utama Polyline sebagai fallback.
3. IF sebuah Haul tidak memiliki `colorValue` dan Trip induknya juga tidak memiliki `colorValue`, THEN THE Map_Screen SHALL memakai warna default dari tema aplikasi (misalnya `AppColors.defaultHaulColor`) pada saat Polyline dirender.
4. THE Markers_List_Screen SHALL menyediakan aksi "Ubah kategori" untuk setiap Marker yang tersimpan, yang dapat diakses melalui menu konteks yang dipicu oleh trailing icon `more_vert` pada item Marker; long-press pada item Marker SHALL memunculkan menu konteks yang sama sebagai shortcut alternatif.
5. WHEN pengguna memilih aksi "Ubah kategori" pada sebuah Marker dan memilih Marker_Category yang valid, THE Langgeng_Sea_App SHALL memperbarui kategori Marker melalui `marker_repository`, SHALL memperbarui ikon Marker di Map_Screen pada render berikutnya, dan SHALL memperbarui urutan/kelompok Marker di Markers_List_Screen sesuai kategori baru.
6. IF pengguna mencoba menetapkan Marker_Category yang tidak terdefinisi di enum domain, THEN THE Langgeng_Sea_App SHALL menolak perubahan tersebut dan menampilkan pesan kesalahan yang menyebutkan daftar kategori yang valid.
7. WHEN pengguna menekan (single tap) sebuah Marker pada Markers_List_Screen, THE Langgeng_Sea_App SHALL membuka Map_Screen melalui `go_router` dengan query parameter `focusMarkerId`, mengatur viewport peta agar ter-center pada posisi Marker dengan zoom level minimum 15, dan menyorot Marker dengan Marker_Popup (konsisten dengan AC 3c pada Requirement 3).
8. WHEN Map_Screen dibuka melalui aksi jump-to-location dari Markers_List_Screen, Map_Mode SHALL ditentukan oleh prioritas Requirement 4 (tidak di-override); jika Tracking_Controller atau Navigation_Service sedang aktif, viewport tetap di-center ke posisi Marker tetapi layout Map_Mode yang berlaku tetap diterapkan. Jika History_Overlay sedang aktif saat jump, History_Overlay SHALL tetap aktif dan Map_Mode di-derive sesuai aturan AC 4 Requirement 4.
9. THE Langgeng_Sea_App SHALL mempertahankan hubungan historis antara Track_Point dan Track induknya ketika warna Track diubah — perubahan warna SHALL hanya memodifikasi field `colorValue` pada Trip atau Haul dan tidak menyentuh Track_Point.
10. WHERE Marker_Category sebuah Marker diubah, THE Langgeng_Sea_App SHALL menyimpan kategori sebelumnya di log audit (melalui Logger pada level info dengan kunci `marker.category.change`) untuk keperluan debug, tetapi SHALL NOT menyediakan fitur undo manual pada PR #21.

#### Correctness Properties

- **Round-trip (color persist):** Menetapkan warna X pada Trip/Haul, menutup layar, membuka kembali layar detail, dan membaca kembali `colorValue` SHALL mengembalikan X tanpa kehilangan precision.
- **Invariant (color precedence):** Untuk setiap Haul H dengan Trip induk T, warna Polyline render H adalah `H.colorValue ?? T.colorValue ?? AppColors.defaultHaulColor` — deterministik terhadap state persist — diverifikasi dengan unit test fungsi `resolveHaulColor`.
- **Invariant (track_point immutability):** Perubahan `colorValue` pada Trip/Haul SHALL tidak pernah memodifikasi record di tabel `track_point` — verifikasi dengan repository test yang melakukan `count(*)` dan hash checksum Track_Point sebelum dan sesudah perubahan warna.
- **Invariant (category validity):** Untuk setiap Marker di `marker_repository`, `Marker_Category` SHALL selalu merupakan anggota enum domain yang terdefinisi — diverifikasi dengan invariant check saat load dan saat save.
- **Round-trip (category update):** Mengubah Marker_Category dari A ke B melalui `updateCategory`, menutup Markers_List_Screen, dan membukanya kembali SHALL menampilkan Marker pada kelompok B dengan ikon B; `marker.category.change` SHALL tercatat di Logger dengan `from=A` dan `to=B`.
- **Metamorphic (jump-to-location deterministik):** Untuk setiap Marker M dengan posisi (lat, lon), aksi jump-to-location SHALL menghasilkan viewport dengan `center` pada (lat, lon) dalam toleransi 1e-6 derajat dan `zoom ≥ 15`, independen dari Map_Mode awal. Map_Mode yang berlaku tetap mengikuti prioritas Requirement 4; viewport `center` dan `zoom` tidak di-override oleh Map_Mode.

---

## Referensi Implementasi (non-normative)

Daftar file yang diprediksi terdampak, untuk orientasi fase design. Tidak mengikat — design phase bebas memperluas atau mempersempit.

- **Requirement 1:** `app/lib/core/services/gps_service.dart`, `app/lib/features/tracking/application/tracking_controller.dart`, penambahan Background_Service handler (baru), `app/android/app/src/main/AndroidManifest.xml`.
- **Requirement 2:** `app/lib/features/map/presentation/map_screen.dart`, `app/lib/features/map/application/all_history_visible_provider.dart`, `app/lib/features/map/application/history_overlay_providers.dart`.
- **Requirement 3:** `app/lib/features/map/presentation/widgets/` (Polyline + Marker), popup baru, integrasi `NavigationController.startFollowTrack`.
- **Requirement 4:** `app/lib/features/map/presentation/map_screen.dart`, state `Map_Mode` baru (kemungkinan di `map_overlay_state.dart`), widget bottom sheet baru.
- **Requirement 5:** `app/lib/features/tracking/data/trip_repository.dart`, `haul_repository.dart`, `app/lib/features/marker/data/marker_repository.dart`, `markers_list_screen.dart`, router entry `go_router` baru untuk jump-to-location.
