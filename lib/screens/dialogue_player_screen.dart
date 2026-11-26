import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dialogue.dart';
import '../models/romanisation.dart';
import '../services/analytics.dart';
import '../services/api_service.dart';
import '../services/feature_flags.dart';
import '../services/progress_service.dart';
import '../services/pronunciation_player.dart';
import '../services/theme_service.dart';
import '../theme/app_tokens.dart';
import '../theme/motion.dart';
import '../theme/tibetan_type.dart';
import '../widgets/app_text_style.dart';
import '../widgets/content_width.dart';
import '../widgets/romanisation_text.dart';

typedef DialogueLoader = Future<Dialogue?> Function(String id);
typedef DialogueAudio = Future<void> Function(String url);

/// Result of finishing a dialogue: `true` when the server accepted it.
typedef DialogueSubmitter =
    Future<bool> Function(Dialogue dialogue, List<DialogueAnswer> answers);

/// Counts the finished dialogue's learning-path node
/// (`POST /learn/path/nodes/dialogue:<id>/complete`).
typedef DialogueNodeCompleter =
    Future<void> Function(String nodeId, int correct, int total);

/// Plays a listening dialogue (plan item #27): lines appear one at a time
/// with the speaker's avatar and audio, a tap shows the English, phonetics
/// follow Settings > Reading Help, then 2 or 3 questions. Signed-in
/// learners' answers are graded by the server through `/progress/complete`;
/// otherwise they are checked here and the day still counts for the streak.
///
/// Route: `/dialogue/<id>` (see [onGenerateRoute]). Behind the `dialogues`
/// kill switch.
class DialoguePlayerScreen extends StatefulWidget {
  static const String routePrefix = '/dialogue/';
  static const String killSwitch = 'dialogues';

  final String dialogueId;

  /// Test seams; the defaults use the API, the pronunciation player and
  /// the learner's settings.
  final DialogueLoader? loader;
  final DialogueAudio? playAudio;
  final DialogueSubmitter? submit;
  final DialogueNodeCompleter? completeNode;
  final TransliterationMode? readingMode;
  final bool? enabled;
  final bool? autoplay;

  const DialoguePlayerScreen({
    super.key,
    required this.dialogueId,
    this.loader,
    this.playAudio,
    this.submit,
    this.completeNode,
    this.readingMode,
    this.enabled,
    this.autoplay,
  });

  static String routeFor(String dialogueId) =>
      '$routePrefix${Uri.encodeComponent(dialogueId)}';

  /// The dialogue's node id on the learning path (`GET /learn/path`).
  static String pathNodeId(String dialogueId) => 'dialogue:$dialogueId';

  /// Builds `/dialogue/<id>`; null for any other route name.
  static Route<bool>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? '';
    if (!name.startsWith(routePrefix)) return null;
    final id = Uri.decodeComponent(name.substring(routePrefix.length));
    if (id.isEmpty || id.contains('/')) return null;
    return MaterialPageRoute<bool>(
      settings: settings,
      builder: (_) => DialoguePlayerScreen(dialogueId: id),
    );
  }

  @override
  State<DialoguePlayerScreen> createState() => _DialoguePlayerScreenState();
}

enum _Phase { loading, failed, disabled, listening, questions, done }

class _DialoguePlayerScreenState extends State<DialoguePlayerScreen> {
  _Phase _phase = _Phase.loading;
  Dialogue? _dialogue;
  int _shown = 0;
  final Set<int> _translated = {};
  int _question = 0;
  String? _picked;
  final List<DialogueAnswer> _answers = [];
  final Stopwatch _clock = Stopwatch();
  final Stopwatch _questionClock = Stopwatch();
  final ScrollController _scroll = ScrollController();
  bool? _submitted;

  bool get _enabled =>
      widget.enabled ??
      FeatureFlags.instance.isEnabled(DialoguePlayerScreen.killSwitch);

