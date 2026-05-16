# PR #27 — Tracking Crash Fix + Detailed GPX Export

**Branch:** `feat/tracking-crash-and-export-upgrade-pr27` → `main`
**Status:** Planning (this doc) → Implementation
**Depends on:** PR #26 (`feat/integrate-pr23-pr24`) merged to `main`

> Catatan untuk pelanjut konteks: kalau Anda baca dokumen ini fresh,
> mulai dari `tasks.md` untuk daftar pekerjaan langkah-demi-langkah.
> Dokumen ini cuma "kenapa-nya"; `design.md` "bagaimana-nya".

---

## Konteks user-side (sumber masalah)

### Crash 1 — Battery permission

> "ketika saya tracking sekarang muncul pemberitahuan mengizinkan di
> belakang layar terkait baterai itu. nah ketika saya pencet izinkan
> aplikasi crash force close."

User tekan tombol **MULAI** (mulai tarikan). Beberapa saat kemudian
sistem munculkan dialog Android **"Allow Langgeng Sea to ignore battery
optimizations?"**. User tekan **Allow**. Aplikasi langsung force-close.

### Crash 2 — Resume haul setelah crash 1

> "kemudian saya buka lagi kan otomatis ada popup dong mau melanjutkan
> tracking atau akhiri dan ketika saya tekan tracking app force-close
> lagi."

User buka aplikasi lagi. Karena crash sebelumnya meninggalkan haul
dengan status `recording` di DB, dialog crash recovery muncul:
"Tarikan #N masih tercatat sedang merekam. Anda bisa melanjutkan
tracking atau menutup tarikan…". User tekan **Lanjutkan**. Force-close
lagi.

### Lingkungan testing

- HP: Redmi Note 10 Pro
- ROM: PixelOS (custom ROM, bukan stock MIUI)
- Versi Android: kemungkinan Android 14+ (PixelOS biasanya track ke
  AOSP terbaru — minimal API 34)

Catatan penting: **PixelOS = stock-Android-like**, bukan MIUI.
Artinya bug bukan karena OEM-quirk Xiaomi (yang sering jadi tersangka
biasa) — bug ada di kode kita atau di interaksi
`permission_handler` × `flutter_background_service` × Android 14+
foreground service rules. Itu kabar baik untuk debugging — tidak
butuh OEM-specific workaround.

---

## Konteks user-side (perbaikan ekspor)

### Yang user minta

> "untuk eksport ini saya ingin lebih detail. dan boleh memilih antara
> ekport jalur saja atau penanda saja dan juga boleh keduanya.
> kemudian saya ingin lengkap beserta nama yang mengekport tadi /
> nama kapalnya. kemudian warna jalur, kategori penanda. kemudian
> data tarikannya dll."

### Keputusan yang sudah diambil bersama user

1. **Format**: GPX saja (sudah dikonfirmasi). Field-field tambahan
   yang tidak ada di skema GPX 1.1 native akan masuk ke
   `<extensions>` dengan namespace `xmlns:lsea`. Aplikasi pihak
   ketiga (Google Earth, Garmin, Strava, OsmAnd) tetap bisa baca
   waypoints + tracks; aplikasi Langgeng Sea sendiri (atau pengirim
   yang sama-sama pakai Langgeng Sea) bisa baca data lengkap.

2. **Field yang masuk** (✅ confirmed by user):

   **Identitas eksportir:**
   - Nama nelayan (dari `UserProfile.ownerName`)
   - Nama kapal (dari `UserProfile.vesselName`)
   - Tanggal + waktu ekspor (auto, bukan input user)

   **Per Trip:**
   - Nama trip
   - Tanggal mulai/akhir
   - Total jarak, durasi, sapuan (rolled-up dari semua haul)

   **Per Tarikan (Haul):**
   - Nama tarikan + `orderIndex` (`Tarikan #1`, `Tarikan #2`, …)
   - **Warna jalur** (`Haul.colorValue`) — di-encode di
     `<extensions>` sebagai ARGB hex (`#FF4FC3F7`)
   - Jarak, durasi, kecepatan rata-rata, arah rata-rata, luas
     sapuan
   - (User TIDAK minta: log book, tangkapan, lebar trawl per
     tarikan, status. Skip dulu, tambah belakangan kalau perlu.)

   **Per Penanda (Marker):**
   - Nama penanda
   - Kategori (productive / hazard / port / other) — di-encode di
     `<sym>` (Garmin-compatible icon name) + `<extensions>`
   - Koordinat
   - Catatan
   - Tanggal dibuat

