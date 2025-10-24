import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'memory_match_game.dart';

class ExtraGamesScreen extends StatelessWidget {
  const ExtraGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Extra Games',
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
            Text(
              'More Ways to Learn',
              style: GoogleFonts.kalam(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : const Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Explore additional games and activities to enhance your Tibetan learning experience.',
              style: GoogleFonts.kalam(
                fontSize: 16,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey.shade400 
                    : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            
            // Game Cards Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
              children: [
                _buildGameCard(
                  'Memory Match',
                  'Match Tibetan words with their meanings',
                  Icons.memory,
                  Colors.purple,
                  true,
                  context,
                ),
                _buildGameCard(
                  'Word Builder',
                  'Build words from Tibetan letters',
                  Icons.build,
                  Colors.orange,
                  false,
                  context,
                ),
                _buildGameCard(
                  'Speed Quiz',
                  'Quick-fire questions to test your knowledge',
                  Icons.speed,
                  Colors.red,
                  false,
                  context,
                ),
                _buildGameCard(
                  'Audio Challenge',
                  'Listen and identify Tibetan words',
                  Icons.headphones,
                  Colors.green,
                  false,
                  context,
                ),
                _buildGameCard(
                  'Story Mode',
                  'Learn through interactive Tibetan stories',
                  Icons.book,
                  Colors.blue,
                  false,
                  context,
                ),
                _buildGameCard(
                  'Daily Challenge',
                  'Special challenges updated daily',
                  Icons.today,
                  Colors.amber,
                  false,
                  context,
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Coming Soon Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.indigo.shade100,
                    Colors.purple.shade100,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.rocket_launch,
                    color: Colors.indigo.shade700,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'More Games Coming Soon!',
                    style: GoogleFonts.kalam(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We\'re working on exciting new games and features to make your Tibetan learning journey even more engaging.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.kalam(
                      fontSize: 14,
                      color: Colors.indigo.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard(String title, String description, IconData icon, Color color, bool isAvailable, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isAvailable ? () {
            if (title == 'Memory Match') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MemoryMatchGame(),
                ),
              );
            } else {
              // TODO: Navigate to other games
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$title coming soon!')),
              );
            }
          } : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: isAvailable ? color : Colors.grey,
                        size: 32,
                      ),
                    ),
                    if (!isAvailable)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.kalam(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isAvailable 
                        ? (Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : const Color(0xFF2C3E50))
                        : Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: GoogleFonts.kalam(
                    fontSize: 12,
                    color: isAvailable 
                        ? (Theme.of(context).brightness == Brightness.dark 
                            ? Colors.grey.shade400 
                            : Colors.grey.shade600)
                        : Colors.grey.shade400,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isAvailable) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Coming Soon',
                      style: GoogleFonts.kalam(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

