import 'package:flutter/material.dart';
import 'quiz_screen.dart';

class LevelSelectionScreen extends StatelessWidget {
  const LevelSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Learning Path',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
        ),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - AppBar().preferredSize.height,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPath(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPath(BuildContext context) {
    return Stack(
      children: [
        // Path line
        Positioned(
          left: 45,
          top: 0,
          bottom: 0,
          child: Container(
            width: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Column(
          children: [
            _buildLevel(
              context,
              1,
              'Beginner',
              Colors.green,
              true, // unlocked
              false, // completed
            ),
            _buildConnector(),
            _buildLevel(
              context,
              2,
              'Intermediate',
              Colors.blue,
              true, // unlocked
              false, // not completed
            ),
            _buildConnector(),
            _buildLevel(
              context,
              3,
              'Advanced',
              Colors.purple,
              true, // unlocked
              false, // not completed
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConnector() {
    return const SizedBox(height: 30);
  }

  Widget _buildLevel(
    BuildContext context,
    int level,
    String title,
    Color color,
    bool isUnlocked,
    bool isCompleted,
  ) {
    return Opacity(
      opacity: isUnlocked ? 1.0 : 0.6,
      child: Container(
        margin: const EdgeInsets.only(bottom: 30),
        child: InkWell(
          onTap: isUnlocked
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizScreen(level: level),
                    ),
                  );
                }
              : null,
          child: Row(
            children: [
              // Level circle with icon
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: isUnlocked ? Colors.white : Colors.grey[300],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isUnlocked ? color : Colors.grey,
                    width: 3,
                  ),
                  boxShadow: isUnlocked
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isCompleted) ...[
                      // Background circle for completed level
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Icon(
                        Icons.check_circle,
                        color: color,
                        size: 32,
                      ),
                    ] else ...[
                      Text(
                        '$level',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: isUnlocked ? color : Colors.grey,
                        ),
                      ),
                    ],
                    if (!isUnlocked)
                      const Icon(
                        Icons.lock,
                        color: Colors.grey,
                        size: 24,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Level details
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isUnlocked ? color.withOpacity(0.3) : Colors.grey[300]!,
                      width: 2,
                    ),
                    boxShadow: isUnlocked
                        ? [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isUnlocked ? Colors.black87 : Colors.grey,
                        ),
                      ),
                      if (isUnlocked && !isCompleted) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            level == 1
                                ? 'Learn Basic Words'
                                : level == 2
                                    ? 'Practice Simple Sentences'
                                    : 'Master Complex Sentences',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          level == 1
                              ? 'Start with basic vocabulary and essential words'
                              : level == 2
                                  ? 'Form basic sentences and simple conversations'
                                  : 'Learn advanced grammar and complex expressions',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 