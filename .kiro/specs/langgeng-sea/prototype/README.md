# Langgeng Sea - UI/UX Prototype

Prototype HTML statis untuk preview desain **Clean Liquid Glass** dengan mode terang & gelap.

## Cara Membuka

1. Download atau clone repo ini.
2. Buka file `index.html` di browser (double-click file tersebut), atau:
3. Drag file `index.html` ke tab browser baru.

Tidak butuh server, build, atau dependency install — semua sudah siap pakai.

## Fitur Prototype

- 9 screen utama aplikasi
- Toggle **Light / Dark mode** (tombol kanan atas, tersimpan di localStorage)
- Phone frame preview 340x720
- Semua komponen glass dengan backdrop-filter blur

## 9 Screen yang Ditampilkan

| # | Screen | Deskripsi |
|---|---|---|
| 01 | Home / Peta (Idle) | Layar utama saat idle, tombol "Mulai Tebar" |
| 02 | Tracking Aktif | Mode recording haul dengan live stats |
| 03 | Haul Summary | Bottom sheet setelah angkat trawl |
| 04 | Riwayat Trip | List trip dengan filter & chip |
| 05 | Dashboard | Statistik, grafik, top spots |
| 06 | Log Book | Form catat hasil tangkap (opsional) |
| 07 | Pengaturan | Profil, preferensi, peta offline |
| 08 | Onboarding | Layar sambutan pertama install |
| 09 | Ekspor / Bagikan | Share trip ke user lain |

## Design Tokens

Lihat file `styles.css` bagian `:root`, `[data-theme="light"]`, dan `[data-theme="dark"]` untuk seluruh token warna, spacing, radius, dan motion yang akan di-porting ke Flutter theme.

## Catatan untuk Developer Flutter

Saat implementasi di Flutter, token CSS ini akan di-convert ke `ThemeData`:

- Color tokens → `ColorScheme`
- Radius → `BorderRadiusGeometry`
- Shadow → `BoxShadow`
- Glass effect → `BackdropFilter` + `ImageFilter.blur` + `Container` dengan `Color.withOpacity`
- Motion → `Curves.easeOutCubic` + `Duration`

File target porting: `lib/core/theme/app_theme.dart` (akan dibuat di M0 Setup).
