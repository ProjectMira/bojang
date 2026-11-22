import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/lesson_style.dart';
import '../models/quiz_question.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import '../services/analytics.dart';
import '../services/api_service.dart';
import '../services/progress_service.dart';
import '../services/pronunciation_player.dart';
import '../services/theme_service.dart';
import '../theme/app_tokens.dart';
import '../utils/yak_lines.dart';
import '../widgets/answer_feedback_banner.dart';
import '../widgets/yak_mascot.dart';
import '../widgets/yak_says.dart';
import '../widgets/lesson_style_sheet.dart';
import '../widgets/speaker_button.dart';
import '../widgets/reading_voice_pickers.dart';
import '../widgets/romanisation_text.dart';
import 'lesson_complete_screen.dart';
import '../widgets/content_width.dart';
import '../widgets/app_text_style.dart';

class QuizScreen extends StatefulWidget {
  final String topicFilePath;

  /// Topic name for the app bar. Falls back to a name derived from
  /// [topicFilePath].
  final String? title;

  /// Forces a lesson style. Null (the normal case) uses the learner's saved
  /// preference, [ThemeService.lessonStyle].
  final LessonStyle? style;

  /// Where the lesson was opened from (home_shortcut, topic_list,
  /// lesson_intro, lesson_complete...), for analytics.
  final String? source;

  const QuizScreen({
    super.key,
    required this.topicFilePath,
    this.title,
    this.style,
    this.source,
  });

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
  // Right answers in a row; the yak calls out runs of them.
  int _combo = 0;
  late AnimationController _animationController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  // Scrolls the options up while the feedback banner covers the bottom of
  // the screen, so the last option (maybe the right answer) stays visible.
  final ScrollController _scrollController = ScrollController();
  String? _remoteSessionId;
  String? _remoteLevelId;
  // Question index whose pronunciation already auto-played, so rebuilds
  // don't replay it.
  int? _autoPlayedIndex;
  late LessonStyle _style;
  // Bumped when the lesson restarts, so timers from the old run do nothing.
  int _generation = 0;
  // Analytics: when the current run started, its length, and whether it
  // reached the completion screen (so leaving afterwards is not a quit).
  DateTime _startedAt = DateTime.now();
  int _questionCount = 0;
  bool _completed = false;
  // When the question on screen appeared, for answer response times.
  DateTime _questionShownAt = DateTime.now();
  int _answeredCount = 0;

  String get _topicName =>
      widget.title ?? _getDisplayNameFromFilePath(widget.topicFilePath);

  void _trackQuit() {
    if (_completed || _questionCount == 0) return;
    Analytics.track('lesson_quit', {
      'reason': 'back',
      'answered': _answeredCount,
      'question_s': DateTime.now().difference(_questionShownAt).inSeconds,
      'source': widget.source,
      'topic': _topicName,
      'topic_path': widget.topicFilePath,
      'question_index': currentQuestionIndex,
      'question_count': _questionCount,
      'score': score,
      'style': _style.name,
      'duration_s': DateTime.now().difference(_startedAt).inSeconds,
    });
  }

