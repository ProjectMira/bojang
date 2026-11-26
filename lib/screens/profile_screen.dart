import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/analytics.dart';
import '../services/progress_service.dart';
import '../services/google_auth_service.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_text_style.dart';
import '../widgets/stat_chip.dart';
import 'settings_screen.dart';
import 'auth_screen.dart';
import '../widgets/content_width.dart';
import '../services/feature_flags.dart';
import '../services/social_service.dart';
import '../widgets/family_streaks_card.dart';
import '../services/learner_profile.dart';
import '../widgets/learner_avatar.dart';
import '../widgets/profile_setup_sheet.dart';
import '../widgets/weekly_board_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<WeeklyBoardCardState> _boardKey = GlobalKey();

  /// The tab was opened: fresh board, and the name + picture ask.
  Future<void> onShown() async {
    _boardKey.currentState?.reload();
    final saved = await maybeAskForProfile(context, 'profile_tab');
    if (saved) _boardKey.currentState?.reload();
  }

  Future<void> _editProfile(String source) async {
    final saved = await showProfileSetupSheet(context, source: source);
    if (saved) _boardKey.currentState?.reload();
  }

  String playerName = 'Tibetan Learner';
  User? currentUser;
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    LearnerProfile.instance.load();
    _loadUserData();
    _loadPackageInfo();
  }

  Future<void> _loadUserData() async {
    final googleAuthService = Provider.of<GoogleAuthService>(
      context,
      listen: false,
    );
    setState(() {
      currentUser = googleAuthService.currentUser;
      playerName = currentUser?.displayName ?? 'Tibetan Learner';
    });
    final stats = await ApiService().getUserProgress();
    if (stats != null && mounted) {
      await Provider.of<ProgressService>(
        context,
        listen: false,
      ).updateFromServer(stats);
    }
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _packageInfo = info);
    }
  }

  Future<void> _openMadeBy() async {
    Analytics.track('made_by_opened', {'source': 'profile'});
    final uri = Uri.parse('https://ta4tsering.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openSignIn() {
    Analytics.track('sign_in_opened', {'source': 'profile'});
    Navigator.of(context).pushAndRemoveUntil(
      screenRoute('auth', (context) => const AuthScreen()),
      (route) => false,
    );
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Sign Out',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
            ),
            content: Text(
              'Are you sure you want to sign out?',
              style: GoogleFonts.poppins().copyWith(
                fontFamilyFallback: const ['Jomolhari'],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins().copyWith(
                    fontFamilyFallback: const ['Jomolhari'],
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Sign Out',
                  style: GoogleFonts.poppins(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                ),
              ),
            ],
          ),
    );

    if (shouldLogout == true) {
      final googleAuthService = Provider.of<GoogleAuthService>(
        context,
        listen: false,
      );
      Analytics.track('signed_out', {'source': 'profile'});
      await googleAuthService.signOut();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          screenRoute('auth', (context) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProgressService>(
      builder: (context, progressService, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              'Profile',
              style: AppTextStyles.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTokens.ink(context),
              ),
            ),
            backgroundColor: Colors.transparent,
            systemOverlayStyle: AppTokens.statusBar(context),
            foregroundColor: AppTokens.ink(context),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit name and picture',
                onPressed: () => _editProfile('profile_edit_button'),
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    screenRoute(
                      'settings',
                      (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
              if (currentUser != null)
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: _handleLogout,
                ),
            ],
          ),
          body: ContentWidth(
            child: SingleChildScrollView(
              // Clear the floating tab bar the page runs under.
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                children: [
                  // Profile Header
                  Container(
                    width: double.infinity,
                    key: const Key('profile-header'),
                    decoration: BoxDecoration(
                      // On an iPad the header is narrower than the screen,
                      // so it gets rounded top corners instead of ending in
                      // two hard edges.
                      borderRadius:
                          Breakpoints.isTablet(context)
                              ? const BorderRadius.vertical(
                                top: Radius.circular(AppRadius.hero),
                              )
                              : null,
                      // Solid brand blue behind all the text (white reads at
                      // 4.5:1 or more on it). The fade into the page lives in
                      // a separate strip below, so no label ever sits on the
                      // pale end of a gradient.
                      color: AppColors.primary,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        ListenableBuilder(
                          listenable: LearnerProfile.instance,
                          builder: (context, _) {
                            final picked = LearnerProfile.instance.avatar;
                            final photo = currentUser?.profileImageUrl;
                            return Semantics(
                              button: true,
                              label: 'Change your picture',
                              child: GestureDetector(
                                key: const Key('profile-avatar'),
                                onTap: () => _editProfile('profile_avatar'),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 12,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child:
                                          picked == null && photo != null
                                              ? CircleAvatar(
                                                radius: 53,
                                                backgroundColor: Colors.white,
                                                child: CircleAvatar(
                                                  radius: 50,
                                                  backgroundImage: NetworkImage(
                                                    photo,
                                                  ),
                                                ),
                                              )
                                              : LearnerAvatar(
                                                avatar: picked,
                                                size: 106,
                                                border: true,
                                              ),
                                    ),
                                    Positioned(
                                      right: -2,
                                      bottom: 2,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.primary,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.edit_rounded,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        ListenableBuilder(
                          listenable: LearnerProfile.instance,
                          builder: (context, _) {
                            final name = LearnerProfile.instance.name;
                            if (name == null &&
                                playerName == 'Tibetan Learner') {
                              return TextButton.icon(
                                key: const Key('profile-add-name'),
                                onPressed:
                                    () => _editProfile('profile_add_name'),
                                icon: const Icon(
                                  Icons.add_rounded,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  'Add your name',
                                  style: AppTextStyles.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            }
                            return Text(
                              name ?? playerName,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        if (currentUser?.email != null)
                          Text(
                            currentUser!.email,
                            style: AppTextStyles.poppins(
                              fontSize: 14,
                              // White70 on the blue is about 3:1; full white
                              // clears 4.5:1.
                              color: Colors.white,
                            ),
                          ),
                        const SizedBox(height: 8),
                        ProfileHeaderPill(
                          key: const Key('profile-league-pill'),
                          text:
                              '${progressService.league} League • ${progressService.xp} XP',
                          fontSize: 14,
                        ),
                        if (currentUser != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: ProfileHeaderPill(
                              text: switch (currentUser!.authProvider) {
                                AuthProvider.apple => 'Apple Account',
                                AuthProvider.google => 'Google Account',
                                AuthProvider.email => 'Email Account',
                              },
                              fontSize: 12,
                            ),
                          ),
                        if (currentUser == null)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            child: ElevatedButton.icon(
                              onPressed: _openSignIn,
                              icon: const Icon(Icons.login, size: 18),
                              label: Text(
                                'Create an account or sign in',
                                style: AppTextStyles.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  // Fade from the header's blue into the page.
                  Container(
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary,
                          Theme.of(context).scaffoldBackgroundColor,
                        ],
                      ),
                    ),
                  ),

                  // This week's board, first thing under the header.
                  ValueListenableBuilder<int>(
                    valueListenable: FeatureFlags.instance.changes,
                    builder: (context, _, child) {
                      if (!SocialService.leaderboardEnabled) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                        child: WeeklyBoardCard(key: _boardKey),
                      );
                    },
                  ),

                  // Stats Section
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Progress',
                          style: AppTextStyles.title(context),
                        ),
                        const SizedBox(height: 16),

                        // Stats Grid
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: Breakpoints.isTablet(context) ? 4 : 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.35,
                          children: [
                            _buildStatCard(
                              context,
                              Icons.bolt,
                              '${progressService.xp}',
                              'XP',
                              AppColors.gold,
                            ),
                            _buildStatCard(
                              context,
                              Icons.local_fire_department,
                              '${progressService.currentStreak}',
                              'Streak',
                              AppColors.orange,
                            ),
                            _buildStatCard(
                              context,
                              Icons.check_circle,
                              '${progressService.completedLevelsCount}',
                              'Lessons',
                              AppColors.green,
                            ),
                            _buildStatCard(
                              context,
                              Icons.emoji_events,
                              progressService.league,
                              'League',
                              AppColors.purple,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        const FamilyStreaksCard(),

                        const SizedBox(height: 32),

                        // Settings Section
                        Text('Settings', style: AppTextStyles.title(context)),
                        const SizedBox(height: 16),

                        _buildSettingsCard(
                          context,
                          'Settings',
                          'Manage app preferences and notifications',
                          Icons.settings,
                          () {
                            Navigator.push(
                              context,
                              screenRoute(
                                'settings',
                                (context) => const SettingsScreen(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        _buildSettingsCard(
                          context,
                          'Reset Progress',
                          'Clear local streaks, scores, and cached progress',
                          Icons.refresh,
                          () => _showResetDialog(progressService),
                        ),

                        const SizedBox(height: 12),

                        _buildSettingsCard(
                          context,
                          'About App',
                          'Learn more about Bojang',
                          Icons.info,
                          _showAboutDialog,
                        ),

                        const SizedBox(height: 8),

                        _buildFooter(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    IconData icon,
    String value,
    String title,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTokens.surface(context),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppTokens.cardBorder(context)),
        boxShadow: AppTokens.shadow(context),
      ),
      child: Center(
        child: StatChip(icon: icon, value: value, label: title, color: color),
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppTokens.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTokens.cardBorder(context)),
        boxShadow: AppTokens.shadow(context),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTokens.tint(AppColors.primary, context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(
          title,
          style: AppTextStyles.poppins(
            fontWeight: FontWeight.w600,
            color: AppTokens.ink(context),
          ),
        ),
        subtitle: Text(subtitle, style: AppTextStyles.caption(context)),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: AppTokens.inkSoft(context),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final info = _packageInfo;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Text(
              'ཀ',
              style: TextStyle(
                fontSize: 20,
                color: AppTokens.inkSoft(context).withOpacity(0.5),
                fontFamilyFallback: const ['Jomolhari'],
              ),
            ),
            const SizedBox(height: 8),
            if (info != null)
              Text(
                'Bojang v${info.version} (${info.buildNumber})',
                style: AppTextStyles.caption(context),
              ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: _openMadeBy,
              child: Text(
                'made by ta4tsering.com',
                style: AppTextStyles.caption(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog(ProgressService progressService) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: Text(
              'Reset Progress',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
            ),
            content: Text(
              'Are you sure you want to reset all your progress? This action cannot be undone.',
              style: GoogleFonts.poppins().copyWith(
                fontFamilyFallback: const ['Jomolhari'],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins().copyWith(
                    fontFamilyFallback: const ['Jomolhari'],
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Analytics.track('progress_reset', {'source': 'profile'});
                  await progressService.resetProgress();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      content: Text(
                        'Progress reset on this device.',
                        style: GoogleFonts.poppins().copyWith(
                          fontFamilyFallback: const ['Jomolhari'],
                        ),
                      ),
                    ),
                  );
                },
                child: Text(
                  'Reset',
                  style: GoogleFonts.poppins(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                ),
              ),
            ],
          ),
    );
  }

  void _showAboutDialog() {
    Analytics.track('about_opened', {'source': 'profile'});
    final version =
        _packageInfo != null
            ? '${_packageInfo!.version} (${_packageInfo!.buildNumber})'
            : '';
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('About Bojang'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bojang - Tibetan Learning App'),
                const SizedBox(height: 8),
                Text('Version $version'),
                const SizedBox(height: 16),
                const Text(
                  'Bojang teaches Tibetan with short lessons, generated practice sessions, XP, streaks, and league progress. Start with vocabulary and phrases, then build toward verbs and sentence practice.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }
}

/// A label on the profile header's blue: the blue hue's tint as the fill
/// and [AppTokens.textOnTint] as the text, so it reads at 4.5:1 or more in
/// light and dark mode (white on translucent white did not).
class ProfileHeaderPill extends StatelessWidget {
  final String text;
  final double fontSize;

  const ProfileHeaderPill({super.key, required this.text, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTokens.hueTint(AppPalette.blue, context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.poppins(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: AppTokens.textOnTint(AppColors.primary, context),
        ),
      ),
    );
  }
}
