import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/offline_map/data/tile_cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Allow portrait only for MVP (landscape map is a nice-to-have for v2).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Initialise the FMTC backend *before* the first FlutterMap is built.
  // Failure here doesn't block the app — the provider falls back to a
  // plain network-only tile layer and the user sees a banner in
  // Settings when they try to add offline regions.
  try {
    await FmtcTileCacheService().initialise();
  } catch (_) {
    // Swallow: tile cache is best-effort. The map still works online.
  }

  runApp(
    const ProviderScope(
      child: LangengSeaApp(),
    ),
  );
}
