import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/history/presentation/haul_detail_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/history/presentation/trip_detail_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../widgets/app_shell.dart';

/// Route paths (centralized for type-safe navigation).
///
/// Tab routes live inside the [ShellRoute] so the bottom nav persists.
/// Detail routes sit at the root-navigator level so they cover the shell
/// (bottom nav hides) and users get a natural "back" gesture.
abstract class AppRoutes {
  // Tabs
  static const String map = '/';
  static const String history = '/history';
  static const String dashboard = '/dashboard';
  static const String settings = '/settings';

  // Detail routes (root navigator)
  static const String tripDetailPath = '/trip/:id';
  static const String haulDetailPath = '/haul/:id';

  // Coming in later milestones
  static const String markerList = '/markers';
  static const String mapOffline = '/settings/offline-map';
  static const String profile = '/settings/profile';
  static const String logBook = '/log-book/:haulId';

  /// Builds the concrete path for a trip detail. Keeps callers from
  /// string-concatenating route fragments.
  static String tripDetail(String id) => '/trip/$id';
  static String haulDetail(String id) => '/haul/$id';
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

/// App-wide GoRouter configuration with a bottom-nav shell.
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppRoutes.map,
  debugLogDiagnostics: false,
  routes: [
    // Shell-bound tab routes. Bottom nav stays visible.
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

    // Root-level detail routes — push on top of the shell.
    GoRoute(
      path: AppRoutes.tripDetailPath,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return _slideUp(TripDetailScreen(tripId: id));
      },
    ),
    GoRoute(
      path: AppRoutes.haulDetailPath,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return _slideUp(HaulDetailScreen(haulId: id));
      },
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

/// Modal-style slide-up for drill-down routes. Keeps the Clean Liquid
/// Glass feel without the platform swoosh.
CustomTransitionPage<T> _slideUp<T>(Widget child) {
  return CustomTransitionPage<T>(
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}
