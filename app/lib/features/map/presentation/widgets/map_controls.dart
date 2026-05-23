import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'map_action_button.dart';

/// Floating column of map-related action buttons (right-aligned).
///
/// PR #40 — disederhanakan: hanya tombol "Ke posisi saya" yang
/// tersisa di sini. Kalibrasi kompas pindah ke MapOverflowMenu
/// (titik tiga). MapActionButton dipakai sebagai widget dasar untuk
/// menyatukan ukuran dengan tombol floating lain.
class MapControls extends StatelessWidget {
  const MapControls({
    super.key,
    required this.onCenterOnMe,
    this.centerEnabled = true,
    @Deprecated('Compass calibration moved to MapOverflowMenu in PR #40')
    this.onCompassCalibration,
    @Deprecated('showCompass parameter is no-op since PR #40')
    this.showCompass = false,
  });

  final VoidCallback onCenterOnMe;
  final bool centerEnabled;
  final VoidCallback? onCompassCalibration;
  final bool showCompass;

  @override
  Widget build(BuildContext context) {
    return MapActionButton(
      icon: PhosphorIconsBold.navigationArrow,
      tooltip: 'Ke posisi saya',
      onTap: centerEnabled ? onCenterOnMe : null,
      primary: true,
    );
  }
}
