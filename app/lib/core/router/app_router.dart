import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../widgets/app_shell.dart';

/// Route paths (centralized for type-safe navigation).
abstract class AppRoutes {
  static const String map = '/';
  static const String history = '/history';
  static const String dashboard = '/dashboard';
  static const String settings = '/settings';

  // Future routes (coming in M2+)
  static const String tripDetail = '/history/trip/:id';
  static const String haulDetail = '/history/haul/:id';
  static const String markerList = '/markers';
  static const String mapOffline = '/settings/offline-map';
  static const String profile = '/settings/profile';
  static const String logBook = '/log-book/:haulId';
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

/// App-wide GoRouter configuration with a bottom-nav shell.
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppRoutes.map,
  debugLogDiagnostics: false,
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.map,
          pageBuilder: (_, __) => _noTransition(const MapScreen()),
        ),
        GoRoute(
          path: AppRoutes.history,
          pageBuilder: (_, __) => _noTransition(const HistoryScreen()),
        ),
        GoRoute(
          path: AppRoutes.dashboard,
          pageBuilder: (_, __) => _noTransition(const DashboardScreen()),
        ),
        GoRoute(
          path: AppRoutes.settings,
          pageBuilder: (_, __) => _noTransition(const SettingsScreen()),
        ),
      ],
    ),
  ],
);

CustomTransitionPage<T> _noTransition<T>(Widget child) {
  return CustomTransitionPage<T>(
    child: child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    transitionsBuilder: (_, __, ___, child) => child,
  );
}
