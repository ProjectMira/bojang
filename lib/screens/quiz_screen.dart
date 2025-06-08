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
    setState(() {
      selectedAnswerIndex = answerIndex;
    });

    // Show feedback and move to next question after a delay
    Future.delayed(const Duration(seconds: 1), () {
      if (currentQuestionIndex < questions.length - 1) {
        setState(() {
          currentQuestionIndex++;
          selectedAnswerIndex = null;
        });
      } else {
        // Quiz completed
        Navigator.pop(context);
      }
    });
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
                    if (selectedAnswerIndex != null) {
                      if (isSelected) {
                        buttonColor = isCorrect ? Colors.green : Colors.red;
                      } else if (isCorrect) {
                        buttonColor = Colors.green;
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          padding: const EdgeInsets.all(16),
                        ),
                        onPressed: selectedAnswerIndex == null
                            ? () => _handleAnswer(index)
                            : null,
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