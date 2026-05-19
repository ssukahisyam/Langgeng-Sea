import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/observability/logger.dart';
import '../../../../core/settings/application/app_settings_provider.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../tracking/application/tracking_controller.dart';
import '../../../tracking/application/tracking_mode_activation.dart';
import '../../../tracking/application/tracking_permission_flow.dart';
import '../../../tracking/domain/entities/tracking_mode.dart';
import 'tracking_mode_tutorial_sheet.dart';

/// Card di Settings yang menampilkan toggle Mode Tracking
/// (Normal / Akurasi) — PR #29 R1.
///
/// Saat user memilih [TrackingMode.accurate], card menampilkan dialog
/// konfirmasi lalu menjalankan [activateAccurateMode]. Hasil flow
/// permission dijemput dengan pattern matching:
/// - [AccurateActivated] → mode tersimpan, snackbar sukses.
/// - [AccurateActivatedWithBatteryWarning] → mode tersimpan, snackbar
///   memberitahu battery optimization belum di-grant.
/// - [AccurateNeedsSystemSettings(reason)] → tampilkan
///   [TrackingModeTutorialSheet]. Untuk reason `notifications`, mode
///   TIDAK pindah ke Akurasi (foreground service akan crash). Untuk
///   reason `battery`, mode tetap pindah Akurasi.
/// - [AccurateDeclined] → mode tetap Normal, snackbar penjelasan.
/// - [AccurateUnsupportedPlatform] → snackbar "Tidak tersedia".
///
/// Saat user memilih [TrackingMode.normal] (downgrade), card langsung
/// menyimpan mode tanpa dialog. Kalau ada haul yang sedang recording,
/// `TrackingController.downgradeBackgroundService()` di-panggil supaya
/// foreground service di-stop tanpa stop haul.
class TrackingModeCard extends ConsumerStatefulWidget {
  const TrackingModeCard({super.key});

  @override
  ConsumerState<TrackingModeCard> createState() => _TrackingModeCardState();
}

class _TrackingModeCardState extends ConsumerState<TrackingModeCard> {
  /// Idempotent guard supaya user yang spam-tap segmented Akurasi
  /// tidak memicu activation flow ganda (P2 di requirements).
  bool _busy = false;

  PermissionHandler? _handler;
  PermissionHandler get _permissionHandler =>
      _handler ??= RealPermissionHandler();

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    final colors = context.colors;
    final mode = ref.watch(trackingModeProvider);

