# M7 — Ekspor / Impor

**Status:** ✅ Done
**Branch:** `feat/m7-export-import`

---

## Apa yang Dikirim

### Fitur Baru

1. **GPX Export** (`gpx_exporter.dart`)
   - Export single haul atau full trip sebagai GPX 1.1
   - Valid XML structure dengan `<trk>/<trkseg>/<trkpt>` elements
   - Includes time, speed per track point
   - Compatible dengan semua GPS viewer (Google Earth, etc.)

2. **Langgeng Sea JSON Export** (`lsea_json_exporter.dart`)
   - Format proprietary `.lsea.json` untuk sharing antar pengguna
   - Includes full trip data: hauls, track points, logbook, catches
   - Includes sender identity (nama + kapal) untuk attribution
   - Format versioned (`langgeng-sea-v1`) untuk backward compat

3. **JSON Import + Preview** (`lsea_json_importer.dart`)
   - Parse & validate `.lsea.json` files
   - Returns `ImportPreview` with: sender name, vessel, haul count, distance, date
   - Strict validation: format version check, required fields
   - Full DB import deferred to M8/M9 (MVP shows preview only)

4. **Export Sheet** (`export_sheet.dart`)
   - Bottom sheet (glass-3) matching Screen 09 prototype
   - Format picker: Langgeng Sea (.lsea.json) / GPX
   - Share app icons: WhatsApp, Telegram, Email, Simpan
   - Uses `share_plus` → Share.shareXFiles for OS share sheet
   - Trip preview info in header

5. **Import Screen** (`import_screen.dart`)
   - File picker with `file_picker` package (custom extension filter)
   - Info banner explaining imported data separation
   - Preview card showing sender info + stats
   - Placeholder "Impor ke Data Bersama" action (SnackBar confirmation)

6. **Export Service** (`export_service.dart`)
   - Orchestrates: repos → exporter → temp file → File path
   - Riverpod provider: `exportServiceProvider`
   - Handles both formats via `ExportFormat` enum

### Infrastruktur

- Route `/import` ditambahkan ke `app_router.dart`
- No new packages needed (xml, share_plus, file_picker already in pubspec)

### Unit Tests

- `gpx_exporter_test.dart` — 6 tests: XML structure, lat/lon, time/speed, null handling, XML escaping, multi-track
- `lsea_json_test.dart` — 10 tests: format field, exportedBy, trip structure, logbook/catches, round-trip, error cases

---

## Keputusan Teknis

| Keputusan | Alasan |
|---|---|
| StringBuffer untuk GPX (bukan xml package) | GPX structure flat & simple, less overhead |
| dart:convert jsonEncode untuk .lsea.json | Standard, no extra deps needed |
| Import hanya preview (no DB write) | Full import complex; MVP cukup preview + placeholder |
| ExportService sebagai orchestrator | Clean separation: exporter stateless, service fetches data |
| Format versioned (langgeng-sea-v1) | Future-proof: bisa add langgeng-sea-v2 tanpa breaking |

---

## Yang Belum Diimplementasi (Ditunda)

- Full DB import (write imported data ke SQLite) → M8/M9
- Profile name/vessel auto-fill dari settings → needs profile feature
- Share intent receiver (terima file dari app lain) → v2
- Marker export/import → v2
