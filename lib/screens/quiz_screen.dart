import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/quiz_question.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/progress_service.dart';
import '../services/theme_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/answer_feedback_banner.dart';
import 'lesson_complete_screen.dart';

class QuizScreen extends StatefulWidget {
  final String topicFilePath;

  const QuizScreen({super.key, required this.topicFilePath});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<QuizQuestion>> questionsFuture;
  int currentQuestionIndex = 0;
  int? selectedAnswerIndex;
  bool showFeedback = false;
  bool lastAnswerCorrect = true;
  int score = 0;
  late AnimationController _animationController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _remoteSessionId;
  String? _remoteLevelId;

  @override
  void initState() {
    super.initState();
    questionsFuture = _loadQuestions();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  Future<List<QuizQuestion>> _loadQuestions() async {
    try {
      debugPrint('Loading quiz from: ${widget.topicFilePath}');

      if (widget.topicFilePath.startsWith('api://level/')) {
        final levelId = widget.topicFilePath.replaceFirst('api://level/', '');
        _remoteLevelId = levelId;
        final session = await ApiService().getLearningSession(
          levelId: levelId,
          numQuestions: 10,
          exerciseTypes: const ['multiple_choice'],
        );
        if (session == null) {
          throw FormatException(
            'Could not start this lesson. Please try again.',
          );
        }
        _remoteSessionId = session['session_id'] as String?;
        final allExercises = List<Map<String, dynamic>>.from(
          session['exercises'] as List<dynamic>? ?? [],
        );
        // Only multiple_choice exercises are supported in the quiz screen.
        // memory_match and translation_match use different data shapes.
        final exercises =
            allExercises
                .where(
                  (e) =>
                      e['type'] == 'multiple_choice' ||
                      e['exercise_type'] == 'multiple_choice',
                )
                .toList();
        final questions = <QuizQuestion>[];
        for (final exercise in exercises) {
          try {
            questions.add(QuizQuestion.fromApiExercise(exercise));
          } catch (e) {
            debugPrint('Skipping invalid remote exercise: $e');
          }
        }

        if (questions.isEmpty) {
          throw FormatException('No exercises found for this lesson yet.');
        }
        return questions;
      }

      // Try to load the JSON file
      String jsonString;
      try {
        jsonString = await rootBundle.loadString(widget.topicFilePath);
        if (jsonString.isEmpty) {
          throw FormatException('Quiz file is empty');
        }
      } catch (e) {
        throw FormatException('Failed to load quiz file: ${e.toString()}');
      }

      // Try to parse the JSON
      Map<String, dynamic> jsonMap;
      try {
        jsonMap = json.decode(jsonString);
      } catch (e) {
        throw FormatException('Invalid JSON format: ${e.toString()}');
      }

      // Validate the JSON structure
      if (!jsonMap.containsKey('exercises')) {
        throw FormatException('Missing required key: "exercises"');
      }

      final exercises = jsonMap['exercises'];
      if (exercises is! List) {
        throw FormatException('"exercises" must be an array');
      }

      final List<dynamic> exercisesJson = exercises;
      if (exercisesJson.isEmpty) {
        throw FormatException('No exercises found in the quiz');
      }

      // Convert JSON to QuizQuestion objects with validation
      final questions =
          exercisesJson.map((exerciseJson) {
            if (exerciseJson is! Map<String, dynamic>) {
              throw FormatException(
                'Invalid exercise format: must be an object',
              );
            }

            try {
              return QuizQuestion.fromJson(exerciseJson);
            } catch (e) {
              throw FormatException('Invalid exercise data: ${e.toString()}');
            }
          }).toList();

      debugPrint('Successfully loaded ${questions.length} questions');

      // Shuffle the questions for variety
      // questions.shuffle();
      return questions;
    } catch (e) {
      debugPrint('Error loading questions from ${widget.topicFilePath}: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _handleAnswer(int answerIndex, List<QuizQuestion> questions) async {
    final isCorrect =
        answerIndex == questions[currentQuestionIndex].correctAnswerIndex;
    final audioPath = isCorrect ? 'audio/correct.mp3' : 'audio/incorrect.mp3';

    final themeService = Provider.of<ThemeService>(context, listen: false);
    if (themeService.soundEffectsEnabled) {
      try {
        debugPrint('Attempting to play audio: $audioPath');
        await _audioPlayer.setVolume(themeService.soundEffectsVolume);
        await _audioPlayer.play(AssetSource(audioPath));
        debugPrint('Audio played successfully.');
      } catch (e) {
        debugPrint('Error playing audio: $e');
      }
    }

    if (isCorrect) HapticFeedback.lightImpact();

    setState(() {
      selectedAnswerIndex = answerIndex;
      showFeedback = true;
      lastAnswerCorrect = isCorrect;
      if (isCorrect) score++;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (isCorrect) {
        if (currentQuestionIndex < questions.length - 1) {
          setState(() {
            currentQuestionIndex++;
            selectedAnswerIndex = null;
            showFeedback = false;
          });
          _animationController.reset();
          _animationController.forward();
        } else {
          _goToCompletion(questions.length);
        }
      } else {
        setState(() {
          selectedAnswerIndex = null;
          showFeedback = false;
        });
      }
    });
  }

  Future<void> _goToCompletion(int totalQuestions) async {
    final category = _getCategoryFromFilePath(widget.topicFilePath);
    final progressService = Provider.of<ProgressService>(
      context,
      listen: false,
    );

    await progressService.updateQuizResults(
      category,
      score,
      totalQuestions,
      context: context,
    );

    // updateQuizResults may schedule an achievement dialog on a 500ms
    // delay; wait it out alongside the remote submit so it has a chance to
    // open (and get dismissed below) before this route is replaced, rather
    // than firing later against a disposed context.
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 600)),
      _submitRemoteProgress(totalQuestions),
    ]);

