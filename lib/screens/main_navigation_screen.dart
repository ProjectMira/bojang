import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import 'home_page.dart';
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

  void _goToStreak() => setState(() => _currentIndex = 1);

  List<Widget> get _screens => [
    HomePage(onSeeStreak: _goToStreak),
    const StreakViewScreen(),
    const ExtraGamesScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = AppTokens.isDark(context);
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTokens.surface(context),
          boxShadow: AppTokens.shadow(context),
          border:
              isDark
                  ? Border(
                    top: BorderSide(color: AppTokens.cardBorder(context)),
                  )
                  : null,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.home_filled,
                  label: 'Home',
                  index: 0,
                  color: AppColors.primary,
                ),
                _buildNavItem(
                  icon: Icons.local_fire_department,
                  label: 'Streak',
                  index: 1,
                  color: AppColors.orange,
                ),
                _buildNavItem(
                  icon: Icons.games,
                  label: 'Games',
                  index: 2,
                  color: AppColors.purple,
                ),
                _buildNavItem(
                  icon: Icons.person,
                  label: 'Profile',
                  index: 3,
                  color: AppColors.green,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required Color color,
  }) {
    final isSelected = _currentIndex == index;
    final inactiveColor = AppTokens.inkSoft(context);

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? AppTokens.tint(color, context) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? AppTokens.tint(color, context, opacity: 0.22)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? color : inactiveColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
