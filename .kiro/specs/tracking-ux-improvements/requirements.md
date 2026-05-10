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

## Requirements

### Requirement 1: Tracking GPS yang Andal di Background dan Layar Mati

**User Story:** Sebagai nelayan trawl yang melaut berjam-jam dengan layar HP dimatikan untuk menghemat baterai, saya ingin rekaman Track tetap mengikuti belokan kapal secara akurat meskipun Langgeng_Sea_App berada di background atau perangkat dalam Doze_Mode, sehingga Track yang tersimpan tidak hanya berupa garis lurus dari titik awal ke titik akhir.

#### Acceptance Criteria

1. WHEN pengguna memulai sesi tracking Trip atau Haul melalui Langgeng_Sea_App, THE Tracking_Controller SHALL mengaktifkan Background_Service sebagai Android foreground service dengan Persistent_Notification yang menampilkan status "Tracking aktif" dan nama Haul/Trip yang sedang direkam.
2. WHILE sesi tracking aktif, layar perangkat dalam keadaan mati, perangkat tidak berada di Doze_Mode, dan akurasi GPS terlapor ≤ 50 meter, THE Background_Service SHALL memperoleh pembacaan GPS dari GPS_Service dan mempersist Track_Point ke `track_point_repository` dengan jarak waktu antar Track_Point tersimpan tidak melebihi 5 detik. Batas timing pada acceptance criterion ini hanya berlaku di luar Doze_Mode; perilaku saat Doze_Mode aktif atau akurasi GPS > 50 meter diatur terpisah di acceptance criterion 4.
3. WHILE sesi tracking aktif, Langgeng_Sea_App di background, dan kapal bergerak dengan kecepatan hingga 15 knot (sekitar 7,7 m/s), THE Background_Service SHALL memastikan jarak spasial antar dua Track_Point berurutan yang tersimpan tidak melebihi 50 meter pada kondisi sinyal GPS normal.
4. WHEN perangkat Android memasuki Doze_Mode sementara sesi tracking aktif, THE Background_Service SHALL mempertahankan perolehan GPS dengan jarak waktu antar Track_Point tersimpan tidak melebihi 30 detik.
5. IF izin lokasi latar belakang (`ACCESS_BACKGROUND_LOCATION`) belum diberikan saat pengguna memulai sesi tracking, THEN THE Tracking_Controller SHALL meminta izin tersebut melalui `permission_handler` dan menampilkan penjelasan mengapa izin tersebut dibutuhkan sebelum memulai sesi.
6. IF pengguna menolak memberikan `ACCESS_BACKGROUND_LOCATION`, THEN THE Tracking_Controller SHALL menampilkan peringatan non-blocking bahwa tracking tidak akan berjalan saat aplikasi di background, SHALL NOT memulai sesi tracking secara otomatis, dan SHALL menunggu pengguna menekan ulang tombol "Mulai tracking" untuk memulai sesi dengan perolehan GPS foreground saja.
7. IF Background_Service dihentikan oleh sistem operasi saat sesi tracking aktif, THEN THE Tracking_Controller SHALL mencatat kejadian ini melalui Logger, mencoba me-restart Background_Service sebanyak tiga kali dengan jeda eksponensial (1s, 2s, 4s), dan tidak menghilangkan Track_Point yang sudah tersimpan.
8. WHEN sesi tracking dihentikan oleh pengguna, THE Tracking_Controller SHALL menghentikan Background_Service dan menghapus Persistent_Notification.
9. THE Background_Service SHALL mempersist setiap Track_Point secara atomik ke `track_point_repository` sesegera mungkin setelah diperoleh, tanpa menunggu aplikasi kembali ke foreground.
10. THE Langgeng_Sea_App SHALL mendukung perilaku background tracking pada perangkat Android versi 8.0 (API 26) hingga 14 (API 34) sebagaimana dideklarasikan di `AndroidManifest.xml`.

#### Correctness Properties

