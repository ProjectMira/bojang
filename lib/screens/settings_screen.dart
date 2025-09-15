import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../services/progress_service.dart';
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
              style: GoogleFonts.kalam(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
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
                  subtitle: themeService.isDarkMode ? 'Dark Mode' : 'Light Mode',
                  icon: themeService.isDarkMode ? Icons.dark_mode : Icons.light_mode,
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
                        builder: (context) => const NotificationSettingsScreen(),
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
                  subtitle: '${progressService.unlockedAchievements.length} unlocked',
                  icon: Icons.emoji_events,
                  onTap: () => _showAchievements(progressService),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
                
                const SizedBox(height: 12),
                
                _buildSettingsCard(
                  title: 'Export Progress',
                  subtitle: 'Backup your learning data',
                  icon: Icons.download,
                  onTap: () => _exportProgress(),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
                
                const SizedBox(height: 12),
                
                _buildSettingsCard(
                  title: 'Reset Progress',
                  subtitle: 'Start fresh (cannot be undone)',
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
      style: GoogleFonts.kalam(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.white 
            : const Color(0xFF2C3E50),
      ),
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
            color: isDestructive 
                ? Colors.red.withOpacity(0.1)
                : Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon, 
            color: isDestructive 
                ? Colors.red 
                : Theme.of(context).primaryColor
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.kalam(
            fontWeight: FontWeight.w600,
            color: isDestructive 
                ? Colors.red 
                : (Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : const Color(0xFF2C3E50)),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark 
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
      builder: (context) => AlertDialog(
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
      builder: (context) => AlertDialog(
        title: const Text('Audio Settings'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Audio settings will be available in a future update.'),
            SizedBox(height: 16),
            Text('Features coming soon:'),
            Text('• Sound effects volume'),
            Text('• Pronunciation playback speed'),
            Text('• Audio quality settings'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  void _showGoalsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Learning Goals'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Goal setting will be available in a future update.'),
            SizedBox(height: 16),
            Text('Features coming soon:'),
            Text('• Daily quiz targets'),
            Text('• Weekly learning goals'),
            Text('• Custom reminders'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  void _showAchievements(ProgressService progressService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Achievements'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: progressService.unlockedAchievements.length,
            itemBuilder: (context, index) {
              final achievementId = progressService.unlockedAchievements[index];
              return ListTile(
                leading: const Icon(Icons.emoji_events, color: Colors.amber),
                title: Text(progressService.getAchievementTitle(achievementId)),
                subtitle: Text(progressService.getAchievementDescription(achievementId)),
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
  
  void _exportProgress() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export feature coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  void _showResetDialog(ProgressService progressService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Progress'),
        content: const Text(
          'Are you sure you want to reset all your progress? This will delete all your achievements, streaks, and quiz results. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // TODO: Implement reset functionality in ProgressService
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Progress reset functionality coming soon!')),
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
      builder: (context) => AlertDialog(
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
              'Learn Tibetan language through interactive quizzes and games. Build your vocabulary and improve your understanding of this beautiful language.',
            ),
            SizedBox(height: 16),
            Text(
              'Bojang represents a bridge between traditional Tibetan culture and modern digital learning, making this ancient language accessible through contemporary educational technology.',
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
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Your privacy is important to us. Bojang stores your learning progress locally on your device. We do not collect or share personal information. All quiz results and achievements are stored securely on your device.',
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