3. **Filter ekspor** (✅ confirmed):
   - Mode: Jalur saja / Penanda saja / Keduanya (sudah ada)
   - **Tambahan saran saya yang user setujui ("semua")**:
     - Filter rentang tanggal (7 hari / 30 hari / kustom range
       picker)
     - Filter per-trip (centang trip mana saja)
     - Filter kategori penanda (centang kategori mana saja)

4. **Layar ekspor** (✅ Opsi A confirmed):
   - **Settings → Ekspor Data**: tetap ada, sekarang dengan filter
     lengkap di atas
   - **Trip detail → Bagikan**: tetap ada (bottom sheet ringkas
     untuk share 1 trip cepat)

---

## Requirements

### Requirement R1 — Tracking tidak boleh crash saat permission battery dialog dijawab

**User story:** Sebagai nelayan yang baru install/update aplikasi, saat
saya tekan **MULAI** untuk pertama kali, dialog "izinkan di belakang
layar" muncul; saat saya tekan **Izinkan**, aplikasi tidak boleh
crash dan tracking harus berjalan normal.

**Acceptance criteria:**

```
WHEN tombol MULAI ditekan untuk pertama kali
  AND status `Permission.ignoreBatteryOptimizations` adalah `denied`
THEN dialog OS muncul
  AND user bisa tap Izinkan tanpa aplikasi crash
  AND tracking berhasil mulai (notifikasi foreground service muncul)
  AND title bar pindah ke "MEREKAM TARIKAN"

WHEN user tap Tolak di dialog itu
THEN aplikasi tidak crash
  AND tracking tetap mulai (cuma akurasi saat layar mati menurun;
      tidak fatal)
  AND di-log warning ke Logger (untuk debugging)

WHEN user sudah pernah Izinkan sebelumnya
THEN dialog tidak muncul lagi
  AND tracking mulai langsung
```

**Correctness properties:**

- `Permission.ignoreBatteryOptimizations.request()` HARUS dibungkus
  `try/catch` yang menelan exception, BUKAN propagate ke caller
- `_service.startService()` (Android foreground service) HARUS dipanggil
  dengan delay minimal setelah permission flow tuntas, supaya
  Android 14+ requirement "notification dalam 5 detik" tidak
  ter-violate
- Permission flow TIDAK boleh terjadi di dalam `runZonedGuarded`
  yang sama dengan startup app — kalau permission dialog throw,
  jangan sampai zone-level handler ikut crash app

### Requirement R2 — Crash recovery resume tidak boleh crash

**User story:** Sebagai nelayan yang sebelumnya mengalami crash, saat
saya buka aplikasi lagi dan dialog "Lanjutkan tracking" muncul, saya
bisa tekan **Lanjutkan** dan aplikasi melanjutkan tracking tanpa crash
(bahkan kalau permission battery sebelumnya tidak granted).

**Acceptance criteria:**

```
WHEN aplikasi dibuka pasca crash
  AND ada haul dengan status `recording` di DB
THEN dialog crash recovery muncul

WHEN user tekan Lanjutkan
THEN tracking resume tanpa crash
  AND polyline sebelumnya muncul kembali di peta
  AND metric counter resume dari nilai DB

WHEN user tekan Tutup
THEN haul di-finalize (status -> completed) dengan data yang ada
  AND tidak ada haul yang stale (`recording`) di DB
  AND aplikasi tidak crash
```

**Correctness properties:**

- `resumeHaul()` TIDAK boleh re-request permission battery
  (sudah pernah granted/denied di session sebelumnya — flag
  `permission_handler` masih track-nya). Cukup re-start foreground
  service.
- `_bgService.start()` di resume path HARUS guard kalau service
  sebelumnya masih running (sisa-sisa session kemarin). Kalau
  running, stop dulu lalu start ulang.
