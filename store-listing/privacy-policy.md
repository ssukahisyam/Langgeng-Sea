# Kebijakan Privasi Langgeng Sea

**Versi:** 1.0
**Berlaku efektif:** saat aplikasi pertama kali dirilis ke Google Play Store
**Kontak:** privacy@langgengsea.id _(placeholder — ganti sebelum submission)_

---

## 1. Ringkasan Singkat

Langgeng Sea adalah aplikasi tracking GPS untuk nelayan trawl Indonesia.
**Semua data Anda disimpan di perangkat Anda sendiri.** Kami tidak memiliki
server. Kami tidak mengumpulkan data pribadi. Kami tidak menjalankan iklan,
analitik pihak ketiga, ataupun tracker perilaku pengguna.

Jika kalimat di atas sudah menjawab pertanyaan Anda, Anda tidak perlu
melanjutkan. Dokumen ini memperinci hal yang sama secara formal.

---

## 2. Data yang Kami Kumpulkan

**Tidak ada.**

Langgeng Sea tidak mengumpulkan, mengirim, atau menyimpan data Anda di
server mana pun. Hal ini berlaku untuk:

- Identitas pribadi (nama, email, nomor telepon, foto).
- Lokasi GPS (titik koordinat, jejak kapal, spot tangkap).
- Data aktivitas tangkap (jumlah hasil, log book, marker).
- Data perangkat (IMEI, nomor seri, informasi SIM).
- Data penggunaan aplikasi (screen views, tap events, durasi sesi).

Seluruh data yang Anda masukkan — termasuk jejak GPS, log book, marker
spot, catatan tangkap, dan profil kapal — disimpan secara lokal di
database SQLite di dalam memori internal HP Anda. Database tersebut hanya
dapat diakses oleh aplikasi Langgeng Sea.

---

## 3. Izin (Permission) yang Diminta

Langgeng Sea meminta izin berikut dari sistem Android. Masing-masing izin
dipakai sebatas untuk fungsi yang dijelaskan di bawah.

### 3.1 Location (Lokasi) — WAJIB

- **Izin yang diminta:** `ACCESS_FINE_LOCATION`,
  `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`.
- **Kegunaan:** membaca koordinat GPS HP Anda untuk merekam jejak kapal
  selama fitur "Mulai Tebar" aktif.
- **Kapan dibaca:** hanya ketika Anda menekan tombol **Mulai Tebar**.
  Saat tombol **Angkat Trawl** ditekan, pembacaan GPS berhenti.
- **Kapan TIDAK dibaca:** di luar sesi tebar aktif. Aplikasi tidak
  melacak Anda di latar belakang tanpa sepengetahuan Anda.
- **Apakah dikirim ke server?** Tidak. Koordinat hanya ditulis ke
  database lokal di HP Anda.

### 3.2 Foreground Service Location — WAJIB

- **Izin yang diminta:** `FOREGROUND_SERVICE`,
  `FOREGROUND_SERVICE_LOCATION`, `WAKE_LOCK`.
- **Kegunaan:** agar tracking GPS tetap berjalan saat layar HP mati atau
  Anda membuka aplikasi lain. Notifikasi "sedang merekam" akan tampil
  di status bar selama sesi tebar aktif sebagai indikator transparan.

### 3.3 Notifications — OPSIONAL (Android 13+)

- **Izin yang diminta:** `POST_NOTIFICATIONS`.
- **Kegunaan:** menampilkan notifikasi "sedang merekam" saat tracking
  aktif. Tanpa izin ini tracking tetap jalan tapi Anda tidak akan lihat
  indikator di status bar.

### 3.4 Internet — OPSIONAL (hanya untuk download peta)

- **Izin yang diminta:** `INTERNET`, `ACCESS_NETWORK_STATE`.
- **Kegunaan:** satu-satunya penggunaan internet adalah men-**download
  tile peta offline** dari OpenStreetMap saat Anda berada di darat /
  terhubung WiFi. Download hanya terjadi saat Anda menekan tombol
  "Download Peta Offline" di halaman Pengaturan Peta.
- **Di laut:** aplikasi bekerja sepenuhnya offline. Tidak ada traffic
  internet keluar.
- **Apakah dikirim data Anda?** Tidak. Request yang dikirim hanya
  permintaan HTTP publik ke server OpenStreetMap untuk mengambil gambar
  peta — sama seperti browser saat membuka situs peta mana pun. Tidak
  ada informasi jejak kapal / tangkap Anda yang ikut dikirim.

