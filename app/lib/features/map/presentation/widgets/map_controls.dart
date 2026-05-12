import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';

import 'package:flutter_map/flutter_map.dart';

/// Floating column of map-related action buttons (right-aligned).
class MapControls extends StatelessWidget {
  const MapControls({
    super.key,
    required this.onCenterOnMe,
    this.onCompassReset,
    this.showCompass = false,
    this.centerEnabled = true,
    this.mapController,
  });

  final VoidCallback onCenterOnMe;
  final VoidCallback? onCompassReset;
  final bool showCompass;
  final bool centerEnabled;
  final MapController? mapController;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showCompass && onCompassReset != null) ...[
          if (mapController != null)
            StreamBuilder<MapEvent>(
              stream: mapController!.mapEventStream,
              builder: (context, snapshot) {
                final rotation = mapController!.camera.rotation;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ControlButton(
                      icon: PhosphorIconsBold.compass,
                      tooltip: 'Kiblat ulang',
                      onTap: onCompassReset!,
                      rotation: rotation * (3.141592653589793 / 180.0),
                    ),
                    const SizedBox(height: AppSizes.sp2),
                  ],
                );
              },
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ControlButton(
                  icon: PhosphorIconsBold.compass,
                  tooltip: 'Kiblat ulang',
                  onTap: onCompassReset!,
                ),
                const SizedBox(height: AppSizes.sp2),
              ],
            ),
        ],
        _ControlButton(
          icon: PhosphorIconsBold.navigationArrow,
          tooltip: 'Ke posisi saya',
          onTap: centerEnabled ? onCenterOnMe : null,
          primary: true,
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.primary = false,
    this.rotation,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool primary;
  final double? rotation;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final enabled = onTap != null;
    final iconColor = primary
        ? Colors.white
        : (enabled ? tokens.textSecondary : tokens.textTertiary);

    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: GlassCard(
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
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    )
                  : null,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: rotation == null
                      ? Icon(icon, color: iconColor, size: 20)
                      : Transform.rotate(
                          angle: rotation!,
                          child: Icon(icon, color: iconColor, size: 20),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
