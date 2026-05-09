import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Log severity levels, ordered by ascending urgency.
enum LogLevel {
  debug(0, 'DEBUG'),
  info(1, 'INFO'),
  warn(2, 'WARN'),
  error(3, 'ERROR');

  const LogLevel(this.priority, this.label);
  final int priority;
  final String label;
}

/// A minimal `print`-based logger with level filtering.
///
/// - **Debug builds:** everything is printed (`LogLevel.debug` and up).
/// - **Release builds:** only warnings & errors are printed — keeps
///   logcat quiet and avoids leaking debug noise in production APKs.
///
/// This is the MVP-level logger. When the app moves to real
/// observability (Sentry, Firebase Crashlytics), the `CrashReporter`
/// interface in `crash_reporter.dart` takes over for structured
/// reporting. Until then, `Logger` exists so feature code can write
/// breadcrumb-style log lines without pulling extra dependencies.
///
/// Usage:
///
/// ```dart
/// Logger.instance.info('tracking started', {'tripId': tripId});
/// Logger.instance.error('tile download failed', error, stack);
/// ```
class Logger {
  Logger._();

  /// Process-wide singleton. A singleton is fine here because the
  /// logger is state-free apart from its (compile-time) level floor.
  static final Logger instance = Logger._();

  /// Minimum level that will be emitted. In release builds this is
  /// raised to `warn` automatically; tests may override it via
  /// [setMinimumLevel] for quieter output.
  LogLevel _minimum = kReleaseMode ? LogLevel.warn : LogLevel.debug;

  /// Override the minimum level. Primarily useful from tests.
  @visibleForTesting
  void setMinimumLevel(LogLevel level) => _minimum = level;

  void debug(String message, [Map<String, dynamic>? context]) =>
      _emit(LogLevel.debug, message, context);

  void info(String message, [Map<String, dynamic>? context]) =>
      _emit(LogLevel.info, message, context);

  void warn(
    String message, [
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stack,
  ]) =>
      _emit(LogLevel.warn, message, context, error: error, stack: stack);

  void error(
    String message,
    Object error, [
    StackTrace? stack,
    Map<String, dynamic>? context,
  ]) =>
      _emit(LogLevel.error, message, context, error: error, stack: stack);

  void _emit(
    LogLevel level,
    String message,
    Map<String, dynamic>? context, {
    Object? error,
    StackTrace? stack,
  }) {
    if (level.priority < _minimum.priority) return;

    final ctx = _formatContext(context);
    final line = '[${level.label}] $message${ctx.isEmpty ? '' : ' $ctx'}';

    // Plain `print` — Flutter already routes these to logcat on Android
    // and to the debug console in IDEs. We intentionally avoid
    // `dart:developer`'s `log` to keep the output format predictable
    // and greppable.
    // ignore: avoid_print
    print(line);
    if (error != null) {
      // ignore: avoid_print
      print('  error: $error');
    }
    if (stack != null) {
      // ignore: avoid_print
      print('  stack:\n$stack');
    }
  }

  String _formatContext(Map<String, dynamic>? context) {
    if (context == null || context.isEmpty) return '';
    return context.entries.map((e) => '${e.key}=${e.value}').join(' ');
  }
}

/// Riverpod provider. Tests / alternative runtimes can override this
/// with a recording / silent logger if they need to assert on log
/// output. Most feature code can just use `Logger.instance` directly.
final loggerProvider = Provider<Logger>((ref) => Logger.instance);
