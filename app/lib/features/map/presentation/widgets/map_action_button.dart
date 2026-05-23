import 'package:flutter/material.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';

/// Shared button widget untuk floating actions di map screen.
///
/// PR #40 — sebelumnya kolom kanan map screen mencampur 3 ukuran
/// tombol berbeda (40 lingkaran, 48 rounded square, pill variabel).
/// Widget ini menyatukan styling: 44×44 rounded square, icon 22,
/// GlassCard level2 untuk tombol biasa. Variant [primary] sedikit
/// lebih besar (48×48) dengan gradient untuk CTA utama (Center-on-me).
///
/// Spec:
/// - default: 44×44, BorderRadius radiusMd, icon size 22, level2
/// - primary: 48×48, BorderRadius radiusMd, icon size 24, level3 +
///   primary gradient overlay (mengikuti pola lama MapControls primary)
/// - active: tampilkan dot indicator kecil di pojok untuk menandai
///   bahwa toggle sedang aktif (mis. layers expanded, marker overlay on)
class MapActionButton extends StatelessWidget {
  const MapActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.primary = false,
    this.active = false,
    this.badgeText,
  });

  /// Phosphor / Material icon yang ditampilkan di tengah tombol.
  final IconData icon;

  /// Accessible label untuk Tooltip + Semantics. Bahasa Indonesia.
  final String tooltip;

  /// Tap handler. `null` me-disable tombol (opacity dikurangi, tap
  /// di-ignore).
  final VoidCallback? onTap;

  /// CTA utama → 48×48 + gradient. Default false (tombol toolbar
  /// biasa).
  final bool primary;

  /// Tampilkan dot indicator (status "on") di pojok kanan atas.
  /// Cocok untuk toggle button yang menggambarkan state on/off.
  final bool active;

  /// Optional badge teks kecil (mis. "3/5") di pojok kanan atas.
  /// Saat di-set, dot [active] disembunyikan dan badge dipakai.
  final String? badgeText;

  static const double _sizeNormal = 44;
  static const double _sizePrimary = 48;
  static const double _iconSizeNormal = 22;
  static const double _iconSizePrimary = 24;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final enabled = onTap != null;
    final size = primary ? _sizePrimary : _sizeNormal;
    final iconSize = primary ? _iconSizePrimary : _iconSizeNormal;
    final iconColor = primary
        ? Colors.white
        : (enabled
            ? (active ? context.colors.primary : tokens.textSecondary)
            : tokens.textTertiary);

    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GlassCard(
              level: primary ? GlassLevel.level3 : GlassLevel.level2,
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              child: Material(
                color: primary ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                child: Ink(
                  decoration: primary
                      ? BoxDecoration(
                          gradient: tokens.primaryGradient,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMd),
                        )
                      : null,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: Icon(icon, color: iconColor, size: iconSize),
                    ),
                  ),
                ),
              ),
            ),
            if (badgeText != null)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.primary,
                    borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                    border: Border.all(color: tokens.surface3, width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 18),
                  child: Text(
                    badgeText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              )
            else if (active)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: context.colors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: tokens.surface3, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