### 3.5 Storage — OPSIONAL (untuk ekspor/impor)

- **Izin yang diminta:** `READ_EXTERNAL_STORAGE` (hanya di Android ≤12).
- **Kegunaan:** membaca file `.gpx` atau `.lsea.json` yang Anda pilih
  untuk diimpor. Ekspor ditulis via dialog sistem (Storage Access
  Framework) sehingga tidak butuh izin khusus.

---

## 4. Data yang Anda Bagikan Secara Sukarela

Fitur **Ekspor** di dalam aplikasi memungkinkan Anda mengirim file
`.gpx` atau `.lsea.json` ke kontak lain (WhatsApp, email, drive).
Kalau Anda memilih mengirim file ini, data di dalamnya meninggalkan
perangkat Anda atas kehendak Anda sendiri. Kami tidak pernah terlibat
dalam proses itu.

Fitur **Impor** hanya membaca file yang Anda pilih secara eksplisit.
File tersebut tidak ikut meninggalkan HP.

---

## 5. Analitik, Iklan, dan Tracking

- **Tidak ada analitik.** Aplikasi tidak memakai Google Analytics,
  Firebase Analytics, Mixpanel, Amplitude, atau SDK analitik lainnya.
- **Tidak ada iklan.** Aplikasi 100% bebas iklan.
- **Tidak ada tracking cross-app / identifier iklan.** Aplikasi tidak
  membaca AAID (Advertising ID) maupun identifier perangkat lain.
- **Tidak ada crash reporter pihak ketiga di versi 1.0.** Di versi
  mendatang kami mungkin akan menambahkan crash reporter (misal Sentry
  atau Firebase Crashlytics) untuk memperbaiki bug yang dilaporkan
  nelayan. Jika itu dilakukan, kebijakan privasi ini akan di-update
  lebih dulu dan Anda akan diminta persetujuan eksplisit sebelum data
  crash dikirim.

---

## 6. Anak-Anak

Aplikasi ini ditujukan untuk pengguna dewasa (nelayan dan kru kapal).
Kami tidak mengumpulkan data dari anak di bawah 13 tahun.

---

## 7. Perubahan Kebijakan

Kalau kebijakan ini berubah (misal kami menambahkan fitur cloud sync di
v2), versi barunya akan dipublish di halaman Play Store dan di
repository GitHub. Perubahan besar akan diumumkan lewat notifikasi
in-app sebelum fitur terkait aktif.

---

## 8. Kontak

Pertanyaan, keluhan, atau permintaan penghapusan data:

- **Email:** privacy@langgengsea.id _(placeholder)_
- **GitHub:** https://github.com/ssukahisyam/Langgeng-Sea/issues
- **WhatsApp:** +62-xxx-xxx-xxxx _(placeholder beta support)_

Karena data Anda hanya tersimpan di HP Anda, penghapusan data
dilakukan dengan meng-uninstall aplikasi atau menghapus data aplikasi
lewat Settings → Apps → Langgeng Sea → Storage → Clear data.

---

## English Summary (Non-Authoritative)

Langgeng Sea is a GPS tracking app for Indonesian trawl fishers. We do
**not** collect, transmit, or store any of your data on any server. All
trip data — GPS tracks, log books, markers — lives only in the local
SQLite database on your phone.

Permissions requested:

- **Location** (fine + coarse + background + foreground service
  location): read GPS coordinates during an active tracking session so
  your trawl haul can be recorded.
- **Notifications** (Android 13+): show the "recording" status bar
  indicator during an active session.
- **Internet**: only used to download OpenStreetMap tiles for offline
  use, on your explicit request via the "Download Offline Map" button.
- **Storage** (Android ≤12): read `.gpx` / `.lsea.json` files you
  explicitly pick for import.

No analytics. No advertising. No third-party tracking. No cross-device
sync. No account registration. Deleting the app deletes all your data.

If you share an exported file via WhatsApp or email, that's your own
action — we're not involved.

This policy will be updated before any behaviour change (e.g. adding a
cloud sync feature or a crash reporter). You will be asked for explicit
consent before any such feature becomes active.

Contact: privacy@langgengsea.id _(placeholder; replace prior to Play
Store submission)_ or file an issue at
https://github.com/ssukahisyam/Langgeng-Sea/issues.
