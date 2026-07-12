import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/quiz_question.dart';
import '../services/api_service.dart';
import '../services/progress_service.dart';

/// Quick-fire quiz: answer as many questions as possible in 60 seconds.
class SpeedQuizScreen extends StatefulWidget {
  const SpeedQuizScreen({super.key});

  @override
  State<SpeedQuizScreen> createState() => _SpeedQuizScreenState();
}

enum _QuizPhase { intro, loading, playing, finished }

class _SpeedQuizScreenState extends State<SpeedQuizScreen> {
  static const int roundSeconds = 60;

  _QuizPhase _phase = _QuizPhase.intro;
  final List<QuizQuestion> _questions = [];
  int _currentIndex = 0;
  int _correct = 0;
  int _answered = 0;
  int _secondsLeft = roundSeconds;
  int? _selectedIndex;
  bool _showingFeedback = false;
  bool _fetchingMore = false;
  String _topicName = '';
  int _bestScore = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadBestScore();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _bestScore = prefs.getInt('speed_quiz_best') ?? 0;
    });
  }

  Future<void> _saveBestScore() async {
    if (_correct <= _bestScore) return;
    _bestScore = _correct;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('speed_quiz_best', _correct);
  }

  Future<List<QuizQuestion>> _fetchQuestions() async {
    final levels = await ApiService().getLearningLevels();
    final eligible =
        (levels ?? [])
            .where((level) => (level['word_count'] as int? ?? 0) >= 5)
            .toList();
    if (eligible.isEmpty) return [];

    final topic = eligible[Random().nextInt(eligible.length)];
    final session = await ApiService().getLearningSession(
      levelId: (topic['id'] ?? '').toString(),
      numQuestions: 15,
      exerciseTypes: const ['multiple_choice'],
    );
    if (session == null) return [];

    final exercises = List<Map<String, dynamic>>.from(
      session['exercises'] as List<dynamic>? ?? [],
    );
    final questions = <QuizQuestion>[];
    for (final exercise in exercises) {
      final type = exercise['type'] ?? exercise['exercise_type'];
      if (type != 'multiple_choice') continue;
      try {
        questions.add(QuizQuestion.fromApiExercise(exercise));
      } catch (_) {
        // Skip malformed exercises.
      }
    }
    if (questions.isNotEmpty) {
      _topicName = (topic['name'] ?? '').toString();
    }
    return questions;
  }

  Future<void> _startRound() async {
    setState(() {
      _phase = _QuizPhase.loading;
    });

    final questions = await _fetchQuestions();
    if (!mounted) return;

    if (questions.isEmpty) {
      setState(() {
        _phase = _QuizPhase.intro;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load questions. Check your connection.'),
        ),
      );
      return;
    }

    setState(() {
      _questions
        ..clear()
        ..addAll(questions);
      _currentIndex = 0;
      _correct = 0;
      _answered = 0;
      _secondsLeft = roundSeconds;
      _selectedIndex = null;
      _showingFeedback = false;
      _phase = _QuizPhase.playing;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        _finishRound();
      } else {
        setState(() {
          _secondsLeft--;
        });
      }
    });
  }

  Future<void> _topUpQuestions() async {
    if (_fetchingMore) return;
    _fetchingMore = true;
    final more = await _fetchQuestions();
    _fetchingMore = false;
    if (!mounted || _phase != _QuizPhase.playing) return;
    if (more.isNotEmpty) {
      setState(() {
        _questions.addAll(more);
      });
    }
  }

  void _finishRound() {
    _timer?.cancel();
    _saveBestScore();
    if (_answered > 0) {
      // Speed quiz counts toward streak and stats like any other quiz.
      Provider.of<ProgressService>(
        context,
        listen: false,
      ).updateQuizResults('speed quiz', _correct, _answered);
    }
    setState(() {
      _phase = _QuizPhase.finished;
    });
  }

  void _handleAnswer(int index) {
    if (_showingFeedback || _phase != _QuizPhase.playing) return;

    final question = _questions[_currentIndex];
    final isCorrect = index == question.correctAnswerIndex;

    setState(() {
      _selectedIndex = index;
      _showingFeedback = true;
      _answered++;
      if (isCorrect) _correct++;
    });

    // Fetch more questions before the pool runs dry.
    if (_currentIndex >= _questions.length - 3) {
      _topUpQuestions();
    }

    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted || _phase != _QuizPhase.playing) return;
      if (_currentIndex < _questions.length - 1) {
        setState(() {
          _currentIndex++;
          _selectedIndex = null;
          _showingFeedback = false;
        });
      } else {
        // Ran out of questions before the timer — end the round.
        _finishRound();
      }
    });
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _titleColor => _isDark ? Colors.white : const Color(0xFF2C3E50);

  Color get _subtitleColor =>
      _isDark ? Colors.grey.shade400 : Colors.grey.shade600;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Speed Quiz',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ).copyWith(fontFamilyFallback: const ['Jomolhari']),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: switch (_phase) {
        _QuizPhase.intro => _buildIntro(),
        _QuizPhase.loading => const Center(child: CircularProgressIndicator()),
        _QuizPhase.playing => _buildPlaying(),
        _QuizPhase.finished => _buildFinished(),
      },
    );
  }

  Widget _buildIntro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚡', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Quick-fire round',
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: _titleColor,
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
            ),
            const SizedBox(height: 8),
            Text(
              'Answer as many questions as you can in $roundSeconds seconds. Wrong answers don\'t stop the clock — keep moving!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: _subtitleColor,
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
            ),
            const SizedBox(height: 12),
            if (_bestScore > 0)
              Text(
                '🏆 Best: $_bestScore correct',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade700,
                ).copyWith(fontFamilyFallback: const ['Jomolhari']),
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startRound,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Start',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaying() {
    final question = _questions[_currentIndex];
    final timeFraction = _secondsLeft / roundSeconds;

    return Column(
      children: [
        // Timer + score row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(
                Icons.timer,
                color: _secondsLeft <= 10 ? Colors.red : _subtitleColor,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                '$_secondsLeft s',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _secondsLeft <= 10 ? Colors.red : _titleColor,
                ).copyWith(fontFamilyFallback: const ['Jomolhari']),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Score: $_correct',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: timeFraction,
              minHeight: 8,
              backgroundColor:
                  _isDark ? Colors.grey.shade700 : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                _secondsLeft <= 10 ? Colors.red : Theme.of(context).primaryColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Topic: $_topicName',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: _subtitleColor,
          ).copyWith(fontFamilyFallback: const ['Jomolhari']),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  elevation: 4,
                  color: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      question.tibetanText,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _titleColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(question.options.length, (index) {
                  final isSelected = _selectedIndex == index;
                  final isCorrect = index == question.correctAnswerIndex;

                  Color? tileColor = Theme.of(context).cardColor;
                  if (_showingFeedback) {
                    if (isCorrect) {
                      tileColor =
                          _isDark
                              ? Colors.green.shade900
                              : Colors.green.shade100;
                    } else if (isSelected) {
                      tileColor =
                          _isDark ? Colors.red.shade900 : Colors.red.shade100;
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Material(
                      color: tileColor,
                      borderRadius: BorderRadius.circular(14),
                      elevation: 2,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap:
                            _showingFeedback
                                ? null
                                : () => _handleAnswer(index),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Text(
                            question.options[index],
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: _titleColor,
                            ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinished() {
    final accuracy =
        _answered > 0 ? (_correct / _answered * 100).round() : 0;
    final isNewBest = _correct > 0 && _correct >= _bestScore;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isNewBest ? '🏆' : '⏱️',
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            Text(
              isNewBest ? 'New best score!' : 'Time\'s up!',
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: _titleColor,
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildResultStat('Correct', '$_correct', Colors.green),
                const SizedBox(width: 12),
                _buildResultStat('Answered', '$_answered', Colors.blue),
                const SizedBox(width: 12),
                _buildResultStat('Accuracy', '$accuracy%', Colors.purple),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '🏆 Best: $_bestScore correct',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: _subtitleColor,
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startRound,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Play Again',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Done',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: _subtitleColor,
                ).copyWith(fontFamilyFallback: const ['Jomolhari']),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultStat(String label, String value, Color color) {
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
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ).copyWith(fontFamilyFallback: const ['Jomolhari']),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: _subtitleColor,
            ).copyWith(fontFamilyFallback: const ['Jomolhari']),
          ),
        ],
      ),
    );
  }
}
