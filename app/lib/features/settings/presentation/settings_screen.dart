import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/settings/application/app_settings_provider.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../export_import/data/imported_dataset_repository.dart';
import '../../onboarding/data/user_profile_repository.dart';
import '../../onboarding/domain/entities/user_profile.dart';
import 'widgets/device_status_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.text;
    final tokens = context.tokens;
    final mode = ref.watch(themeModeProvider);
    final profile = ref.watch(userProfileProvider).asData?.value;

    return AmbientBackground(
      child: SafeArea(
        bottom: false,
        child: _buildLazyList(context, ref, mode, profile),
      ),
    );
  }

  /// PR follow-up performance: pakai [ListView.builder] dengan
  /// `RepaintBoundary` per item supaya scroll lebih smooth. Sebelumnya
  /// `ListView(children: [...])` build semua child sekaligus saat
  /// mount, dan setiap card berisi shadow / gradient / GlassCard yang
  /// di-paint dalam satu pass — itu yang bikin frame drop saat user
  /// scroll ke bawah.
  Widget _buildLazyList(
    BuildContext context,
    WidgetRef ref,
    ThemeMode mode,
    UserProfile? profile,
  ) {
    final text = context.text;
    final tokens = context.tokens;

    // Build daftar widget item. Method-helper-style supaya body
    // tetap kebaca dan tiap card bisa di-bungkus RepaintBoundary
    // tanpa nested noise.
    final items = <Widget>[
      Text(AppStrings.tabSettings, style: text.headlineLarge),
      const SizedBox(height: AppSizes.sp5),
      // PR #41: card "Status Perangkat" promote ke posisi paling
      // atas (di atas Profile) supaya user langsung lihat status
      // permission saat buka Settings. Background warning kalau
      // ada permission wajib yang denied.
      const DeviceStatusCard(),
      const SizedBox(height: AppSizes.sp3),
      _buildProfileCard(context, profile),
      const SizedBox(height: AppSizes.sp3),
      _buildThemeCard(context, ref, mode),
      const SizedBox(height: AppSizes.sp3),
      _PolylineWidthCard(),
      const SizedBox(height: AppSizes.sp3),
      _buildToolsCard(context, profile),
      const SizedBox(height: AppSizes.sp6),
      _buildFooter(context),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.sp5,
        AppSizes.sp4,
        AppSizes.sp5,
        120,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => RepaintBoundary(
        child: items[i],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, UserProfile? profile) {
    final text = context.text;
    final tokens = context.tokens;
    return Semantics(
      label: profile == null
          ? 'Profil belum diisi, ketuk untuk mengisi'
          : 'Profil ${profile.name}, kapal ${profile.vesselName}, '
              'ketuk untuk mengedit',
      button: true,
      child: GlassCard(
        level: GlassLevel.level2,
        padding: const EdgeInsets.all(AppSizes.sp4),
        onTap: () => context.push(AppRoutes.profileEdit),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: tokens.primaryGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: tokens.glowPrimary,
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                PhosphorIconsFill.sailboat,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSizes.sp4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    profile?.vesselName ?? 'Profil Belum Diisi',
                    style: text.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _profileSubtitle(profile),
                    style: text.bodySmall?.copyWith(
                      color: tokens.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              PhosphorIconsRegular.pencilSimple,
              size: 20,
              color: tokens.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCard(BuildContext context, WidgetRef ref, ThemeMode mode) {
    final tokens = context.tokens;
    return GlassCard(
      level: GlassLevel.level2,
      padding: const EdgeInsets.all(AppSizes.sp1),
      child: Column(
        children: [
          _SettingsTile(
            iconColor: context.colors.secondary,
            iconBg: tokens.accentSoft,
            icon: PhosphorIconsBold.moon,
            title: 'Tema Aplikasi',
            subtitle: _themeLabel(mode),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(PhosphorIconsRegular.sun, size: 16),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(PhosphorIconsRegular.moon, size: 16),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(PhosphorIconsRegular.circleHalf, size: 16),
                ),
              ],
              selected: {mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  ref.read(themeModeProvider.notifier).setMode(s.first),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsCard(BuildContext context, UserProfile? profile) {
    final tokens = context.tokens;
    return GlassCard(
      level: GlassLevel.level2,
      padding: const EdgeInsets.all(AppSizes.sp1),
      child: Column(
        children: [
          _SettingsTile(
            iconColor: context.colors.secondary,
            iconBg: tokens.accentSoft,
            icon: PhosphorIconsBold.ruler,
            title: 'Lebar Bukaan Trawl',
            subtitle: profile == null
                ? 'Isi profil untuk mengatur'
                : '${_fmtWidth(profile.trawlWidthMeters)} meter',
            onTap: profile == null
                ? null
                : () => context.push(AppRoutes.profileEdit),
          ),
          Divider(color: tokens.border, height: 1, indent: 16, endIndent: 16),
          _SettingsTile(
            iconColor: context.colors.primary,
            iconBg: tokens.primarySoft,
            icon: PhosphorIconsBold.downloadSimple,
            title: 'Peta Offline',
            subtitle: 'Download tile agar peta jalan tanpa sinyal',
            onTap: () => context.push(AppRoutes.offlineMap),
          ),
          Divider(color: tokens.border, height: 1, indent: 16, endIndent: 16),
          _SettingsTile(
            iconColor: context.colors.primary,
            iconBg: tokens.primarySoft,
            icon: PhosphorIconsBold.shareFat,
            title: 'Ekspor Data',
            subtitle: 'Bagikan jalur & penanda dalam format GPX',
            onTap: () => context.push(AppRoutes.exportData),
          ),
          Divider(color: tokens.border, height: 1, indent: 16, endIndent: 16),
          // PR follow-up: tile Impor Data dipindah dari Manajemen
          // Data card ke Tools card. Tile yang lama menggunakan
          // GpxSyncService.importFromGpx() (parser legacy yang
          // abaikan extension <lsea:haul>). Sekarang push ke
          // ImportScreen yang pakai GpxImporter baru — fix bug:
          // 1. Dataset row muncul di Kelola Data Impor
          // 2. Warna polyline match colorValue dari file
          // 3. Jarak/durasi/sweptArea match value di lsea:haul
          _SettingsTile(
            iconColor: context.colors.secondary,
            iconBg: tokens.accentSoft,
            icon: PhosphorIconsBold.download,
            title: 'Impor Data',
            subtitle: 'Muat file GPX dari nelayan lain',
            onTap: () => context.push(AppRoutes.importData),
          ),
          Divider(color: tokens.border, height: 1, indent: 16, endIndent: 16),
          // PR #33: tile Kelola Data Impor pindah dari Manajemen
          // Data card ke Tools card supaya semua data management
          // ada di satu tempat.
          _ImportedDatasetsTile(),
          Divider(color: tokens.border, height: 1, indent: 16, endIndent: 16),
          _SettingsTile(
            iconColor: context.colors.secondary,
            iconBg: tokens.accentSoft,
            icon: PhosphorIconsBold.mapPin,
            title: 'Kelola Penanda',
            subtitle: 'Lihat & atur penanda lokasi di peta',
            onTap: () => context.push(AppRoutes.markerList),
          ),
          // PR #41: BatteryOptimizationTile dihapus dari sini.
          // Permission battery sekarang ada di card "Status
          // Perangkat" di atas Profile, bareng Lokasi & Notifikasi.
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    return Center(
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tokens.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              PhosphorIconsFill.anchorSimple,
              size: 22,
              color: context.colors.primary,
            ),
          ),
          const SizedBox(height: AppSizes.sp2),
          Text(
            'Langgeng Sea v0.1.0 (M8)',
            style: text.labelSmall?.copyWith(
              color: tokens.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            AppStrings.tagline,
            style: text.labelSmall?.copyWith(color: tokens.textTertiary),
          ),
        ],
      ),
    );
  }

  String _profileSubtitle(UserProfile? p) {
    if (p == null) return 'Tekan untuk mengisi profil kapal';
    final parts = <String>[p.friendlyGreeting];
    if (p.vesselGtOptional != null) {
      parts.add('GT ${_fmtWidth(p.vesselGtOptional!)}');
    }
    if (p.homePortOptional != null && p.homePortOptional!.isNotEmpty) {
      parts.add(p.homePortOptional!);
    }
    return parts.join(' • ');
  }

  String _fmtWidth(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  String _themeLabel(ThemeMode m) => switch (m) {
        ThemeMode.light => 'Mode Terang',
        ThemeMode.dark => 'Mode Gelap',
        ThemeMode.system => 'Ikuti Sistem',
      };
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.iconBg,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color iconBg;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;

    return Opacity(
      opacity: enabled ? 1.0 : 0.6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.sp3 + 2,
              AppSizes.sp3,
              AppSizes.sp3 + 2,
              AppSizes.sp3,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: AppSizes.sp3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: text.labelMedium),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(
                          color: tokens.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
                if (trailing == null && onTap != null)
                  Icon(
                    PhosphorIconsRegular.caretRight,
                    size: 16,
                    color: tokens.textTertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card with a slider to adjust the map polyline width (4–16px).
class _PolylineWidthCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PolylineWidthCard> createState() => _PolylineWidthCardState();
}

class _PolylineWidthCardState extends ConsumerState<_PolylineWidthCard> {
  /// Draft value selama user drag slider. Null = pakai value
  /// committed dari provider. Saat user lepas slider (`onChangeEnd`),
  /// kita commit sekali ke DB lalu reset draft → provider stream
  /// emit nilai baru → null fallback ke committed.
  ///
  /// Tujuan: hindari DB write per drag-tick (12 commit untuk slider
  /// 4→16) yang trigger Drift stream re-emit + MapScreen polyline
  /// rebuild.
  double? _draftValue;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    final committedWidth = ref.watch(polylineWidthProvider);
    final currentWidth = _draftValue ?? committedWidth;

    return GlassCard(
      level: GlassLevel.level2,
      padding: const EdgeInsets.all(AppSizes.sp1),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.sp3 + 2,
          AppSizes.sp3,
          AppSizes.sp3 + 2,
          AppSizes.sp2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tokens.primarySoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    PhosphorIconsBold.lineSegments,
                    size: 16,
                    color: context.colors.primary,
                  ),
                ),
                const SizedBox(width: AppSizes.sp3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Ketebalan Garis Peta', style: text.labelMedium),
                      const SizedBox(height: 2),
                      Text(
                        '${currentWidth.round()} px',
                        style: text.bodySmall?.copyWith(
                          color: tokens.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sp2),
            // Visual preview line — pakai currentWidth (draft) supaya
            // user dapat feedback realtime saat drag tanpa harus
            // commit ke DB.
            Container(
              height: currentWidth,
              decoration: BoxDecoration(
                gradient: tokens.primaryGradient,
                borderRadius: BorderRadius.circular(currentWidth / 2),
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: context.colors.primary,
                inactiveTrackColor: tokens.border,
                thumbColor: context.colors.primary,
                overlayColor: context.colors.primary.withValues(alpha: 0.12),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 8,
                ),
              ),
              child: Slider(
                value: currentWidth,
                min: 4,
                max: 16,
                divisions: 12,
                onChanged: (value) {
                  // Local state only — TIDAK commit ke DB di sini.
                  setState(() => _draftValue = value);
                },
                onChangeEnd: (value) async {
                  // Commit final value ke DB sekali, lalu reset draft.
                  await ref
                      .read(appSettingsRepositoryProvider)
                      .setPolylineWidth(value.round());
                  if (mounted) {
                    setState(() => _draftValue = null);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// PR #33: tile "Kelola Data Impor" yang menampilkan counter dataset
/// + navigasi ke `ImportedDatasetsScreen`. Counter di-update reaktif
/// lewat `importedDatasetsProvider` stream — hilang otomatis kalau
/// user hapus dataset terakhir, muncul lagi setelah import baru.
class _ImportedDatasetsTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final asyncDatasets = ref.watch(importedDatasetsProvider);
    final count = asyncDatasets.asData?.value.length ?? 0;
    final subtitle =
        count == 0 ? 'Belum ada data impor' : '$count dataset diimpor';
    return _SettingsTile(
      iconColor: context.colors.primary,
      iconBg: tokens.primarySoft,
      icon: PhosphorIconsBold.folderOpen,
      title: 'Kelola Data Impor',
      subtitle: subtitle,
      onTap: () => context.push(AppRoutes.importedDatasets),
    );
  }
}
