import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';

class MemoryMatchGame extends StatefulWidget {
  const MemoryMatchGame({super.key});

  @override
  State<MemoryMatchGame> createState() => _MemoryMatchGameState();
}

class _MemoryMatchGameState extends State<MemoryMatchGame>
    with TickerProviderStateMixin {
  late List<MemoryCard> _cards;
  late AnimationController _flipController;
  late AnimationController _matchController;
  
  int? _firstCardIndex;
  int? _secondCardIndex;
  bool _canFlip = true;
  int _matches = 0;
  int _moves = 0;
  
  final List<Map<String, String>> _cardData = [
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
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _matchController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _initializeGame();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _matchController.dispose();
    super.dispose();
  }

  void _initializeGame() {
    _cards = [];
    
    // Create pairs of cards
    for (int i = 0; i < _cardData.length; i++) {
      _cards.add(MemoryCard(
        id: i * 2,
        text: _cardData[i]['tibetan']!,
        type: CardType.tibetan,
        pairId: i,
      ));
      _cards.add(MemoryCard(
        id: i * 2 + 1,
        text: _cardData[i]['english']!,
        type: CardType.english,
        pairId: i,
      ));
    }
    
    // Shuffle the cards
    _cards.shuffle(Random());
    
    setState(() {
      _firstCardIndex = null;
      _secondCardIndex = null;
      _matches = 0;
      _moves = 0;
      _canFlip = true;
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
      
      // Check for match after animation
      Future.delayed(const Duration(milliseconds: 800), () {
        _checkForMatch();
      });
    }
  }

  void _checkForMatch() {
    if (_firstCardIndex == null || _secondCardIndex == null) return;
    
    final firstCard = _cards[_firstCardIndex!];
    final secondCard = _cards[_secondCardIndex!];
    
    if (firstCard.pairId == secondCard.pairId) {
      // Match found!
      setState(() {
        firstCard.isMatched = true;
        secondCard.isMatched = true;
        _matches++;
      });
      
      _matchController.forward().then((_) {
        _matchController.reset();
      });
      
      // Check if game is complete
      if (_matches == _cardData.length) {
        _showCompletionDialog();
      }
    } else {
      // No match - flip cards back
      Future.delayed(const Duration(milliseconds: 500), () {
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
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Congratulations!',
          style: GoogleFonts.kalam(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events,
              color: Colors.amber,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'You completed the memory game!',
              style: GoogleFonts.kalam(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Moves: $_moves',
              style: GoogleFonts.kalam(
                fontSize: 16,
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initializeGame();
            },
            child: Text('Play Again', style: GoogleFonts.kalam()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(
              'Done',
              style: GoogleFonts.kalam(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
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
          style: GoogleFonts.kalam(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeGame,
          ),
        ],
      ),
      body: Column(
        children: [
          // Game Stats
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('Matches', '$_matches/${_cardData.length}', Icons.check_circle, Colors.green),
                _buildStatCard('Moves', '$_moves', Icons.touch_app, Colors.blue),
              ],
            ),
          ),
          
          // Game Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.8,
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
              'Match Tibetan letters with their English pronunciations',
              style: GoogleFonts.kalam(
                fontSize: 16,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey.shade400 
                    : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: GoogleFonts.kalam(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: GoogleFonts.kalam(
                  fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.grey.shade400 
                      : Colors.grey.shade600,
                ),
              ),
            ],
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
                color: card.isMatched 
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
                border: card.isMatched 
                    ? Border.all(color: Colors.green, width: 2)
                    : null,
              ),
              child: Center(
                child: card.isFlipped || card.isMatched
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            card.text,
                            style: GoogleFonts.kalam(
                              fontSize: card.type == CardType.tibetan ? 24 : 16,
                              fontWeight: FontWeight.bold,
                              color: card.isMatched 
                                  ? Colors.green.shade700
                                  : Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.white 
                                      : const Color(0xFF2C3E50),
                            ),
                          ),
                          if (card.type == CardType.english)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'EN',
                                style: GoogleFonts.kalam(
                                  fontSize: 10,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      )
                    : Icon(
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
  final CardType type;
  final int pairId;
  bool isFlipped;
  bool isMatched;

  MemoryCard({
    required this.id,
    required this.text,
    required this.type,
    required this.pairId,
    this.isFlipped = false,
    this.isMatched = false,
  });
}

enum CardType { tibetan, english }
