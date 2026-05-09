import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/export_import/presentation/import_screen.dart';
import '../../features/history/presentation/haul_detail_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/history/presentation/trip_detail_screen.dart';
import '../../features/logbook/presentation/log_book_form_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/marker/presentation/markers_list_screen.dart';
import '../../features/offline_map/presentation/offline_regions_screen.dart';
import '../../features/offline_map/presentation/region_picker_screen.dart';
import '../../features/onboarding/data/user_profile_repository.dart';
import '../../features/onboarding/domain/entities/user_profile.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/profile_form_screen.dart';
import '../../features/settings/presentation/profile_edit_screen.dart';
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

  // Onboarding & profile
  static const String onboarding = '/onboarding';
  static const String profileForm = '/onboarding/profile';
  static const String profileEdit = '/profile/edit';

  // Coming in later milestones
  static const String markerList = '/markers';
  static const String importData = '/import';
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

/// Provider-backed router so redirect logic can watch the user profile.
///
/// When the profile is null → force redirect to [AppRoutes.onboarding].
/// Once the user saves a profile (stream emits non-null) the router
/// refreshes and lets the user reach the main shell.
final appRouterProvider = Provider<GoRouter>((ref) {
  // We *listen* (not watch) to avoid rebuilding the router on every emit —
  // the notifier below triggers GoRouter.refresh() instead.
  final refresh = _ProviderRefreshNotifier<AsyncValue<UserProfile?>>(
    ref,
    userProfileProvider,
  );
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.map,
    debugLogDiagnostics: false,
    refreshListenable: refresh,
    redirect: (context, state) {
      final profileAsync = ref.read(userProfileProvider);
      // During initial load, stay where you are.
      if (!profileAsync.hasValue) return null;

      final profile = profileAsync.value;
      final loc = state.matchedLocation;
      final inOnboarding = loc == AppRoutes.onboarding ||
          loc == AppRoutes.profileForm;

      if (profile == null && !inOnboarding) {
        return AppRoutes.onboarding;
      }
      if (profile != null && inOnboarding) {
        return AppRoutes.map;
      }
      return null;
    },
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
      GoRoute(
        path: AppRoutes.importData,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, __) => _slideUp(const ImportScreen()),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, __) => _slideUp(const OnboardingScreen()),
      ),
      GoRoute(
        path: AppRoutes.profileForm,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, __) => _slideUp(const ProfileFormScreen()),
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, __) => _slideUp(const ProfileEditScreen()),
      ),
    ],
  );
});

/// Adapts a Riverpod provider into a [Listenable] so GoRouter will
/// re-run its `redirect` when the underlying state changes.
class _ProviderRefreshNotifier<T> extends ChangeNotifier {
  _ProviderRefreshNotifier(Ref ref, ProviderListenable<T> provider) {
    _sub = ref.listen(provider, (_, __) => notifyListeners());
  }

  late final ProviderSubscription<T> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

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
