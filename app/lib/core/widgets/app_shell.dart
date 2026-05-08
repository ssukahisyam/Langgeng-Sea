import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../constants/app_strings.dart';
import '../router/app_router.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// Shell with bottom navigation. Hosts the 4 main destinations.
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

  int _indexFromLocation(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location == _tabs[i].path ||
          (location != '/' && location.startsWith(_tabs[i].path) && _tabs[i].path != '/')) {
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

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.sp3,
            0,
            AppSizes.sp3,
            AppSizes.sp3,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: AppSizes.blurGlass3,
                sigmaY: AppSizes.blurGlass3,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: tokens.surface3,
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
