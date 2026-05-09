import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../data/user_profile_repository.dart';
import '../../domain/entities/user_profile.dart';

/// Reusable profile form — used by both first-run onboarding and the
/// Settings "edit" flow. Caller supplies the CTA label and the onSaved
/// callback so the navigation target differs per context.
class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({
    super.key,
    required this.ctaLabel,
    required this.onSaved,
    this.initial,
  });

  final String ctaLabel;
  final UserProfile? initial;
  final void Function(UserProfile profile) onSaved;

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _vessel;
  late final TextEditingController _gt;
  late final TextEditingController _width;
  late final TextEditingController _port;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _name = TextEditingController(text: init?.name ?? '');
    _vessel = TextEditingController(text: init?.vesselName ?? '');
    _gt = TextEditingController(
      text: init?.vesselGtOptional == null
          ? ''
          : init!.vesselGtOptional!.toStringAsFixed(
              init.vesselGtOptional! % 1 == 0 ? 0 : 1),
    );
    _width = TextEditingController(
      text: (init?.trawlWidthMeters ?? UserProfile.defaultTrawlWidthMeters)
          .toStringAsFixed(
        (init?.trawlWidthMeters ?? UserProfile.defaultTrawlWidthMeters) % 1 == 0
            ? 0
            : 1,
      ),
    );
    _port = TextEditingController(text: init?.homePortOptional ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _vessel.dispose();
    _gt.dispose();
    _width.dispose();
    _port.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final width = double.tryParse(_width.text.replaceAll(',', '.')) ??
        UserProfile.defaultTrawlWidthMeters;
    final gtText = _gt.text.trim();
    final gt = gtText.isEmpty
        ? null
        : double.tryParse(gtText.replaceAll(',', '.'));

    final validationError = UserProfile.validate(
      name: _name.text,
      vesselName: _vessel.text,
      trawlWidthMeters: width,
      vesselGt: gt,
    );
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final saved = await ref.read(userProfileRepositoryProvider).saveProfile(
            name: _name.text,
            vesselName: _vessel.text,
            trawlWidthMeters: width,
            vesselGt: gt,
            homePort: _port.text,
          );
      if (!mounted) return;
      widget.onSaved(saved);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassCard(
            level: GlassLevel.level2,
            padding: const EdgeInsets.all(AppSizes.sp5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FieldLabel('Nama Anda'),
                const SizedBox(height: AppSizes.sp2),
                Semantics(
                  label: 'Input nama nelayan',
                  textField: true,
                  child: TextFormField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration(
                      context,
                      hint: 'Misal: Hasan',
                      icon: PhosphorIconsRegular.user,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                ),
                const SizedBox(height: AppSizes.sp4),
                _FieldLabel('Nama Kapal'),
                const SizedBox(height: AppSizes.sp2),
                Semantics(
                  label: 'Input nama kapal',
                  textField: true,
                  child: TextFormField(
                    controller: _vessel,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration(
                      context,
                      hint: 'Misal: KM Harapan Jaya',
                      icon: PhosphorIconsRegular.sailboat,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                ),
                const SizedBox(height: AppSizes.sp4),
                _FieldLabel('GT Kapal (opsional)'),
                const SizedBox(height: AppSizes.sp2),
                Semantics(
                  label: 'Input Gross Tonnage kapal, opsional',
                  textField: true,
                  child: TextFormField(
                    controller: _gt,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    decoration: _decoration(
                      context,
                      hint: 'Contoh: 5',
                      icon: PhosphorIconsRegular.scales,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.sp4),
          GlassCard(
            level: GlassLevel.level2,
            padding: const EdgeInsets.all(AppSizes.sp5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FieldLabel('Lebar Bukaan Trawl (meter)'),
                const SizedBox(height: AppSizes.sp1),
                Text(
                  'Default 20m — ganti sesuai ukuran trawl Anda',
                  style: text.bodySmall?.copyWith(color: tokens.textTertiary),
                ),
                const SizedBox(height: AppSizes.sp2),
                Semantics(
                  label: 'Input lebar bukaan trawl dalam meter',
                  textField: true,
                  child: TextFormField(
                    controller: _width,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    decoration: _decoration(
                      context,
                      hint: '20',
                      icon: PhosphorIconsRegular.ruler,
                      suffix: 'm',
                    ),
                    validator: (v) {
                      final parsed =
                          double.tryParse((v ?? '').replaceAll(',', '.'));
                      if (parsed == null || parsed <= 0) {
                        return 'Masukkan angka > 0';
                      }
                      if (parsed > 200) return 'Maksimum 200';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: AppSizes.sp4),
                _FieldLabel('Pelabuhan Asal (opsional)'),
                const SizedBox(height: AppSizes.sp2),
                Semantics(
                  label: 'Input pelabuhan asal, opsional',
                  textField: true,
                  child: TextFormField(
                    controller: _port,
                    textInputAction: TextInputAction.done,
                    decoration: _decoration(
                      context,
                      hint: 'Misal: Brondong',
                      icon: PhosphorIconsRegular.anchorSimple,
                    ),
                    onFieldSubmitted: (_) => _onSave(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.sp6),
          Semantics(
            label: widget.ctaLabel,
            button: true,
            child: PrimaryActionButton(
              label: _saving ? 'Menyimpan…' : widget.ctaLabel,
              icon: PhosphorIconsBold.check,
              variant: ActionButtonVariant.primary,
              onPressed: _saving ? null : _onSave,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(
    BuildContext context, {
    required String hint,
    required IconData icon,
    String? suffix,
  }) {
    final tokens = context.tokens;
    return InputDecoration(
      hintText: hint,
      hintStyle: context.text.bodyMedium?.copyWith(color: tokens.textTertiary),
      prefixIcon: Icon(icon, size: 20, color: tokens.textSecondary),
      suffixText: suffix,
      filled: true,
      fillColor: tokens.surface1,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        borderSide: BorderSide(color: tokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        borderSide: BorderSide(color: tokens.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        borderSide: BorderSide(color: context.colors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sp4,
        vertical: AppSizes.sp4,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: context.text.titleSmall);
  }
}
