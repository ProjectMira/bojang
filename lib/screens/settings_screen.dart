import 'package:flutter/material.dart' hide Feedback;
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/analytics.dart';
import '../services/feedback.dart';
import '../services/location_service.dart';
import '../models/romanisation.dart';
import '../services/reading_help.dart';
import '../services/theme_service.dart';
import '../services/pronunciation_player.dart';
import '../services/progress_service.dart';
import '../services/api_service.dart';
import '../services/google_auth_service.dart';
import '../widgets/animations_picker.dart';
import '../widgets/lesson_style_sheet.dart';
import '../widgets/reading_voice_pickers.dart';
import 'notification_settings_screen.dart';
import 'auth_screen.dart';
import '../widgets/content_width.dart';
import '../widgets/leaderboard_entry_points.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// The published privacy policy (also the App Store Connect privacy URL).
const String privacyPolicyUrl = 'https://www.bojang.in/privacy-policy.html';

/// "Version 2.17.0 (22)" from the installed package, or "Version" while it
/// is still loading or unavailable.
String versionLabel(PackageInfo? info) {
  if (info == null || info.version.isEmpty) return 'Version';
  final build = info.buildNumber;
  return build.isEmpty
      ? 'Version ${info.version}'
      : 'Version ${info.version} ($build)';
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _locationSharing = false;
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    LocationService.instance.sharingEnabled.then((on) {
      if (mounted) setState(() => _locationSharing = on);
    });
    _loadPackageInfo();
  }

  /// The installed version comes from the platform, never a literal: CI
  /// bumps pubspec's version on every push.
  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _packageInfo = info);
    } catch (_) {
      // No platform channel (e.g. some test hosts): keep the bare label.
    }
  }

  String get _versionLabel => versionLabel(_packageInfo);

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
          body: ContentWidth(child: SingleChildScrollView(
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
                  title: 'Animations',
                  subtitle: animationsSubtitle(context, themeService),
                  icon: Icons.animation,
                  onTap: () => showAnimationsPicker(context),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
                  title: 'Lesson Style',
                  subtitle:
                      '${themeService.lessonStyle.title} · ${themeService.lessonStyle.subtitle}',
                  icon: lessonStyleIcon(themeService.lessonStyle),
                  onTap: () => showLessonStylePicker(context),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),

                const SizedBox(height: 12),

                ListenableBuilder(
                  listenable: ReadingHelp.instance,
                  builder: (context, _) => _buildSettingsCard(
                  title: 'Reading Help',
                  subtitle:
                      themeService.transliterationMode != TransliterationMode.off &&
                              ReadingHelp.instance.newWordsOnly
                          ? '${themeService.transliterationMode.title} · new words only'
                          : '${themeService.transliterationMode.title} · ${themeService.transliterationMode.subtitle}',
                  icon: Icons.translate,
                  onTap: () => showTransliterationPicker(context),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
                ),

                const SizedBox(height: 12),

                _buildSettingsCard(
                  title: 'Notifications',
                  subtitle: 'Manage learning reminders',
                  icon: Icons.notifications,
                  onTap: () {
                    Navigator.push(
                      context,
                      screenRoute(
                        'notification_settings',
                        (context) => const NotificationSettingsScreen(),
                      ),
                    );
                  },
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),

                const SizedBox(height: 12),

                _buildSettingsCard(
                  title: 'Audio Settings',
                  subtitle: 'Sound effects, haptics and pronunciation',
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

                // Account Section (signed-in users only)
                if (Provider.of<GoogleAuthService>(
                  context,
                  listen: false,
                ).isSignedIn) ...[
                  _buildSectionHeader('Account'),
                  const SizedBox(height: 16),

                  _buildSettingsCard(
                    title: 'Delete Account',
                    subtitle: 'Permanently delete your account and synced data',
                    icon: Icons.delete_forever,
                    onTap: _handleDeleteAccount,
                    isDestructive: true,
                  ),

                  const SizedBox(height: 32),
                ],

                // Privacy Section
                _buildSectionHeader('Privacy'),
                const SizedBox(height: 16),

                _buildSettingsCard(
                  title: 'Share usage analytics',
                  subtitle: Analytics.optedOut
                      ? 'Off: nothing about how you use Bojang is sent'
                      : 'Taps, screens and lessons help us improve Bojang',
                  icon: Icons.insights,
                  trailing: Switch.adaptive(
                    value: !Analytics.optedOut,
                    onChanged: (share) async {
                      await Analytics.setOptOut(!share);
                      if (share) {
                        Analytics.track('setting_changed', {
                          'setting': 'usage_analytics',
                          'value': true,
                        });
                      }
                      if (mounted) setState(() {});
                    },
                    activeColor: Theme.of(context).primaryColor,
                  ),
                ),

                const SizedBox(height: 12),

                _buildSettingsCard(
                  title: 'Share approximate location',
                  subtitle: Analytics.optedOut
                      ? 'Needs usage analytics to be on'
                      : 'About 10 km, never your exact position',
                  icon: Icons.place_outlined,
                  trailing: Switch.adaptive(
                    value: _locationSharing && !Analytics.optedOut,
                    onChanged: Analytics.optedOut
                        ? null
                        : (on) async {
                            final result = await LocationService.instance
                                .setSharing(on, source: 'settings');
                            if (!mounted) return;
                            setState(() => _locationSharing = result);
                            if (on && !result) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Location is off for Bojang. You can allow it in your device Settings.',
                                  ),
                                ),
                              );
                            }
                          },
                    activeColor: Theme.of(context).primaryColor,
                  ),
                ),

                const SizedBox(height: 12),

                _buildSettingsCard(
                  title: 'Show me on the leaderboard',
                  subtitle: 'Your display name and weekly XP, nothing else',
                  icon: Icons.emoji_events_outlined,
                  trailing: const LeaderboardVisibilitySwitch(),
                ),

                const SizedBox(height: 32),

                // About Section
                _buildSectionHeader('About'),
                const SizedBox(height: 16),

                _buildSettingsCard(
                  title: 'About Bojang',
                  subtitle: _versionLabel,
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
          ),),
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
    Analytics.screen('settings_language');
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
    Analytics.screen('settings_audio');
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
                  ValueListenableBuilder<bool>(
                    valueListenable: Feedback.haptics..load(),
                    builder: (context, on, _) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Haptics'),
                      subtitle: const Text('Vibrate with answers and celebrations'),
                      value: on,
                      onChanged: Feedback.haptics.set,
                    ),
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
                  const Text('Pronunciation Voice'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      alignment: Alignment.centerLeft,
                    ),
                    icon: const Icon(Icons.record_voice_over),
                    label: Text(
                      PronunciationVoices.labels[themeService.pronunciationVoice] ??
                          themeService.pronunciationVoice,
                    ),
                    onPressed: () => showVoicePicker(context),
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
    Analytics.screen('settings_goals');
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
    Analytics.track('achievements_viewed', {
      'source': 'settings',
      'unlocked': progressService.unlockedAchievements.length,
    });
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
      Analytics.track('progress_exported', {
        'success': false,
        'reason': 'not_signed_in',
      });
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
    Analytics.track('progress_exported', {
      'success': export != null,
      'reason': export != null ? null : 'api_failed',
    });
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
                  Analytics.track('progress_reset', {'source': 'settings'});
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

  Future<void> _handleDeleteAccount() async {
    Analytics.track('account_deletion_started');
    final wantsToContinue = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Delete Account?',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
            ),
            content: Text(
              'This permanently deletes your account and all synced data: '
              'XP, streaks, league progress, completed levels, and quiz '
              'history. This cannot be undone.',
              style: GoogleFonts.poppins().copyWith(
                fontFamilyFallback: const ['Jomolhari'],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Continue',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (wantsToContinue != true) {
      Analytics.track('account_deletion_cancelled', {'step': 'first_confirm'});
    }
    if (wantsToContinue != true || !mounted) return;

    final confirmedDeletion = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Are you sure?',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
            ),
            content: Text(
              'Your account will be permanently deleted. You can keep using '
              'Bojang without an account, but your synced progress cannot '
              'be recovered.',
              style: GoogleFonts.poppins().copyWith(
                fontFamilyFallback: const ['Jomolhari'],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete My Account',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
    if (confirmedDeletion != true) {
      Analytics.track('account_deletion_cancelled', {'step': 'final_confirm'});
    }
    if (confirmedDeletion != true || !mounted) return;

    final apiService = Provider.of<ApiService>(context, listen: false);
    final authService = Provider.of<GoogleAuthService>(context, listen: false);
    final progressService = Provider.of<ProgressService>(
      context,
      listen: false,
    );

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    bool success;
    try {
      success = await apiService.deleteAccount();
    } catch (_) {
      success = false;
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // Dismiss the progress indicator.

    if (success) {
      // Recorded before signOut, which resets the analytics identity.
      Analytics.track('account_deleted');
      await authService.signOut();
      await progressService.resetProgress();
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              title: Text(
                'Account Deleted',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                ).copyWith(fontFamilyFallback: const ['Jomolhari']),
              ),
              content: Text(
                'Your account and synced data have been permanently deleted.',
                style: GoogleFonts.poppins().copyWith(
                  fontFamilyFallback: const ['Jomolhari'],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        screenRoute('auth', (context) => const AuthScreen()),
        (route) => false,
      );
    } else {
      Analytics.track('account_deletion_failed', {'step': 'api'});
      await showDialog<void>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(
                'Something Went Wrong',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                ).copyWith(fontFamilyFallback: const ['Jomolhari']),
              ),
              content: Text(
                "We couldn't delete your account. Please check your "
                "connection and try again.",
                style: GoogleFonts.poppins().copyWith(
                  fontFamilyFallback: const ['Jomolhari'],
                ),
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
  }

  void _showAboutDialog() {
    Analytics.track('about_opened', {'source': 'settings'});
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
                Text(_versionLabel),
                const SizedBox(height: 16),
                const Text(
                  'Learn Tibetan through short lessons, generated practice sessions, vocabulary drills, XP, streaks, and league progress.',
                ),
                const SizedBox(height: 16),
                const Text(
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
    Analytics.track('privacy_opened', {'source': 'settings'});
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Privacy Policy'),
            content: const SingleChildScrollView(
              child: Text(
                'Bojang stores your lesson progress on your device and, when you have an account, on our servers so it syncs.\n\n'
                'Usage analytics: to improve the app we record how it is used: '
                'the screens you open and for how long, the buttons and answers you tap, swipes and scrolls, '
                'lessons and games you play and your scores, settings you change, crashes, and screen recordings of app sessions. '
                'Each event carries your account ID, app version, device model, operating system, language and time zone. '
                'This goes to our servers, to PostHog (analytics) and to Google Firebase (crash reports, app performance and push notifications). We never read what you type in text fields, '
                'and we do not collect your contacts, photos, location, or advertising ID, and do not sell your data or use it to track you across other apps.\n\n'
                'You can turn usage analytics off in Settings > Privacy. Deleting your account deletes your progress and your analytics events from our servers.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Analytics.track('privacy_policy_link_opened', {'source': 'settings'});
                  launchUrl(
                    Uri.parse(privacyPolicyUrl),
                    mode: LaunchMode.externalApplication,
                  ).catchError((Object _) => false);
                },
                child: const Text('Full policy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _rateApp() {
    Analytics.track('rate_app_tapped', {'source': 'settings'});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thank you! App store rating coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
