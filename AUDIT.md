# Audit Aplikasi Styra

Dokumen ini menjelaskan secara detail setiap temuan dari audit aplikasi, dikelompokkan per Tier prioritas. Setiap nomor berisi: apa masalahnya, kenapa penting, contoh konkret di kode, dan rekomendasi solusi.

> Disclaimer: Ini panduan untuk roadmap, bukan urutan eksekusi wajib. Anda bebas pick dan choose sesuai kapasitas tim.

---

## Daftar Isi

- [Tier S — Blocker untuk skala](#tier-s--blocker-untuk-skala)
- [Tier A — Data integrity & user-facing risk](#tier-a--data-integrity--user-facing-risk)
- [Tier B — Safety](#tier-b--safety)
- [Tier C — UX polish & quality](#tier-c--ux-polish--quality)
- [Tier D — Engineering hygiene](#tier-d--engineering-hygiene)
- [Tier E — Quick wins](#tier-e--quick-wins)
- [Yang sudah bagus](#yang-sudah-bagus-jangan-diutak-atik)
- [Roadmap](#roadmap-eksekusi-saran)

---

## Tier S — Blocker untuk skala

Kategori ini berisi masalah foundational. Tanpa fix, semua perbaikan lain akan jalan blind atau di atas tanah retak.

### 1. CI tidak benar-benar gating

**Apa masalahnya?**

GitHub Actions workflow CI di `.github/workflows/flutter.yml` punya 3 step penting:
- `Verify formatting` — cek `dart format` rapi atau tidak
- `Analyze code` — jalankan `flutter analyze` (cari error & warning)
- `Run unit + integration tests` — jalankan `flutter test`

Tapi ketiganya pakai `continue-on-error: true`. Artinya: kalau format salah, ada lint error, atau test gagal — workflow tetap hijau. Tidak ada gating, hanya laporan informasi.

**Kenapa penting?**

PR review jadi pertahanan satu-satunya. Kalau reviewer terburu-buru atau lupa cek tab Actions, kode rusak masuk main. Bug yang seharusnya tertangkap CI lewat tanpa tergores.

Kontras dengan `release.yml` yang sudah benar (gating tanpa `continue-on-error`) — workflow CI seharusnya lebih ketat, bukan lebih longgar.

**Contoh konkret:**

```yaml
# .github/workflows/flutter.yml baris 70, 82, 86
- name: Verify formatting
  continue-on-error: true     # format drift bisa masuk main
- name: Analyze code
  continue-on-error: true     # lint error bisa masuk main
- name: Run unit + integration tests
  continue-on-error: true     # test gagal bisa masuk main
```

**Solusi:**

Hapus 3 baris `continue-on-error: true`. Kalau analyze full belum siap dijadikan blocking (banyak warning pre-existing), prioritaskan `flutter test` sebagai gating dulu.

**Effort:** 10 menit. **Impact:** Sangat tinggi.

---

### 2. Crash reporter tidak terhubung ke catch sites

**Apa masalahnya?**

`lib/core/observability/crash_reporter.dart` punya interface `CrashReporter` dengan default `NoopCrashReporter` (tidak melakukan apa-apa). Hanya 4 tempat di `main.dart` yang panggil `crashReporter.recordError`:
- `FlutterError.onError`
- `PlatformDispatcher.onError`
- FMTC initialise error
- Background service init error

Tidak ada satupun catch block di feature-level yang forward ke crash reporter. `Logger.warn` yang dipakai di 50+ tempat hanya `print()` ke console — tidak persisted, tidak bisa di-pull dari device user.

**Kenapa penting?**

Begitu Sentry / Crashlytics / GlitchTip aktif (rencana v1.1 sesuai komentar di kode), semua bug yang user lapor di lapangan akan invisible. Tim tidak punya cara tahu "tracking saya berhenti tadi siang" itu karena:
- Foreground service di-kill OS?
- POST_NOTIFICATIONS dicabut user?
- GPS service off?
- Crash di isolate background?

Padahal abstraksi sudah disiapkan persis untuk ini.

**Contoh konkret:**

```dart
// tracking_controller.dart:154
} catch (e) {
  Logger.instance.warn('tracking.bg_start_failed', {'error': e.toString()});
  _markBackgroundFailed();
  // ↑ error ini hilang setelah app ditutup. Tidak masuk Sentry.
}
```

**Solusi:**

Inject `CrashReporter` ke `Logger`. Setiap `Logger.warn(key, data)` otomatis panggil:
- `crashReporter.log(key, data)` untuk breadcrumb
- `crashReporter.recordError(...)` kalau level error

Lalu wire Sentry sebagai implementasi konkret di `main.dart`.

**Effort:** 2-4 jam. **Impact:** Sangat tinggi (setelah Sentry hidup).

---

### 3. PRAGMA `foreign_keys = ON` tidak di-set + LogBook FK orphan bug

**Apa masalahnya?**

Drift declare foreign keys di `tables.dart`, tapi SQLite default `PRAGMA foreign_keys = OFF`. Drift tidak otomatis turn on. Akibatnya:
- FK declarations seperti `references(trips)` jadi sekadar dokumentasi
- Bisa insert haul dengan `tripId` yang tidak ada → orphan diam-diam
- Cascade delete tidak terjadi otomatis

Sudah ada bug konkret:

```dart
// tables.dart — LogBookEntries
class LogBookEntries extends Table {
  TextColumn get tripId => text().nullable()();   // ← TIDAK ADA .references(trips, #id)
  TextColumn get haulId => text().nullable()();   // ← TIDAK ADA .references(hauls, #id)
}
```

Saat `deleteHaul()` dipanggil, log_book_entries dengan `haul_id` tersebut tetap nyangkut di DB (bersama catch_items-nya). `LogBookRepository` tidak punya method `deleteByHaulId`.

**Kenapa penting?**

- Storage growth diam-diam — log book yang tidak punya parent haul tetap nyangkut selamanya
- Future export (CSV / Excel) akan bingung "log book ini punya siapa?"
- Integrity assumption di kode bisa salah yang akhirnya bikin null pointer di tempat lain

**Solusi (3 langkah):**

1. Aktifkan FK enforcement di `MigrationStrategy.beforeOpen`:
```dart
beforeOpen: (details) async {
  await customStatement('PRAGMA foreign_keys = ON');
}
```

2. Bikin migrasi v12 yang convert `LogBookEntries.haulId/tripId` jadi proper `.references()` dengan cascade. Plus cleanup orphan yang sudah ada:
```sql
DELETE FROM log_book_entries WHERE haul_id NOT IN (SELECT id FROM hauls);
```

3. Tambah `PRAGMA quick_check` di beforeOpen, log warning ke crash reporter kalau gagal.

**Effort:** 2-3 hari. **Impact:** Tinggi (data integrity).

---

## Tier A — Data integrity & user-facing risk

### 4. Tidak ada backup-restore database

**Apa masalahnya?**

Database SQLite disimpan di `getApplicationDocumentsDirectory()/langgeng_sea.sqlite`. Tidak ada cara user untuk:
- Backup file ini ke storage atau cloud
- Restore dari backup di device baru

Yang ada cuma export GPX, tapi GPX hanya carry sebagian data (track + marker). Yang HILANG kalau user format HP atau ganti device:
- Log book entries (catch per haul, BBM, biaya, weather)
- Catch items (per spesies)
- App settings (alarm preferences, polyline width)
- User profile
- Offline regions metadata

**Kenapa penting?**

Skenario riil: nelayan pakai app 6 bulan, log book penuh data CPUE per spesies. HP rusak / dibersihin pabrik / hilang → semua hilang permanen. Tidak ada cara recovery.

Aplikasi local-first wajib punya export-to-file walaupun tidak ada cloud sync.

**Solusi:**

Settings → "Cadangkan Data" yang:
1. `db.close()`
2. Copy file ke external storage atau temp
3. `Share.shareFiles()` untuk user simpan via WhatsApp / Drive / email

Restore: pick file `.sqlite` atau `.lsea.backup` (zip), validate header magic + schema version, atomic replace, restart app.

Bonus: pre-migration backup otomatis ke `documents/.backups/` setiap kali `schemaVersion` naik.

**Effort:** 1 minggu. **Impact:** Sangat tinggi.

---

### 5. Outlier / speed-jump detection di `_onReading` MISSING

**Apa masalahnya?**

`tracking_controller.dart:377-388` hanya gate pakai `accuracyMeters > 50`. Tidak ada cek inter-fix.

Kalau GPS lompat 1.500m dalam 2 detik (≈ 2.700 km/jam, fisik mustahil untuk perahu trawl), point tetap diterima dan menambah distance + bikin spike di polyline. Ini umum terjadi saat GPS lock baru pulih dari oklusi (kanopi awan tebal, masuk dermaga, di bawah jembatan).

**Kenapa penting?**

Distance & swept area ter-inflate. "Jarak rata-rata tarikan" tidak reliable untuk catch-per-effort calculation. Polyline jadi spike yang misleading saat user lihat history.

**Solusi:**

Simpan `_lastReading.timestamp`, hitung implied speed antar dua fix:
```dart
final dt = reading.timestamp.difference(_lastReading.timestamp);
final dx = GeoCalculator.haversineMeters(_lastReading.latLng, reading.latLng);
final impliedSpeedMps = dx / dt.inSeconds;
final impliedKnots = impliedSpeedMps * 1.94384;

if (impliedKnots > 25) {
  // Drop fix ini dari aggregate (tetap simpan ke DB sebagai raw, tapi
  // jangan tambah ke distance / livePoints).
  return;
}
```

Trawl jarang > 6 knot, threshold 25 knot sudah sangat longgar (untuk speedboat sekalipun).

**Effort:** 2-4 jam. **Impact:** Tinggi (data quality).

---

### 6. Auto-pause / stationary detection MISSING

**Apa masalahnya?**

Tidak ada deteksi "perahu diam". Skenario riil:
- Mesin mogok 30 menit di tengah haul → distance tetap nambah dari jitter (meskipun gate 50m bantu sedikit)
- User lupa "Angkat Trawl" sampai pulang ke pelabuhan → 2 jam logging GPS di port = battery drain + DB bloat + skewed metrics

**Kenapa penting?**

- Battery drain saat user tidak sadar tracking masih jalan
- DB bloat (8.6k row track point per 12 jam, kalau ada 2 jam diam = 2.5k row sampah)
- Metric haul jadi salah (avg speed turun karena ada 2 jam diam, swept area inflate karena distance jitter)

**Solusi:**

Heuristik sederhana:
- Hitung median speed window 5 menit terakhir
- Kalau median < 0.3 knot → masuk state "DIAM"
- Tampilkan banner non-blocking: "Trawl masih merekam — diam selama 5 menit. Lupa angkat?"
- User bisa tap "Angkat sekarang" atau "Lanjutkan tracking"

Tidak perlu auto-stop (false positive bisa frustrating). Cukup nudge.

Bonus advanced: auto-finalize haul kalau diam > 30 menit + screen off + user tidak respons banner. Tapi ini opsional.

**Effort:** 4-8 jam. **Impact:** Tinggi.

---

### 7. `livePoints` rebuild O(n²) + double subscription

**Apa masalahnya?**

Di `tracking_controller.dart:407`:
```dart
state = state.copyWith(
  livePoints: [...state.livePoints, newPoint],  // copy seluruh list per tick
  ...
);
```

Per fix bikin `List<LatLng>` baru sepanjang `n+1`. Trip 8 jam @ 2 detik = 14.400 fix → akumulasi alokasi sekitar 100 juta LatLng instance, garbage collection pressure tinggi.

Lebih buruk: `active_haul_polyline.dart` baca dari dua sumber sekaligus — `trackPointsByHaulProvider` (DB stream) DAN `state.livePoints`. Kedua-duanya rebuild PolylineLayer pada setiap tick.

**Kenapa penting?**

Di Redmi entry-level, lag akan terasa setelah haul 6+ jam. Frame drop, ANR risk meningkat.

**Solusi:**

Pilihan A (cepat): hapus `livePoints` dari `TrackingState`. ActiveHaulPolyline cukup baca DB stream — Drift sudah throttle internal.

Pilihan B (lebih hati-hati): pertahankan tapi pakai bounded buffer (last 200 fix saja untuk live preview). Render full polyline lewat provider terpisah yang baca dari DB.

Plus: wrap rebuild di `PolylineSimplifier` (yang sudah ada di codebase) kalau > 500 fix.

**Effort:** 2-3 jam. **Impact:** Sedang-tinggi.

---

### 8. Tile cache size unbounded + `deleteRegionTiles` adalah no-op

**Apa masalahnya?**

`FmtcTileCacheService.deleteRegionTiles()` adalah NO-OP. Komentar di kode mengakui:
```dart
@override
Future<void> deleteRegionTiles(OfflineRegion region) async {
  // FMTC doesn't have a per-region delete in the store API...
  // For now, just let the region metadata row be removed by the
  // repository; cached tiles stay warm until the user clears them...
}
```

Plus tidak ada size limit / quota. User bisa download 100 region = puluhan GB tanpa peringatan. Tidak ada LRU / TTL.

**Kenapa penting?**

User download region besar 2-3 kali, tiba-tiba HP penuh, salahkan aplikasi. Storage explosion adalah first-line UX disaster.

**Solusi:**

1. Settings → "Penyimpanan Peta" tampilkan total GB + per-region breakdown
2. Hard cap konfigurasi (default 2 GB), warn saat 80%, block download saat 100%
3. LRU cleanup: tile yang tidak diakses > 6 bulan ter-evict pertama
4. Implementasi `deleteRegionTiles` real: query `OfflineTileMath.totalTiles` untuk tile keys, lalu FMTC `removeTile` per key. Atau pakai `tags` field FMTC untuk grouping per region
5. "Hapus semua tile yang tidak terpakai" tombol darurat di Settings

**Effort:** 1.5 minggu. **Impact:** Sedang-tinggi.

---

## Tier B — Safety

### 9. SOS button + low-battery emergency save

**Apa masalahnya?**

App tracking nelayan tanpa fitur safety adalah anomali besar. Tidak ada:
- Tombol SOS / Panic
- Low-battery warning + emergency save
- Geofence keluar zona aman
- Share live location ke kontak darurat

**Kenapa penting?**

Aplikasi ini dipakai nelayan kecil di laut yang punya risiko nyawa. Mesin mogok, cuaca tiba-tiba berubah, kecelakaan — semua bisa terjadi. Tanpa safety feature, app cuma jadi tracker pasif.

Bandingkan dengan Boating, Fishbrain, Navionics — semua punya minimal SOS / share location.

**Solusi (paket minimum):**

1. **Tombol SOS** di home screen (atau persistent FAB):
   - Long-press 3 detik untuk hindari accidental tap
   - Kirim WhatsApp ke kontak darurat (lat/lng + Google Maps link)
   - Pakai `url_launcher` ke `wa.me/<nomor>?text=<encoded message>`
   - Setting → "Kontak Darurat" untuk save 1-3 nomor

   Effort: 1 hari.

2. **Low-battery emergency save**:
   - Saat baterai < 15% sambil recording → force flush DB
   - Tampilkan warning besar: "Baterai hampir habis. Simpan posisi?"
   - Offer "Bagikan posisi terakhir ke kontak darurat" (auto-fill koordinat)

   Effort: 4 jam.

3. **Geofence keluar zona aman** (advanced):
   - User define lingkaran "zona aman" (radius 30km dari home port)
   - Alarm kalau keluar
   - WPP zone overlay Indonesia (zona penangkapan resmi)

   Effort: 2-3 hari.

4. **Man-overboard detection** (paling advanced):
   - Deteksi sudden speed drop 5→0 knot dalam 1 detik + heading random
   - Audible alarm + auto-share lokasi
   - Butuh tuning false-positive

   Effort: 1 minggu, parkir untuk v2.

**Effort total minimum (item 1 + 2):** 1-2 hari. **Impact:** Sangat tinggi (safety).

---

### 10. GPS gap visualization missing

**Apa masalahnya?**

Saat sinyal GPS hilang (kabut tebal, masuk area teduh, GPS error sementara):
- Background service tidak emit fix selama 5 menit
- Lalu emit fix lagi 2km dari posisi terakhir
- Polyline draw garis lurus menyilangi 2km itu — padahal user sebenarnya tidak lewat sana

Distance metric ikut salah karena haversine 2km itu masuk total.

**Kenapa penting?**

Track history jadi misleading. Distance haul tidak akurat. User bingung kenapa ada garis lurus aneh di tengah laut.

**Solusi:**

1. Detect gap: `timestamp[i] - timestamp[i-1] > 60 detik`
2. Insert flag `is_gap_start` ke point berikutnya (kolom baru di tables)
3. Renderer split polyline jadi multiple segments di gap, render gap segment dashed/translucent
4. Distance: jangan tambahkan leg yang gap-nya > 60s

**Effort:** 4-6 jam. **Impact:** Sedang.

---

## Tier C — UX polish & quality

### 11. Pagination + search di History

**Apa masalahnya?**

`TripRepository.listSummaries()` fetch semua trip + N+1 query haul per trip lalu di-aggregate in-memory. Komentar di kode bilang "fine up to thousands of trips" — tidak benar.

Tiap kali `tripDao.watchAll()` emit (sering), `asyncMap((_) => listSummaries())` jalan ulang full N+1.

`HistoryScreen` pakai ListView non-paginated. Dengan 1000+ trip, scroll smooth, tapi initial load dan setiap stream re-emit = blocking IO + UI jank.

Plus: tombol filter di AppBar `onPressed: null` dengan tooltip "Filter (segera)" — UX sudah berjanji ada, tapi tidak terkirim.

**Solusi:**

1. DAO baru: `findPaged(offset, limit)`, `searchByName(query, limit)`
2. Denormalize `total_distance_meters` dan `haul_count` ke kolom `trips` (kolom baru di v12) supaya tidak perlu N+1
3. `HistoryScreen` pakai `ListView.builder` dengan `infinite_scroll_pagination` atau cursor-based
4. Filter functional: date range, has logbook, has imported, by home_port, by trawl width
5. Wire tombol filter yang sekarang disabled

**Effort:** 1.5 minggu. **Impact:** Sedang.

---

### 12. Soft delete + recycle bin

**Apa masalahnya?**

Semua delete adalah hard delete:
- `MarkerDao.deleteMarker`
- `HaulDao.deleteHaul`
- `TripDao.deleteTrip`
- `LogBookDao.deleteEntry`
- `ImportedDatasetDao.deleteDatasetCascade`

Semua langsung `DELETE FROM`. Tap delete tidak dapat di-undo selain via dialog konfirmasi.

**Kenapa penting?**

Di laut dengan tangan basah / sarung tangan, mistap sering. Kalau user accidentally delete trip yang sudah lama, tidak ada cara recovery.

Recycle bin pattern populer dan murah secara DB.

**Solusi:**

1. Tambah `deleted_at INTEGER NULL` di `markers`, `trips`, `hauls`, `imported_datasets` (migrasi v12)
2. Semua DAO read filter `WHERE deleted_at IS NULL`
3. Hard-delete jadi `_purge` yang dipanggil oleh background job (umur > 30 hari) atau tombol "Kosongkan Sampah"
4. Settings → "Tempat Sampah" tampil semua item di-soft-delete dengan tombol Pulihkan
5. SnackBar `undo` setelah delete (5 detik) tetap soft-delete + restore-pada-undo

**Effort:** 1 minggu. **Impact:** Sedang.

---

### 13. Adaptive sampling rate

**Apa masalahnya?**

Background isolate hardcode `intervalDuration: 2s` (`flutter_background_tracking_service.dart:591`). Tidak adapt dengan kondisi.

Diam di port = 2 detik per fix berlebihan (battery drain percuma). Steaming straight 6 knot = 5 detik cukup, tidak akan kehilangan bentuk track. Trawl manuver tajam mungkin butuh 2 detik.

**Kenapa penting?**

Battery saving 30-50% claim realistis untuk trip 10 jam. Itu beda antara "bisa jalan trip 12 jam" vs "HP mati di tengah trip".

**Solusi:**

Heuristik:
- Speed < 0.5 knot → 30s interval
- Speed 0.5-3 knot (trawling slow) → 2s
- Speed > 3 knot (steaming) → 5s
- Heading change > 30° dalam window → turunkan interval ke 2s sementara

Foreground stream `LocationAccuracy.high` + `distanceFilter: 2m` juga tidak adapt — sama treatment.

**Effort:** 4-6 jam. **Impact:** Sedang.

---

### 14. Speed/heading smoothing (rolling median)

**Apa masalahnya?**

`live_stats_panel.dart` tampilkan `currentSpeedKnots` langsung dari fix terakhir. Hasilnya nilai bouncy 0.0 → 1.4 → 0.7 → 2.1 setiap detik di kondisi GPS noise normal.

User akan baca "kecepatan goyang" walaupun perahu konstan.

**Kenapa penting?**

UX issue sederhana tapi mengurangi trust user pada data. Kalau angka goyang, user mikir "GPS-nya ngaco".

**Solusi:**

Rolling median 5 sampel (atau EMA dengan α≈0.3) sebelum ditampilkan. Kalman 1-D untuk speed sebenarnya overkill — rolling median sudah 90% solution.

Heading sudah ditangani lewat circular mean untuk avg, tapi current heading di panel langsung pakai `reading.headingDegrees` mentah → noisy juga saat boat speed marginal.

**Effort:** 3-4 jam. **Impact:** Sedang (UX).

---

### 15. Skeleton screen + error state reusable

**Apa masalahnya?**

22 lokasi pakai `CircularProgressIndicator` polos. Untuk daftar (riwayat trip, marker, dataset), spinner di tengah layar memberi kesan stuck.

Error state generic — exception text di-expose ke user:
```dart
// markers_list_screen.dart:111
error: (e, _) => Center(child: Text('Error: $e')),
```

Di nelayan target, `DriftWrappedException: foo bar` tidak actionable.

**Solusi:**

1. **Skeleton card widget** di `core/widgets/skeleton_card.dart` — neutral card dengan shimmer/pulse seukuran TripCard. Untuk daftar: 5-7 skeleton saat loading, bukan satu spinner

2. **ErrorStateView reusable** di `core/widgets/`:
   - Icon + judul ramah ("Tidak bisa memuat penanda")
   - CTA "Coba lagi" yang trigger `ref.invalidate(provider)`
   - Optional "lihat detail" yang expand teknis stack trace
   - Log raw exception ke `Logger.instance.error`, tapi UI cuma tunjukkan kategori user-friendly

**Effort:** 1-2 hari. **Impact:** Sedang.

---

### 16. CSV export (logbook + summary)

**Apa masalahnya?**

Hanya GPX 1.1 (full) dan LSEA-JSON (legacy, per-trip only). CSV missing.

GPX bagus untuk peta tapi useless buat administrasi. Nelayan / koperasi / PPL minta laporan tabel: spesies, berat, BBM, biaya, hari tangkap.

**Kenapa penting?**

CSV langsung buka di Excel/Sheets, format universal. Cost vs value paling tinggi dari export format mana pun.

**Solusi:**

`CsvExporter` class baru di `export_import/data/`. Tiga sheet logical:

1. `trips.csv`: id, name, started_at, ended_at, home_port, total_distance, total_swept_area_ha, haul_count
2. `hauls.csv`: trip_id, order, started_at, duration, distance, swept_area, avg_speed, log_book_yes_no
3. `catches.csv`: trip_id, haul_id, species, weight_kg

ExportScreen tambah toggle "Format: GPX / CSV / Keduanya". Filter sama dengan GPX (date range, trip ids).

**Effort:** 3-5 hari (paket `csv` Dart sudah mature). **Impact:** Sedang-tinggi.

---

### 17. Import deduplication

**Apa masalahnya?**

`GpxImporter.import()` selalu `Uuid().v4()` baru untuk dataset row dan children. Re-import file yang sama = duplikasi penuh (haul, trackpoint, marker semua double).

Tidak ada cek "trip dengan `lsea:trip id` ini sudah pernah di-import". Tidak ada cek marker collision (lat/lon ± toleransi + name match).

**Kenapa penting?**

User pasti akan re-import file yang sama (tukar via WhatsApp 2x). Saat ini = data dobel, 2x storage, salah agregasi di Dashboard stats.

**Solusi:**

1. Saat parse, hash konten file (atau pakai `lsea:exporter exportedAt` + `lsea:trip id`) sebagai fingerprint
2. Sebelum commit, query `imported_datasets WHERE fingerprint = ?` → kalau exist, dialog "Sudah pernah diimpor pada {date}. Lewati / Ganti / Tetap impor?"
3. Per-trip dedup: kalau `lsea:trip id` cocok dengan trip user sendiri (datasetId NULL), warning "Trip ini punya Anda sendiri, bukan impor"
4. Marker dedup: kalau lat/lon dalam radius 50m + nama persis = skip default

**Effort:** 1 minggu (termasuk UI dialog). **Impact:** Sedang.

---

## Tier D — Engineering hygiene

### 18. Widget test coverage hampir nol

**Apa masalahnya?**

Cuma 5 testWidgets total:
- `app/test/widget_test.dart` (1 smoke)
- `app/test/features/history/follow_haul_picker_sheet_test.dart` (4)

Tidak ada widget test untuk: MapScreen, DashboardScreen, SettingsScreen, OnboardingScreen, HistoryScreen, MarkersListScreen, LogBookFormScreen, ExportScreen, OfflineRegionsScreen, CompassScreen, PermissionChecklistSheet, DeviceStatusCard, NavigationPanel.

Domain math di-cover bagus (formatters, geo_calculator, tracking_mode), tapi UI murni tidak terjamah.

**Kenapa penting?**

UI regression saat ini hanya ketahuan saat manual smoke test. Setiap PR = potential breakage di area lain.

**Solusi:**

Mulai dari sheet & dialog (lebih mudah di-isolasi daripada full screen):
- PermissionChecklistSheet — state per permission
- HaulSummarySheet — action enum routing
- ProfileForm validation
- DeleteConfirmDialog
- LayersExpandable toggle behavior

Pakai `mocktail` (sudah ada di dev_dependencies).

**Effort:** 2-3 hari batch pertama. **Impact:** Sedang.

---

### 19. Background tracking service tidak punya unit test langsung

**Apa masalahnya?**

`flutter_background_tracking_service.dart` (678 baris) adalah file paling kompleks di repo: foreground service start, isolate handler, retry exponential, POST_NOTIFICATIONS gate, channel-importance check, wakelock, OEM workaround.

Test yang ada (`tracking_controller_test.dart`) override `BackgroundTrackingService` lewat `FakeGpsService` saja. Service yang sesungguhnya tidak pernah dieksekusi di test.

Production crash yang sudah teridentifikasi di komentar (PR #27 R1, PR #31, PR #41) mengindikasikan area ini secara historis rapuh.

**Solusi:**

Refactor: `FlutterBackgroundTrackingService` terima `BackgroundServicePlatform` di constructor, suntik via provider. Tulis 8-10 test untuk:
- notification permission denied
- channel importance none
- isRunning=true existing
- start exception
- retry exhaustion

**Effort:** 1.5 hari. **Impact:** Sedang-tinggi (regresi prevention).

---

### 20. `MapScreen` god-class 2.069 baris

**Apa masalahnya?**

Tanggung jawab MapScreen sekarang: render map, follow user, heading-up rotation, focus marker/trip/haul, permission flow + auto-dismiss, crash recovery dialog, marker pick tooltip overlay, long-press menu, polyline tap popup, GPS service status stream, offline regions overlay, marker creation 3 jalur, recording-state UI, navigation panel, scale indicator.

`setState` dipanggil 13× di file ini saja.

**Kenapa penting?**

- Tidak bisa di-widget-test (fan-out provider terlalu lebar)
- Perubahan kecil sering trigger regression di area lain
- Merge conflict risk tinggi kalau multiple PR sentuh map

**Solusi:**

Pisah jadi:
- `MapScreenController` (Notifier untuk follow/heading-up/popup state)
- `_PermissionFlow` widget
- `_FocusController` (handle focus marker/trip/haul)
- `_MarkerPickFlow` per concern
- Map widget tinggal compose layer

Mulai dari `_focusOn*` (paling self-contained).

**Effort:** 3-5 hari. **Impact:** Sedang (long-term).

---

### 21. UI bypass controller, langsung mutasi repository

**Apa masalahnya?**

13 file presentation memanggil `ref.read(xRepositoryProvider).<mutation>` langsung:
```dart
// haul_detail_screen.dart:139
await ref.read(haulRepositoryProvider).setColor(haul.id, color);

// trip_detail_screen.dart:159
await ref.read(tripRepositoryProvider).deleteTrip(trip.id);

// marker_info_sheet.dart:257
await ref.read(markerRepositoryProvider).delete(marker.id);
```

**Kenapa penting?**

Tidak ada satu titik untuk:
- Audit log / breadcrumb
- Optimistic update + rollback
- Cross-feature coordination (mis. delete trip → cancel ongoing export)
- Testability (harus inject DB lewat ProviderContainer untuk widget test)

`TrackingController` sudah benar (semua mutasi haul/trip lewat sana). Pola yang sama harusnya dipakai untuk MarkerController, LogBookController, OfflineRegionController, ImportedDatasetController, UserProfileController.

**Solusi:**

Bikin Notifier per feature dengan method mutasi, refactor 13 call site. Mulai dari yang paling sering dimutasi (marker → 4 call sites; trip & haul → 4 call sites).

**Effort:** 2-4 hari. **Impact:** Sedang (long-term).

---

### 22. Dependabot + pre-commit + coverage report missing

**Apa masalahnya?**

- Tidak ada `.github/dependabot.yml` — dependency CVE / minor update tidak otomatis di-track (`pubspec.yaml` 30+ deps dengan caret range)
- Tidak ada `.husky/`, `lefthook.yml`, atau equivalent — dev bisa commit kode yang gagal `dart format` atau `flutter analyze`
- `flutter test --coverage` tidak ada di workflow, tidak ada codecov upload — tidak ada metrik objektif coverage untuk monitor regresi
- Hanya 1 build profile efektif (debug & release) — tidak ada `staging` flavor untuk uji APK release-build dengan API/asset berbeda

**Solusi:**

- `dependabot.yml`: 15 menit
- Lefthook + format/analyze hook: 1 jam
- Coverage step + upload-artifact: 30 menit
- Flavor staging (kalau memang dibutuhkan): 2-3 jam

**Effort:** Setengah hari total. **Impact:** Sedang (preventif).

---

## Tier E — Quick wins (1-2 hari total)

### 23. Hardcoded `Colors.green/red/blue` di marker — bobrok di dark mode

**Lokasi:** `lib/features/marker/presentation/markers_list_screen.dart:385-390`

```dart
Color _categoryColor(MarkerCategory cat) => switch (cat) {
  MarkerCategory.productive => Colors.green,
  MarkerCategory.hazard     => Colors.red,
  MarkerCategory.port       => Colors.blue,
  MarkerCategory.other      => Colors.grey,
};
```

Material legacy colors ignore design tokens (`tokens.success`, `tokens.danger`, `colors.primary`, `tokens.textTertiary`). Di dark mode, `Colors.red` (#F44336) menyilaukan vs `tokens.danger` (#EF5350).

**Solusi:** Ganti ke `MarkerCategory.colorOf(BuildContext context)` extension yang baca tokens. Sekalian unify dengan `marker_pin.dart` (yang juga punya color mapping sendiri).

**Effort:** 15 menit.

---

### 24. Migrate 9× `withOpacity()` ke `withValues(alpha:)`

Flutter 3.27+ deprecate `withOpacity`. Sebagian besar codebase sudah migrate, sisanya inkonsisten:
- `markers_list_screen.dart:206, 271, 417, 434`
- `dashboard_screen.dart:207, 562, 566, 624`
- `map_screen.dart:1869`

**Solusi:** Find & replace careful (jangan ubah string yang bukan API call).

**Effort:** 30 menit.

---

### 25. Touch target 32dp — melanggar `AppSizes.touchTargetMin = 48`

`app_sizes.dart:31` declare `touchTargetMin = 48` sebagai contract weatherproof, tapi banyak IconButton dipres ke 32x32:
- `track_popup.dart:165-174`
- `map_screen.dart:1604-1613` (overlay context chip close)
- `markers_list_screen.dart:284-292` (three-dot)
- `log_book_form_screen.dart:302-307` (trash icon)

PRD requirement = deck nelayan basah & goyang. 32px hit area = pasti miss-tap.

**Solusi:** Ganti `BoxConstraints(minWidth: 32, minHeight: 32)` → `BoxConstraints(minWidth: AppSizes.touchTargetMin, minHeight: AppSizes.touchTargetMin)`. Visual size icon tetap 18-22, tapi hit area 48.

**Effort:** 15 menit.

---

### 26. Confirmation dialog tidak konsisten

`DeleteConfirmDialog` sudah well-designed (icon merah, FilledButton danger, copy menjelaskan apa yang akan terhapus). Tapi tidak semua call-site memakainya:

- `markers_list_screen.dart:355-371` — pakai raw AlertDialog, kedua tombol `TextButton` neutral, tidak ada warna danger
- `imported_datasets_screen.dart:302-326` — pakai `FilledButton.tonal` dengan custom danger, beda lagi
- `map_screen.dart:704-744` — recovery dialog, yet another pattern

**Solusi:** Ganti semua call-site jadi `DeleteConfirmDialog.show()`. Untuk imported datasets perluas DeleteConfirmDialog supaya menerima `body` lebih panjang.

**Effort:** 30 menit.

---

### 27. Form validation pakai SnackBar — pindahkan ke inline validator

**Lokasi:** `lib/features/onboarding/presentation/widgets/profile_form.dart:83-93`, `add_marker_dialog.dart:39-46`

```dart
final validationError = UserProfile.validate(...);
if (validationError != null) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(validationError)),
  );
  return;
}
```

SnackBar default 4 detik — user belum baca selesai sudah hilang. Lebih buruk: snackbar muncul di atas tombol Simpan, kalau user re-tap dalam panik snackbar tertimpa.

**Solusi:** `Form` + `TextFormField` + `validator:` sudah dipakai sebagian. Pindahkan SEMUA validation ke validator-level. SnackBar cuma untuk async error (network/DB).

**Effort:** 1-2 jam.

---

### 28. Notif `setForegroundNotificationInfo` setiap fix — battery drain

**Lokasi:** `flutter_background_tracking_service.dart:636-644`

Update notif text setiap fix di background isolate. Pada 2s cadence = 1.800 update/jam. Padahal text-nya `"GPS aktif untuk $shortHaul"` — tidak berubah dari fix ke fix kecuali haulId beda.

**Solusi:** Update notif text saat berubah saja. Atau update tiap 30 detik dengan info berguna (distance, duration).

**Effort:** 30 menit.

---

### 29. Dashboard N+1 query

**Lokasi:** `dashboard_stats_provider.dart:198-207`

```dart
for (final entry in logEntries) {
  if (entry.haulId == null) continue;
  final catchQuery = db.select(db.catchItems)
    ..where((c) => c.logBookEntryId.equals(entry.id));
  final items = await catchQuery.get();  // ← query per entry
  ...
}
```

Sudah ada `catchItems` di-fetch sekali di atas (line 154), tapi dilakukan lagi per entry untuk top-spot. 200 trip × 10 entry = 2000 query.

**Solusi:** Pakai `catchItems` yang sudah di-fetch + group in-memory. 5-baris perubahan.

**Effort:** 1-2 jam.

---

### 30. Notif click handler missing

Tap notif persistent "Merekam" tidak bawa user ke map screen. Standar Android — kalau ada persistent notif, click harusnya bring app to foreground + navigate ke layar relevan.

**Solusi:** Set pending intent di notification builder ke MainActivity dengan extra `route=/map`. MainActivity baca extra, deeplink lewat go_router.

**Effort:** 1 jam.

---

### 31. Trip Detail title bilingual

**Lokasi:** `trip_detail_screen.dart:90` — `Text('Trip Detail')` ← satu-satunya bilingual mix saat sisanya Indonesia

**Solusi:** Ganti jadi "Detail Trip" (urutan Indonesia: noun + modifier).

**Effort:** 5 menit.

---

### 32. Localization `AppStrings` cuma cover 20%

`AppStrings` (`lib/core/constants/app_strings.dart`) hanya berisi ~30 konstanta. Sisanya hardcoded inline. Banyak yang masih English jargon di tengah Indonesia:

- `map_screen.dart:1383` — `'Background GPS gagal. Tetap merekam di foreground.'` ("Background", "foreground" English)
- `map_screen.dart:1382` — `'Background GPS restarting…'` (full English)
- `dashboard_screen.dart:75` — error string bilingual

**Solusi (Phase 1, cepat):**
- Expand `AppStrings` mencakup semua user-facing copy
- Move title-title screen ke konstanta
- Ganti "Background" → "latar belakang", "foreground" → "saat aplikasi terbuka"

**Solusi (Phase 2):**
- Aktifkan `flutter_localizations`, generate `.arb` bundle
- Mulai dengan `id_ID` saja (target user 100% Indonesian)
- English jadi optional fallback untuk debug/QA

**Effort:** 1-2 hari (Phase 1).

---

## Yang sudah bagus, jangan diutak-atik

Untuk transparansi, ini area yang sudah solid dan tidak perlu diganggu:

1. **Permission flow + foreground service handling** — race Android 14 sudah dipikirkan, channel-disable case ditangani, idempotent guard `isRunning()`, NotificationPermissionDeniedException + NotificationChannelDisabledException terdefinisi rapi

2. **Crash recovery orphan haul** (`tracking_controller.dart:269`) — finalize daripada crash dialog loop

3. **Exponential retry 1s/2s/4s** dengan reset counter saat status running pulih

4. **Zone guard di main.dart** — FlutterError + PlatformDispatcher + runZonedGuarded lengkap. Bahkan ada fallback NoopCrashReporter di zone handler kalau container belum siap

5. **Incremental aggregate math** di tracking controller — per-tick flat cost, bukan re-sum semua. Detail yang sering miss di app lain

6. **Subscription discipline** — semua 5 StreamSubscription punya cancel() di lifecycle yang benar

7. **Riverpod pattern** — Notifier-based controllers, provider co-located dengan repo, override-friendly untuk test

8. **Crash reporter abstraction** — Interface pattern dengan Noop default. Sentry nanti tinggal swap

9. **Dartdoc** — 3.439 baris `///` untuk 172 file. Banyak rationale historis (PR #27, #31, #40) terdokumentasi langsung di kode

10. **Schema Drift dengan migrasi berurutan** v1→v11. Test migrasi ada walaupun belum punya schema dump

11. **Release signing** — smart fallback ke debug signing kalau key.properties tidak ada. CI bisa bikin sideload-able APK tanpa secrets di repo

12. **Bootstrap robustness** — fallback NoopCrashReporter di zone handler, FMTC init dengan try-catch, BG service init defensive

13. **Test helpers** — FakeGpsService, FakeNavigationAlertService sudah ada di test/helpers/. Base bagus untuk expand widget test

14. **Navigation alarm state machine** dengan debounce + cancel-on-flip (`_advanceAlarmState` follow-track) sudah benar

15. **PolylineSimplifier** RDP iterative tersedia, tinggal dipakai juga di live polyline

---

## Roadmap eksekusi (saran)

### Sprint 1 (1 minggu) — Foundation tidak retak

Total effort: ~3 hari engineer.

1. **#1 CI gating** (10 menit) — Hapus `continue-on-error` di analyze + test step
2. **#2 Crash reporter wired** (2-4 jam) — Bridge Logger ↔ CrashReporter, wire Sentry di main.dart
3. **#3 FK pragma + log book FK fix** (2-3 hari) — Migrasi v12 dengan PRAGMA + cleanup orphan
4. **#7 livePoints fix** (2-3 jam) — Bounded buffer atau hapus dari TrackingState
5. **#28 Notif throttling** (30 menit) — Update only when changed
6. **Quick wins #23, #24, #25, #26** (~2 jam total)

### Sprint 2 (1 minggu) — Data quality & safety baseline

Total effort: ~5 hari engineer.

1. **#5 Outlier detection** (2-4 jam) — Speed-jump filter di `_onReading`
2. **#6 Auto-pause / stationary** (4-8 jam) — Banner "lupa angkat?"
3. **#9 SOS button + low-battery emergency** (1-2 hari) — Paket safety minimum
4. **#10 GPS gap visualization** (4-6 jam) — Detect gap, dashed segment
5. **#14 Speed/heading smoothing** (3-4 jam) — Rolling median di live stats

### Sprint 3 (1-2 minggu) — User-facing polish

1. **#4 Backup-restore DB** (1 minggu) — Settings → Cadangkan + Restore
2. **#15 Skeleton + ErrorStateView** (1-2 hari) — Reusable widgets
3. **#16 CSV export** (3-5 hari) — Trips, hauls, catches sheets

### Backlog (rolling)

- #8 Tile cache size limit + per-region delete
- #11 Pagination history
- #12 Soft delete recycle bin
- #13 Adaptive sampling rate
- #17 Import dedup
- #18-#21 Test coverage + refactor MapScreen + extract controllers
- #22 Engineering hygiene (dependabot, pre-commit, coverage)
- #27, #29, #30, #31, #32 Quick wins lainnya

---

## Estimasi total

- **Sprint 1 + 2** = ~2 minggu engineer → menutup ~70% risiko paling kritis
- **Sprint 3** = 1-2 minggu engineer → fitur yang user langsung lihat dampaknya
- **Backlog** = rolling, bisa dikerjakan paralel dengan PR feature lain

Saran: mulai dari **Sprint 1** dulu (foundation) sebelum kerjakan apapun. Tanpa crash reporter (#2), semua bug fix berikutnya jalan blind. Tanpa CI gating (#1), kode rusak bisa lewat tanpa terdeteksi. Tanpa FK enforcement (#3), data corruption bisa nyangkut diam-diam.

Setelah Sprint 1, urutan Sprint 2 dan 3 fleksibel sesuai prioritas bisnis Anda.
