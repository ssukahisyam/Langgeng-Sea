import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/history/presentation/haul_detail_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/history/presentation/trip_detail_screen.dart';
import '../../features/logbook/presentation/log_book_form_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/marker/presentation/markers_list_screen.dart';
import '../../features/offline_map/presentation/offline_regions_screen.dart';
import '../../features/offline_map/presentation/region_picker_screen.dart';
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

  // Offline maps
  static const String offlineMap = '/settings/offline-map';
  static const String offlineMapPicker = '/settings/offline-map/new';

  // Coming in later milestones
  static const String markerList = '/markers';
  static const String profile = '/settings/profile';
  static const String logBookHaul = '/log-book/haul/:id';
  static const String logBookTrip = '/log-book/trip/:id';
  // Legacy alias (kept for backward compat)
  static const String logBook = '/log-book/:haulId';

  /// Builds the concrete path for a trip detail. Keeps callers from
  /// string-concatenating route fragments.
  static String tripDetail(String id) => '/trip/$id';
  static String haulDetail(String id) => '/haul/$id';
  static String logBookForHaul(String id) => '/log-book/haul/$id';
  static String logBookForTrip(String id) => '/log-book/trip/$id';
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
    GoRoute(
      path: AppRoutes.offlineMap,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, __) => _slideUp(const OfflineRegionsScreen()),
    ),
    GoRoute(
      path: AppRoutes.offlineMapPicker,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, __) => _slideUp(const RegionPickerScreen()),
    ),
    GoRoute(
      path: AppRoutes.logBookHaul,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return _slideUp(LogBookFormScreen(haulId: id));
      },
    ),
    GoRoute(
      path: AppRoutes.logBookTrip,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return _slideUp(LogBookFormScreen(tripId: id));
      },
    ),
    GoRoute(
      path: AppRoutes.markerList,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, __) => _slideUp(const MarkersListScreen()),
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