    return GlassCard(
      level: GlassLevel.level2,
      padding: const EdgeInsets.all(AppSizes.sp1),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.sp3 + 2,
          AppSizes.sp3,
          AppSizes.sp3 + 2,
          AppSizes.sp3,
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
                    PhosphorIconsBold.broadcast,
                    size: 16,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: AppSizes.sp3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Mode Tracking', style: text.labelMedium),
                      const SizedBox(height: 2),
                      Text(
                        mode.subtitle,
                        style: text.bodySmall?.copyWith(
                          color: tokens.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // PR follow-up (Bug 3 edukasi): info icon yang
                // memunculkan dialog perbedaan Normal vs Akurasi
                // supaya user paham bahwa Mode Normal tidak track
                // saat layar mati — sesuai design, bukan bug.
                IconButton(
                  onPressed: _showInfoDialog,
                  icon: Icon(
                    PhosphorIconsRegular.info,
                    size: 18,
                    color: tokens.textSecondary,
                  ),
                  tooltip: 'Info Mode Tracking',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                if (_busy)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.sp3),
            Semantics(
              label: 'Pilih mode tracking',
              child: SegmentedButton<TrackingMode>(
                segments: const [
                  ButtonSegment<TrackingMode>(
                    value: TrackingMode.normal,
                    label: Text('Normal'),
                    icon: Icon(PhosphorIconsRegular.gauge, size: 16),
                  ),
                  ButtonSegment<TrackingMode>(
                    value: TrackingMode.accurate,
                    label: Text('Akurasi'),
                    icon: Icon(PhosphorIconsRegular.target, size: 16),
                  ),
                ],
                selected: {mode},
                showSelectedIcon: false,
                onSelectionChanged: _busy
                    ? null
                    : (selection) => _onSelectionChanged(selection.first),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSelectionChanged(TrackingMode target) async {
    final current = ref.read(trackingModeProvider);
    if (target == current) return; // no-op

    if (target == TrackingMode.normal) {
      await _switchToNormal();
    } else {
      await _switchToAccurate();
    }
  }

  /// Pindah Akurasi → Normal: tidak butuh konfirmasi, langsung simpan.
  /// Kalau ada haul yang sedang recording, downgrade foreground service
  /// supaya tidak orphan (R5 AC1).
  /// PR follow-up: dialog edukasi perbedaan Normal vs Akurasi.
  /// Dimunculkan saat user tap info icon. Konsisten dengan wording
  /// di subtitle TrackingMode supaya tidak ada ekspektasi
  /// "Normal harusnya tetap track saat layar mati" yang berlawanan
  /// dengan design Mode Normal (foreground GPS subscription saja
  /// tanpa foreground service).
  Future<void> _showInfoDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mode Tracking'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mode Normal',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 4),
            Text(
              'Tracking tetap berusaha merekam saat layar mati, tapi tanpa '
              'optimasi baterai sehingga hasilnya bisa kurang akurat di '
              'beberapa device. Memerlukan izin notifikasi.',
            ),
            SizedBox(height: 12),
            Text(
              'Mode Akurasi',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 4),
            Text(
              'Tracking tetap merekam saat layar mati dengan akurasi maksimal. '
              'Cocok untuk trip panjang. Memerlukan izin notifikasi dan '
              'pengoptimalan baterai.',
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  Future<void> _switchToNormal() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(appSettingsRepositoryProvider);
      await repo.setTrackingMode(TrackingMode.normal);

      // Stop foreground service kalau sedang aktif. Operasi ini
      // idempotent — kalau service tidak running, panggilan
      // `_bgService.stop()` di TrackingController di-swallow.
      try {
        await ref
            .read(trackingControllerProvider.notifier)
            .downgradeBackgroundService();
      } catch (e) {
        Logger.instance.warn(
          'tracking.mode_card_downgrade_failed',
          {'error': e.toString()},
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mode Normal aktif. Hemat baterai.'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Pindah Normal → Akurasi: konfirmasi dulu, lalu jalankan
  /// activation flow. Hasil dijemput dan UI side effect (snackbar /
  /// sheet) di-trigger di sini.
  Future<void> _switchToAccurate() async {
    final confirmed = await _showConfirmDialog();
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final result = await activateAccurateMode(
        handler: _permissionHandler,
      );

      if (!mounted) return;
      await _handleActivationResult(result);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _showConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aktifkan Mode Akurasi?'),
        content: const Text(
          'Mode Akurasi memerlukan izin notifikasi dan akses pengaturan '
          'baterai. Tracking akan tetap merekam saat layar mati.\n\n'
          'Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleActivationResult(ActivateAccurateResult result) async {
    final repo = ref.read(appSettingsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    switch (result) {
      case AccurateActivated():
        await repo.setTrackingMode(TrackingMode.accurate);
        await _maybeUpgradeRunningHaul();
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Mode Akurasi aktif.'),
            duration: Duration(seconds: 2),
          ),
        );

      case AccurateActivatedWithBatteryWarning():
        await repo.setTrackingMode(TrackingMode.accurate);
        await _maybeUpgradeRunningHaul();
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Mode Akurasi aktif, tapi pengoptimalan baterai belum dimatikan. '
              'GPS bisa dibatasi saat layar mati.',
            ),
            duration: Duration(seconds: 4),
          ),
        );

      case AccurateNeedsSystemSettings(:final reason):
        // Untuk reason notifications: mode TIDAK pindah Akurasi
        // (foreground service akan crash tanpa notifikasi).
        // Untuk reason battery: mode tetap pindah Akurasi karena
        // foreground service bisa jalan tanpa exemption.
        if (reason == NeedSettingsReason.battery) {
          await repo.setTrackingMode(TrackingMode.accurate);
          await _maybeUpgradeRunningHaul();
        }
        if (!mounted) return;
        await TrackingModeTutorialSheet.show(context, reason: reason);

      case AccurateDeclined():
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Izin notifikasi dibutuhkan untuk Mode Akurasi. Mode tetap Normal.',
            ),
            duration: Duration(seconds: 3),
          ),
        );

      case AccurateUnsupportedPlatform():
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Mode Akurasi tidak tersedia di platform ini.'),
            duration: Duration(seconds: 2),
          ),
        );
    }
  }

  /// Kalau ada haul yang sedang recording saat user pindah ke Akurasi,
  /// upgrade foreground service supaya tracking lanjut tanpa
  /// kehilangan data (R5 AC4). Kalau gagal, log warning — mode toggle
  /// tetap commit, user akan lihat banner backgroundDegraded.
  Future<void> _maybeUpgradeRunningHaul() async {
    try {
      await ref
          .read(trackingControllerProvider.notifier)
          .upgradeBackgroundService();
    } catch (e) {
      Logger.instance.warn(
        'tracking.mode_card_upgrade_failed',
        {'error': e.toString()},
      );
    }
  }
}