- **Invariant (monotonic timestamps):** Untuk setiap Trip atau Haul aktif, urutan Track_Point tersimpan SHALL memiliki `timestamp` yang non-descending.
- **Invariant (sampling density — foreground ≡ background):** Dengan skenario simulasi pembacaan GPS di `fake_async`, rata-rata jarak waktu antar Track_Point tersimpan dalam mode background SHALL tidak lebih dari 1,5× rata-rata dalam mode foreground untuk input pembacaan yang identik.
- **Round-trip (restart recovery):** Jika Background_Service dihentikan lalu di-restart saat Trip aktif, kumpulan Track_Point yang sudah tersimpan sebelum restart SHALL tetap utuh, dan Track_Point baru SHALL berlanjut append-only tanpa duplikat `timestamp`.
- **Metamorphic (foreground vs background path length):** Panjang Track (jumlah segmen haversine) yang direkam saat layar mati pada simulator yang sama SHALL berada di rentang ±10% dari panjang Track saat layar menyala pada input sintetis yang identik. Properti ini divalidasi melalui unit test dengan stream pembacaan GPS yang dimock.

---

### Requirement 2: Zoom dan Pan Bebas pada Mode Tampilkan Semua Riwayat

**User Story:** Sebagai pengguna yang menekan tombol jejak kaki untuk menampilkan seluruh histori tracking dan Marker di peta, saya ingin tetap bisa melakukan zoom-in, zoom-out, dan menggeser peta tanpa peta memaksa kembali ke Fit_All_Bounds, sehingga saya bebas memeriksa area tertentu dari histori.

#### Acceptance Criteria

1. WHEN pengguna mengaktifkan History_Overlay (tombol jejak kaki ditekan dari keadaan non-aktif menjadi aktif), THE Map_Screen SHALL melakukan Fit_All_Bounds tepat satu kali untuk menampilkan seluruh Marker dan Track yang dimuat oleh History_Overlay.
2. WHILE History_Overlay aktif, THE Map_Screen SHALL meneruskan seluruh User_Map_Gesture (pinch zoom, double-tap zoom, pan, rotate) ke `flutter_map` `MapController` dan SHALL memperbarui viewport sesuai input pengguna.
3. WHILE History_Overlay aktif dan pengguna telah melakukan minimal satu User_Map_Gesture setelah Fit_All_Bounds awal, THE Map_Screen SHALL NOT memicu Fit_All_Bounds otomatis pada perubahan data overlay berikutnya (penambahan Marker baru, refresh layer, atau pembaruan polyline).
4. WHEN data History_Overlay diperbarui sementara pengguna sudah melakukan User_Map_Gesture, THE Map_Screen SHALL menggambar ulang layer Marker dan Polyline tanpa mengubah `center` dan `zoom` peta.
5. WHERE pengguna menekan kontrol eksplisit "Paskan semua" pada UI History_Overlay, THE Map_Screen SHALL melakukan Fit_All_Bounds satu kali pada saat kontrol tersebut ditekan.
6. WHEN pengguna menonaktifkan History_Overlay lalu mengaktifkannya kembali, THE Map_Screen SHALL memperlakukan aktivasi tersebut sebagai aktivasi pertama (acceptance criterion 1 berlaku kembali, state "user sudah melakukan gesture" di-reset).
7. IF data History_Overlay kosong (tidak ada Marker dan tidak ada Track), THEN THE Map_Screen SHALL NOT melakukan Fit_All_Bounds dan SHALL mempertahankan viewport yang sedang aktif.

#### Correctness Properties

