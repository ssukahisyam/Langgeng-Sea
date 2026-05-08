# UI/UX Design Spec - Langgeng Sea

**Style:** Clean Liquid Glass (Glassmorphism + Minimalism)
**Themes:** Light Mode & Dark Mode
**Versi:** 1.0
**Tanggal:** 8 Mei 2026

---

## 1. Design Philosophy

### Clean Liquid Glass
Gaya visual yang memadukan tiga prinsip:

- **Clean** — Layout minimalis, whitespace generous, tipografi jelas, ikon simpel.
- **Liquid** — Transisi halus, gradient lembut, bentuk organik (rounded corners besar), motion yang natural.
- **Glass** — Efek glassmorphism: permukaan semi-transparan dengan backdrop blur, menciptakan kesan kedalaman & premium.

### Prinsip Utama
1. **Clarity first** — Fungsi utama harus terlihat dalam 1 detik.
2. **Thumb-friendly** — Semua tombol aksi utama dapat dijangkau satu tangan.
3. **Weather-proof UX** — Kontras tinggi, tombol minimal 60dp, terbaca di bawah matahari terik.
4. **Calm aesthetics** — Tidak menggunakan warna mencolok berlebihan, fokus pada ketenangan visual khas laut.
5. **Consistent motion** — Semua animasi pakai easing `ease-out-quart`, durasi 250-400ms.

---

## 2. Color System

### 2.1 Light Mode

| Token | Hex | Usage |
|---|---|---|
| `--primary` | `#0277BD` | Tombol utama, link, active state |
| `--primary-hover` | `#0288D1` | Hover tombol |
| `--primary-soft` | `#E1F5FE` | Background chip, highlight halus |
| `--accent` | `#FF6F00` | CTA sekunder, badge penting |
| `--accent-soft` | `#FFF3E0` | Background accent halus |
| `--success` | `#2E7D32` | Tombol "Mulai Tebar", success state |
| `--danger` | `#D32F2F` | Tombol "Angkat Trawl", destructive |
| `--warning` | `#F9A825` | Akurasi GPS sedang |
| `--bg` | `#F4F8FB` | Background utama app |
| `--bg-gradient-start` | `#E8F4FA` | Ambient gradient top |
| `--bg-gradient-end` | `#F9FBFD` | Ambient gradient bottom |
| `--surface` | `rgba(255,255,255,0.72)` | Kartu glass |
| `--surface-solid` | `#FFFFFF` | Modal, sheet |
| `--border` | `rgba(15,23,42,0.08)` | Border halus |
| `--divider` | `rgba(15,23,42,0.06)` | Divider |
| `--text` | `#0F172A` | Heading |
| `--text-secondary` | `#475569` | Body |
| `--text-tertiary` | `#94A3B8` | Caption, metadata |
| `--shadow-sm` | `0 2px 8px rgba(15,23,42,0.04)` | Elevation 1 |
| `--shadow-md` | `0 8px 24px rgba(15,23,42,0.08)` | Elevation 2 (cards) |
| `--shadow-lg` | `0 20px 40px rgba(2,119,189,0.15)` | Elevation 3 (FAB, sheet) |

### 2.2 Dark Mode

| Token | Hex | Usage |
|---|---|---|
| `--primary` | `#4FC3F7` | Tombol utama (lebih terang untuk kontras) |
| `--primary-hover` | `#81D4FA` | Hover |
| `--primary-soft` | `rgba(79,195,247,0.12)` | Highlight |
| `--accent` | `#FFB74D` | CTA sekunder |
| `--accent-soft` | `rgba(255,183,77,0.12)` | Accent background |
| `--success` | `#66BB6A` | Success |
| `--danger` | `#EF5350` | Destructive |
| `--warning` | `#FFD54F` | Warning |
| `--bg` | `#050B18` | Background utama |
| `--bg-gradient-start` | `#0A1628` | Ambient gradient top |
| `--bg-gradient-end` | `#050B18` | Ambient gradient bottom |
| `--surface` | `rgba(255,255,255,0.06)` | Kartu glass |
| `--surface-solid` | `#0F1B2E` | Modal, sheet |
| `--border` | `rgba(255,255,255,0.08)` | Border |
| `--divider` | `rgba(255,255,255,0.06)` | Divider |
| `--text` | `#F1F5F9` | Heading |
| `--text-secondary` | `#CBD5E1` | Body |
| `--text-tertiary` | `#64748B` | Caption |
| `--shadow-sm` | `0 2px 8px rgba(0,0,0,0.2)` | Elevation 1 |
| `--shadow-md` | `0 8px 24px rgba(0,0,0,0.35)` | Elevation 2 |
| `--shadow-lg` | `0 20px 40px rgba(0,0,0,0.45)` | Elevation 3 |