  @override
  void initState() {
    super.initState();
    if (!_enabled) {
      _phase = _Phase.disabled;
      Analytics.track('dialogue_disabled', {'dialogue_id': widget.dialogueId});
      return;
    }
    unawaited(_load());
  }

  @override
  void dispose() {
    _scroll.dispose();
    if (widget.playAudio == null) {
      unawaited(PronunciationPlayer.instance.stop());
    }
    super.dispose();
  }

  Future<Dialogue?> _defaultLoader(String id) async {
    final json = await ApiService().getDialogue(id);
    return json == null ? null : Dialogue.fromJson(json);
  }

  Future<void> _load() async {
    setState(() => _phase = _Phase.loading);
    Dialogue? dialogue;
    try {
      dialogue = await (widget.loader ?? _defaultLoader)(widget.dialogueId);
    } catch (_) {
      dialogue = null;
    }
    if (!mounted) return;
    if (dialogue == null || dialogue.lines.isEmpty) {
      Analytics.track('dialogue_load_failed', {
        'dialogue_id': widget.dialogueId,
      });
      setState(() => _phase = _Phase.failed);
      return;
    }
    if (widget.playAudio == null) {
      PronunciationPlayer.instance.prefetch(dialogue.audioUrls);
    }
    Analytics.track('dialogue_started', {
      'dialogue_id': dialogue.id,
      'status': dialogue.status,
      'lines': dialogue.lines.length,
      'questions': dialogue.questions.length,
      'has_audio': dialogue.hasAudio,
      'graded': dialogue.session != null,
    });
    _clock.start();
    setState(() {
      _dialogue = dialogue;
      _phase = _Phase.listening;
      _shown = 0;
    });
    _reveal();
  }

  bool get _autoplay {
    if (widget.autoplay != null) return widget.autoplay!;
    try {
      return context.read<ThemeService>().soundEffectsEnabled;
    } catch (_) {
      return true;
    }
  }

  void _play(DialogueLine line, {required String source}) {
    final url = line.audioUrl;
    if (url == null) return;
    if (widget.playAudio != null) {
      unawaited(widget.playAudio!(url));
    } else {
      unawaited(PronunciationPlayer.instance.play(url, source: source));
    }
  }

