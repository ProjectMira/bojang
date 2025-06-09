import 'package:flutter/material.dart';
import '../data/quiz_data.dart';
import '../models/quiz_question.dart';
import 'package:google_fonts/google_fonts.dart';

class QuizScreen extends StatefulWidget {
  final int level;

  const QuizScreen({super.key, required this.level});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with SingleTickerProviderStateMixin {
  late Future<List<QuizQuestion>> questionsFuture;
  List<QuizQuestion> questions = [];
  int currentQuestionIndex = 0;
  int? selectedAnswerIndex;
  bool showFeedback = false;
  int score = 0;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    questionsFuture = QuizData.getQuestionsForLevel(widget.level);
    _loadQuestions();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
            _showCompletionDialog();
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

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final percentage = (score / questions.length) * 100;
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
                'Your Score: $score/${questions.length}',
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
                Navigator.of(context).pop(); // Return to level selection
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
          'Level ${widget.level}',
          style: GoogleFonts.kalam(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
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
              child: Text(
                'Error loading questions: ${snapshot.error}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No questions available for this level.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
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
                                  onTap: showFeedback ? null : () => _handleAnswer(index),
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
} 