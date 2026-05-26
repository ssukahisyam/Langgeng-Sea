# Styra — Flutter App

Source Flutter project untuk aplikasi tracking GPS offline nelayan trawl
Indonesia. Ini adalah **M0 Foundation** — fondasi proyek dengan theme,
routing, dan skeleton screens. Implementasi fitur GPS tracking, peta,
haul, dsb. akan datang di M1 dan milestone berikutnya.

## Prasyarat

- Flutter SDK **3.24.x** atau lebih baru ([install guide](https://docs.flutter.dev/get-started/install))
- Android Studio atau VS Code dengan plugin Flutter
- Android device / emulator (min API 26 / Android 8.0)
- JDK 17

Cek instalasi:

```bash
flutter --version
flutter doctor
```

## Menjalankan Aplikasi

```bash
# Dari root project
cd app

# Install dependencies
flutter pub get

# Generate code untuk Drift (M2+), Freezed (M3+), dll.
dart run build_runner build --delete-conflicting-outputs

# Jalankan di device/emulator yang terhubung
flutter run
```

> ⚠️ **Penting mulai M2:** Karena Drift butuh code-gen, selalu jalankan
> `build_runner` setelah `flutter pub get` atau setelah mengubah file
> `*_dao.dart` / `tables.dart`.

Aplikasi akan terbuka dengan layar Map sebagai tab utama. Semua tombol
utama sudah clickable dan menampilkan bottom sheet "Sedang Dibangun"
karena fitur GPS & map akan diintegrasikan di M1.

## Generate Code (akan diperlukan di M2+)

Untuk freezed, json_serializable, drift, dan riverpod_generator:

```bash
flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode selama development
flutter pub run build_runner watch --delete-conflicting-outputs
```

## Testing

```bash
flutter test                   # unit + widget tests
flutter test --coverage        # dengan coverage
```

## Build APK

```bash
# Debug APK (cepat)
flutter build apk --debug

# Release APK (minify, proguard)
flutter build apk --release

# Split per ABI (lebih kecil ukuran download)
flutter build apk --release --split-per-abi
```

Output: `build/app/outputs/flutter-apk/`.

## Struktur Folder

```
app/
├── lib/
│   ├── main.dart                        # Entry point + ProviderScope
│   ├── app.dart                         # MaterialApp.router + theme wiring
│   │
│   ├── core/                            # Reusable cross-feature code
│   │   ├── constants/app_strings.dart
│   │   ├── theme/
│   │   │   ├── app_colors.dart          # Color tokens (light + dark)
│   │   │   ├── app_sizes.dart           # Spacing, radius, sizes
│   │   │   ├── app_typography.dart      # Plus Jakarta Sans styles
│   │   │   ├── app_theme.dart           # ThemeData + LangTokens extension
│   │   │   └── theme_controller.dart    # Riverpod theme mode provider
│   │   ├── router/app_router.dart       # GoRouter shell + routes
│   │   └── widgets/                     # Reusable glass components
│   │       ├── glass_card.dart
│   │       ├── primary_action_button.dart
│   │       ├── status_chip.dart
│   │       ├── ambient_background.dart
│   │       └── app_shell.dart           # Bottom nav shell
│   │
│   └── features/                        # Feature-first vertical slices
│       ├── map/presentation/            # Home tab (M1)
│       ├── history/presentation/        # Trip history (M3)
│       ├── dashboard/presentation/      # Stats dashboard (M6)
│       └── settings/presentation/       # Preferences (M8)
│
├── test/                                # Unit & widget tests
├── android/                             # Android-specific config
├── pubspec.yaml                         # Dependencies
└── analysis_options.yaml                # Lint rules
```

## Konvensi Kode

- **Null safety** penuh.
- **Single quotes** untuk string Dart.
- **Const constructors** wherever possible.
- **Trailing commas** untuk formatting rapi.
- **Immutable state** — pakai `freezed` mulai M2.
- **Riverpod** untuk state management, bukan Provider atau setState global.

Lint dijalankan otomatis di CI. Jalankan lokal:

```bash
dart format .
flutter analyze
```

## Permissions yang Diperlukan

Dideklarasikan di `android/app/src/main/AndroidManifest.xml`:

| Permission | Tujuan |
|---|---|
| `ACCESS_FINE_LOCATION` | GPS akurasi tinggi untuk tracking |
| `ACCESS_BACKGROUND_LOCATION` | Tracking saat HP terkunci (M2) |
| `FOREGROUND_SERVICE_LOCATION` | Service rekaman titik GPS (M2) |
| `WAKE_LOCK` | Mencegah sleep saat tracking |
| `POST_NOTIFICATIONS` | Notif persistent saat tracking (Android 13+) |
| `INTERNET` | **Hanya** untuk download tile peta offline di darat |

## Roadmap

Lihat [`.kiro/specs/langgeng-sea/tasks.md`](../.kiro/specs/langgeng-sea/tasks.md) untuk breakdown lengkap
M0 → M10.

**Status saat ini: M0 — Foundation ✅**

Next: **M1 — Core Map & GPS** (peta OSM + tracking realtime).