### 2.3 Ambient / Atmospheric
Setiap screen memiliki **blobs** gradient di background (blur 80-120px) untuk menciptakan kedalaman seperti air laut:
- Light: gradasi biru muda → putih
- Dark: gradasi biru tua → hampir hitam, dengan aksen cyan tipis

---

## 3. Glass Surface System

### 3.1 Glass Card Variants

| Level | Use case | Light `background` | Dark `background` | Blur |
|---|---|---|---|---|
| **Glass-1** | Card sekunder, list item | `rgba(255,255,255,0.60)` | `rgba(255,255,255,0.04)` | 16px |
| **Glass-2** | Card utama, modal | `rgba(255,255,255,0.72)` | `rgba(255,255,255,0.06)` | 24px |
| **Glass-3** | Floating FAB, bottom sheet | `rgba(255,255,255,0.85)` | `rgba(255,255,255,0.10)` | 32px |

Semua glass card mendapat:
```css
backdrop-filter: blur(24px) saturate(180%);
border: 1px solid var(--border);
border-radius: 24px;
box-shadow: var(--shadow-md);
```

### 3.2 Liquid Corner Radius
- **Small chip/pill:** `999px`
- **Button:** `18px`
- **Card:** `24px`
- **Modal / bottom sheet:** `32px` (top corners)
- **Hero container:** `28px`

---

## 4. Typography

**Font:** Plus Jakarta Sans (fallback: Inter, -apple-system, Roboto, sans-serif)

| Style | Size | Weight | Line-height | Usage |
|---|---|---|---|---|
| Display | 32 sp | 700 | 1.2 | Hero stats |
| H1 | 28 sp | 700 | 1.25 | Screen title |
| H2 | 22 sp | 600 | 1.3 | Section heading |
| H3 | 18 sp | 600 | 1.35 | Card title |
| Body L | 16 sp | 500 | 1.5 | Default body |
| Body | 14 sp | 500 | 1.5 | Default body compact |
| Caption | 12 sp | 500 | 1.4 | Metadata |
| Button | 16 sp | 600 | 1.0 | Button label |

Angka (jarak, kecepatan, luas) pakai **tabular-nums** agar stabil saat real-time update.

---

## 5. Spacing & Grid

Base unit: **4px**

- `space-1`: 4 — inline gap kecil
- `space-2`: 8
- `space-3`: 12
- `space-4`: 16 — **default padding**
- `space-5`: 20
- `space-6`: 24 — section gap
- `space-8`: 32 — screen padding
- `space-10`: 40

**Safe area:** Screen padding horizontal = 20px di phone standar, 24px di tablet.

---

## 6. Iconography

- **Library:** Phosphor Icons (regular + bold variant) — bentuknya organik cocok dengan liquid style.
- **Ukuran:** 20/24/28 px.
- **Stroke:** 1.5px untuk regular, 2px untuk bold (active state).
- Pewarnaan ikon mengikuti token `--text-secondary` (inactive) → `--primary` (active).

---

## 7. Motion & Interaction

| Event | Durasi | Easing |
|---|---|---|
| Page transition | 300ms | `cubic-bezier(0.2, 0.8, 0.2, 1)` |
| Button tap | 150ms scale(0.97) | `ease-out` |
| Glass fade-in | 400ms | `ease-out-quart` |
| Live stats update | 250ms | `ease-in-out` |
| Bottom sheet | 350ms | spring (stiffness 180, damping 22) |
| Map pan/zoom | native | native |

