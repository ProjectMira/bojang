import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/quiz_question.dart';
import '../../services/analytics.dart';
import '../../services/api_service.dart';
import '../../services/pronunciation_player.dart';
import '../../services/theme_service.dart';
import '../../services/user_kv.dart';
import '../../theme/app_tokens.dart';
import '../../theme/tibetan_type.dart';
import '../../widgets/app_text_style.dart';
import '../../widgets/content_width.dart';
import '../../widgets/romanisation_text.dart';
import '../../widgets/script/script_exercise_views.dart';
import '../../widgets/yak_mascot.dart';
import '../../widgets/yak_says.dart';

/// The alphabet gate before Unit 2 (route `/script/gate`): a 10-question
/// reading check that passes at 80%, or, for "I already read Tibetan", a
/// 5-question quick test. The server grades it
/// (`POST /learn/script/gate/complete`) and stores user_kv
/// `script/gate_passed` (and `script/gate_skipped` for the quick test),
/// which `GET /learn/path` reads; the app writes the same keys too.
class ScriptGateScreen extends StatefulWidget {
  const ScriptGateScreen({super.key, this.source});

  final String? source;

  /// Share of right answers that passes.
  static const double passRatio = 0.8;

  /// user_kv namespace and keys.
  static const String kvNamespace = 'script';
  static const String kvPassed = 'gate_passed';
  static const String kvSkipped = 'gate_skipped';

  /// Whether [correct] of [total] passes.
  static bool passes(int correct, int total) =>
      total > 0 && correct / total >= passRatio;

  @override
  State<ScriptGateScreen> createState() => _ScriptGateScreenState();
}

enum _Stage { choose, loading, asking, saving, result, failed }

class _ScriptGateScreenState extends State<ScriptGateScreen> {
  _Stage _stage = _Stage.choose;
  String _mode = 'full';
  String? _sessionId;
  List<QuizQuestion> _questions = [];
  int _index = 0;
  int? _picked;
  bool _answered = false;
  final List<Map<String, dynamic>> _answers = [];
  int _localCorrect = 0;
  Map<String, dynamic>? _result;
  DateTime _shownAt = DateTime.now();

  static const _types = [
    QuizQuestion.multipleChoice,
    QuizQuestion.readSyllable,
    QuizQuestion.findRoot,
    QuizQuestion.buildStack,
  ];

  Future<void> _start(String mode) async {
    setState(() {
      _mode = mode;
      _stage = _Stage.loading;
    });
    Analytics.track('script_gate_started', {'mode': mode, 'source': widget.source ?? 'unknown'});
    final json = await ApiService().getScriptGate(mode: mode, supportedTypes: _types);
    if (!mounted) return;
    final questions = <QuizQuestion>[];
    for (final e in json?['exercises'] as List? ?? const []) {
      try {
        questions.add(QuizQuestion.fromAnyExercise(Map<String, dynamic>.from(e as Map)));
      } catch (_) {}
    }
    if (json == null || questions.isEmpty) {
      setState(() => _stage = _Stage.failed);
      return;
    }
    setState(() {
      _sessionId = json['session_id'] as String?;
      _questions = questions;
      _index = 0;
      _answers.clear();
      _localCorrect = 0;
      _stage = _Stage.asking;
      _shownAt = DateTime.now();
    });
  }

  void _answer(int index, {bool? correct, String? text}) {
    if (_answered) return;
    final q = _questions[_index];
    final right = correct ?? index == q.correctAnswerIndex;
    _answers.add({
      'exercise_id': q.exerciseId,
      'answer': text ?? q.answerIdFor(index),
      'correct': right,
      'ms': DateTime.now().difference(_shownAt).inMilliseconds,
    });
    if (right) _localCorrect++;
    setState(() {
      _picked = index;
      _answered = true;
    });
    final theme = context.read<ThemeService>();
    final url = q.audioFor(theme.pronunciationVoice);
    if (url != null && theme.soundEffectsEnabled) {
      PronunciationPlayer.instance.play(url, volume: theme.pronunciationVolume, source: 'script_gate');
    }
  }

