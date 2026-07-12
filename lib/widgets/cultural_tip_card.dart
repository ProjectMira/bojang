import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import 'app_text_style.dart';

class CulturalTipCard extends StatelessWidget {
  final String title;
  final String tip;
  final String tibetanText;
  final IconData icon;
  final Color color;

  const CulturalTipCard({
    super.key,
    required this.title,
    required this.tip,
    required this.tibetanText,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTokens.tint(color, context),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTokens.ink(context),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Tibetan Text
          if (tibetanText.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTokens.surface(context),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Text(
                tibetanText,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamilyFallback: const ['Jomolhari'],
                  color: AppTokens.ink(context),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Tip Content
          Text(
            tip,
            style: AppTextStyles.poppins(
              fontSize: 15,
              height: 1.5,
              color: AppTokens.inkSoft(context),
            ),
          ),
        ],
      ),
    );
  }
}

class CulturalTipsData {
  static final List<Map<String, dynamic>> tips = [
    {
      'title': 'Traditional Greeting',
      'tip':
          'When greeting someone in Tibet, it\'s traditional to press your palms together and bow slightly. This gesture shows respect and is accompanied by saying "Tashi Delek" (བཀྲ་ཤིས་བདེ་ལེགས།).',
      'tibetan': 'བཀྲ་ཤིས་བདེ་ལེགས།',
      'icon': Icons.waving_hand,
      'color': Colors.orange,
    },
    {
      'title': 'Prayer Wheels',
      'tip':
          'Prayer wheels (མ་ནི་འཁོར་ལོ།) are always spun clockwise. Each turn is believed to have the same spiritual benefit as reciting the mantra written inside.',
      'tibetan': 'མ་ནི་འཁོར་ལོ།',
      'icon': Icons.circle,
      'color': Colors.purple,
    },
    {
      'title': 'Sacred Mountains',
      'tip':
          'Mount Kailash (ཀང་རིན་པོ་ཆེ།) is considered the most sacred mountain in Tibet. Pilgrims circumambulate it clockwise as a form of spiritual practice.',
      'tibetan': 'ཀང་རིན་པོ་ཆེ།',
      'icon': Icons.landscape,
      'color': Colors.blue,
    },
    {
      'title': 'Tea Culture',
      'tip':
          'Tibetan butter tea (བོད་ཇ།) is a staple drink made with tea, yak butter, and salt. It provides energy and warmth in the high altitude environment.',
      'tibetan': 'བོད་ཇ།',
      'icon': Icons.local_cafe,
      'color': Colors.brown,
    },
    {
      'title': 'Respect for Elders',
      'tip':
          'In Tibetan culture, showing respect to elders is paramount. Always greet older people first and use honorific language when speaking to them.',
      'tibetan': 'རྒན་པོ་ལ་གུས་པ།',
      'icon': Icons.elderly,
      'color': Colors.green,
    },
    {
      'title': 'Monastery Etiquette',
      'tip':
          'When visiting monasteries, dress modestly, speak quietly, and always walk clockwise around sacred objects. Photography may be restricted in certain areas.',
      'tibetan': 'དགོན་པ།',
      'icon': Icons.temple_buddhist,
      'color': Colors.red,
    },
  ];

  static Map<String, dynamic> getRandomTip() {
    return tips[(DateTime.now().day) % tips.length];
  }
}