  void _reveal() {
    final dialogue = _dialogue!;
    if (_shown >= dialogue.lines.length) return;
    final line = dialogue.lines[_shown];
    setState(() => _shown += 1);
    if (_autoplay) _play(line, source: 'dialogue_auto');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final motion = Motion.read(context);
      final target = _scroll.position.maxScrollExtent;
      if (motion.animates) {
        _scroll.animateTo(
          target,
          duration: motion.scale(const Duration(milliseconds: 300)),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  void _toggleTranslation(int index) {
    setState(() {
      if (!_translated.remove(index)) _translated.add(index);
    });
    Analytics.track('dialogue_translation_toggled', {
      'dialogue_id': _dialogue!.id,
      'line': index + 1,
      'shown': _translated.contains(index),
    });
  }

  void _startQuestions() {
    final dialogue = _dialogue!;
    if (dialogue.questions.isEmpty) {
      unawaited(_finish());
      return;
    }
    _questionClock
      ..reset()
      ..start();
    setState(() {
      _phase = _Phase.questions;
      _question = 0;
      _picked = null;
    });
  }

  void _pick(DialogueOption option) {
    if (_picked != null) return;
    final question = _dialogue!.questions[_question];
    final correct = question.isCorrect(option.id);
    _answers.add(
      DialogueAnswer(
        questionId: question.id,
        optionId: option.id,
        correct: correct,
        ms: _questionClock.elapsedMilliseconds,
      ),
    );
    Analytics.track('dialogue_question_answered', {
      'dialogue_id': _dialogue!.id,
      'question_id': question.id,
      'correct': correct,
    });
    setState(() => _picked = option.id);
  }

  void _nextQuestion() {
    if (_question + 1 >= _dialogue!.questions.length) {
      unawaited(_finish());
      return;
    }
    _questionClock
      ..reset()
      ..start();
    setState(() {
      _question += 1;
      _picked = null;
    });
  }

  Future<bool> _defaultSubmit(
    Dialogue dialogue,
    List<DialogueAnswer> answers,
  ) async {
    final localDate = ProgressService.localDateString(DateTime.now());
    final session = dialogue.session;
    if (session != null && answers.isNotEmpty) {
      return ApiService().submitProgressCompletion(
        dialogueCompletion(
          session: session,
          answers: answers,
          localDate: localDate,
          timeTakenSeconds: _clock.elapsed.inSeconds,
        ),
      );
    }
    // No server session (signed out or the level is missing): the answers
    // were checked here; still count the day for the streak.
    return await ApiService().recordActivity(localDate) != null;
  }

  Future<void> _defaultCompleteNode(
    String nodeId,
    int correct,
    int total,
  ) async {
    final api = ApiService();
    if (!api.isAuthenticated) return;
    await api.completePathNode(
      nodeId,
      correct: total > 0 ? correct : null,
      total: total > 0 ? total : null,
    );
  }

  Future<void> _finish() async {
    final dialogue = _dialogue!;
    _clock.stop();
    setState(() => _phase = _Phase.done);
    final correct = _answers.where((a) => a.correct).length;
    bool ok;
    try {
      ok = await (widget.submit ?? _defaultSubmit)(dialogue, List.of(_answers));
    } catch (_) {
      ok = false;
    }
    // The learning path's dialogue node (signed-in learners only; the
    // server ignores a session under 70%).
    try {
      await (widget.completeNode ?? _defaultCompleteNode)(
        DialoguePlayerScreen.pathNodeId(dialogue.id),
        correct,
        _answers.length,
      );
    } catch (_) {}
    Analytics.track('dialogue_completed', {
      'dialogue_id': dialogue.id,
      'correct': correct,
      'total': _answers.length,
      'graded': dialogue.session != null,
      'submitted': ok,
      'translations_opened': _translated.length,
      'duration_s': _clock.elapsed.inSeconds,
    });
    if (mounted) setState(() => _submitted = ok);
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final dialogue = _dialogue;
    return Scaffold(
      backgroundColor: AppTokens.background(context),
      appBar: AppBar(
        title: Text(dialogue?.title ?? 'Listening'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).maybePop(_submitted ?? false),
        ),
      ),
      body: SafeArea(
        child: ContentWidth(
          maxWidth: ContentWidth.reading,
          child: switch (_phase) {
            _Phase.loading => const Center(child: CircularProgressIndicator()),
            _Phase.failed => _Message(
              text: "This dialogue isn't available right now.",
              action: 'Try again',
              onAction: _load,
            ),
            _Phase.disabled => const _Message(
              text: 'Listening dialogues are switched off for now.',
            ),
            _Phase.listening => _listening(context, dialogue!),
            _Phase.questions => _questions(context, dialogue!),
            _Phase.done => _done(context),
          },
        ),
      ),
    );
  }

  TransliterationMode _mode(BuildContext context) {
    if (widget.readingMode != null) return widget.readingMode!;
    try {
      return context.watch<ThemeService>().transliterationMode;
    } catch (_) {
      return TransliterationMode.defaultMode;
    }
  }

  Widget _listening(BuildContext context, Dialogue dialogue) {
    final mode = _mode(context);
    final finished = _shown >= dialogue.lines.length;
    final tablet = Breakpoints.isTablet(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: EdgeInsets.symmetric(
              horizontal: tablet ? 32 : 16,
              vertical: 16,
            ),
            children: [
              if (dialogue.titleBo.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: TibetanText(
                    dialogue.titleBo,
                    size: TibetanType.titleSize,
                    textAlign: TextAlign.center,
                    color: AppTokens.ink(context),
                  ),
                ),
              if (dialogue.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    dialogue.description,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                      context,
                      color: AppTokens.inkSoft(context),
                    ),
                  ),
                ),
              for (var i = 0; i < _shown; i++)
                _LineBubble(
                  key: ValueKey('dialogue-line-$i'),
                  line: dialogue.lines[i],
                  speaker: dialogue.speakerOf(dialogue.lines[i]),
                  leading: dialogue.isLeading(dialogue.lines[i]),
                  translated: _translated.contains(i),
                  mode: mode,
                  onTap: () => _toggleTranslation(i),
                  onReplay:
                      dialogue.lines[i].audioUrl == null
                          ? null
                          : () {
                            Analytics.track('dialogue_line_replayed', {
                              'dialogue_id': dialogue.id,
                              'line': i + 1,
                            });
                            _play(dialogue.lines[i], source: 'dialogue_replay');
                          },
                ),
              if (_shown == 1 && _translated.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Tap a line to see it in English',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption(
                      context,
                      color: AppTokens.inkSoft(context),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _BottomButton(
          label: finished ? 'Answer questions' : 'Next line',
          onPressed: finished ? _startQuestions : _reveal,
        ),
      ],
    );
  }

  Widget _questions(BuildContext context, Dialogue dialogue) {
    final question = dialogue.questions[_question];
    final picked = _picked;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Question ${_question + 1} of ${dialogue.questions.length}',
                style: AppTextStyles.caption(
                  context,
                  color: AppTokens.inkSoft(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(question.prompt, style: AppTextStyles.title(context)),
              const SizedBox(height: 20),
              for (final option in question.options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OptionTile(
                    key: ValueKey('dialogue-option-${option.id}'),
                    text: option.text,
                    state:
                        picked == null
                            ? _OptionState.idle
                            : question.isCorrect(option.id)
                            ? _OptionState.correct
                            : option.id == picked
                            ? _OptionState.wrong
                            : _OptionState.idle,
                    onTap: picked == null ? () => _pick(option) : null,
                  ),
                ),
            ],
          ),
        ),
        if (picked != null)
          _BottomButton(
            label:
                _question + 1 >= dialogue.questions.length
                    ? 'Finish'
                    : 'Continue',
            onPressed: _nextQuestion,
          ),
      ],
    );
  }

  Widget _done(BuildContext context) {
    final correct = _answers.where((a) => a.correct).length;
    final total = _answers.length;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.headphones_rounded,
                    size: 56,
                    color: dark ? AppColors.greenNight : AppColors.green,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    total == 0
                        ? 'Dialogue finished'
                        : '$correct of $total right',
                    style: AppTextStyles.display(context),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _submitted == false
                        ? "We couldn't save this one. Your answers still count here."
                        : 'Listen again any time from the path.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                      context,
                      color: AppTokens.inkSoft(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _BottomButton(
          label: 'Done',
          onPressed:
              _submitted == null
                  ? null
                  : () => Navigator.of(context).maybePop(_submitted ?? false),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- widgets

Color _speakerColor(BuildContext context, String key) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (key) {
    'coral' => dark ? AppColors.orangeNight : AppColors.orange,
    'teal' => dark ? AppColors.greenNight : AppColors.green,
    'gold' => dark ? AppColors.goldNight : AppColors.goldLip,
    _ => dark ? AppColors.purpleNight : AppColors.purple,
  };
}

/// An original, simple avatar: the speaker's colour as a circle or a
/// rounded square, with the first letter of their name.
class SpeakerAvatar extends StatelessWidget {
  final DialogueSpeaker speaker;
  final double size;

  const SpeakerAvatar({super.key, required this.speaker, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final color = _speakerColor(context, speaker.color);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: speaker.name,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape:
              speaker.shape == 'circle' ? BoxShape.circle : BoxShape.rectangle,
          borderRadius:
              speaker.shape == 'circle'
                  ? null
                  : BorderRadius.circular(size * 0.28),
        ),
        child: ExcludeSemantics(
          child: Text(
            speaker.initial,
            style: AppTextStyles.poppins(
              fontSize: size * 0.45,
              fontWeight: FontWeight.w700,
              color: dark ? AppColors.backgroundDark : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _LineBubble extends StatelessWidget {
  final DialogueLine line;
  final DialogueSpeaker speaker;
  final bool leading;
  final bool translated;
  final TransliterationMode mode;
  final VoidCallback onTap;
  final VoidCallback? onReplay;

  const _LineBubble({
    super.key,
    required this.line,
    required this.speaker,
    required this.leading,
    required this.translated,
    required this.mode,
    required this.onTap,
    this.onReplay,
  });

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    final accent = _speakerColor(context, speaker.color);
    final align = leading ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    final textAlign = leading ? TextAlign.start : TextAlign.end;
    final Widget translation =
        translated && line.english.isNotEmpty
            ? Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                line.english,
                textAlign: textAlign,
                style: AppTextStyles.body(context),
              ),
            )
            : const SizedBox(width: double.infinity);
    final bubble = Flexible(
      child: Material(
        color: AppTokens.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: accent.withValues(alpha: 0.5), width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: align,
                    children: [
                      Text(
                        speaker.name,
                        style: AppTextStyles.caption(context, color: accent),
                      ),
                      TibetanText(
                        line.tibetan,
                        size: TibetanType.bodySize,
                        textAlign: textAlign,
                        color: AppTokens.ink(context),
                      ),
                      RomanisationText(
                        line.romanisation,
                        fontSize: 15,
                        mode: mode,
                        textAlign: textAlign,
                        alignment: align,
                      ),
                      // AnimatedSize asserts with a zero duration
                      // (Settings > Animations > Off).
                      if (motion.scale(const Duration(milliseconds: 200)) ==
                          Duration.zero)
                        translation
                      else
                        AnimatedSize(
                          duration: motion.scale(
                            const Duration(milliseconds: 200),
                          ),
                          curve: Curves.easeOut,
                          alignment: Alignment.topCenter,
                          child: translation,
                        ),
                    ],
                  ),
                ),
                if (onReplay != null)
                  IconButton(
                    icon: const Icon(Icons.volume_up_rounded),
                    tooltip: 'Play ${speaker.name}\'s line',
                    color: accent,
                    onPressed: onReplay,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    final avatar = SpeakerAvatar(speaker: speaker);
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          leading
              ? [
                avatar,
                const SizedBox(width: 10),
                bubble,
                const SizedBox(width: 40),
              ]
              : [
                const SizedBox(width: 40),
                bubble,
                const SizedBox(width: 10),
                avatar,
              ],
    );
    final child = Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: row,
    );
    if (!motion.animates) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion.scale(const Duration(milliseconds: 260)),
      curve: Curves.easeOutCubic,
      builder:
          (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 12),
              child: child,
            ),
          ),
      child: child,
    );
  }
}

enum _OptionState { idle, correct, wrong }

class _OptionTile extends StatelessWidget {
  final String text;
  final _OptionState state;
  final VoidCallback? onTap;

  const _OptionTile({
    super.key,
    required this.text,
    required this.state,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (border, fill, icon) = switch (state) {
      _OptionState.correct => (
        dark ? AppColors.greenNight : AppColors.green,
        dark ? AppColors.greenNightTint : AppColors.greenTint,
        Icons.check_circle_rounded,
      ),
      _OptionState.wrong => (
        dark ? AppColors.redNight : AppColors.red,
        dark ? AppColors.redNightTint : AppColors.redTint,
        Icons.cancel_rounded,
      ),
      _OptionState.idle => (
        dark ? AppColors.inkSoftDark : AppColors.whiteLip,
        AppTokens.surface(context),
        null,
      ),
    };
    return Semantics(
      button: onTap != null,
      selected: state != _OptionState.idle,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(text, style: AppTextStyles.body(context)),
                  ),
                  if (icon != null) Icon(icon, color: border),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _BottomButton({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: onPressed,
          child: Text(
            label,
            style: AppTextStyles.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;

  const _Message({required this.text, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(context),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}
