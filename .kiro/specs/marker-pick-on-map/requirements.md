# Requirements — PR #32 Marker Pick on Map

> Format: EARS (Event–Action–Result–State) · Bahasa Indonesia.
> Konteks: user nelayan ingin menandai lokasi di peta tanpa harus
> berada di lokasi tersebut. Saat ini fitur paling discoverable
> (floating Add Marker button) hanya bekerja saat ada GPS fix dan
> menandai posisi sekarang. Long-press di peta sudah ada tapi user
> tidak menemukan fitur itu.

## Latar belakang

Saat ini ada 3 cara tambah marker:

| Cara | Butuh GPS? | Discoverable? |
|---|---|---|
| Tap floating button Add Marker di MapScreen | Ya | Ya — tombol jelas di layar |
| Long-press di peta | Tidak | Tidak — tidak ada visual cue |
| Settings → Kelola Penanda → tambah baru | Tidak (pakai placeholder 0,0 yang bug) | Sebagian — perlu navigasi |

User mengeluhkan "sekarang hanya ketika berada di lokasi tersebut".
Dua masalah: (1) discoverability long-press buruk, (2) Markers list
add flow placeholder lat/lon = 0 sehingga marker masuk ke koordinat
salah.

Solusi yang diputuskan: **Pilihan 2 (mode crosshair) + tooltip
discoverability** sesuai jawaban user.

## Requirements

### R1 — Long-press peta tetap berfungsi

**Saat** user long-press di peta yang tidak sedang dalam mode
tracking aktif tertentu,
**aplikasi** harus menampilkan menu opsi yang sudah ada (navigasi
ke titik, tambah marker di titik) seperti existing behavior,
**sehingga** user existing tidak kehilangan workflow yang sudah
mereka kenal.

**Acceptance criteria:**
- AC1: Long-press di peta membuka `LongPressMenu` dengan dua opsi
  `Mulai Navigasi ke Sini` dan `Tandai sebagai Penanda`.
- AC2: `Tandai sebagai Penanda` membuka `AddMarkerDialog` dengan
  koordinat dari titik long-press (perilaku existing).

### R2 — Tombol Add Marker punya 2 mode

**Sebagai** nelayan,
**saya bisa** menggunakan tombol Add Marker untuk dua skenario:
tap pendek = tandai posisi saya saat ini, tekan lama = pilih
lokasi lain di peta,
**supaya** saya tidak perlu mencari menu tersembunyi untuk
menandai tempat tanpa GPS.

**Acceptance criteria:**
- AC1: Tap (short press) tombol Add Marker = perilaku existing
  (pakai `currentReadingProvider`, kalau tidak ada GPS tampilkan
  snackbar "Tunggu sinyal GPS dulu sebelum menandai lokasi").
- AC2: Long-press tombol Add Marker = masuk mode `pickMarkerLocation`.
- AC3: Tombol punya `Semantics.label` yang menyebutkan dua mode
  ("Tandai lokasi saya. Tekan lama untuk pilih lokasi di peta.").
- AC4: Haptic feedback ringan saat long-press teregister.

### R3 — Mode pickMarkerLocation menampilkan crosshair + bottom sheet kontrol

**Saat** mode peta = `pickMarkerLocation`,
**aplikasi** harus menampilkan crosshair fixed di tengah viewport
peta dan bottom sheet dengan instruksi + dua tombol [Tandai di
Sini] [Batal],
**sehingga** user paham bahwa mereka harus pan/zoom peta supaya
posisi yang diinginkan ada di crosshair, lalu konfirmasi.

**Acceptance criteria:**
- AC1: Crosshair (icon `+` atau pin floating) berada tepat di
  center viewport, fixed terhadap layar (bukan koordinat peta).
- AC2: Crosshair tetap di tengah saat user pan/zoom peta.
- AC3: Bottom sheet menampilkan teks instruksi
  "Pan peta ke lokasi yang ingin ditandai. Lepas saat sudah pas."
- AC4: Bottom sheet menampilkan koordinat live saat user pan
  (mis. "Saat ini: -7.20451, 113.40123") supaya user yakin.
- AC5: Tombol [Tandai di Sini] di kanan bawah, [Batal] di kiri.
- AC6: Tap [Tandai di Sini] mengambil `_mapController.camera.center`,
  lalu menutup mode dan membuka `AddMarkerDialog` dengan koordinat
  itu (reuse dialog existing).
