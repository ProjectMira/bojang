import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/progress_service.dart';
import '../services/google_auth_service.dart';
import '../models/user.dart';
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

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final googleAuthService = Provider.of<GoogleAuthService>(context, listen: false);
    setState(() {
      currentUser = googleAuthService.currentUser;
      playerName = currentUser?.displayName ?? 'Tibetan Learner';
    });
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign Out', style: GoogleFonts.kalam(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to sign out?', style: GoogleFonts.kalam()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.kalam()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Sign Out',
              style: GoogleFonts.kalam(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      final googleAuthService = Provider.of<GoogleAuthService>(context, listen: false);
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
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Edit Name',
          style: GoogleFonts.kalam(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          style: GoogleFonts.kalam(),
          decoration: InputDecoration(
            labelText: 'Your Name',
            labelStyle: GoogleFonts.kalam(),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.kalam()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(
              'Save',
              style: GoogleFonts.kalam(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        playerName = result;
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
              style: GoogleFonts.kalam(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2C97DD), Color(0xFFF5F7FA)],
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage: currentUser?.profileImageUrl != null 
                        ? NetworkImage(currentUser!.profileImageUrl!) 
                        : null,
                    child: currentUser?.profileImageUrl == null
                        ? Text(
                            playerName.isNotEmpty ? playerName[0].toUpperCase() : 'T',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C97DD),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    playerName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (currentUser?.email != null)
                    Text(
                      currentUser!.email,
                      style: GoogleFonts.kalam(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Level ${progressService.currentLevel} Learner',
                    style: GoogleFonts.kalam(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (currentUser?.authProvider == AuthProvider.google)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Google Account',
                        style: GoogleFonts.kalam(
                          fontSize: 12,
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            
            // Stats Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Progress',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Stats Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                    children: [
                      _buildStatCard(
                        'Quizzes Taken',
                        '${progressService.totalQuizzesTaken}',
                        Icons.quiz,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'Accuracy',
                        '${progressService.accuracy.toStringAsFixed(1)}%',
                        Icons.track_changes,
                        Colors.green,
                      ),
                      _buildStatCard(
                        'Correct Answers',
                        '${progressService.totalCorrectAnswers}',
                        Icons.check_circle,
                        Colors.orange,
                      ),
                      _buildStatCard(
                        'Achievements',
                        '${progressService.unlockedAchievements.length}',
                        Icons.emoji_events,
                        Colors.purple,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Settings Section
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildSettingsCard(
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
                    'Reset Progress',
                    'Start your learning journey fresh',
                    Icons.refresh,
                    () => _showResetDialog(progressService),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  _buildSettingsCard(
                    'About App',
                    'Learn more about Bojang',
                    Icons.info,
                    _showAboutDialog,
                  ),
                  
                  const SizedBox(height: 32),
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
            color: const Color(0xFF2C97DD).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF2C97DD)),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  void _showResetDialog(ProgressService progressService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Reset Progress',
          style: GoogleFonts.kalam(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to reset all your progress? This action cannot be undone.',
          style: GoogleFonts.kalam(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.kalam()),
          ),
          TextButton(
            onPressed: () async {
              // TODO: Implement reset functionality in ProgressService
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Reset functionality coming soon!',
                    style: GoogleFonts.kalam(),
                  ),
                ),
              );
            },
            child: Text(
              'Reset',
              style: GoogleFonts.kalam(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
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