**Tactile feedback:** Haptic `light` saat tap tombol utama, `medium` saat Mulai Tebar / Angkat Trawl.

---

## 8. Screen-by-Screen Specs

### 8.1 Onboarding (First Launch)

**3 slides + profile form:**
1. Welcome — ilustrasi kapal & tagline "Jejak Setia di Lautan"
2. Tracking offline — ilustrasi sinyal satelit + peta tanpa sinyal
3. Multi-haul — ilustrasi trawl dengan beberapa jalur

Bottom: dot indicator + tombol "Lanjut" / "Lewati".

### 8.2 Home / Map Screen (Main Hub)

**Layout:**
- Full-screen map (OSM + OpenSeaMap overlay)
- **Top bar glass** — profil kapal kiri, status trip kanan (chip: "Trip Aktif" / "Belum Trip")
- **Floating GPS Accuracy chip** — kanan atas peta ("±4m" hijau / "±20m" kuning / "±50m" merah)
- **Boat icon** — di tengah, rotate sesuai heading
- **Bottom glass panel** (ketika idle):
  - Tombol besar **"MULAI TEBAR"** hijau (atau "MULAI TRIP" jika belum trip)
  - Mini stats: "Trip ke-3 hari ini" / "0 haul"
- **Bottom nav** (4 tab): Peta 🗺️ / Riwayat 📋 / Dashboard 📊 / Pengaturan ⚙️

### 8.3 Tracking Mode (Active Haul)

Saat user tap "Mulai Tebar", layout berubah:
- **Top glass panel** muncul dengan **live stats**:
  - Durasi (HH:MM:SS) — display
  - Jarak (km) — display
  - Kecepatan (knot) — display
- **Polyline** biru aktif di peta, bertambah real-time.
- **Bottom glass panel** berganti:
  - Tombol besar **"ANGKAT TRAWL"** merah
  - Sub-text: "Haul #1 aktif • ±4m"
- **Indikator pulse** merah di top bar.

### 8.4 Haul Summary (Setelah Angkat Trawl)

Bottom sheet glass naik:
- Header: "Haul #1 Selesai" + input nama haul (editable)
- **Metric grid (2x3):** Jarak | Durasi | Kecepatan avg | Luas sapuan | Arah | Waktu selesai
- **Mini peta preview** polyline haul
- Tombol: **"Isi Log Book"** (outlined) / **"Haul Berikutnya"** (primary) / **"Akhiri Trip"** (text)

### 8.5 History (Riwayat)

- Search bar + filter tanggal (glass chip)
- List trip cards (glass-1):
  - Tanggal + nama
  - Chip metrik: `3 haul` `12.4 km` `45 kg`
  - Mini progress bar hasil tangkap
- Tap → Trip Detail screen dengan list hauls + peta gabungan.

### 8.6 Dashboard

- Period switcher (pill group): `Hari ini` `7 hari` `30 hari` `Total`
- **Hero metric** glass card: Total hasil tangkap dalam periode
- Grid 2x2 metrik: Trip | Haul | Jarak | BBM
- Bar chart: Hasil tangkap per hari (fl_chart)
- List: Top 5 spot produktif (dengan mini map pin)

### 8.7 Settings

List sections dengan glass-1 cards:
- **Profil Kapal** (nama, GT, pelabuhan, lebar trawl)
- **Preferensi Tracking** (interval GPS, unit)
- **Peta Offline** (list area + tombol tambah)
- **Tema** (Light / Dark / Ikuti Sistem)
- **Data** (total storage, ekspor semua, hapus semua)
- **Tentang** (versi, kredit, lisensi)

### 8.8 Marker / Lokasi Saya

- List marker dengan icon kategori berwarna
- FAB glass: "+" untuk tambah marker (atau long-press peta)

### 8.9 Log Book Form

- Field opsional jelas ditandai "(opsional)" agar nelayan tidak merasa wajib isi
- Hasil tangkap: dynamic list catch items (jenis + berat kg)
- Cuaca: segmented control (cerah / mendung / hujan)
- Gelombang: segmented control (tenang / sedang / tinggi)
- Catatan: textarea