- `Trip` lookup di `resumeHaul()` HARUS tahan kalau trip parent
  sudah dihapus (misal user manual hapus dari Riwayat tapi haul
  recovery-nya ketinggal). Saat ini fungsi crash sunyi karena
  `state.activeTrip = null` lalu code path lain expect non-null.

### Requirement R3 — Permission battery juga bisa diatur dari Settings

**User story:** Sebagai nelayan yang awalnya menolak permission
battery (atau uninstall-install ulang dan ingin re-grant), saya bisa
buka Settings → "Pengaturan Lanjutan" dan toggle/buka permission
battery dari sana, tanpa harus mulai tarikan dulu.

**Acceptance criteria:**

```
WHEN user buka Settings
THEN ada tile "Akurasi Saat Layar Mati" / "Pengaturan Daya"
  AND tile menunjukkan status saat ini (Aktif / Belum diatur)

WHEN status Belum diatur, user tap tile
THEN dialog permission OS muncul
  AND saat user pilih Izinkan, status berubah ke Aktif tanpa restart

WHEN status sudah Aktif, user tap tile
THEN buka layar Settings sistem (Battery → Battery optimization)
  via openAppSettings() supaya user bisa cabut/ganti manual
```

**Correctness properties:**

- Tile harus reaktif terhadap perubahan permission saat app resume
  dari background (gunakan `WidgetsBindingObserver.didChangeAppLifecycleState`)
- Status check pakai `Permission.ignoreBatteryOptimizations.status`,
  rendering harus tahan kalau platform return PermissionStatus
  yang tidak `granted/denied/permanentlyDenied` (defensive enum
  exhaustiveness)

### Requirement R4 — GPX export memuat semua field yang user minta

**User story:** Sebagai nelayan yang ingin backup atau berbagi data
ke nelayan lain, file GPX yang saya hasilkan harus berisi: identitas
saya (nama, kapal), tanggal ekspor, daftar trip dengan stats lengkap,
daftar tarikan dengan warna jalur + stats, daftar penanda dengan
kategori dan catatan.

**Acceptance criteria:**

```
GIVEN UserProfile berisi {ownerName: "Pak Budi", vesselName: "KM Bahari"}
  AND ada 1 trip selesai dengan 2 haul (warna biru, hijau)
  AND ada 3 marker (1 productive, 1 hazard, 1 port)
WHEN user pilih "Semua Data" di ExportScreen lalu Ekspor
THEN file GPX berisi:
  - <metadata>
      <name>Data Langgeng Sea (Lengkap)</name>
      <author><name>Pak Budi</name></author>
      <extensions>
        <lsea:exporter>
          <lsea:vesselName>KM Bahari</lsea:vesselName>
          <lsea:ownerName>Pak Budi</lsea:ownerName>
          <lsea:exportedAt>2026-05-16T...Z</lsea:exportedAt>
        </lsea:exporter>
      </extensions>
    </metadata>
  - 3 elemen <wpt> (markers), masing-masing dengan
    <name>, <desc>, <sym>, dan <extensions><lsea:marker
    category="productive|hazard|port|other"/></extensions>
  - 2 elemen <trk> (1 per haul), masing-masing dengan
    <name>Tarikan #1</name>, <desc> berisi stats human-readable,
    <extensions><lsea:haul colorValue="0xFF...">… stats …
    </lsea:haul></extensions>, dan <trkseg> dengan track points.
  - File harus PARSABLE oleh xml.dart parser tanpa exception
  - File harus PARSABLE oleh GPX viewer pihak ketiga (Google Earth)
    minimal sampai melihat tracks + waypoints
```

**Correctness properties:**

- Semua string field yang user-input (nama trip, nama haul, notes)
  HARUS escape XML-safe (`&`, `<`, `>`, `"`, `'`)
- Field nullable (warna jalur null = "auto-palette") harus
  TIDAK menulis elemen kosong — skip elemen sama sekali
- Waktu ISO 8601 dengan suffix `Z` untuk UTC, BUKAN `+00:00`
- Coordinate precision: 7 desimal (≈ 1 cm) tanpa trailing zero
- File yang TIDAK punya data sama sekali (user pilih filter yang
  hasilnya kosong) tetap valid GPX dengan `<metadata>` saja, root
  tag TIDAK self-closing — sudah ada di PR #25/26, jangan regress

