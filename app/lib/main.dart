import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/observability/crash_reporter.dart';
import 'core/observability/logger.dart';
import 'features/offline_map/data/tile_cache_service.dart';

void main() async {
  // Wrap the entire bootstrap in a guarded zone so uncaught async
  // errors outside the Flutter framework (e.g. from initialisers,
  // isolates, or fire-and-forget futures) are still funnelled into
  // the crash reporter instead of silently vanishing.
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Build a ProviderContainer eagerly so we can resolve the crash
      // reporter *before* `runApp`. We then hand the same container
      // to ProviderScope via `parent:` so features see one graph.
      final container = ProviderContainer();
      final crashReporter = container.read(crashReporterProvider);

      // Initialise the crash reporter first. Today this is a no-op
      // (NoopCrashReporter); when Sentry is wired in post-rilis the
      // provider override changes but this line stays identical.
      await crashReporter.initialise();
      Logger.instance.info('crash reporter initialised');

      // Any error inside the Flutter framework (build / layout /
      // paint / gesture) comes through FlutterError.onError.
      FlutterError.onError = (FlutterErrorDetails details) {
        // Keep the default dev-mode red-screen behaviour locally.
        FlutterError.presentError(details);
        crashReporter.recordError(
          details.exception,
          details.stack ?? StackTrace.current,
          context: {
            'source': 'FlutterError',
            if (details.library != null) 'library': details.library!,
            if (details.context != null)
              'contextSummary': details.context!.toString(),
          },
        );
      };

      // Errors that escape the Flutter framework entirely — typically
      // platform-channel callbacks, raw isolate errors, or gesture
      // handlers that throw asynchronously — land on the root
      // PlatformDispatcher. Returning true marks them as handled so
      // the default handler (which would hard-crash the app in some
      // cases) doesn't fire on top.
      PlatformDispatcher.instance.onError = (error, stack) {
        crashReporter.recordError(
          error,
          stack,
          context: const {'source': 'PlatformDispatcher'},
        );
        return true;
      };

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
      } catch (error, stack) {
        Logger.instance.warn(
          'FMTC tile cache init failed — falling back to online-only',
          null,
          error,
          stack,
        );
        crashReporter.recordError(
          error,
          stack,
          context: const {'source': 'FmtcTileCacheService.initialise'},
        );
      }

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const LangengSeaApp(),
        ),
      );
    },
    (error, stack) {
      // Zone-level fallback: anything that escapes both FlutterError
      // and PlatformDispatcher — including errors during bootstrap
      // before those handlers are installed — ends up here.
      if (kDebugMode) {
        // ignore: avoid_print
        print('Zone-guarded error: $error\n$stack');
      }
      // Best-effort: the container may not have been built yet.
      try {
        const NoopCrashReporter().recordError(error, stack, context: const {
          'source': 'runZonedGuarded',
        });
      } catch (_) {
        // Swallow — we've already logged above.
      }
    },
  );
}