- **Invariant (idempotent gesture handling):** Setelah Fit_All_Bounds awal, untuk setiap urutan User_Map_Gesture yang tidak bersinggungan dengan kontrol "Paskan semua", `center` dan `zoom` terakhir yang dihasilkan SHALL hanya bergantung pada urutan gesture — tidak pernah di-override oleh pembaruan data overlay.
- **Invariant (single initial fit):** Dalam satu siklus aktivasi History_Overlay, Fit_All_Bounds otomatis SHALL terjadi tepat satu kali; setiap Fit_All_Bounds tambahan dalam siklus yang sama SHALL merupakan hasil dari penekanan eksplisit "Paskan semua".
- **Round-trip (toggle reset):** Menonaktifkan lalu mengaktifkan kembali History_Overlay SHALL mengembalikan perilaku ke keadaan "Fit_All_Bounds awal belum dilakukan", yang dapat diverifikasi melalui sequence test (activate → gesture → deactivate → activate → expect Fit_All_Bounds dipanggil sekali).

---

### Requirement 3: Tampilan Kontras dan Interaksi Tap pada Polyline/Marker Tracking

**User Story:** Sebagai pengguna yang melihat Track histori di peta, saya ingin Polyline dan titik awal Track tampak kontras di atas tile peta, dapat saya tekan untuk memunculkan label nama Track, dan memberi saya tombol cepat untuk memulai Navigation_Service menuju Track tersebut.

#### Acceptance Criteria

1. WHILE History_Overlay aktif, THE Map_Screen SHALL merender setiap Polyline milik Track menggunakan warna solid (alpha = 1.0) dengan rasio kontras minimum 4.5:1 terhadap tile peta baik pada preset peta terang maupun gelap.
2. WHILE History_Overlay aktif, THE Map_Screen SHALL merender setiap Polyline dengan `strokeWidth` minimal 4 logical pixels dan `borderColor` kontras (misalnya putih di atas polyline warna utama) agar tetap terlihat di atas tile peta bertekstur tinggi.
3. WHEN pengguna menekan (tap) sebuah Polyline Track atau titik awal Track pada History_Overlay dan Track memiliki nama yang tersimpan, THE Map_Screen SHALL menampilkan popup info yang memuat nama Track tersebut (displayName Trip/Haul), kategori atau jenis (Trip atau Haul), waktu mulai dalam format `yyyy-MM-dd HH:mm`, dan satu tombol aksi "Navigasi ke sini".
3a. WHEN pengguna menekan (tap) sebuah Polyline Track atau titik awal Track pada History_Overlay dan Track tidak memiliki nama yang tersimpan, THE Map_Screen SHALL menampilkan popup info dengan konten yang sama, menggunakan label default sesuai acceptance criterion 7 sebagai pengganti nama Track.
4. WHEN pengguna menekan tombol "Navigasi ke sini" pada popup Polyline Track atau titik awal Track, THE Navigation_Service SHALL memulai sesi `FollowTrackTarget` dengan `pathPoints` dari Track tersebut, THE Map_Screen SHALL menutup popup info, dan THE Map_Screen SHALL beralih ke Map_Mode `Navigating` (lihat Requirement 4).
5. WHEN pengguna menekan area kosong pada peta saat popup info Track sedang ditampilkan, THE Map_Screen SHALL menutup popup info tanpa memulai Navigation_Service.
6. WHERE sebuah Marker atau Track memiliki warna kustom (lihat Requirement 5), THE Map_Screen SHALL menggunakan warna kustom sebagai warna utama dan SHALL menambahkan `borderColor` pendukung agar rasio kontras pada acceptance criterion 1 tetap terpenuhi.
7. IF sebuah Track tidak memiliki nama yang tersimpan, THEN THE Map_Screen SHALL menampilkan label default dalam format `yyyy-MM-dd HH:mm` berdasarkan `startedAt` Track.
8. THE Map_Screen SHALL menyediakan area hit-test Polyline dengan toleransi minimum 16 logical pixels dari sumbu polyline, agar Polyline yang tipis tetap bisa ditekan dengan mudah di perangkat mobile.

#### Correctness Properties