### Requirement R5 — Filter ekspor lengkap

**User story:** Sebagai nelayan yang punya data 1 tahun terakhir, saya
ingin bisa ekspor "minggu ini saja" atau "trip si Ujang minggu lalu",
tanpa harus ekspor semuanya yang puluhan MB.

**Acceptance criteria:**

```
ExportScreen punya 4 section filter:

1. Konten:
   - [x] Jalur tarikan
   - [x] Penanda
   (Salah satu / dua-duanya. Tidak boleh dua-duanya off → button
   "Ekspor" disabled.)

2. Rentang tanggal (kalau "Jalur tarikan" dicentang):
   - ( ) Semua waktu (default)
   - ( ) 7 hari terakhir
   - ( ) 30 hari terakhir
   - ( ) Rentang kustom… → date range picker

3. Pilih trip (kalau "Jalur tarikan" dicentang DAN ada >1 trip):
   - Default: semua trip dalam rentang tanggal
   - Tombol "Pilih trip…" → modal sheet checkbox per trip
     (dengan ringkasan: "Trip 8 Mei · 3 tarikan · 12 km")

4. Kategori penanda (kalau "Penanda" dicentang):
   - [x] Spot Produktif
   - [x] Karang/Bahaya
   - [x] Pelabuhan
   - [x] Lainnya
   (Default semua dicentang. User bisa uncheck individual.)

WHEN user kombinasi filter menghasilkan 0 hauls + 0 markers
THEN tombol Ekspor disabled
  AND ada pesan helper "Tidak ada data yang cocok dengan filter."

WHEN user tap Ekspor
THEN nama file mencerminkan filter:
  - "all" → langgeng_sea_lengkap_YYYYMMDD.gpx
  - jalur saja, 7 hari → langgeng_sea_jalur_7hari_YYYYMMDD.gpx
  - penanda saja → langgeng_sea_penanda_YYYYMMDD.gpx
  - rentang kustom → langgeng_sea_jalur_2024-06-01_2024-06-15.gpx
```

**Correctness properties:**

- Filter rentang tanggal dipotong di `Trip.startedAt` (bukan
  `endedAt`) — trip yang mulai dalam rentang tapi selesai di luar
  TETAP masuk
- Filter per-trip override filter rentang tanggal (kalau user
  pilih trip eksplisit, ignore rentang)
- Filter kategori penanda OR semantics (penanda yang category-nya
  ada di whitelist masuk)

### Requirement R6 — Per-trip share tetap ada (Opsi A)

**User story:** Saat saya buka detail Trip dan tap "Bagikan", saya
bisa langsung share trip ini saja sebagai GPX, tanpa harus buka
Settings → Ekspor → centang trip mana → Ekspor.

**Acceptance criteria:**

```
WHEN user buka TripDetailScreen
  AND tap tombol Bagikan / share icon
THEN bottom sheet muncul dengan ringkasan trip
  AND tombol "Bagikan Sekarang"

WHEN user tap Bagikan Sekarang
THEN file GPX di-generate dengan SAMA isi seperti ExportScreen
     (filter hanya 1 trip, semua haul + opsional markers di
     dalam bounding box trip)
  AND langsung buka share sheet sistem
```

(Implementasi sudah ada — `ExportSheet`. Cukup pastikan dia pakai
`GpxExporter.exportTrip` yang sama struktur dengan `exportAll`,
plus tambahkan field-field baru.)

---

## Non-functional

- **Stabilitas**: zero crash saat permission flow apa pun, termasuk
  edge case "user tutup dialog OS dengan back-button alih-alih
  Allow/Deny"
- **Backward-compat data**: file GPX yang dihasilkan harus tetap
  terbuka di GPX reader pihak ketiga (Google Earth, OsmAnd, Garmin
  BaseCamp) — extensions namespace tidak boleh memutus parsing
- **Performance**: ekspor dataset besar (10 trip × 50 haul × 500
  point × 100 marker) harus selesai < 5 detik di Redmi Note 10 Pro
- **Locale**: semua string user-facing di Bahasa Indonesia, tidak
  campur bahasa Inggris
- **No new permissions**: tidak menambah uses-permission baru di
  AndroidManifest — semua sudah ada