    if (!mounted) return;

    final xpEarned = score * 10;
    final accuracy = totalQuestions > 0 ? (score / totalQuestions) * 100 : 0.0;

    Navigator.of(context).popUntil((route) => route is! DialogRoute);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder:
            (context, animation, secondaryAnimation) => LessonCompleteScreen(
              score: score,
              totalQuestions: totalQuestions,
              xpEarned: xpEarned,
              accuracy: accuracy,
              streak: progressService.currentStreak,
              topicFilePath: widget.topicFilePath,
            ),
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _submitRemoteProgress(int totalQuestions) async {
    if (_remoteSessionId == null ||
        _remoteLevelId == null ||
        !ApiService().isAuthenticated) {
      return;
    }
    final xpEarned = score * 10;
    final success = await ApiService().submitProgressCompletion({
      'session_id': _remoteSessionId,
      'level_id': _remoteLevelId,
      'xp_earned': xpEarned,
      'correct_answers': score,
      'total_questions': totalQuestions,
      'time_taken_seconds': 0,
    });
    if (!success) return;

    final stats = await ApiService().getUserProgress();
    if (stats != null && mounted) {
      await Provider.of<ProgressService>(
        context,
        listen: false,
      ).updateFromServer(stats);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.background(context),
      appBar: AppBar(
        title: Text(
          _getDisplayNameFromFilePath(widget.topicFilePath),
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTokens.ink(context),
          ).copyWith(fontFamilyFallback: const ['Jomolhari']),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTokens.ink(context),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<List<QuizQuestion>>(
        future: questionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading questions...',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[400], size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading questions',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          questionsFuture = _loadQuestions(); // Retry loading
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final questions = snapshot.data ?? [];
          if (questions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.quiz_outlined,
                      color: Colors.grey[400],
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Questions Available',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This quiz section is currently empty. Please try another section.',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final question = questions[currentQuestionIndex];

          return Stack(
            children: [
              _buildQuizBody(context, question, questions),
              AnswerFeedbackBanner(
                visible: showFeedback,
                isCorrect: lastAnswerCorrect,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuizBody(
    BuildContext context,
    QuizQuestion question,
    List<QuizQuestion> questions,
  ) {
    return Column(
      children: [
        // Progress and Score
        Container(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${currentQuestionIndex + 1} of ${questions.length}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                ).copyWith(fontFamilyFallback: const ['Jomolhari']),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Score: $score',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                ),
              ),
            ],
          ),
        ),
        // Progress bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (currentQuestionIndex + 1) / questions.length,
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade700
                          : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${((currentQuestionIndex + 1) / questions.length * 100).toInt()}% Complete',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                    ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                  ),
                  Text(
                    'Accuracy: ${score > 0 ? ((score / (currentQuestionIndex + 1)) * 100).toInt() : 0}%',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w600,
                    ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Question Card
        Expanded(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          // const Text(
                          //   'Question',
                          //   style: TextStyle(
                          //     fontSize: 18,
                          //     fontWeight: FontWeight.w500,
                          //     color: Colors.grey,
                          //   ),
                          // ),
                          const SizedBox(height: 16),
                          Text(
                            question.tibetanText,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Answer options
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: question.options.length,
                    itemBuilder: (context, index) {
                      final isSelected = selectedAnswerIndex == index;
                      final isCorrect = index == question.correctAnswerIndex;

                      Color? buttonColor;
                      if (showFeedback) {
                        if (isSelected) {
                          buttonColor =
                              isCorrect
                                  ? Colors.green.shade100
                                  : Colors.red.shade100;
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: InkWell(
                            onTap:
                                showFeedback
                                    ? null
                                    : () => _handleAnswer(index, questions),
                            borderRadius: BorderRadius.circular(15),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                color:
                                    buttonColor ?? AppTokens.surface(context),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          showFeedback
                                              ? (isSelected
                                                  ? (isCorrect
                                                      ? Colors.green
                                                      : Colors.red)
                                                  : Colors.grey)
                                              : Colors.blue.withValues(
                                                alpha: 0.1,
                                              ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        String.fromCharCode(65 + index),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              showFeedback
                                                  ? (isSelected
                                                      ? Colors.white
                                                      : Colors.grey)
                                                  : Colors.blue,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      question.options[index],
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getDisplayNameFromFilePath(String filePath) {
    // Extract the filename without extension
    if (filePath.startsWith('api://level/')) {
      return filePath
          .replaceFirst('api://level/', '')
          .replaceAll('_', ' ')
          .replaceAll('-', ' ')
          .toUpperCase();
    }
    final filename = filePath.split('/').last.split('.').first;

    // Map of known quiz types to their display names
    const displayNames = {
      'alphabet': 'Alphabet',
      'vowels': 'Vowels',
      'word_meaning': 'Word Meaning',
      'body-parts': 'Body Parts',
      'fruits_and_vegetables': 'Fruits and Vegetables',
      'stacked_words': 'Stacked Words',
      'numbers': 'Numbers',
      'calender': 'Calendar',
      'introduction': 'Introduction',
      'resturants': 'Restaurants',
    };

    // Return the mapped display name or format the filename as a fallback
    return displayNames[filename] ??
        filename.replaceAll('_', ' ').replaceAll('-', ' ').toUpperCase();
  }

  String _getCategoryFromFilePath(String filePath) {
    // Extract category from file path for progress tracking
    if (filePath.startsWith('api://level/')) {
      return filePath.replaceFirst('api://level/', '');
    }
    final filename = filePath.split('/').last.split('.').first;

    // Map quiz files to categories for progress tracking
    if (filename.contains('alphabet') || filename.contains('vowels')) {
      return 'alphabet';
    } else if (filename.contains('numbers') || filename.contains('calender')) {
      return 'numbers';
    } else if (filename.contains('introduction') ||
        filename.contains('greetings')) {
      return 'greetings';
    }

    return filename.toLowerCase().replaceAll('_', ' ');
  }
}
