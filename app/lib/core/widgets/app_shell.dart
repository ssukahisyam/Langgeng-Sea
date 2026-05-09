import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../constants/app_strings.dart';
import '../router/app_router.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// Shell with bottom navigation + 4-tab IndexedStack.
///
/// PERFORMANCE NOTES:
///
/// 1) StatefulShellRoute.indexedStack (configured in app_router.dart)
///    keeps all 4 tab screens alive in memory. Tapping a tab only
///    flips which one is visible — no widget rebuild, no provider
///    re-subscription, no drift re-query. The `navigationShell` we
///    receive here IS the IndexedStack (wrapped in a StatefulNavigationShell).
///
/// 2) No BackdropFilter on the bottom nav. Previous design blurred
///    the viewport behind it every frame (~10-20ms main-thread hit
///    on SD720G). Replaced with a solid semi-transparent surface that
///    reads as "above content" without the raster cost.
///
/// 3) MediaQuery padding injection: every tab child is wrapped in a
///    MediaQuery that inflates `viewPadding.bottom` by the measured
///    nav height. Any SafeArea / Scaffold / Sliver in a child screen
///    then automatically reserves room for the floating nav — no
///    per-screen edits needed.
///
/// 4) Horizontal slide overlay: tapping a tab triggers a one-shot
///    animation that slides the outgoing screen OFF screen in the
///    direction you'd expect (tap right tab = new screen comes in
///    from the right, outgoing screen exits to the left, and vice
///    versa). Because the IndexedStack keeps both alive, the
///    animation is pure compositor work — no rebuild cost.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  /// The shell route's branch switcher. See StatefulShellRoute.indexedStack.
  final StatefulNavigationShell navigationShell;

  static const _tabs = <_NavTab>[
    _NavTab(
      label: AppStrings.tabMap,
      icon: PhosphorIconsRegular.mapTrifold,
      activeIcon: PhosphorIconsFill.mapTrifold,
    ),
    _NavTab(
      label: AppStrings.tabHistory,
      icon: PhosphorIconsRegular.clockCounterClockwise,
      activeIcon: PhosphorIconsFill.clockCounterClockwise,
    ),
    _NavTab(
      label: AppStrings.tabDashboard,
      icon: PhosphorIconsRegular.chartPie,
      activeIcon: PhosphorIconsFill.chartPie,
    ),
    _NavTab(
      label: AppStrings.tabSettings,
      icon: PhosphorIconsRegular.gearSix,
      activeIcon: PhosphorIconsFill.gearSix,
    ),
  ];

  /// Measured footprint of the floating bottom nav (content + vertical
  /// padding inside, excluding the outer margin). Used to inject
  /// viewPadding so child screens can place bottom content just above
  /// it.
  static const double _navBarContentHeight = 56;

  /// Small gap between the bottom of the nav bar's visual edge and
  /// the next-highest UI element in a child screen. User requested
  /// "jangan jauh-jauh" — 8px is tight but still visually separated.
  static const double _gapAboveNav = 8;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late Animation<Offset> _oldOffset;
  late Animation<Offset> _newOffset;

  /// Tracks the PREVIOUS index so we can detect direction when the
  /// navigationShell's index changes. Initialised to current so the
  /// first frame doesn't accidentally animate.
  late int _lastIndex = widget.navigationShell.currentIndex;

  /// Snapshot of the outgoing screen captured just before the new tab
  /// takes over. Rendered as an overlay that slides off-screen while
  /// the new tab content slides in behind it.
  Widget? _outgoingSnapshot;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _outgoingSnapshot = null);
      }
    });
    // Set initial (no-op) offsets.
    _setOffsets(toRight: true);
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newIndex = widget.navigationShell.currentIndex;
    if (newIndex != _lastIndex) {
      // Capture a freeze-frame of the outgoing tab. Using the
      // oldWidget's navigationShell ensures we draw the PREVIOUS
      // tab's state, not the new one.
      final toRight = newIndex > _lastIndex;
      _outgoingSnapshot = _buildOutgoingSnapshot(oldWidget.navigationShell);
      _setOffsets(toRight: toRight);
      _animController.forward(from: 0);
      _lastIndex = newIndex;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Configure tween offsets depending on direction.
  /// [toRight] = user tapped a tab to the right of the current one:
  ///   - Outgoing slides OUT to the LEFT  (Offset(-1, 0))
  ///   - Incoming slides IN  from the RIGHT (already in place, just reveal)
  /// [toRight] = false:
  ///   - Outgoing slides OUT to the RIGHT (Offset(1, 0))
  ///   - Incoming slides IN  from the LEFT
  ///
  /// Incoming content is the IndexedStack itself, rendered in place.
  /// To simulate "slide in", we briefly translate IT in the opposite
  /// direction from its start pos, then animate back to (0,0).
  void _setOffsets({required bool toRight}) {
    final outEnd = toRight ? const Offset(-1, 0) : const Offset(1, 0);
    final inStart = toRight ? const Offset(1, 0) : const Offset(-1, 0);

    _oldOffset = Tween<Offset>(begin: Offset.zero, end: outEnd).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInCubic),
    );
    _newOffset = Tween<Offset>(begin: inStart, end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  /// Build a snapshot of the outgoing tab as a paused widget tree.
  /// We pass the previous navigationShell so we render whatever was
  /// visible BEFORE the index change.
  Widget _buildOutgoingSnapshot(StatefulNavigationShell oldShell) {
    return IgnorePointer(
      // Ignore so user can't tap on the sliding-away content.
      child: RepaintBoundary(child: oldShell),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final currentIndex = widget.navigationShell.currentIndex;

    // System-gesture-bar inset (Android gesture nav ~20dp; button = 0).
    final systemInsetBottom = MediaQuery.of(context).padding.bottom;

    // Total bottom inset that child screens should treat as "don't
    // paint anchored UI below this". Equals:
    //   gesture bar (already part of padding.bottom)
    // + nav-bar content height
    // + small gap above nav
    // + outer margin of the nav bar's wrapper
    final totalBottomInset = systemInsetBottom +
        AppShell._navBarContentHeight +
        AppShell._gapAboveNav +
        AppSizes.sp3;

    final mq = MediaQuery.of(context);
    final injectedMq = mq.copyWith(
      padding: mq.padding.copyWith(bottom: totalBottomInset),
      viewPadding: mq.viewPadding.copyWith(bottom: totalBottomInset),
    );

    return Scaffold(
      extendBody: true,
      body: MediaQuery(
        data: injectedMq,
        // The IndexedStack (navigationShell) is the real base layer.
        // On top we slide the old-snapshot overlay OUT, and the
        // shell itself slides IN from the opposite side. When the
        // animation completes, the snapshot is removed.
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return FractionalTranslation(
                  translation: _animController.isAnimating
                      ? _newOffset.value
                      : Offset.zero,
                  child: child,
                );
              },
              child: widget.navigationShell,
            ),
            if (_outgoingSnapshot != null)
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return FractionalTranslation(
                    translation: _oldOffset.value,
                    child: child,
                  );
                },
                child: _outgoingSnapshot,
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: AppShell._gapAboveNav),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.sp3,
            0,
            AppSizes.sp3,
            0,
          ),
          child: Container(
            decoration: BoxDecoration(
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
                for (var i = 0; i < AppShell._tabs.length; i++)
                  Expanded(
                    child: _NavButton(
                      tab: AppShell._tabs[i],
                      selected: i == currentIndex,
                      onTap: () => widget.navigationShell.goBranch(
                        i,
                        // initialLocation: true = reset the branch's
                        // navigator stack when re-tapping the SAME tab.
                        // Off when switching tabs so the user comes back
                        // to the same scroll position etc.
                        initialLocation: i == currentIndex,
                      ),
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
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

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