- **Invariant (tap target reachability):** Untuk setiap Track yang ter-render di History_Overlay, ada posisi tap yang valid (dalam toleransi hit-test) yang SHALL memunculkan popup info Track yang benar — diverifikasi dengan widget test pada beberapa tingkat zoom.
- **Round-trip (tap → navigate → back):** Setelah tap Polyline → tekan "Navigasi ke sini" → batalkan navigasi, Langgeng_Sea_App SHALL kembali ke Map_Mode sebelum navigasi dimulai (`Idle` atau `ViewingHistory`) dengan History_Overlay dalam keadaan yang sama seperti sebelum navigasi dimulai.
- **Invariant (contrast under theme toggle):** Saat pengguna mengubah tema aplikasi (terang ↔ gelap), rasio kontras Polyline SHALL tetap ≥ 4.5:1 tanpa perlu menggambar ulang manual (dibuktikan dengan golden test terhadap palet warna tile peta yang dipakai).

---

### Requirement 4: Tampilan Peta Adaptif Sesuai Map_Mode

**User Story:** Sebagai pengguna yang memakai peta pada berbagai konteks (melihat peta biasa, sedang tracking, sedang navigasi, atau sedang melihat histori), saya ingin Map_Screen hanya menampilkan kontrol yang relevan dengan Map_Mode saya saat itu, sehingga peta tidak tertutup oleh tombol dan kartu yang tidak dibutuhkan.

#### Acceptance Criteria

1. THE Map_Screen SHALL memelihara Map_Mode sebagai state terobservasi dengan tepat satu dari empat nilai: `Idle`, `Tracking`, `Navigating`, `ViewingHistory`.
2. WHEN Tracking_Controller berpindah dari "tidak aktif" menjadi "aktif", THE Map_Screen SHALL mengubah Map_Mode menjadi `Tracking`.
3. WHEN Navigation_Service berpindah dari "tidak aktif" menjadi "aktif", THE Map_Screen SHALL mengubah Map_Mode menjadi `Navigating`.
4. WHEN History_Overlay diaktifkan oleh pengguna dan Tracking_Controller serta Navigation_Service dalam keadaan tidak aktif, THE Map_Screen SHALL mengubah Map_Mode menjadi `ViewingHistory`.
5. WHEN Tracking_Controller, Navigation_Service, dan History_Overlay semuanya dalam keadaan tidak aktif, THE Map_Screen SHALL mengubah Map_Mode menjadi `Idle`.
6. WHILE Map_Mode bernilai `Idle`, THE Map_Screen SHALL menampilkan sebuah Floating Action Button utama berlabel "Mulai tracking", tombol aktivasi History_Overlay, dan kontrol peta standar (my-location, layer, kompas); THE Map_Screen SHALL NOT menampilkan tombol "Berhenti tracking", kartu statistik tracking, maupun kartu progres navigasi. Batasan kontrol UI pada criterion ini hanya berlaku ketika Map_Mode benar-benar bernilai `Idle`; Map_Mode lainnya diatur oleh criterion 7–9.
7. WHILE Map_Mode bernilai `Tracking`, THE Map_Screen SHALL menampilkan bottom sheet yang dapat di-collapse dengan ringkasan statistik tracking aktif (durasi, jarak kumulatif, kecepatan terakhir) dan tombol "Berhenti tracking" di dalamnya, serta kontrol peta standar; THE Map_Screen SHALL NOT menampilkan tombol "Mulai tracking", kontrol aktivasi History_Overlay, maupun kartu progres navigasi.
8. WHILE Map_Mode bernilai `Navigating`, THE Map_Screen SHALL menampilkan `NavigationPanel` M11 (jarak ke target, ETA, bearing, progress bar untuk follow-track) dan tombol "Batalkan navigasi", serta kontrol peta standar; THE Map_Screen SHALL NOT menampilkan tombol "Mulai tracking", kontrol aktivasi History_Overlay, maupun bottom sheet statistik tracking.
9. WHILE Map_Mode bernilai `ViewingHistory`, THE Map_Screen SHALL menampilkan kontrol History_Overlay (toggle jejak kaki, filter, "Paskan semua") dan kontrol peta standar; THE Map_Screen SHALL NOT menampilkan tombol "Mulai tracking", tombol "Berhenti tracking", maupun kartu statistik tracking.
10. WHERE sebuah kontrol tersembunyi oleh Map_Mode tetap dapat diakses pengguna, THE Map_Screen SHALL menyediakannya di overflow menu yang dapat dibuka tanpa mengubah Map_Mode aktif.
11. WHEN Map_Mode berubah, THE Map_Screen SHALL menjalankan transisi visual dengan durasi maksimum 250 ms untuk kontrol yang disembunyikan maupun ditampilkan (fade atau slide).
12. IF Tracking_Controller dan Navigation_Service sama-sama aktif, THEN THE Map_Screen SHALL memprioritaskan Map_Mode `Navigating` untuk layout atas (NavigationPanel) dan tetap menampilkan bottom sheet tracking dalam keadaan collapsed; pengaturan ini SHALL didokumentasikan di komentar kode kontrol. IF salah satu atau kedua service tidak aktif, THEN THE Map_Screen SHALL NOT menerapkan layout khusus ini dan Map_Mode SHALL ditentukan oleh aturan transisi di criterion 2–5.