  void _next() {
    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _picked = null;
        _answered = false;
        _shownAt = DateTime.now();
      });
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    setState(() => _stage = _Stage.saving);
    final result = _sessionId == null || !ApiService().isAuthenticated
        ? null
        : await ApiService().completeScriptGate(sessionId: _sessionId!, answers: _answers);
    final passed = result != null
        ? result['passed'] == true
        : ScriptGateScreen.passes(_localCorrect, _questions.length);
    if (passed) {
      await UserKv.instance.update(ScriptGateScreen.kvNamespace, ScriptGateScreen.kvPassed, (_) => true);
      if (_mode == 'quick') {
        await UserKv.instance.update(ScriptGateScreen.kvNamespace, ScriptGateScreen.kvSkipped, (_) => true);
      }
    }
    Analytics.track('script_gate_completed', {
      'mode': _mode,
      'passed': passed,
      'correct': result?['correct'] ?? _localCorrect,
      'total': result?['total'] ?? _questions.length,
      'saved': result != null,
    });
    if (!mounted) return;
    setState(() {
      _result = {
        'passed': passed,
        'correct': result?['correct'] ?? _localCorrect,
        'total': result?['total'] ?? _questions.length,
        'saved': result != null,
      };
      _stage = _Stage.result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.background(context),
      appBar: AppBar(
        title: Text(
          'Reading check',
          style: AppTextStyles.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: AppTokens.ink(context)),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTokens.ink(context),
        systemOverlayStyle: AppTokens.statusBar(context),
      ),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          maxWidth: ContentWidth.reading,
          child: switch (_stage) {
            _Stage.choose => _choose(),
            _Stage.loading || _Stage.saving => const YakLoader(),
            _Stage.asking => _asking(),
            _Stage.result => _resultView(),
            _Stage.failed => YakNotice(
              title: 'Could not load the check',
              body: 'It needs a connection. Try again in a moment.',
              actionLabel: 'Try again',
              onAction: () => _start(_mode),
            ),
          },
        ),
      ),
    );
  }

  Widget _choose() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Unit 2 uses Tibetan script',
          style: AppTextStyles.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppTokens.ink(context)),
        ),
        const SizedBox(height: 8),
        Text(
          'Show you can read letters and syllables, and the path opens. Pass with 8 of 10 right.',
          style: AppTextStyles.poppins(fontSize: 15, color: AppTokens.inkSoft(context)),
        ),
        const SizedBox(height: 12),
        Center(child: Text('ཀ ཁ ག ང', style: TibetanType.style(size: TibetanType.displaySize, color: AppTokens.ink(context)))),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          onPressed: () => _start('full'),
          child: const Text('Take the reading check (10 questions)'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          onPressed: () {
            Analytics.track('script_gate_skip_chosen', {'source': widget.source ?? 'unknown'});
            _start('quick');
          },
          child: const Text('I already read Tibetan (5 quick questions)'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Learn the letters first'),
        ),
      ],
    );
  }

  Widget _asking() {
    final q = _questions[_index];
    final script = q.script;
    final ink = AppTokens.ink(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LinearProgressIndicator(
          value: (_index + (_answered ? 1 : 0)) / _questions.length,
          minHeight: 8,
          borderRadius: BorderRadius.circular(6),
        ),
        const SizedBox(height: 6),
        Text(
          'Question ${_index + 1} of ${_questions.length}',
          style: AppTextStyles.poppins(fontSize: 13, color: AppTokens.inkSoft(context)),
        ),
        const SizedBox(height: 16),
        Text(
          switch (q.type) {
            QuizQuestion.findRoot => 'Tap the root letter',
            QuizQuestion.buildStack => 'Build this syllable from its parts',
            _ => 'How do you read this?',
          },
          textAlign: TextAlign.center,
          style: AppTextStyles.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppTokens.inkSoft(context)),
        ),
        const SizedBox(height: 8),
        Center(child: Text(q.tibetanText, style: TibetanType.style(size: TibetanType.letterSize, color: ink))),
        if (_answered && q.type != QuizQuestion.readSyllable && q.type != QuizQuestion.multipleChoice)
          RomanisationText(q.romanisation, fontSize: 18),
        if (_answered && (script?.english.isNotEmpty ?? false))
          Center(child: Text(script!.english, style: AppTextStyles.poppins(fontSize: 15, color: AppTokens.inkSoft(context)))),
        const SizedBox(height: 16),
        if (q.type == QuizQuestion.findRoot && script != null)
          FindRootTiles(
            payload: script,
            answered: _answered,
            selected: _picked,
            correctIndex: q.correctAnswerIndex,
            onPick: (i) => _answer(i),
          )
        else if (q.type == QuizQuestion.buildStack && script != null)
          BuildStackView(
            key: ValueKey(q.exerciseId),
            payload: script,
            answered: _answered,
            onSubmit: (built, ok) => _answer(0, correct: ok, text: built),
          )
        else
          for (var i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Option(
                text: q.options[i],
                state: !_answered ? null : (i == q.correctAnswerIndex ? true : (i == _picked ? false : null)),
                onTap: _answered ? null : () => _answer(i),
              ),
            ),
        if (_answered) ...[
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _next,
            child: Text(_index < _questions.length - 1 ? 'Next' : 'See result'),
          ),
        ],
      ],
    );
  }

  Widget _resultView() {
    final r = _result!;
    final passed = r['passed'] == true;
    return YakNotice(
      mood: passed ? YakMood.cheering : YakMood.thinking,
      title: passed ? 'You read Tibetan!' : 'Not yet',
      body: passed
          ? '${r['correct']} of ${r['total']} right. Unit 2 is open.'
              '${r['saved'] == true ? '' : ' Sign in and go online to save it to your path.'}'
          : '${r['correct']} of ${r['total']} right; the check needs ${(r['total'] as int) * 4 ~/ 5}. '
              'The letter chart will get you there.',
      actionLabel: passed ? 'Continue' : 'Practise the letters',
      onAction: () => Navigator.of(context).maybePop(passed),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.text, required this.state, required this.onTap});

  final String text;
  final bool? state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fill = switch (state) {
      true => AppTokens.hueTint(AppPalette.green, context),
      false => AppTokens.hueTint(AppPalette.red, context),
      null => AppTokens.surface(context),
    };
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: AppTokens.cardBorder(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            text,
            style: AppTextStyles.poppins(fontSize: 18, color: AppTokens.ink(context)),
          ),
        ),
      ),
    );
  }
}
