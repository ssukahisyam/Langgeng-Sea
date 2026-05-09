import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../constants/app_strings.dart';
import '../router/app_router.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// Shell with bottom navigation. Hosts the 4 main destinations.
///
/// PERFORMANCE NOTES:
///
/// 1) No BackdropFilter: the floating bottom-nav used to wrap its
///    container in `BackdropFilter(ImageFilter.blur(...))`. That forces
///    Flutter to rasterise the full viewport every frame — on
///    SD720G-class hardware that's a visible frame drop when scrolling
///    the tab content beneath. Replaced with a solid-tinted container
///    (semi-transparent via alpha) which keeps the "glass look" at
///    zero runtime cost.
///
/// 2) MediaQuery padding injection: every tab child screen is wrapped
///    in a MediaQuery that inflates `viewPadding.bottom` by the
///    measured nav height. So any screen that uses `SafeArea` or
///    respects `MediaQuery.padding.bottom` (Scaffold, ListView,
///    SliverList) automatically leaves breathing room for the floating
///    nav — without editing each screen individually.
///
/// 3) AnimatedSwitcher transition: tapping a tab cross-fades + slides
///    the new screen in over ~180ms. Pure GPU compositor work, no
///    extra raster. Does NOT allow swipe — strictly tap-driven.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _tabs = <_NavTab>[
    _NavTab(
      path: AppRoutes.map,
      label: AppStrings.tabMap,
      icon: PhosphorIconsRegular.mapTrifold,
      activeIcon: PhosphorIconsFill.mapTrifold,
    ),
    _NavTab(
      path: AppRoutes.history,
      label: AppStrings.tabHistory,
      icon: PhosphorIconsRegular.clockCounterClockwise,
      activeIcon: PhosphorIconsFill.clockCounterClockwise,
    ),
    _NavTab(
      path: AppRoutes.dashboard,
      label: AppStrings.tabDashboard,
      icon: PhosphorIconsRegular.chartPie,
      activeIcon: PhosphorIconsFill.chartPie,
    ),
    _NavTab(
      path: AppRoutes.settings,
      label: AppStrings.tabSettings,
      icon: PhosphorIconsRegular.gearSix,
      activeIcon: PhosphorIconsFill.gearSix,
    ),
  ];

  /// Measured footprint of the floating bottom nav (content + vertical
  /// padding inside, excluding the outer margin). Kept in sync with
  /// [_NavButton]'s sizing + the decoration padding below. Used to
  /// inject viewPadding so child screens can place bottom content just
  /// above it.
  static const double _navBarContentHeight = 56;

  /// Small gap between the bottom of the nav bar's visual edge and the
  /// next-highest UI element in a child screen (e.g. action panel).
  /// User requested "jangan jauh-jauh" — 8px is tight but still visually
  /// separated.
  static const double _gapAboveNav = 8;

  int _indexFromLocation(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location == _tabs[i].path ||
          (location != '/' &&
              location.startsWith(_tabs[i].path) &&
              _tabs[i].path != '/')) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _indexFromLocation(location);
    final tokens = context.tokens;

    // System-gesture-bar inset (Android gesture nav = ~20dp; button
    // nav = 0). This is already part of the default viewPadding.bottom
    // that SafeArea respects — we just reuse the value to add nav-bar
    // height on top of it.
    final systemInsetBottom = MediaQuery.of(context).padding.bottom;

    // Total bottom inset child screens should treat as "don't paint
    // content below this" for anchored UI. Equals:
    //   gesture bar (already in padding.bottom)
    // + nav-bar content height
    // + small gap above nav
    // + outer margin of the nav bar's wrapper
    final totalBottomInset = systemInsetBottom +
        _navBarContentHeight +
        _gapAboveNav +
        AppSizes.sp3; // outer nav margin

    // Inject this value as viewPadding.bottom into every child. Any
    // SafeArea or sliver inside the screen automatically adds this
    // much space — no per-screen edits needed.
    final mq = MediaQuery.of(context);
    final injectedMq = mq.copyWith(
      padding: mq.padding.copyWith(bottom: totalBottomInset),
      viewPadding: mq.viewPadding.copyWith(bottom: totalBottomInset),
    );

    return Scaffold(
      extendBody: true,
      body: MediaQuery(
        data: injectedMq,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          // Unique key per tab so AnimatedSwitcher detects the change.
          // GoRouter rebuilds `child` when the route changes; we just
          // need a stable key per route to trigger the transition.
          transitionBuilder: (child, animation) {
            // Slide + fade from 6% screen height below. Feels like the
            // content "lifts up" into place — a small touch that
            // matches the Liquid Glass visual language.
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(currentIndex),
            child: child,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: _gapAboveNav),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.sp3,
            0,
            AppSizes.sp3,
            0,
          ),
          child: Container(
            decoration: BoxDecoration(
              // Slightly opaque surface — no blur, but still reads as
              // "above the content". Alpha tuned to feel glass-like
              // without the BackdropFilter cost.
              color: tokens.surface3.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(AppSizes.radiusXl),
              border: Border.all(color: tokens.borderStrong),
              boxShadow: [
                BoxShadow(
                  color: tokens.shadowMd,
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.sp2,
              vertical: AppSizes.sp2 + 2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _NavButton(
                      tab: _tabs[i],
                      selected: i == currentIndex,
                      onTap: () => context.go(_tabs[i].path),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  const _NavTab({
    required this.path,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _NavTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = selected ? context.colors.primary : tokens.textTertiary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.sp2 - 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? tab.activeIcon : tab.icon,
                size: 22,
                color: color,
              ),
              const SizedBox(height: 2),
              Text(
                tab.label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
