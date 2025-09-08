import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/quiz_question.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';

class QuizScreen extends StatefulWidget {
  final String topicFilePath;

  const QuizScreen({super.key, required this.topicFilePath});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with SingleTickerProviderStateMixin {
  late Future<List<QuizQuestion>> questionsFuture;
  int currentQuestionIndex = 0;
  int? selectedAnswerIndex;
  bool showFeedback = false;
  int score = 0;
  late AnimationController _animationController;
  late Animation<double> _animation;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    questionsFuture = _loadQuestions();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  Future<List<QuizQuestion>> _loadQuestions() async {
    try {
      print('Loading quiz from: ${widget.topicFilePath}');
      
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
      final questions = exercisesJson.map((exerciseJson) {
        if (exerciseJson is! Map<String, dynamic>) {
          throw FormatException('Invalid exercise format: must be an object');
        }

        try {
          return QuizQuestion.fromJson(exerciseJson);
        } catch (e) {
          throw FormatException('Invalid exercise data: ${e.toString()}');
        }
      }).toList();

      print('Successfully loaded ${questions.length} questions');
      
      // Shuffle the questions for variety
      // questions.shuffle();
      return questions;
    } catch (e) {
      print('Error loading questions from ${widget.topicFilePath}: $e');
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
    final isCorrect = answerIndex == questions[currentQuestionIndex].correctAnswerIndex;
    final audioPath = isCorrect ? 'audio/correct.mp3' : 'audio/incorrect.mp3';

    try {
      print('Attempting to play audio: $audioPath');
      await _audioPlayer.play(AssetSource(audioPath));
      print('Audio played successfully.');
    } catch (e) {
      print('Error playing audio: $e');
    }

    setState(() {
      selectedAnswerIndex = answerIndex;
      showFeedback = true;
      if (isCorrect) score++;
    });
    if (isCorrect) {
      _showFeedbackDialog(true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop();
          if (currentQuestionIndex < questions.length - 1) {
            setState(() {
              currentQuestionIndex++;
              selectedAnswerIndex = null;
              showFeedback = false;
            });
            _animationController.reset();
            _animationController.forward();
          } else {
            _showCompletionDialog(questions.length);
          }
        }
      });
    } else {
      _showFeedbackDialog(false);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop();
          setState(() {
            selectedAnswerIndex = null;
            showFeedback = false;
          });
        }
      });
    }
  }

  void _showCompletionDialog(int totalQuestions) {
    final percentage = (score / totalQuestions) * 100;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Quiz Completed!', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                percentage >= 70 ? Icons.emoji_events : Icons.star,
                color: percentage >= 70 ? Colors.amber : Colors.blue,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Your Score: $score/totalQuestions',
                style: GoogleFonts.kalam(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: GoogleFonts.kalam(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: percentage >= 70 ? Colors.green[700] : Colors.blue[700],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                percentage >= 70 
                    ? 'ལེགས་སོ། Excellent!'
                    : 'Keep practicing!',
                style: TextStyle(
                  fontSize: 20,
                  color: percentage >= 70 ? Colors.green : Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Return to sublevel selection
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  void _showFeedbackDialog(bool isCorrect) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.error,
                color: isCorrect ? Colors.green : Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                isCorrect ? 'ལེགས་སོ། Amazing!' : 'སེམས་ཤུགས་མ་ཆག \nTry again!',
                style: TextStyle(
                  fontSize: 24,
                  color: isCorrect ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getDisplayNameFromFilePath(widget.topicFilePath),
          style: GoogleFonts.kalam(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
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
                    style: GoogleFonts.kalam(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
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
                    Icon(
                      Icons.error_outline,
                      color: Colors.red[400],
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading questions',
                      style: GoogleFonts.kalam(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                      style: GoogleFonts.kalam(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This quiz section is currently empty. Please try another section.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final question = questions[currentQuestionIndex];

          return Column(
            children: [
              // Progress and Score
              Container(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Score: $score',
                      style: GoogleFonts.kalam(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
              // Progress bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: currentQuestionIndex / questions.length,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                    minHeight: 10,
                  ),
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
                                buttonColor = isCorrect ? Colors.green.shade100 : Colors.red.shade100;
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
                                  onTap: showFeedback ? null : () => _handleAnswer(index, questions),
                                  borderRadius: BorderRadius.circular(15),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      color: buttonColor ?? Colors.white,
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: showFeedback
                                                ? (isSelected ? (isCorrect ? Colors.green : Colors.red) : Colors.grey)
                                                : Colors.blue.withOpacity(0.1),
                                          ),
                                          child: Center(
                                            child: Text(
                                              String.fromCharCode(65 + index),
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: showFeedback
                                                    ? (isSelected ? Colors.white : Colors.grey)
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
        },
      ),
    );
  }

  String _getDisplayNameFromFilePath(String filePath) {
    // Extract the filename without extension
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
      'resturants': 'Restaurants'
    };

    // Return the mapped display name or format the filename as a fallback
    return displayNames[filename] ?? 
           filename.replaceAll('_', ' ').replaceAll('-', ' ').toUpperCase();
  }
} 