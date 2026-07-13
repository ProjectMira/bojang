import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import '../services/api_service.dart';
import '../utils/topic_visuals.dart';

class MemoryMatchGame extends StatefulWidget {
  const MemoryMatchGame({super.key});

  @override
  State<MemoryMatchGame> createState() => _MemoryMatchGameState();
}

enum _GamePhase { pickingTopic, loading, playing }

class _MemoryMatchGameState extends State<MemoryMatchGame>
    with TickerProviderStateMixin {
  late AnimationController _matchController;

  _GamePhase _phase = _GamePhase.pickingTopic;
  List<Map<String, dynamic>> _topics = [];
  bool _topicsLoading = true;
  String? _topicId;
  String _topicName = '';

  /// All fetched pairs for the game; played in boards of [_pairsPerBoard].
  List<Map<String, dynamic>> _allPairs = [];
  int _boardStart = 0;
  static const int _pairsPerBoard = 2;

  List<MemoryCard> _cards = [];
  int? _firstCardIndex;
  int? _secondCardIndex;
  bool _canFlip = true;
  int _boardMatches = 0;
  int _matches = 0;
  int _moves = 0;
  int _totalPairs = 0;

  // Offline fallback: Tibetan alphabet pronunciation pairs.
  static const List<Map<String, String>> _fallbackPairs = [
    {'tibetan': 'ཀ', 'english': 'Ka'},
    {'tibetan': 'ཁ', 'english': 'Kha'},
    {'tibetan': 'ག', 'english': 'Ga'},
    {'tibetan': 'ང', 'english': 'Nga'},
    {'tibetan': 'ཅ', 'english': 'Ca'},
    {'tibetan': 'ཆ', 'english': 'Cha'},
    {'tibetan': 'ཇ', 'english': 'Ja'},
    {'tibetan': 'ཉ', 'english': 'Nya'},
  ];

  @override
  void initState() {
    super.initState();
    _matchController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _loadTopics();
  }

  @override
  void dispose() {
    _matchController.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    final levels = await ApiService().getLearningLevels();
    if (!mounted) return;
    setState(() {
      _topicsLoading = false;
      // Photo matching needs topics where every word has an illustration.
      _topics =
          (levels ?? [])
              .where(
                (level) =>
                    level['has_images'] == true &&
                    (level['word_count'] as int? ?? 0) >= 4,
              )
              .toList();
    });
  }

  Future<void> _startGame(String? topicId, String topicName) async {
    setState(() {
      _phase = _GamePhase.loading;
      _topicId = topicId;
      _topicName = topicName;
    });

    List<Map<String, dynamic>>? apiCards;
    if (topicId != null) {
      apiCards = await ApiService().getMemoryMatchCards(levelId: topicId);
    }
    if (!mounted) return;

    if (apiCards == null || apiCards.length < 4) {
      if (topicId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load words — playing with the alphabet.'),
          ),
        );
      }
      _initializeGame(
        _fallbackPairs
            .map(
              (pair) => {
                'tibetan': pair['tibetan']!,
                'english': pair['english']!,
                'phonetic': '',
              },
            )
            .toList(),
      );
      if (topicId != null) _topicName = 'Alphabet';
      return;
    }

    _initializeGame(apiCards);
  }

  void _startRandomTopic() {
    if (_topics.isEmpty) {
      _startGame(null, 'Alphabet');
      return;
    }
    final topic = _topics[Random().nextInt(_topics.length)];
    _startGame(
      (topic['id'] ?? '').toString(),
      (topic['name'] ?? 'Topic').toString(),
    );
  }

  void _initializeGame(List<Map<String, dynamic>> pairs) {
    _allPairs = List<Map<String, dynamic>>.from(pairs)..shuffle(Random());
    _totalPairs = _allPairs.length;
    _boardStart = 0;
    _matches = 0;
    _moves = 0;
    _loadBoard();
  }

  /// Puts the next [_pairsPerBoard] pairs on the board: one photo (or
  /// English) card plus one Tibetan word card per pair, shuffled.
  void _loadBoard() {
    final boardPairs = _allPairs.skip(_boardStart).take(_pairsPerBoard);
    final cards = <MemoryCard>[];
    var pairId = 0;
    for (final pair in boardPairs) {
      final tibetan = (pair['tibetan'] ?? '').toString();
      final english = (pair['english'] ?? '').toString();
      final phonetic = (pair['phonetic'] ?? '').toString();
      final imageUrl = pair['image_url']?.toString();
      final hasImage = imageUrl != null && imageUrl.isNotEmpty;
      cards.add(
        MemoryCard(
          id: pairId * 2,
          text: tibetan,
          subtitle: '',
          type: CardType.tibetan,
          pairId: pairId,
        ),
      );
      cards.add(
        MemoryCard(
          id: pairId * 2 + 1,
          text: english,
          subtitle: hasImage ? '' : phonetic,
          type: hasImage ? CardType.photo : CardType.english,
          imageUrl: hasImage ? imageUrl : null,
          pairId: pairId,
        ),
      );
      pairId++;
    }
    cards.shuffle(Random());

    setState(() {
      _cards = cards;
      _firstCardIndex = null;
      _secondCardIndex = null;
      _boardMatches = 0;
      _canFlip = true;
      _phase = _GamePhase.playing;
    });
  }

  void _onCardTapped(int index) {
    if (!_canFlip || _cards[index].isFlipped || _cards[index].isMatched) {
      return;
    }

    setState(() {
      _cards[index].isFlipped = true;
    });

    if (_firstCardIndex == null) {
      _firstCardIndex = index;
    } else if (_secondCardIndex == null) {
      _secondCardIndex = index;
      _moves++;
      _canFlip = false;

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _checkForMatch();
      });
    }
  }

  void _checkForMatch() {
    if (_firstCardIndex == null || _secondCardIndex == null) return;

    final firstCard = _cards[_firstCardIndex!];
    final secondCard = _cards[_secondCardIndex!];

    if (firstCard.pairId == secondCard.pairId) {
      setState(() {
        firstCard.isMatched = true;
        secondCard.isMatched = true;
        _matches++;
        _boardMatches++;
      });

      _matchController.forward().then((_) {
        _matchController.reset();
      });

      final boardSize = _cards.length ~/ 2;
      if (_boardMatches == boardSize) {
        if (_boardStart + _pairsPerBoard < _allPairs.length) {
          // Let the match animation land, then bring in the next four cards.
          Future.delayed(const Duration(milliseconds: 900), () {
            if (!mounted) return;
            _boardStart += _pairsPerBoard;
            _loadBoard();
          });
        } else {
          _showCompletionDialog();
        }
      }
    } else {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          firstCard.isFlipped = false;
          secondCard.isFlipped = false;
        });
      });
    }

    setState(() {
      _firstCardIndex = null;
      _secondCardIndex = null;
      _canFlip = true;
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'ལེགས་སོ། Well done!',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
                const SizedBox(height: 16),
                Text(
                  'You matched all $_totalPairs $_topicName words!',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                  ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Moves: $_moves',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _phase = _GamePhase.pickingTopic;
                  });
                },
                child: Text(
                  'Change Topic',
                  style: GoogleFonts.poppins().copyWith(
                    fontFamilyFallback: const ['Jomolhari'],
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startGame(_topicId, _topicName);
                },
                child: Text(
                  'Play Again',
                  style: GoogleFonts.poppins(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Memory Match',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ).copyWith(fontFamilyFallback: const ['Jomolhari']),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_phase == _GamePhase.playing)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'New words',
              onPressed: () => _startGame(_topicId, _topicName),
            ),
        ],
      ),
      body: switch (_phase) {
        _GamePhase.pickingTopic => _buildTopicPicker(),
        _GamePhase.loading => const Center(child: CircularProgressIndicator()),
        _GamePhase.playing => _buildGame(),
      },
    );
  }

  Widget _buildTopicPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF2C3E50);

    if (_topicsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Pick a topic',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: titleColor,
          ).copyWith(fontFamilyFallback: const ['Jomolhari']),
        ),
        const SizedBox(height: 4),
        Text(
          'Match photos with their Tibetan words, four cards at a time.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ).copyWith(fontFamilyFallback: const ['Jomolhari']),
        ),
        const SizedBox(height: 16),
        // Random topic button
        Material(
          color: Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _startRandomTopic,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shuffle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Surprise me',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_topics.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Topics need an internet connection. You can still play with the alphabet:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
            ),
          ),
        if (_topics.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton(
              onPressed: () => _startGame(null, 'Alphabet'),
              child: const Text('Play with the Alphabet'),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.4,
            ),
            itemCount: _topics.length,
            itemBuilder: (context, index) {
              final topic = _topics[index];
              final name = (topic['name'] ?? '').toString();
              final wordCount = topic['word_count'] as int? ?? 0;
              return Material(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap:
                      () => _startGame((topic['id'] ?? '').toString(), name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            isDark
                                ? Colors.white12
                                : Colors.black.withOpacity(0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          topicEmoji(name),
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: titleColor,
                                ).copyWith(
                                  fontFamilyFallback: const ['Jomolhari'],
                                ),
                              ),
                              Text(
                                '$wordCount words',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color:
                                      isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                ).copyWith(
                                  fontFamilyFallback: const ['Jomolhari'],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildGame() {
    return Column(
      children: [
        // Game Stats
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard(
                'Topic',
                _topicName,
                Icons.category,
                Colors.purple,
              ),
              _buildStatCard(
                'Matches',
                '$_matches/$_totalPairs',
                Icons.check_circle,
                Colors.green,
              ),
              _buildStatCard('Moves', '$_moves', Icons.touch_app, Colors.blue),
            ],
          ),
        ),

        // Game Grid: one board of four cards (two photos + two words).
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: _cards.length,
              itemBuilder: (context, index) {
                return _buildCard(_cards[index], index);
              },
            ),
          ),
        ),

        // Instructions
        Container(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Match each picture with its Tibetan word',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
            ).copyWith(fontFamilyFallback: const ['Jomolhari']),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
            ),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardFace(MemoryCard card) {
    if (card.type == CardType.photo && card.imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          card.imageUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          // If the photo can't load, fall back to the English word so the
          // pair stays matchable.
          errorBuilder: (context, error, stackTrace) => _cardText(card),
        ),
      );
    }
    return _cardText(card);
  }

  Widget _cardText(MemoryCard card) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            card.text,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: card.type == CardType.tibetan ? 24 : 15,
              fontWeight: FontWeight.bold,
              color:
                  card.isMatched
                      ? Colors.green.shade700
                      : Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF2C3E50),
            ).copyWith(fontFamilyFallback: const ['Jomolhari']),
          ),
          if (card.type == CardType.english && card.subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                card.subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade500,
                ).copyWith(fontFamilyFallback: const ['Jomolhari']),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(MemoryCard card, int index) {
    return GestureDetector(
      onTap: () => _onCardTapped(index),
      child: AnimatedBuilder(
        animation: _matchController,
        builder: (context, child) {
          return Transform.scale(
            scale: card.isMatched ? 1.0 + (_matchController.value * 0.1) : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color:
                    card.isMatched
                        ? Colors.green.withOpacity(0.3)
                        : card.isFlipped
                        ? Theme.of(context).cardColor
                        : Theme.of(context).primaryColor.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
                border:
                    card.isMatched
                        ? Border.all(color: Colors.green, width: 2)
                        : null,
              ),
              child: Center(
                child:
                    card.isFlipped || card.isMatched
                        ? _buildCardFace(card)
                        : const Icon(
                          Icons.help_outline,
                          color: Colors.white,
                          size: 32,
                        ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MemoryCard {
  final int id;
  final String text;
  final String subtitle;
  final CardType type;
  final String? imageUrl;
  final int pairId;
  bool isFlipped;
  bool isMatched;

  MemoryCard({
    required this.id,
    required this.text,
    required this.subtitle,
    required this.type,
    required this.pairId,
    this.imageUrl,
    this.isFlipped = false,
    this.isMatched = false,
  });
}

enum CardType { tibetan, english, photo }
