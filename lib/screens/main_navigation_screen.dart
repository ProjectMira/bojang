import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/analytics.dart';
import '../services/home_widget_sync.dart';
import '../services/progress_service.dart';
import '../services/push_service.dart';
import '../services/social_service.dart';
import '../widgets/leaderboard_entry_points.dart';
import '../theme/app_tokens.dart';
import '../theme/motion.dart';
import 'home_page.dart';
import 'practice_screen.dart';
import 'streak_view_screen.dart';
import 'extra_games_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // The Streak tab became Practice (plan item #18); the streak lives in
  // Home's top bar now.
  static const _tabNames = ['home', 'practice', 'games', 'profile'];

  final GlobalKey<PracticeScreenState> _practiceKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    Analytics.screen('tab_home');
    PushService.requestedScreen.addListener(_openRequestedTab);
    // A notification tapped while the app was closed is already waiting.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openRequestedTab());
    // App start (the main navigation is built once, after splash and
    // onboarding): the home-screen widget sync and the weekly result.
    HomeWidgetSync.instance.attach(
      Provider.of<ProgressService>(context, listen: false),
    );
    _weeklyResultTimer = Timer(weeklyResultDelay, _showLastWeekResult);
  }

  Timer? _weeklyResultTimer;

  /// "You finished #12": once per week, a moment after launch, and only
  /// when nothing else is on top (a lesson, a celebration, a sheet).
  Future<void> _showLastWeekResult() async {
    if (!mounted) return;
    final result = await SocialService.instance.unseenLastWeekResult();
    if (result == null || !mounted) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    await showWeeklyResultSheet(context, result);
  }

  /// How long after launch the weekly result waits.
  static const Duration weeklyResultDelay = Duration(seconds: 3);

  @override
  void dispose() {
    PushService.requestedScreen.removeListener(_openRequestedTab);
    _weeklyResultTimer?.cancel();
    super.dispose();
  }

  /// Opens the tab a tapped push notification names (data.screen).
  void _openRequestedTab() {
    final screen = PushService.requestedScreen.value;
    if (screen == null || !mounted) return;
    PushService.requestedScreen.value = null;
    if (screen == 'streak') {
      // Streak pushes used to open the Streak tab.
      _selectTab(0, via: 'push');
      Navigator.of(context).push(
        screenRoute('streak', (_) => const StreakViewScreen()),
      );
      return;
    }
    final index = _tabNames.indexOf(screen);
    if (index >= 0) _selectTab(index, via: 'push');
  }

  void _selectTab(int index, {String via = 'nav_bar'}) {
    if (index != _currentIndex) {
      Analytics.track('tab_selected', {
        'tab': _tabNames[index],
        'from_tab': _tabNames[_currentIndex],
        'via': via,
      });
      Analytics.screen('tab_${_tabNames[index]}');
    }
    final changed = index != _currentIndex;
    setState(() => _currentIndex = index);
    // New mistakes from lessons since the tab was last shown.
    if (changed && _tabNames[index] == 'practice') {
      _practiceKey.currentState?.reload();
    }
  }

  late final List<Widget> _screens = [
    const HomePage(),
    PracticeScreen(key: _practiceKey),
    const ExtraGamesScreen(),
    const ProfileScreen(),
  ];

  static const List<_TabSpec> _tabs = [
    _TabSpec('Home', Icons.home_rounded, Icons.home_outlined, AppColors.primary),
    _TabSpec(
      'Practice',
      Icons.fitness_center_rounded,
      Icons.fitness_center_outlined,
      AppColors.orange,
    ),
    _TabSpec('Games', Icons.sports_esports_rounded, Icons.sports_esports_outlined, AppColors.purple),
    _TabSpec('Profile', Icons.person_rounded, Icons.person_outline_rounded, AppColors.green),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Hidden tabs keep their state but stop their tickers (the path's
      // drifting clouds and flags, the yak's idle loop).
      body: IndexedStack(
        index: _currentIndex,
        children: [
          for (var i = 0; i < _screens.length; i++)
            TickerMode(enabled: i == _currentIndex, child: _screens[i]),
        ],
      ),
      // A floating capsule over the page background, like the iOS tab bar.
      // The body stays above it (no extendBody), so no screen's last row
      // hides underneath.
      bottomNavigationBar: _FloatingTabBar(
        tabs: _tabs,
        currentIndex: _currentIndex,
        onSelect: (index) {
          if (index != _currentIndex) HapticFeedback.selectionClick();
          _selectTab(index);
        },
      ),
    );
  }
}

class _TabSpec {
  final String label;
  final IconData selectedIcon;
  final IconData icon;
  final Color color;

  const _TabSpec(this.label, this.selectedIcon, this.icon, this.color);
}

class _FloatingTabBar extends StatelessWidget {
  final List<_TabSpec> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const _FloatingTabBar({
    required this.tabs,
    required this.currentIndex,
    required this.onSelect,
  });

  static const double _height = 64;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTokens.isDark(context);
    final duration =
        Motion.of(context).scale(const Duration(milliseconds: 280));
    final selected = tabs[currentIndex];
    final glass =
        isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.82)
            : Colors.white.withValues(alpha: 0.86);

    return ColoredBox(
      color: AppTokens.background(context),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
          child: Center(
            heightFactor: 1,
            // Thumb-sized on an iPad instead of spanning the whole width.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_height / 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_height / 2),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      height: _height,
                      decoration: BoxDecoration(
                        color: glass,
                        borderRadius: BorderRadius.circular(_height / 2),
                        border: Border.all(
                          color:
                              isDark
                                  ? Colors.white.withValues(alpha: 0.10)
                                  : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final slot = constraints.maxWidth / tabs.length;
                          return Stack(
                            children: [
                              // The selection pill slides between tabs.
                              AnimatedPositioned(
                                duration: duration,
                                curve: Curves.easeOutCubic,
                                left: slot * currentIndex,
                                top: 0,
                                bottom: 0,
                                width: slot,
                                child: AnimatedContainer(
                                  duration: duration,
                                  decoration: BoxDecoration(
                                    color: AppTokens.tint(
                                      selected.color,
                                      context,
                                      opacity: isDark ? 0.28 : 0.14,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      (_height - 12) / 2,
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  for (var i = 0; i < tabs.length; i++)
                                    Expanded(
                                      child: _TabButton(
                                        spec: tabs[i],
                                        selected: i == currentIndex,
                                        duration: duration,
                                        onTap: () => onSelect(i),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final _TabSpec spec;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  const _TabButton({
    required this.spec,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Inactive tabs use full ink (not the soft token) so labels pass 4.5:1.
    final inactive = AppTokens.ink(context).withValues(alpha: 0.72);
    final color = selected ? _deep(spec.color, context) : inactive;
    return Semantics(
      button: true,
      selected: selected,
      label: '${spec.label} tab',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        highlightShape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(26),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: duration,
              scale: selected ? 1.08 : 1.0,
              child: Icon(
                selected ? spec.selectedIcon : spec.icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: duration,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
              child: Text(spec.label, maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }

  /// The tab colour darkened enough to read on the light glass.
  static Color _deep(Color color, BuildContext context) {
    if (AppTokens.isDark(context)) return color;
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness * 0.72).clamp(0.0, 1.0)).toColor();
  }
}