#### Correctness Properties

- **Invariant (mutual exclusion + priority):** Untuk setiap kombinasi status (`tracking`, `navigating`, `historyOverlayActive`), Map_Mode yang dihasilkan SHALL deterministik dan mematuhi prioritas `Navigating > Tracking > ViewingHistory > Idle` — diverifikasi dengan property-based test atas seluruh 2³ = 8 kombinasi boolean.
- **Invariant (no-forbidden-control):** Untuk setiap Map_Mode, himpunan kontrol UI yang terlihat SHALL menjadi subset dari daftar yang diizinkan mode tersebut (acceptance criteria 6–9); kontrol yang dilarang tidak pernah muncul.
- **Round-trip (mode change reversibility):** Memulai lalu menghentikan tracking dari Map_Mode `Idle` SHALL mengembalikan Map_Mode ke `Idle` dengan kontrol UI identik sebelum tracking dimulai (verifikasi widget test).

---

### Requirement 5: Kustomisasi Warna Track, Edit Marker_Category, dan Jump-To-Location

**User Story:** Sebagai pengguna, saya ingin memberi warna berbeda untuk setiap Trip dan Haul agar mudah dibedakan di peta, mengubah Marker_Category sebuah Marker yang sudah tersimpan, dan menekan Marker di Markers_List_Screen untuk langsung dibawa ke Map_Screen pada posisi Marker tersebut.

#### Acceptance Criteria