- AC7: Tap [Batal] kembali ke `MapMode.idle` tanpa side effect.
- AC8: Saat mode aktif, kontrol map lain (idle controls, tracking
  controls) di-hide.

### R4 — Discoverability tooltip first-time

**Saat** user pertama kali masuk MapScreen setelah update,
**aplikasi** harus menampilkan tooltip overlay singkat di tombol
Add Marker yang menjelaskan "Tekan lama untuk pilih lokasi di
peta",
**sehingga** user existing belajar fitur baru tanpa harus baca
release notes.

**Acceptance criteria:**
- AC1: Tooltip muncul sekali per app install (tracked via
  `SharedPreferences` atau `app_settings` table flag).
- AC2: Tooltip auto-dismiss setelah 5 detik atau saat user tap
  area lain.
- AC3: Tooltip punya tombol kecil `Mengerti` untuk dismiss manual.
- AC4: Tidak muncul lagi setelah dismiss (flag persist).

### R5 — Markers list add flow pakai mode crosshair

**Saat** user tap tombol "+ Tambah Baru" di Markers list screen,
**aplikasi** harus menutup screen dan langsung masuk
`MapMode.pickMarkerLocation` di MapScreen,
**sehingga** user dapat memilih lokasi marker baru di peta dan
tidak terjebak di placeholder lat/lon = 0 yang bug.

**Acceptance criteria:**
- AC1: Markers list screen tampil tombol "+" floating di kanan
  bawah (atau di app bar) yang sebelumnya tidak ada / pakai
  placeholder.
- AC2: Tap tombol "+" pop screen dan navigasi ke MapScreen tab
  dengan `MapMode = pickMarkerLocation` aktif.
- AC3: Setelah konfirmasi marker dibuat, user dapat kembali ke
  Markers list (back button) dan melihat marker baru di list.

### R6 — Tracking active tidak terganggu

**Saat** ada haul yang sedang recording,
**user TIDAK boleh** masuk mode `pickMarkerLocation` lewat
long-press tombol Add Marker (karena bottom sheet tracking sudah
penuh kontrol),
**namun** long-press di peta tetap memunculkan menu yang berisi
opsi tambah marker di titik long-press (R1).

**Acceptance criteria:**
- AC1: Saat `state.isRecording == true`, tombol Add Marker
  long-press tidak memicu mode pick. Bisa: tampilkan snackbar
  "Selesaikan tracking dulu untuk menandai lokasi non-GPS" ATAU
  hide tombol seluruhnya saat recording.
- AC2: Long-press di peta saat tracking tetap menampilkan menu
  yang sudah ada (perilaku existing).

## Correctness properties

- **P1 — Mode picker idempotent**: kalau user sudah dalam mode
  `pickMarkerLocation` lalu memicu cara lain untuk masuk mode itu
  (mis. dari Markers list), tidak terjadi double-trigger atau
  state inconsistent.
- **P2 — Crosshair koordinat tepat**: koordinat yang dipakai untuk
  marker baru = `_mapController.camera.center`, bukan koordinat
  saat user terakhir pan. Test dengan pan setelah tap [Tandai].
- **P3 — Cancel tidak corrupt state**: tap [Batal] atau back
  button mengembalikan `MapMode = idle` tanpa menyimpan apa pun.
- **P4 — Tooltip flag tahan crash**: kalau app crash sebelum user
  tap dismiss, tooltip tetap dianggap "shown" supaya tidak muncul
  ulang setiap launch (tradeoff: lose 1 user yang miss tooltip-nya).

## Non-functional

- **NFR1 — A11y**: crosshair punya `Semantics` label "Crosshair
  pemilih lokasi", bottom sheet kontrol dapat di-fokus screen
  reader.
- **NFR2 — Haptic budget**: haptic feedback hanya saat long-press
  teregister + saat [Tandai di Sini]. Tidak per-pan.
- **NFR3 — Performance**: koordinat live di bottom sheet update
  via `_mapController.mapEventStream` listener dengan throttle
  100ms supaya tidak bikin frame drop saat user pan cepat.
- **NFR4 — String 100% Bahasa Indonesia**.
