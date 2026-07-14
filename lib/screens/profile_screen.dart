import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/progress_service.dart';
import '../services/google_auth_service.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_text_style.dart';
import '../widgets/stat_chip.dart';
import 'settings_screen.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String playerName = 'Tibetan Learner';
  User? currentUser;
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
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
    final uri = Uri.parse('https://ta4tsering.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openSignIn() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthScreen()),
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
      await googleAuthService.signOut();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _updatePlayerName() async {
    final controller = TextEditingController(text: playerName);
    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: Text(
              'Edit Name',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
            ),
            content: TextField(
              controller: controller,
              style: GoogleFonts.poppins().copyWith(
                fontFamilyFallback: const ['Jomolhari'],
              ),
              decoration: InputDecoration(
                labelText: 'Your Name',
                labelStyle: GoogleFonts.poppins().copyWith(
                  fontFamilyFallback: const ['Jomolhari'],
                ),
                border: const OutlineInputBorder(),
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
                onPressed: () => Navigator.pop(context, controller.text),
                child: Text(
                  'Save',
                  style: GoogleFonts.poppins(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                ),
              ),
            ],
          ),
    );

    if (result != null && result.isNotEmpty) {
      await ApiService().updateUserProfile(displayName: result.trim());
      setState(() {
        playerName = result.trim();
      });
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
            foregroundColor: AppTokens.ink(context),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _updatePlayerName,
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
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
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Profile Header
                Container(
                  width: double.infinity,
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
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          backgroundImage:
                              currentUser?.profileImageUrl != null
                                  ? NetworkImage(currentUser!.profileImageUrl!)
                                  : null,
                          child:
                              currentUser?.profileImageUrl == null
                                  ? Text(
                                    playerName.isNotEmpty
                                        ? playerName[0].toUpperCase()
                                        : 'T',
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  )
                                  : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        playerName,
                        style: AppTextStyles.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (currentUser?.email != null)
                        Text(
                          currentUser!.email,
                          style: AppTextStyles.poppins(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '${progressService.league} League • ${progressService.xp} XP',
                        style: AppTextStyles.poppins(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      if (currentUser?.authProvider == AuthProvider.google ||
                          currentUser?.authProvider == AuthProvider.apple)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            currentUser?.authProvider == AuthProvider.apple
                                ? 'Apple Account'
                                : 'Google Account',
                            style: AppTextStyles.poppins(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (currentUser == null)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          child: ElevatedButton.icon(
                            onPressed: _openSignIn,
                            icon: const Icon(Icons.login, size: 18),
                            label: Text(
                              'Sign in to save your progress',
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
                      const SizedBox(height: 32),
                    ],
                  ),
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
                        crossAxisCount: 2,
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
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
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