1. THE Langgeng_Sea_App SHALL menyediakan kontrol color picker pada layar detail Trip maupun Haul, dengan palet minimum 8 warna pre-set dan opsi custom hex.
2. WHEN pengguna memilih warna baru untuk sebuah Trip individual maupun Haul individual (bukan kedua entitas sekaligus), THE Langgeng_Sea_App SHALL mempersist pilihan warna pada field `colorValue` entitas yang bersangkutan saja dan SHALL memakai warna tersebut ketika Polyline entitas tersebut di-render di Map_Screen (termasuk di dalam History_Overlay), tanpa memengaruhi `colorValue` entitas lain.
3. IF pengguna belum pernah memilih warna untuk sebuah Trip atau Haul, THEN THE Langgeng_Sea_App SHALL memakai warna default dari tema aplikasi pada saat Polyline dirender.
4. THE Markers_List_Screen SHALL menyediakan aksi "Ubah kategori" untuk setiap Marker yang tersimpan, yang dapat diakses melalui menu konteks pada item Marker.
5. WHEN pengguna memilih aksi "Ubah kategori" pada sebuah Marker dan memilih Marker_Category yang valid, THE Langgeng_Sea_App SHALL memperbarui kategori Marker melalui `marker_repository`, SHALL memperbarui ikon Marker di Map_Screen pada render berikutnya, dan SHALL memperbarui urutan/kelompok Marker di Markers_List_Screen sesuai kategori baru.
6. IF pengguna mencoba menetapkan Marker_Category yang tidak terdefinisi di enum domain, THEN THE Langgeng_Sea_App SHALL menolak perubahan tersebut dan menampilkan pesan kesalahan yang menyebutkan daftar kategori yang valid.
7. WHEN pengguna menekan (single tap) sebuah Marker pada Markers_List_Screen, THE Langgeng_Sea_App SHALL membuka Map_Screen melalui `go_router`, mengatur viewport peta agar ter-center pada posisi Marker dengan zoom level minimum 15, dan menyorot Marker dengan popup info (konsisten dengan popup Marker di Requirement 3).
8. WHEN Map_Screen dibuka melalui aksi jump-to-location dari Markers_List_Screen, THE Map_Screen SHALL mengatur Map_Mode menjadi `Idle` kecuali Tracking_Controller atau Navigation_Service sedang aktif (prioritas Map_Mode tetap sesuai Requirement 4).
9. THE Langgeng_Sea_App SHALL mempertahankan hubungan historis antara Track_Point dan Track induknya ketika warna Track diubah — perubahan warna SHALL hanya memodifikasi field `colorValue` pada Trip atau Haul dan tidak menyentuh Track_Point.
10. WHERE Marker_Category sebuah Marker diubah, THE Markers_List_Screen SHALL menyimpan kategori sebelumnya di log audit (melalui Logger) untuk keperluan debug, tetapi SHALL NOT menyediakan fitur undo manual pada PR #21.

#### Correctness Properties

- **Round-trip (color persist):** Menetapkan warna X pada Trip/Haul, menutup layar, membuka kembali layar detail, dan membaca kembali `colorValue` SHALL mengembalikan X tanpa kehilangan precision.
- **Invariant (track_point immutability):** Perubahan `colorValue` pada Trip/Haul SHALL tidak pernah memodifikasi record di tabel `track_point` — verifikasi dengan repository test yang melakukan `count(*)` dan hash checksum Track_Point sebelum dan sesudah perubahan warna.
- **Invariant (category validity):** Untuk setiap Marker di `marker_repository`, `Marker_Category` SHALL selalu merupakan anggota enum domain yang terdefinisi — diverifikasi dengan invariant check saat load dan saat save.
- **Metamorphic (jump-to-location deterministik):** Untuk setiap Marker M dengan posisi (lat, lon), aksi jump-to-location SHALL menghasilkan viewport dengan `center` pada (lat, lon) dalam toleransi 1e-6 derajat dan `zoom ≥ 15`, independen dari Map_Mode awal (kecuali Tracking/Navigating sedang aktif, yang tetap mempertahankan Map_Mode prioritas).

---

## Referensi Implementasi (non-normative)

Daftar file yang diprediksi terdampak, untuk orientasi fase design. Tidak mengikat — design phase bebas memperluas atau mempersempit.

- **Requirement 1:** `app/lib/core/services/gps_service.dart`, `app/lib/features/tracking/application/tracking_controller.dart`, penambahan Background_Service handler (baru), `app/android/app/src/main/AndroidManifest.xml`.
- **Requirement 2:** `app/lib/features/map/presentation/map_screen.dart`, `app/lib/features/map/application/all_history_visible_provider.dart`, `app/lib/features/map/application/history_overlay_providers.dart`.
- **Requirement 3:** `app/lib/features/map/presentation/widgets/` (Polyline + Marker), popup baru, integrasi `NavigationController.startFollowTrack`.
- **Requirement 4:** `app/lib/features/map/presentation/map_screen.dart`, state `Map_Mode` baru (kemungkinan di `map_overlay_state.dart`), widget bottom sheet baru.
- **Requirement 5:** `app/lib/features/tracking/data/trip_repository.dart`, `haul_repository.dart`, `app/lib/features/marker/data/marker_repository.dart`, `markers_list_screen.dart`, router entry `go_router` baru untuk jump-to-location.
