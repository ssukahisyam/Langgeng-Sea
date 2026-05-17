import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../constants/app_strings.dart';
import '../router/app_router.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// Shell with bottom navigation. Hosts the 4 main destinations.
///
/// Two non-obvious behaviours that are load-bearing for the rest of the
/// app to feel correct:
///
/// 1. **MediaQuery padding injection.** The bottom nav is a floating
///    `Positioned`-style bar with its own SafeArea handling, which
///    means Flutter's default `MediaQuery` fed to the tab body reports
///    `padding.bottom = 0` even though our UI has a ~76dp opaque panel
///    parked at the bottom. Every screen that puts a fixed-position
///    CTA or bottom sheet above the nav would have to know the magic
///    number. Instead, we wrap `child` in a `MediaQuery` override that
///    says: "the viewport's effective bottom inset = the gesture bar
///    height + the nav bar height + the gap above it". Feature screens
///    can then keep using `MediaQuery.of(context).padding.bottom` (or
///    `SafeArea`) and they automatically clear the floating nav.
///
/// 2. **Horizontal slide between tabs.** `GoRouter`'s `ShellRoute` is
///    configured with `_noTransition` so GoRouter itself does nothing
///    on tab switch. We intercept that with an `AnimatedSwitcher` here
///    that slides the incoming tab in from the correct side based on
///    index delta (tap a tab to the right → slide in from right). This
///    is cheap (no opacity layers, no blur) and matches the tactile
///    feel of a swipe without actually wiring up swipe gestures.
const double _kNavBarContentHeight = 56;
const double _kGapAboveNav = 8;

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  /// The [StatefulNavigationShell] provided by [StatefulShellRoute].
  /// It manages the indexed stack of tab bodies and handles
  /// branch switching without disposing cached widgets.
  final StatefulNavigationShell navigationShell;

  static const tabs = <_NavTab>[
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

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _prevIndex = 0;

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    final tokens = context.tokens;

    // Direction for the tab transition. +1 = user moved right (new
    // tab slides in from the right), -1 = moved left. We snapshot here
    // because the next build might show a different index.
    final direction =
        currentIndex == _prevIndex ? 0 : (currentIndex > _prevIndex ? 1 : -1);
    _prevIndex = currentIndex;

    final mq = MediaQuery.of(context);
    final navClearance = mq.padding.bottom +
        _kNavBarContentHeight +
        _kGapAboveNav +
        AppSizes.sp3;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          MediaQuery(
            // Tell the child screens that the viewport's effective bottom
            // inset already accounts for the floating nav. They can keep
            // using SafeArea / padding.bottom without knowing the magic
            // nav height.
            data: mq.copyWith(
              padding: mq.padding.copyWith(bottom: navClearance),
            ),
            child: _TabTransition(
              direction: direction,
              index: currentIndex,
              child: widget.navigationShell,
            ),
          ),
          Positioned(
            left: AppSizes.sp3,
            right: AppSizes.sp3,
            bottom: AppSizes.sp3 + mq.padding.bottom,
            child: _NavBar(
              currentIndex: currentIndex,
              tokens: tokens,
              onTap: (index) => widget.navigationShell.goBranch(
                index,
                // If already on this tab, pop to the root of the branch.
                initialLocation: index == currentIndex,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The floating bottom bar. No BackdropFilter on this path — the blur
/// was dropping the map screen into the 20-30 FPS range on the Redmi
/// Note 10 Pro. We composite a solid opaque fill against the scaffold
/// background instead, which reads the same at typical viewing
/// distance but costs ~0 ms per frame.
class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.currentIndex,
    required this.tokens,
    required this.onTap,
  });

  final int currentIndex;
  final LangTokens tokens;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    // PR follow-up performance: hapus BackdropFilter sigma 12. Komentar
    // di atas class menjelaskan blur ini menurunkan map screen ke 20-30
    // FPS di Redmi Note 10 Pro. Implementasi sebelumnya tetap pakai
    // BackdropFilter (mismatch dengan komentar). Sekarang pakai solid
    // composite color yang reads sama tapi cost ~0 ms per frame.
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          tokens.surface3.withValues(alpha: 0.95),
          scaffoldBg,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        border: Border.all(
          color: tokens.borderStrong.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: tokens.shadowMd,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      height: _kNavBarContentHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sp2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < AppShell.tabs.length; i++)
            Expanded(
              child: _NavButton(
                tab: AppShell.tabs[i],
                selected: i == currentIndex,
                onTap: () => onTap(i),
              ),
            ),
        ],
      ),
    );
  }
}

/// AnimatedSwitcher with a directional horizontal slide. Cheap enough
/// to keep 120 Hz on mid-range Android.
class _TabTransition extends StatelessWidget {
  const _TabTransition({
    required this.direction,
    required this.index,
    required this.child,
  });

  /// +1 = new tab enters from the right, -1 = from the left, 0 = no anim.
  final int direction;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (direction == 0) {
      // First build or same tab — skip the transition entirely.
      return KeyedSubtree(
        key: ValueKey<int>(index),
        child: child,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (entering, previous) => Stack(
        alignment: Alignment.center,
        children: [
          ...previous,
          if (entering != null) entering,
        ],
      ),
      transitionBuilder: (child, animation) {
        // On incoming tab animation.value goes 0 → 1; on outgoing it
        // goes 1 → 0 (AnimatedSwitcher uses reverseAnimation for the
        // previous child automatically). So the sign of direction is
        // correct for both legs.
        final tween = Tween<Offset>(
          begin: Offset(direction.toDouble(), 0),
          end: Offset.zero,
        );
        return SlideTransition(
          position: tween.animate(animation),
          child: child,
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(index),
        child: child,
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
