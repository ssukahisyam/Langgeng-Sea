import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin abstraction over a crash-reporting backend (Sentry, Crashlytics, …).
///
/// Kept as an interface with a default no-op implementation so the MVP
/// ships without any third-party SDK and we can wire a real backend in
/// v1.1 by swapping the provider override — no call-site changes.
///
/// Typical call-sites:
///
/// ```dart
/// try {
///   await riskyThing();
/// } catch (e, st) {
///   ref.read(crashReporterProvider).recordError(e, st, context: {
///     'feature': 'tracking.startHaul',
///     'tripId': tripId,
///   });
///   rethrow;
/// }
/// ```
abstract class CrashReporter {
  /// Called once at app start (from `main`). Async so backends with
  /// network bootstrap (Sentry DSN fetch, rate-limit config) can finish.
  Future<void> initialise();

  /// Report an error. [context] is a free-form map — values should be
  /// small, non-PII, and serializable (Strings, numbers, bools).
  void recordError(
    Object error,
    StackTrace stack, {
    Map<String, dynamic>? context,
  });

  /// Attach user / session context so crashes can be correlated.
  /// `null` values clear the field.
  ///
  /// **Never** pass raw PII here — use the local profile id or a hash
  /// of the vessel name if you need a grouping key in v1.1.
  void setUserContext({String? userId, String? vesselName});

  /// Record a breadcrumb-style log line that will be attached to the
  /// next reported error. Keep messages short and factual.
  void log(String message);
}

/// Default implementation: silently discards everything. Used by the
/// MVP so the app has no runtime dependency on a crash SDK.
class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();

  @override
  Future<void> initialise() async {}

  @override
  void recordError(
    Object error,
    StackTrace stack, {
    Map<String, dynamic>? context,
  }) {}

  @override
  void setUserContext({String? userId, String? vesselName}) {}

  @override
  void log(String message) {}
}

/// Riverpod provider. Override in `main()` when a real backend is wired:
///
/// ```dart
/// ProviderScope(
///   overrides: [
///     crashReporterProvider.overrideWithValue(SentryCrashReporter()),
///   ],
///   child: const LangengSeaApp(),
/// );
/// ```
final crashReporterProvider = Provider<CrashReporter>((ref) {
  return const NoopCrashReporter();
});
