import 'package:flutter/material.dart';
import '../data/quiz_data.dart';
import '../models/quiz_question.dart';

class QuizScreen extends StatefulWidget {
  final int level;

  const QuizScreen({super.key, required this.level});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late Future<List<QuizQuestion>> questionsFuture;
  List<QuizQuestion> questions = [];
  int currentQuestionIndex = 0;
  int? selectedAnswerIndex;
  bool showFeedback = false;

  @override
  void initState() {
    super.initState();
    questionsFuture = QuizData.getQuestionsForLevel(widget.level);
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    questions = await questionsFuture;
    setState(() {});
  }

  void _handleAnswer(int answerIndex) {
    final isCorrect = answerIndex == questions[currentQuestionIndex].correctAnswerIndex;
    
    setState(() {
      selectedAnswerIndex = answerIndex;
      showFeedback = true;
    });

    // Show feedback and handle navigation
    if (isCorrect) {
      // Show success feedback and move to next question after delay
      _showFeedbackDialog(true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop(); // Close the dialog
          if (currentQuestionIndex < questions.length - 1) {
            setState(() {
              currentQuestionIndex++;
              selectedAnswerIndex = null;
              showFeedback = false;
            });
          } else {
            // Quiz completed
            Navigator.pop(context);
          }
        }
      });
    } else {
      // Show error feedback and allow retry
      _showFeedbackDialog(false);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop(); // Close the dialog
          setState(() {
            selectedAnswerIndex = null;
            showFeedback = false;
          });
        }
      });
    }
  }

  void _showFeedbackDialog(bool isCorrect) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isCorrect ? Colors.green.shade100 : Colors.purple.shade100,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.error,
                color: isCorrect ? Colors.green : Colors.purple,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                isCorrect ? 'ལེགས་སོ། Amazing!' : 'སེམས་ཤུགས་མ་ཆག \nThink again!',
                style: TextStyle(
                  fontSize: 24,
                  color: isCorrect ? Colors.green : Colors.purple,
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
        title: Text('Level ${widget.level}'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<QuizQuestion>>(
        future: questionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading questions: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No questions available for this level.'),
            );
          }

          final question = questions[currentQuestionIndex];

          return Column(
            children: [
              // Progress bar
              LinearProgressIndicator(
                value: (currentQuestionIndex + 1) / questions.length,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  '${currentQuestionIndex + 1}/${questions.length}',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              // Question
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  question.tibetanText,
                  style: const TextStyle(fontSize: 28),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              // Answer options
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: question.options.length,
                  itemBuilder: (context, index) {
                    final isSelected = selectedAnswerIndex == index;
                    final isCorrect = index == question.correctAnswerIndex;
                    
                    Color? buttonColor;
                    if (showFeedback) {
                      if (isSelected) {
                        buttonColor = isCorrect ? Colors.green.shade100 : Colors.red.shade100;
                      } else if (isCorrect) {
                        buttonColor = Colors.green.shade100;
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          padding: const EdgeInsets.all(16),
                        ),
                        onPressed: showFeedback ? null : () => _handleAnswer(index),
                        child: Text(
                          question.options[index],
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
} 