  @override
  void initState() {
    super.initState();
    _style =
        widget.style ??
        Provider.of<ThemeService>(context, listen: false).lessonStyle;
    _startLoading();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  void _startLoading() {
    questionsFuture = _loadQuestions();
    _startedAt = DateTime.now();
    _questionCount = 0;
    questionsFuture.then(
      (questions) {
        _questionCount = questions.length;
        _questionShownAt = DateTime.now();
        Analytics.track('lesson_started', {
          'source': widget.source ?? 'unknown',
          'topic': _topicName,
          'topic_path': widget.topicFilePath,
          'style': _style.name,
          'question_count': questions.length,
          'remote_session': _remoteSessionId != null,
        });
      },
      onError: (Object e) {
        final msg = e.toString();
        Analytics.track('lesson_load_failed', {
          'topic': _topicName,
          'topic_path': widget.topicFilePath,
          'style': _style.name,
          'error': msg.length > 200 ? msg.substring(0, 200) : msg,
        });
      },
    );
    // Fetch every question's pronunciation up front so it plays instantly.
    final voice =
        Provider.of<ThemeService>(context, listen: false).pronunciationVoice;
    questionsFuture.then(
      (questions) => PronunciationPlayer.instance.prefetch(
        questions.map((q) => q.audioFor(voice)),
      ),
      onError: (Object _) {},
    );
  }

  /// Lets the learner switch lesson style from inside a lesson. The choice
  /// is saved for every topic and this lesson restarts in the new style.
  Future<void> _changeStyle() async {
    final picked = await showLessonStylePicker(context);
    if (picked == null || picked == _style || !mounted) return;
    Analytics.track('lesson_style_selected', {
      'style': picked.name,
      'previous_style': _style.name,
      'source': 'quiz',
      'topic': _topicName,
    });
    PronunciationPlayer.instance.stop();
    setState(() {
      _style = picked;
      currentQuestionIndex = 0;
      selectedAnswerIndex = null;
      showFeedback = false;
      score = 0;
      _combo = 0;
      _autoPlayedIndex = null;
      _generation++;
      _startLoading();
    });
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
          exerciseTypes: _style.exerciseTypes,
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
        // Only choice-style exercises are supported in the quiz screen.
        // memory_match and translation_match use different data shapes.
        // picture_choice sessions may contain multiple_choice fallbacks
        // for words that have no illustration yet.
        const supportedTypes = {'multiple_choice', 'picture_choice'};
        final exercises =
            allExercises
                .where(
                  (e) =>
                      supportedTypes.contains(e['type']) ||
                      supportedTypes.contains(e['exercise_type']),
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
        return _style.arrange(questions);
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
    _scrollController.dispose();
    PronunciationPlayer.instance.stop();
    super.dispose();
  }

  /// Speaks a multiple_choice prompt once when its question appears (the
  /// options are English, so hearing the Tibetan gives nothing away). Follows
  /// the sound-effects switch; the speaker button always works.
  /// The question's recording in the learner's chosen voice.
  String? _audioOf(QuizQuestion question) => question.audioFor(
    Provider.of<ThemeService>(context).pronunciationVoice,
  );

  void _autoPlayPrompt(QuizQuestion question) {
    if (_autoPlayedIndex == currentQuestionIndex) return;
    _autoPlayedIndex = currentQuestionIndex;
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final url = question.audioFor(themeService.pronunciationVoice);
    if (url == null || question.hasTibetanOptions) return;
    // A listening question IS its recording, so it plays even with sound
    // effects off; a written prompt's read-aloud follows that switch.
    final isListening = question.type == QuizQuestion.listening;
    if (!isListening && !themeService.soundEffectsEnabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        PronunciationPlayer.instance.play(
          url,
          volume: themeService.pronunciationVolume,
        );
      }
    });
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

    final answered = questions[currentQuestionIndex];
    Analytics.track('question_answered', {
      'topic': _topicName,
      'topic_path': widget.topicFilePath,
      'question_index': currentQuestionIndex,
      'question_count': questions.length,
      'question_type': answered.type,
      'correct': isCorrect,
      'combo': isCorrect ? _combo + 1 : 0,
      'tibetan': answered.wordTibetan,
      'english': answered.englishGloss,
      'chosen': answered.options[answerIndex],
      'correct_answer': answered.options[answered.correctAnswerIndex],
      'response_ms': DateTime.now().difference(_questionShownAt).inMilliseconds,
      'skill': answered.isScript ? 'script' : 'vocabulary',
      'has_audio': answered.audioUrl != null || answered.audioUrls.isNotEmpty,
      'voice': themeService.pronunciationVoice,
      'reading_help': themeService.transliterationMode.name,
      'style': _style.name,
      'source': widget.source,
    });
    _answeredCount++;

    // Picture questions have Tibetan options, so their word is only spoken
    // once answered (earlier would give the answer away). It follows the
    // chime, which is ducked so the word stays clear.
    final question = questions[currentQuestionIndex];
    final revealUrl = question.audioFor(themeService.pronunciationVoice);
    final revealAudio = question.hasTibetanOptions && revealUrl != null;
    if (revealAudio && themeService.soundEffectsEnabled) {
      final revealGeneration = _generation;
      Future.delayed(const Duration(milliseconds: 600), () async {
        if (!mounted || revealGeneration != _generation) return;
        if (currentQuestionIndex >= questions.length) return;
        if (questions[currentQuestionIndex] != question) return;
        try {
          await _audioPlayer.setVolume(themeService.soundEffectsVolume * 0.3);
        } catch (_) {}
        await PronunciationPlayer.instance.play(
          revealUrl,
          volume: themeService.pronunciationVolume,
        );
      });
    }

    setState(() {
      selectedAnswerIndex = answerIndex;
      showFeedback = true;
      lastAnswerCorrect = isCorrect;
      if (isCorrect) score++;
      _combo = isCorrect ? _combo + 1 : 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });

    // One attempt per question: a wrong answer is recorded and the quiz moves
    // on, so the final score reflects what the learner actually knew. The
    // delay is time to read the feedback and see the right answer revealed.
    final feedbackTime =
        revealAudio
            ? const Duration(milliseconds: 2800)
            : const Duration(seconds: 2);
    final generation = _generation;
    Future.delayed(feedbackTime, () {
      if (!mounted || generation != _generation) return;
      if (currentQuestionIndex < questions.length - 1) {
        setState(() {
          currentQuestionIndex++;
          selectedAnswerIndex = null;
          showFeedback = false;
        });
        _questionShownAt = DateTime.now();
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
        _animationController.reset();
        _animationController.forward();
      } else {
        _goToCompletion(questions.length);
      }
    });
  }