### 8.10 Ekspor / Impor

**Ekspor bottom sheet:**
- Pilih format: `GPX` / `Langgeng Sea (.lsea.json)`
- Pilih scope: `Haul ini saja` / `Seluruh trip`
- Tombol "Bagikan" → share sheet OS

**Impor screen:**
- Tombol besar "Pilih File"
- Setelah pilih: preview info (pengirim, kapal, jumlah haul)
- Tombol "Impor ke Data Bersama"

---

## 9. Komponen Kunci (Library)

### 9.1 PrimaryActionButton (Liquid Glass Button)

```
Width: 100% (bottom panel) atau min 240px
Height: 72px
Border-radius: 20px
Background: gradient primary (or success/danger)
Shadow: glow halus pakai --shadow-lg dengan warna brand
Text: 18sp / 700
Icon: 24px di kiri (opsional)
Active state: scale(0.97) + haptic
```

### 9.2 GlassCard

```
Background: rgba(var) with backdrop-blur 24px
Border: 1px subtle
Border-radius: 24px
Padding: 20px
Shadow: --shadow-md
Hover: lift -2px
```

### 9.3 MetricTile

```
Glass-1 surface
Icon (top-left, 20px, colored)
Value (Display 28sp, tabular-nums, primary color)
Label (Caption 12sp, secondary)
Optional trend chip
```

### 9.4 LiquidFAB

```
Size: 64px circle
Background: primary gradient
Shadow: --shadow-lg dengan glow
Icon putih 28px
Pressed: scale(0.92)
```

### 9.5 SegmentedPill

```
Container: glass-1 pill (radius 999)
Items: padding 10/18, radius 999
Active: solid primary background, white text
Inactive: transparent, text-secondary
Transition: 250ms ease-out
```

### 9.6 StatusChip

```
Small pill, padding 6/10, radius 999
Variants: success / warning / danger / neutral
Background soft (20% alpha), text solid color
Icon optional di kiri
```

### 9.7 BottomSheet

```
Top corners radius 32px
Handle bar 40x4 di top (rounded)
Glass-2 background
Max height 90% viewport
Drag to dismiss
```

---

## 10. Accessibility

- **Contrast:** semua teks minimum 4.5:1 (WCAG AA). Glass card dengan teks di atasnya tetap readable (terutama dark mode: pakai `surface-solid` jika di atas foto).
- **Tap target:** minimum 48x48dp (tombol utama 60+).
- **Reduced motion:** respect `prefers-reduced-motion` → disable blur animation, pakai fade sederhana.
- **Font scaling:** semua pakai sp, support Android font size sampai 130%.
- **Haptic:** default enabled, bisa dinonaktifkan di Settings.

---

## 11. Dark Mode Nuances

Dark mode bukan sekadar invert:
- Gunakan `surface` semi-transparan rendah (0.06) agar tidak terlalu gelap.
- Shadow diganti dengan **inset glow** halus di border (1px soft light).
- Warna aksen (oranye) lebih soft (`#FFB74D`) agar tidak menyakitkan mata.
- Map tile bisa pakai dark tile provider (CartoDB Dark) jika tersedia cache.

---

## 12. Asset & Illustration

- **Logo:** Jangkar stilasi + gelombang + titik GPS (minimalis, monoline).
- **Onboarding illustrations:** gaya isometrik flat soft pastel.
- **Empty states:** ilustrasi friendly (misal ikan kecil berenang, perahu kecil).

---

## 13. Prototype Preview

Lihat HTML prototype interaktif di:
`.kiro/specs/langgeng-sea/prototype/index.html`

Buka di browser (double-click atau drag ke tab) untuk melihat:
- 9 screen utama
- Toggle Light / Dark mode
- Responsive phone frame preview

---

## 14. Next Steps (Design)

1. **Sprint design detail** setelah approval UX spec ini:
   - Detail micro-interaction
   - Empty states & error states per screen
   - Logo final & app icon
2. **Handoff ke dev:** eksport token ke `lib/core/constants/app_theme.dart` saat M0 Setup.
3. **User testing:** di M9 validasi dengan 3-5 nelayan beta.
