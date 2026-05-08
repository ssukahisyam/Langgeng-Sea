# M6 — Dashboard Statistik

**Status:** ✅ Shipped  
**Durasi:** ~1 minggu  
**Branch:** `feat/m6-dashboard`

---

## Apa yang dikirim

### 1. Dashboard Stats Provider (`dashboard_stats_provider.dart`)
- `DashboardPeriod` enum: `today`, `week7`, `month30`, `total`
- `DashboardStats` data class — aggregated metrics (trip count, haul count, distance, duration, swept area, catch kg, fuel liters, daily catches, top spots)
- `DailyCatch` model for bar chart data points
- `TopSpot` model for ranked haul spots
- `dashboardPeriodProvider` — StateProvider defaulting to `week7`
- `dashboardStatsProvider` — FutureProvider that queries Drift DB directly (trips, hauls, log_book_entries, catch_items) and aggregates per selected period

### 2. Dashboard Screen (rewritten)
- Period switcher: glass-1 pill group ("Hari ini", "7 Hari", "30 Hari", "Total")
- Hero metric card (glass-2): total catch in kg/ton, trend chip placeholder
- 2×2 metric grid (glass-1 tiles): Trip count, Haul count, Total distance (km), Total BBM (L)
- Bar chart card (glass-2): daily catches using `fl_chart` BarChart — last 7 days, accent highlight on highest bar, gradient fill, rounded top corners (radius 8)
- Top 5 spots card (glass-2): ranked list showing haul name + total catch from that haul
- Loading / error / empty states matching existing app patterns
- ConsumerWidget with `ref.watch` pattern
- All text in Bahasa Indonesia
- Tabular-nums FontFeature for metric values
- Uses AmbientBackground, GlassCard, LangTokens, existing text styles

### 3. Unit Tests (`dashboard_stats_test.dart`)
- DashboardStats default/empty values
- DashboardPeriod enum completeness (4 values)
- DailyCatch and TopSpot model construction

### 4. README Roadmap Updated
- M6 ✅ Done
- M7 🔜 Next

---

## Keputusan Teknis

1. **Direct DB access** — provider menggunakan `appDatabaseProvider` untuk query langsung ke tabel, bukan melalui repository layer, untuk efisiensi aggregation (menghindari N+1 queries)
2. **Period filter on trips.startedAt** — semua data di-filter berdasarkan waktu mulai trip, bukan per haul
3. **Daily catches grouped by trip date** — bar chart menampilkan total kg per hari berdasarkan tanggal trip dimulai
4. **Max 7 bars** — bar chart selalu menampilkan max 7 data points terakhir agar tetap readable
5. **Top spots** — ranked by catch per haul (via log book entry with haulId), max 5

---

## Tidak berubah

- `app_router.dart` — dashboard sudah menjadi tab route sejak M0
- Database schema — tidak ada perubahan tabel / migrasi