  Future<void> _goToCompletion(int totalQuestions) async {
    _completed = true;
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

    Analytics.track('lesson_completed', {
      'topic': _topicName,
      'topic_path': widget.topicFilePath,
      'category': category,
      'style': _style.name,
      'score': score,
      'total': totalQuestions,
      'accuracy': accuracy.round(),
      'xp_earned': xpEarned,
      'streak': progressService.currentStreak,
      'duration_s': DateTime.now().difference(_startedAt).inSeconds,
      'remote_session': _remoteSessionId != null,
    });

    Navigator.of(context).popUntil((route) => route is! DialogRoute);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        settings: const RouteSettings(name: 'lesson_complete'),
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder:
            (context, animation, secondaryAnimation) => LessonCompleteScreen(
              score: score,
              totalQuestions: totalQuestions,
              xpEarned: xpEarned,
              accuracy: accuracy,
              streak: progressService.currentStreak,
              topicFilePath: widget.topicFilePath,
              title: widget.title,
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
    // Let queued activity (e.g. an offline "yesterday") reach the server
    // first; otherwise this lesson can land first, see a gap and reset the
    // streak before yesterday is recorded.
    await Provider.of<ProgressService>(
      context,
      listen: false,
    ).flushPendingActivity();
    final xpEarned = score * 10;
    final success = await ApiService().submitProgressCompletion({
      'session_id': _remoteSessionId,
      'level_id': _remoteLevelId,
      'xp_earned': xpEarned,
      'correct_answers': score,
      'total_questions': totalQuestions,
      'time_taken_seconds': 0,
      'local_date': ProgressService.localDateString(DateTime.now()),
    });
    Analytics.track('lesson_progress_submitted', {
      'success': success,
      'topic_path': widget.topicFilePath,
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
    // Any way out of an unfinished lesson (app bar back, system back gesture)
    // is recorded as a quit; leaving still works exactly as before.
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _trackQuit();
      },
      child: Scaffold(
      backgroundColor: AppTokens.background(context),
      appBar: AppBar(
        title: Text(
          widget.title ?? _getDisplayNameFromFilePath(widget.topicFilePath),
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTokens.ink(context),
          ).copyWith(fontFamilyFallback: const ['Jomolhari']),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: AppTokens.statusBar(context),
        foregroundColor: AppTokens.ink(context),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Bundled offline lessons only have one question kind.
          if (widget.topicFilePath.startsWith('api://level/'))
            IconButton(
              icon: Icon(lessonStyleIcon(_style)),
              tooltip: 'Lesson style: ${_style.title}',
              onPressed: _changeStyle,
            ),
        ],
      ),
      body: ContentWidth(maxWidth: ContentWidth.reading, child: FutureBuilder<List<QuizQuestion>>(
        future: questionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const YakLoader();
          }

          if (snapshot.hasError) {
            // The raw exception is logged, not shown: learners get the yak
            // and a way forward.
            debugPrint('Quiz load failed: ${snapshot.error}');
            return YakNotice.line(
              YakLines.error,
              actionLabel: 'Try again',
              onAction: () => setState(_startLoading),
            );
          }

          final questions = snapshot.data ?? [];
          if (questions.isEmpty) {
            return YakNotice(
              mood: YakMood.thinking,
              title: 'Nothing here yet',
              body: "I'm still gathering words for this one. Try another topic.",
              actionLabel: 'Go back',
              onAction: () => Navigator.of(context).pop(),
            );
          }

          final question = questions[currentQuestionIndex];
          _autoPlayPrompt(question);

          return Stack(
            children: [
              _buildQuizBody(context, question, questions),
              AnswerFeedbackBanner(
                visible: showFeedback,
                isCorrect: lastAnswerCorrect,
                combo: _combo,
                seed: currentQuestionIndex,
                // Tibetan answers are shown on the word line below instead.
                correctAnswerText:
                    !question.hasTibetanOptions &&
                            question.correctAnswerIndex >= 0 &&
                            question.correctAnswerIndex <
                                question.options.length
                        ? question.options[question.correctAnswerIndex]
                        : null,
                tibetan: question.wordTibetan,
                romanisation: question.romanisation,
              ),
            ],
          );
        },
      ),),
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
                    'Accuracy: ${_accuracySoFar()}%',
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
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              // Room under the options for the feedback banner.
              padding: EdgeInsets.fromLTRB(16, 16, 16, showFeedback ? 180 : 16),
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
                          Text(
                            _instructionFor(question),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTokens.inkSoft(context),
                            ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                          ),
                          const SizedBox(height: 16),
                          ..._buildPrompt(context, question),
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

                      // During feedback the right answer is always highlighted,
                      // tapped or not — a wrong pick moves on, so this is the
                      // learner's one chance to see what it should have been.
                      Color? buttonColor;
                      if (showFeedback) {
                        if (isCorrect) {
                          buttonColor = Colors.green.shade100;
                        } else if (isSelected) {
                          buttonColor = Colors.red.shade100;
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
                                              ? (isCorrect
                                                  ? Colors.green
                                                  : (isSelected
                                                      ? Colors.red
                                                      : Colors.grey))
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
                                                  ? (isCorrect || isSelected
                                                      ? Colors.white
                                                      : Colors.grey)
                                                  : Colors.blue,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          question.options[index],
                                          style: GoogleFonts.poppins(
                                            // Tibetan script needs more size
                                            // than Latin to read comfortably.
                                            fontSize:
                                                question.hasTibetanOptions
                                                    ? 24
                                                    : 18,
                                          ).copyWith(
                                            fontFamilyFallback: const [
                                              'Jomolhari',
                                            ],
                                          ),
                                        ),
                                        if (question.showsRomanisation(
                                          answered: showFeedback,
                                        ))
                                          RomanisationText(
                                            question.optionRomanisation(index),
                                            fontSize: 14,
                                            textAlign: TextAlign.start,
                                            alignment:
                                                CrossAxisAlignment.start,
                                          ),
                                      ],
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

  /// Share of the questions answered so far that were right. The question
  /// on screen only counts once it has been answered.
  int _accuracySoFar() {
    final answered = currentQuestionIndex + (showFeedback ? 1 : 0);
    return answered == 0 ? 0 : (score / answered * 100).round();
  }

  String _instructionFor(QuizQuestion question) => switch (question.type) {
    QuizQuestion.pictureChoice => 'Which word matches the picture?',
    QuizQuestion.listening => 'What do you hear?',
    QuizQuestion.reverseChoice when question.isScript =>
      'Which one reads like this?',
    QuizQuestion.reverseChoice => 'How do you say this in Tibetan?',
    _ when question.isScript => 'How do you read this?',
    _ => 'What does this mean?',
  };

  /// Speaker button for the question's word plus the voice chip that changes
  /// its dialect.
  Widget _audioRow(QuizQuestion question, String audio, {double size = 28}) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        SpeakerButton(url: audio, size: size),
        VoiceChip(audioUrls: question.audioUrls, source: 'quiz'),
      ],
    );
  }

  /// The word's phonetics/Wylie; for script questions held back (keeping
  /// its space) until the learner answers.
  Widget _romanisationOf(QuizQuestion question) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Visibility(
        visible: question.showsRomanisation(answered: showFeedback),
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: RomanisationText(question.romanisation, fontSize: 20),
      ),
    );
  }

  /// The part of the question card under the instruction line: a picture,
  /// a speaker, an English word or a Tibetan word, by question kind.
  List<Widget> _buildPrompt(BuildContext context, QuizQuestion question) {
    final audio = _audioOf(question);

    if (question.type == QuizQuestion.listening && audio != null) {
      return [
        _audioRow(question, audio, size: 56),
        const SizedBox(height: 12),
        // The written word stays hidden until answered, so the question is
        // answered by ear.
        Visibility(
          visible: showFeedback,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: Column(
            children: [
              Text(
                question.tibetanText,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              RomanisationText(question.romanisation, fontSize: 18),
            ],
          ),
        ),
      ];
    }

    if (question.type == QuizQuestion.reverseChoice) {
      return [
        Text(
          question.englishGloss ?? '',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTokens.ink(context),
          ).copyWith(fontFamilyFallback: const ['Jomolhari']),
          textAlign: TextAlign.center,
        ),
        if (showFeedback && audio != null) ...[
          const SizedBox(height: 12),
          _audioRow(question, audio),
        ],
      ];
    }

    if (question.imageUrl != null) {
      return [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            question.imageUrl!,
            height: 200,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            },
            // Image failed to load — the English gloss becomes the prompt
            // so the question still works.
            errorBuilder:
                (context, error, stackTrace) => Text(
                  question.englishGloss?.isNotEmpty == true
                      ? question.englishGloss!
                      : question.tibetanText,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
          ),
        ),
        if (showFeedback && audio != null) ...[
          const SizedBox(height: 8),
          _audioRow(question, audio),
        ],
      ];
    }

    return [
      // Tibetan is the hero of the card: larger than the English around it.
      Text(
        question.tibetanText,
        style: AppTextStyles.poppins(
          fontSize: Breakpoints.isTablet(context) ? 60 : 52,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: AppTokens.ink(context),
        ),
        textAlign: TextAlign.center,
      ),
      _romanisationOf(question),
      if (audio != null) ...[
        const SizedBox(height: 12),
        _audioRow(question, audio),
      ],
    ];
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
