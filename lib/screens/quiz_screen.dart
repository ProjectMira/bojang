import 'package:flutter/material.dart' hide Feedback;
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/learning_path.dart';
import '../models/lesson_queue.dart';
import '../models/lesson_style.dart';
import '../models/quiz_question.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import '../services/analytics.dart';
import '../services/feedback.dart';
import '../services/api_service.dart';
import '../services/lesson_milestones.dart';
import '../services/progress_service.dart';
import '../services/pronunciation_player.dart';
import '../services/sound_effects.dart';
import '../services/theme_service.dart';
import '../theme/app_tokens.dart';
import '../utils/yak_lines.dart';
import '../widgets/answer_feedback_banner.dart';
import '../widgets/exercise_label_pill.dart';
import '../widgets/yak_mascot.dart';
import '../widgets/yak_says.dart';
import '../widgets/lesson_style_sheet.dart';
import '../widgets/speaker_button.dart';
import '../widgets/reading_voice_pickers.dart';
import '../widgets/romanisation_text.dart';
import '../services/reading_help.dart';
import 'lesson_complete_screen.dart';
import '../widgets/content_width.dart';
import '../widgets/app_text_style.dart';
import '../theme/tibetan_type.dart';
import '../widgets/script/script_exercise_views.dart';
import '../widgets/script/trace_pad.dart';
import '../widgets/offline_lessons_banner.dart';

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
  late Future<LessonQueue> questionsFuture;
  // The lesson's questions in order: the core, bonus questions when the
  // learner is doing well, then each missed word once more.
  LessonQueue? _lesson;
  int get currentQuestionIndex => _lesson?.index ?? 0;
  int? selectedAnswerIndex;
  bool showFeedback = false;
  bool lastAnswerCorrect = true;
  int get score => _lesson?.correct ?? 0;
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
    Feedback.startLesson();
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
    _lesson = null;
    late final Future<LessonQueue> load;
    load = _loadQuestions().then((lesson) {
      // A restart (new lesson style) may finish first; keep only the latest.
      if (identical(questionsFuture, load)) _lesson = lesson;
      return lesson;
    });
    questionsFuture = load;
    _startedAt = DateTime.now();
    _questionCount = 0;
    questionsFuture.then(
      (lesson) {
        _questionCount = lesson.coreCount;
        _questionShownAt = DateTime.now();
        Analytics.track('lesson_started', {
          'source': widget.source ?? 'unknown',
          'topic': _topicName,
          'topic_path': widget.topicFilePath,
          'style': _style.name,
          'question_count': lesson.coreCount,
          'bonus_available': lesson.allQuestions.length - lesson.coreCount,
          'labels': _labelCounts(lesson),
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
      (lesson) => PronunciationPlayer.instance.prefetch(
        lesson.allQuestions.map((q) => q.audioFor(voice)),
      ),
      onError: (Object _) {},
    );
  }

  static Map<String, int> _labelCounts(LessonQueue lesson) {
    final counts = <String, int>{};
    for (final q in lesson.allQuestions) {
      final label = q.label;
      if (label != null) counts[label] = (counts[label] ?? 0) + 1;
    }
    return counts;
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
      selectedAnswerIndex = null;
      showFeedback = false;
      _combo = 0;
      _autoPlayedIndex = null;
      _generation++;
      _startLoading();
    });
  }

  /// Parses server exercises this screen can render, skipping bad ones.
  static List<QuizQuestion> _parseExercises(Object? raw) {
    final questions = <QuizQuestion>[];
    for (final exercise in List<Map<String, dynamic>>.from(
      raw as List<dynamic>? ?? const [],
    )) {
      // Safe fallback: the server builds only `supported_types`, but an
      // older server ignores that list, so other types are still dropped.
      final type = exercise['type'] ?? exercise['exercise_type'];
      if (!QuizQuestion.renderableTypes.contains(type)) continue;
      try {
        questions.add(QuizQuestion.fromAnyExercise(exercise));
      } catch (e) {
        debugPrint('Skipping invalid remote exercise: $e');
      }
    }
    return questions;
  }

  Future<LessonQueue> _loadQuestions() async {
    try {
      debugPrint('Loading quiz from: ${widget.topicFilePath}');

      // The script course: api://script/learn or api://script/practice.
      if (widget.topicFilePath.startsWith('api://script/')) {
        final mode = widget.topicFilePath.replaceFirst('api://script/', '');
        final session = await ApiService().getScriptSession(
          mode: mode,
          supportedTypes: QuizQuestion.renderableTypes,
        );
        if (session == null) {
          throw FormatException(
            'Could not start this lesson. Please try again.',
          );
        }
        _remoteSessionId = session['session_id'] as String?;
        _remoteLevelId = session['level_id'] as String?;
        final questions = _parseExercises(session['exercises']);
        if (questions.isEmpty) {
          throw FormatException('No exercises found for this lesson yet.');
        }
        return LessonQueue(LessonQueue.easyStart(questions));
      }

      // Review (Practice tab, path practice / unit review): words from the
      // learner's mistakes, issued under a real level the server picks.
      final isReview = widget.topicFilePath.startsWith(kReviewTopicPath);
      if (widget.topicFilePath.startsWith('api://level/') || isReview) {
        final levelId = widget.topicFilePath.replaceFirst('api://level/', '');
        _remoteLevelId = isReview ? null : levelId;
        final session =
            isReview
                ? await ApiService().getReviewSession(
                  nodeId: reviewNodeIdOf(widget.topicFilePath),
                  supportedTypes: QuizQuestion.renderableTypes,
                )
                : await ApiService().getLearningSession(
                  levelId: levelId,
                  numQuestions: 10,
                  exerciseTypes: _style.exerciseTypes,
                  supportedTypes: QuizQuestion.renderableTypes,
                );
        if (isReview) _remoteLevelId = session?['level_id'] as String?;
        if (session == null) {
          throw FormatException(
            'Could not start this lesson. Please try again.',
          );
        }
        _remoteSessionId = session['session_id'] as String?;
        // picture_choice sessions may contain multiple_choice fallbacks for
        // words that have no illustration yet.
        final questions = _parseExercises(session['exercises']);
        if (questions.isEmpty) {
          throw FormatException('No exercises found for this lesson yet.');
        }
        // Harder bonus questions, asked only when the learner does well.
        final bonus = [
          for (final q in _parseExercises(session['adaptive_exercises']))
            LessonQueue.harder(q.withLabel('hard')),
        ];
        final arranged = _style.arrange(questions);
        return LessonQueue(
          // Reviews are words the learner has met; new lessons start easy.
          isReview ? arranged : LessonQueue.easyStart(arranged),
          bonus: bonus,
        );
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
      return LessonQueue(questions);
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
  String? _audioOf(QuizQuestion question) =>
      question.audioFor(Provider.of<ThemeService>(context).pronunciationVoice);

  void _autoPlayPrompt(QuizQuestion question) {
    if (_autoPlayedIndex == currentQuestionIndex) return;
    _autoPlayedIndex = currentQuestionIndex;
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final url = question.audioFor(themeService.pronunciationVoice);
    // Near sounds play from their own prompt; held-back audio waits.
    if (url == null || question.holdsAudio) return;
    if (question.type == QuizQuestion.nearSound) return;
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

  /// [correct] and [answerText] are given by exercises answered without
  /// picking an option (build the stack, tracing).
  void _handleAnswer(
    int answerIndex,
    LessonQueue lesson, {
    bool? correct,
    String? answerText,
  }) async {
    if (showFeedback || lesson.answeredCurrent) return;
    final item = lesson.current;
    final isCorrect =
        correct ?? answerIndex == item.question.correctAnswerIndex;
    final responseMs =
        DateTime.now().difference(_questionShownAt).inMilliseconds;
    lesson.answer(
      optionIndex: answerIndex,
      correct: isCorrect,
      ms: responseMs,
      answerText: answerText,
    );
    final themeService = Provider.of<ThemeService>(context, listen: false);
    Feedback.answer(isCorrect, context: context);

    final answered = item.question;
    // Reading help: word counts for "new words only", and the run of right
    // answers behind the "turn off reading help?" suggestion.
    ReadingHelp.instance.recordAnswer(
      answered.romanisation,
      correct: isCorrect,
      mode: themeService.transliterationMode,
      hiddenUntilAnswered: !answered.showsRomanisation(answered: false),
    );
    Analytics.track('question_answered', {
      'topic': _topicName,
      'topic_path': widget.topicFilePath,
      'question_index': currentQuestionIndex,
      'question_count': lesson.length,
      'question_type': answered.type,
      'correct': isCorrect,
      'combo': isCorrect ? _combo + 1 : 0,
      'tibetan': answered.wordTibetan,
      'english': answered.englishGloss,
      'chosen': answered.options[answerIndex],
      'correct_answer': answered.options[answered.correctAnswerIndex],
      'response_ms': responseMs,
      'role': item.role.name,
      'attempt': item.attempt,
      'label': item.label?.id,
      'to_fix': lesson.toFix,
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
    final question = answered;
    final revealUrl = question.audioFor(themeService.pronunciationVoice);
    final revealAudio = question.holdsAudio && revealUrl != null;
    if (revealAudio && themeService.soundEffectsEnabled) {
      final revealGeneration = _generation;
      Future.delayed(const Duration(milliseconds: 600), () async {
        if (!mounted || revealGeneration != _generation) return;
        if (!identical(lesson.current, item)) return;
        try {
          await SoundEffects.instance.duck(0.3);
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

    // One scored attempt per question: a wrong answer is recorded and the
    // quiz moves on, so the score reflects what the learner knew. The word
    // comes back once at the end to fix. The delay is time to read the
    // feedback and see the right answer revealed.
    // A right answer moves on by itself (Continue skips the wait); a wrong
    // one waits for Continue, so the learner can read the right answer.
    if (isCorrect) {
      final generation = _generation;
      Future.delayed(
        revealAudio
            ? const Duration(milliseconds: 2400)
            : const Duration(milliseconds: 1600),
        () {
          if (mounted && generation == _generation) _advance(via: 'auto');
        },
      );
    }
  }

  /// Leaves the answered question for the next one (or the results).
  void _advance({required String via}) {
    final lesson = _lesson;
    if (!mounted || lesson == null || !showFeedback) return;
    _generation++;
    Analytics.track('question_continue', {
      'via': via,
      'correct': lastAnswerCorrect,
      'question_index': currentQuestionIndex,
    });
    if (!lesson.isDone) {
      late int bonusAdded;
      setState(() {
        bonusAdded = lesson.advance();
        selectedAnswerIndex = null;
        showFeedback = false;
      });
      if (bonusAdded > 0) {
        Analytics.track('lesson_bonus_added', {
          'topic': _topicName,
          'count': bonusAdded,
          'first_try_accuracy': (lesson.coreAccuracy * 100).round(),
        });
      }
      _questionShownAt = DateTime.now();
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      _animationController.reset();
      _animationController.forward();
    } else {
      setState(() => showFeedback = false);
      _goToCompletion(lesson.total);
    }
  }

  bool _allowPop = false;

  /// Back in the middle of a lesson: one gentle "stay?" before leaving.
  Future<void> _confirmQuit() async {
    final lesson = _lesson;
    final left = lesson == null ? 0 : lesson.length - lesson.answered;
    Analytics.track('quit_confirm_shown', {
      'topic': _topicName,
      'question_index': currentQuestionIndex,
      'left': left,
    });
    final quit = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Keep going?',
              style: AppTextStyles.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTokens.ink(context),
              ),
            ),
            content: Text(
              left <= 1
                  ? 'Just one question left in this lesson.'
                  : 'Only $left questions left. Finish to keep your XP and streak.',
              style: AppTextStyles.body(context),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Quit',
                  style: AppTextStyles.poppins(
                    fontSize: 15,
                    color: AppTokens.inkSoft(context),
                  ),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, false),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: Text(
                  'Keep learning',
                  style: AppTextStyles.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
    );
    if (!mounted) return;
    Analytics.track(quit == true ? 'quit_confirmed' : 'quit_confirm_stayed', {
      'topic': _topicName,
      'question_index': currentQuestionIndex,
    });
    if (quit == true) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    }
  }

  Future<void> _goToCompletion(int totalQuestions) async {
    final lesson = _lesson!;
    _completed = true;
    final category = _getCategoryFromFilePath(widget.topicFilePath);
    final progressService = Provider.of<ProgressService>(
      context,
      listen: false,
    );

    // Before updateQuizResults, which its first-run estimate reads.
    final lessonsCompleted =
        await LessonMilestones.instance.recordLessonFinished();
    if (!mounted) return;

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
    final accuracy = lesson.accuracy;

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
      'recycled': lesson.recycled,
      'fixed': lesson.fixed,
      'bonus_shown': lesson.bonusShown,
      'bonus_correct': lesson.bonusCorrect,
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
              fixed: lesson.fixed,
              recycled: lesson.recycled,
              lessonsCompleted: lessonsCompleted,
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
    final answers = _lesson?.answers ?? const <LessonAnswer>[];
    final success = await ApiService().submitProgressCompletion({
      'session_id': _remoteSessionId,
      'level_id': _remoteLevelId,
      'xp_earned': xpEarned,
      // The server grades `answers`; the counts are for servers that
      // predate grading, and follow the same rule.
      'correct_answers': score,
      'total_questions': totalQuestions,
      'time_taken_seconds': 0,
      'local_date': ProgressService.localDateString(DateTime.now()),
      if (answers.isNotEmpty && answers.every((a) => a.exerciseId != null))
        'answers': [for (final a in answers) a.toJson()],
    });
    Analytics.track('lesson_progress_submitted', {
      'success': success,
      'topic_path': widget.topicFilePath,
      'answers': answers.length,
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
      // Mid-lesson, Back asks once before leaving.
      canPop: _allowPop || _completed || _lesson == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _trackQuit();
        } else {
          _confirmQuit();
        }
      },
      child: Scaffold(
        backgroundColor: AppTokens.background(context),
        appBar: AppBar(
          title: Text(
            widget.title ?? _getDisplayNameFromFilePath(widget.topicFilePath),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 18,
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
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Leave lesson',
            onPressed: () => Navigator.of(context).maybePop(),
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
        body: ContentWidth(
          maxWidth: ContentWidth.reading,
          child: FutureBuilder<LessonQueue>(
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

              final lesson = snapshot.data;
              if (lesson == null || lesson.isEmpty) {
                return YakNotice(
                  mood: YakMood.thinking,
                  title: 'Nothing here yet',
                  body:
                      "I'm still gathering words for this one. Try another topic.",
                  actionLabel: 'Go back',
                  onAction: () => Navigator.of(context).pop(),
                );
              }

              final item = lesson.current;
              final question = item.question;
              _autoPlayPrompt(question);

              return Stack(
                children: [
                  _buildQuizBody(context, item, lesson),
                  AnswerFeedbackBanner(
                    visible: showFeedback,
                    isCorrect: lastAnswerCorrect,
                    combo: _combo,
                    seed: currentQuestionIndex,
                    // Tibetan answers are shown on the word line below instead.
                    correctAnswerText:
                        !question.hasTibetanOptions &&
                                !question.answersWithoutOptions &&
                                question.correctAnswerIndex >= 0 &&
                                question.correctAnswerIndex <
                                    question.options.length
                            ? question.options[question.correctAnswerIndex]
                            : null,
                    tibetan: question.wordTibetan,
                    romanisation: question.romanisation,
                    onContinue: () => _advance(via: 'button'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildQuizBody(
    BuildContext context,
    LessonItem item,
    LessonQueue lesson,
  ) {
    final question = item.question;
    final label = item.label;
    return Column(
      children: [
        // One slim row: progress, what is left to fix, question count.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (currentQuestionIndex + 1) / lesson.length,
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade700
                            : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                    minHeight: 10,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (lesson.toFix > 0) ...[
                _ToFixChip(count: lesson.toFix),
                const SizedBox(width: 8),
              ],
              Text(
                '${currentQuestionIndex + 1}/${lesson.length}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.inkSoft(context),
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
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
              padding: EdgeInsets.fromLTRB(16, 12, 16, showFeedback ? 240 : 16),
              child: Column(
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        children: [
                          if (label != null) ...[
                            ExerciseLabelPill(label: label),
                            const SizedBox(height: 10),
                          ],
                          Text(
                            _instructionFor(question),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTokens.inkSoft(context),
                            ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                          ),
                          const SizedBox(height: 10),
                          ..._buildPrompt(context, question),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_scriptBody(question, lesson) case final body?)
                    body
                  else
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
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Card(
                            elevation: 1.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: InkWell(
                              onTap:
                                  showFeedback
                                      ? null
                                      : () => _handleAnswer(index, lesson),
                              borderRadius: BorderRadius.circular(15),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  color:
                                      buttonColor ?? AppTokens.surface(context),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
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
                                            fontSize: 15,
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
                                    const SizedBox(width: 12),
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
                                              question.optionRomanisation(
                                                index,
                                              ),
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

  /// The answer area of script exercises that are not a list of options.
  Widget? _scriptBody(QuizQuestion question, LessonQueue lesson) {
    final script = question.script;
    if (script == null) return null;
    switch (question.type) {
      case QuizQuestion.buildStack:
        return BuildStackView(
          key: ValueKey(question.exerciseId ?? currentQuestionIndex),
          payload: script,
          answered: showFeedback,
          onSubmit:
              (built, correct) =>
                  _handleAnswer(0, lesson, correct: correct, answerText: built),
        );
      case QuizQuestion.trace:
        return TracePad(
          key: ValueKey(question.exerciseId ?? currentQuestionIndex),
          char: script.char,
          freehand: script.freehand,
          enabled: !showFeedback,
          onDone:
              (passed, score) => _handleAnswer(
                0,
                lesson,
                correct: passed,
                answerText: score.toStringAsFixed(2),
              ),
        );
      case QuizQuestion.findRoot:
        return FindRootTiles(
          payload: script,
          answered: showFeedback,
          selected: selectedAnswerIndex,
          correctIndex: question.correctAnswerIndex,
          onPick: (i) => _handleAnswer(i, lesson),
        );
    }
    return null;
  }

  /// Share of the questions answered so far that were right, counted as the
  /// server counts it (first attempts; bonus questions only when right).
  int _accuracySoFar() => (_lesson?.accuracy ?? 0).round();

  String _instructionFor(QuizQuestion question) => switch (question.type) {
    QuizQuestion.nearSound when question.script?.mode == 'same_different' =>
      'Do these sound the same?',
    QuizQuestion.nearSound => 'Which letter do you hear?',
    QuizQuestion.buildStack when question.script?.heard == true =>
      'Build the syllable you hear',
    QuizQuestion.buildStack => 'Build this syllable from its parts',
    QuizQuestion.findRoot => 'Tap the root letter',
    QuizQuestion.readSyllable => 'How do you read this?',
    QuizQuestion.trace when question.script?.freehand == true =>
      'Write this letter',
    QuizQuestion.trace => 'Trace this letter',
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
    final script = question.script;

    if (script != null) {
      switch (question.type) {
        case QuizQuestion.nearSound:
          return [NearSoundPrompt(payload: script, answered: showFeedback)];
        case QuizQuestion.buildStack:
          return [
            if (script.heard && audio != null)
              _audioRow(question, audio, size: 56)
            else
              Text(
                script.target,
                textAlign: TextAlign.center,
                style: TibetanType.style(
                  size: TibetanType.letterSize,
                  color: AppTokens.ink(context),
                ),
              ),
            _romanisationOf(question),
            if (showFeedback && audio != null && !script.heard) ...[
              const SizedBox(height: 8),
              _audioRow(question, audio),
            ],
          ];
        case QuizQuestion.trace:
          return [
            Text(
              script.char,
              textAlign: TextAlign.center,
              style: TibetanType.style(
                size: TibetanType.displaySize,
                color: AppTokens.ink(context),
              ),
            ),
            RomanisationText(question.romanisation, fontSize: 18),
            if (audio != null) ...[
              const SizedBox(height: 8),
              _audioRow(question, audio),
            ],
          ];
        case QuizQuestion.readSyllable:
        case QuizQuestion.findRoot:
          return [
            Text(
              question.tibetanText,
              textAlign: TextAlign.center,
              style: TibetanType.style(
                size: TibetanType.letterSize,
                color: AppTokens.ink(context),
              ),
            ),
            if (question.type == QuizQuestion.findRoot)
              _romanisationOf(question),
            if (showFeedback && script.english.isNotEmpty)
              Text(
                script.english,
                style: AppTextStyles.poppins(
                  fontSize: 16,
                  color: AppTokens.inkSoft(context),
                ),
              ),
            if (showFeedback && audio != null) ...[
              const SizedBox(height: 8),
              _audioRow(question, audio),
            ],
          ];
      }
    }

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
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
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
          child: offlineImage(
            question.imageUrl!,
            height: _pictureHeight(context),
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
          fontSize: Breakpoints.isTablet(context) ? 60 : 46,
          fontWeight: FontWeight.w600,
          height: 1.25,
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

  /// The question picture: 200 on tall phones, less on short ones so the
  /// question and its options fit without scrolling.
  double _pictureHeight(BuildContext context) =>
      (MediaQuery.sizeOf(context).height * 0.22).clamp(120.0, 200.0);

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

/// "2 to fix": missed words still to come back in this lesson.
class _ToFixChip extends StatelessWidget {
  const _ToFixChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count ${count == 1 ? 'word' : 'words'} to fix',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.refresh, size: 14, color: AppColors.red),
          const SizedBox(width: 4),
          Text(
            '$count to fix',
            style: AppTextStyles.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTokens.ink(context),
            ),
          ),
        ],
      ),
    );
  }
}
