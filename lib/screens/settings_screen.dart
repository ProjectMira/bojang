import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../services/progress_service.dart';
import '../services/api_service.dart';
import 'notification_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeService, ProgressService>(
      builder: (context, themeService, progressService, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              'Settings',
              style: GoogleFonts.poppins( 
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
            ),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Theme Section
                _buildSectionHeader('Appearance'),
                const SizedBox(height: 16),

                _buildSettingsCard(
                  title: 'Theme',
                  subtitle:
                      themeService.isDarkMode ? 'Dark Mode' : 'Light Mode',
                  icon:
                      themeService.isDarkMode
                          ? Icons.dark_mode
                          : Icons.light_mode,
                  trailing: Switch.adaptive(
                    value: themeService.isDarkMode,
                    onChanged: (value) => themeService.toggleTheme(),
                    activeColor: Theme.of(context).primaryColor,
                  ),
                ),

                const SizedBox(height: 12),

                _buildSettingsCard(
                  title: 'Language',
                  subtitle: themeService.currentLanguage,
                  icon: Icons.language,
                  onTap: () => _showLanguageDialog(themeService),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),

                const SizedBox(height: 32),

                // Learning Section
                _buildSectionHeader('Learning'),
                const SizedBox(height: 16),

                _buildSettingsCard(
                  title: 'Notifications',
                  subtitle: 'Manage learning reminders',
                  icon: Icons.notifications,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => const NotificationSettingsScreen(),
                      ),
                    );
                  },
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),

                const SizedBox(height: 12),

                _buildSettingsCard(
                  title: 'Audio Settings',
                  subtitle: 'Sound effects and pronunciation',
                  icon: Icons.volume_up,
                  onTap: () => _showAudioSettings(),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),

                const SizedBox(height: 12),

                _buildSettingsCard(
                  title: 'Learning Goals',
                  subtitle: 'Set daily and weekly targets',
                  icon: Icons.flag,
                  onTap: () => _showGoalsDialog(),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),

                const SizedBox(height: 32),

                // Progress Section
                _buildSectionHeader('Progress'),
                const SizedBox(height: 16),

                _buildSettingsCard(
                  title: 'View Achievements',
                  subtitle:
                      '${progressService.unlockedAchievements.length} unlocked',
                  icon: Icons.emoji_events,
                  onTap: () => _showAchievements(progressService),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),

                const SizedBox(height: 12),

                _buildSettingsCard(
                  title: 'Export Progress',
                  subtitle: 'Download your account data',
                  icon: Icons.download,
                  onTap: () => _exportProgress(),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),

                const SizedBox(height: 12),

                _buildSettingsCard(
                  title: 'Reset Progress',
                  subtitle: 'Clear local progress on this device',
                  icon: Icons.refresh,
                  onTap: () => _showResetDialog(progressService),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  isDestructive: true,
                ),

                const SizedBox(height: 32),

                // About Section
                _buildSectionHeader('About'),
                const SizedBox(height: 16),

                _buildSettingsCard(
                  title: 'About Bojang',
                  subtitle: 'Version 2.0.0',
                  icon: Icons.info,
                  onTap: () => _showAboutDialog(),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),

                const SizedBox(height: 12),

                _buildSettingsCard(
                  title: 'Privacy Policy',
                  subtitle: 'How we protect your data',
                  icon: Icons.privacy_tip,
                  onTap: () => _showPrivacyPolicy(),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),

                const SizedBox(height: 12),

                _buildSettingsCard(
                  title: 'Rate App',
                  subtitle: 'Help us improve Bojang',
                  icon: Icons.star,
                  onTap: () => _rateApp(),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins( 
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color:
            Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF2C3E50),
      ).copyWith(fontFamilyFallback: const ['Jomolhari']),
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
    Widget? trailing,
    bool isDestructive = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                isDestructive
                    ? Colors.red.withOpacity(0.1)
                    : Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isDestructive ? Colors.red : Theme.of(context).primaryColor,
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins( 
            fontWeight: FontWeight.w600,
            color:
                isDestructive
                    ? Colors.red
                    : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF2C3E50)),
          ).copyWith(fontFamilyFallback: const ['Jomolhari']),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  void _showLanguageDialog(ThemeService themeService) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Select Language'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('English'),
                  leading: Radio<String>(
                    value: 'English',
                    groupValue: themeService.currentLanguage,
                    onChanged: (value) {
                      if (value != null) {
                        themeService.setLanguage(value);
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Tibetan'),
                  subtitle: const Text('བོད་ཡིག'),
                  leading: Radio<String>(
                    value: 'Tibetan',
                    groupValue: themeService.currentLanguage,
                    onChanged: (value) {
                      if (value != null) {
                        themeService.setLanguage(value);
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  void _showAudioSettings() {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer<ThemeService>(
          builder: (context, themeService, child) {
            return AlertDialog(
              title: const Text('Audio Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sound Effects'),
                    subtitle: const Text('Play correct/incorrect answers sound'),
                    value: themeService.soundEffectsEnabled,
                    onChanged: (val) => themeService.setSoundEffectsEnabled(val),
                  ),
                  const SizedBox(height: 16),
                  const Text('Sound Effects Volume'),
                  Row(
                    children: [
                      const Icon(Icons.volume_down),
                      Expanded(
                        child: Slider(
                          value: themeService.soundEffectsVolume,
                          onChanged: themeService.soundEffectsEnabled
                              ? (val) => themeService.setSoundEffectsVolume(val)
                              : null,
                        ),
                      ),
                      const Icon(Icons.volume_up),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Pronunciation Volume'),
                  Row(
                    children: [
                      const Icon(Icons.volume_down),
                      Expanded(
                        child: Slider(
                          value: themeService.pronunciationVolume,
                          onChanged: (val) => themeService.setPronunciationVolume(val),
                        ),
                      ),
                      const Icon(Icons.volume_up),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Audio Quality'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: themeService.audioQuality,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Standard', child: Text('Standard (Recommended)')),
                      DropdownMenuItem(value: 'High', child: Text('High Quality')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        themeService.setAudioQuality(val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGoalsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer<ThemeService>(
          builder: (context, themeService, child) {
            return AlertDialog(
              title: const Text('Learning Goals'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Daily Quiz Target'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: themeService.dailyQuizTarget,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 Quiz / Day')),
                      DropdownMenuItem(value: 2, child: Text('2 Quizzes / Day')),
                      DropdownMenuItem(value: 3, child: Text('3 Quizzes / Day')),
                      DropdownMenuItem(value: 5, child: Text('5 Quizzes / Day')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        themeService.setDailyQuizTarget(val);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text('Weekly Learning Goal'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: themeService.weeklyGoal,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 3, child: Text('3 Quizzes / Week')),
                      DropdownMenuItem(value: 5, child: Text('5 Quizzes / Week')),
                      DropdownMenuItem(value: 7, child: Text('7 Quizzes / Week')),
                      DropdownMenuItem(value: 10, child: Text('10 Quizzes / Week')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        themeService.setWeeklyGoal(val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAchievements(ProgressService progressService) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Achievements'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: progressService.unlockedAchievements.length,
                itemBuilder: (context, index) {
                  final achievementId =
                      progressService.unlockedAchievements[index];
                  return ListTile(
                    leading: const Icon(
                      Icons.emoji_events,
                      color: Colors.amber,
                    ),
                    title: Text(
                      progressService.getAchievementTitle(achievementId),
                    ),
                    subtitle: Text(
                      progressService.getAchievementDescription(achievementId),
                    ),
                  );
                },
              ),
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

  Future<void> _exportProgress() async {
    if (!ApiService().isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sign in to export synced account data. Local progress stays on this device.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final export = await ApiService().exportUserData();
    if (!mounted) return;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Data Export Ready'),
            content: SingleChildScrollView(
              child: Text(
                export == null
                    ? 'We could not export your account data right now. Please try again later.'
                    : 'Exported at ${export['exported_at'] ?? 'now'}.\n\nProfile, quiz history, and subscription data were retrieved from your account.',
              ),
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

  void _showResetDialog(ProgressService progressService) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset Progress'),
            content: const Text(
              'This clears local streaks, scores, and achievements on this device. Synced account data remains available from the server when you sign in.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  await progressService.resetProgress();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Local progress reset.')),
                  );
                },
                child: const Text('Reset', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('About Bojang'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bojang - Tibetan Learning App'),
                SizedBox(height: 8),
                Text('Version 2.0.0'),
                SizedBox(height: 16),
                Text(
                  'Learn Tibetan through short lessons, generated practice sessions, vocabulary drills, XP, streaks, and league progress.',
                ),
                SizedBox(height: 16),
                Text(
                  'Bojang connects Tibetan language learning with a modern practice flow designed for daily study.',
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

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Privacy Policy'),
            content: const SingleChildScrollView(
              child: Text(
                'Bojang stores local lesson progress on your device and syncs account progress when you sign in. You can export your synced data, restore purchases, and request account deletion from your profile settings when authenticated.',
              ),
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

  void _rateApp() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thank you! App store rating coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
